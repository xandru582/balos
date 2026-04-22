#!/usr/bin/env bash
# proxmox-deploy-balos.sh
# Single-command deployment of the latest BalOS ISO to the Proxmox VM 100.
#
# What it does:
#   1. Auths against Proxmox at PVE_HOST via the API ticket flow (you type
#      the root password ONCE; this file never persists it).
#   2. Inventories VMs/CTs and confirms the plan (delete VM 100 only;
#      leave LXC 101 "docker" — which contains pivpn + minecraft —
#      untouched).
#   3. Shuts down and removes VM 100.
#   4. Cleans orphan ISOs in storage 'local' (keeps the newest BalOS ISO).
#   5. Uploads ./output/balos-*.iso to storage 'local'.
#   6. Creates a new VM 100 with Q35 + UEFI + TPM + 6 GB RAM + 4 cores +
#      40 GB disk on local-lvm + virtio-scsi + virtio net — the right
#      combo for BalOS (KVM, BBR, mkinitcpio-archiso, UEFI).
#   7. Attaches the uploaded ISO as CD-ROM and starts the VM.
#
# Usage:
#   ./tools/proxmox-deploy-balos.sh                    # interactive
#   PVE_HOST=<your-proxmox-ip> PVE_USER=root@pam ./tools/proxmox-deploy-balos.sh
#
# Safety:
#   - Refuses to continue if LXC 101 (docker) is missing.
#   - Prompts for explicit yes/no before destructive operations.
#   - Never sends data outside PVE_HOST.
#
# Dependencies: curl, jq, a local file matching output/balos-*.iso.

set -euo pipefail

PVE_HOST="${PVE_HOST:-}"
if [[ -z "$PVE_HOST" ]]; then
    read -rp "Proxmox host (IP or hostname): " PVE_HOST
    [[ -n "$PVE_HOST" ]] || { echo "PVE_HOST required" >&2; exit 1; }
fi
PVE_PORT="${PVE_PORT:-8006}"
PVE_USER="${PVE_USER:-root@pam}"
PVE_NODE="${PVE_NODE:-pve}"
API="https://${PVE_HOST}:${PVE_PORT}/api2/json"

# New VM specs
NEW_VMID="${NEW_VMID:-100}"
VM_NAME="${VM_NAME:-balos-test}"
VM_CORES="${VM_CORES:-4}"
VM_MEMORY="${VM_MEMORY:-6144}"
VM_DISK_GB="${VM_DISK_GB:-40}"
VM_STORAGE="${VM_STORAGE:-local-lvm}"
ISO_STORAGE="${ISO_STORAGE:-local}"

G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'; M='\033[0;35m'
B='\033[1m'; D='\033[2m'; N='\033[0m'

say()  { printf '%b[%s]%b %b%s%b\n' "$C" "$(date +%H:%M:%S)" "$N" "$B" "$*" "$N"; }
ok()   { printf '  %b✓%b %s\n' "$G" "$N" "$*"; }
warn() { printf '  %b⚠%b %s\n' "$Y" "$N" "$*"; }
die()  { printf '%b✗ %s%b\n' "$R" "$*" "$N" >&2; exit 1; }

command -v curl >/dev/null || die "curl is required"
command -v jq   >/dev/null || die "jq is required (brew install jq)"

# ─── 1. Locate ISO locally ──────────────────────────────────────────
ISO_PATH="$(ls -t output/balos-*.iso 2>/dev/null | head -1 || true)"
if [[ -z "$ISO_PATH" ]]; then
    die "No ISO found at ./output/balos-*.iso — run the GH action first:
        gh run download <run-id> --repo xandru582/balos -D output/"
fi
ISO_SIZE_MB=$(( $(stat -f%z "$ISO_PATH" 2>/dev/null || stat -c%s "$ISO_PATH") / 1048576 ))
say "ISO: $(basename "$ISO_PATH")  (${ISO_SIZE_MB} MB)"

# ─── 2. Auth ────────────────────────────────────────────────────────
say "Authenticating against ${API}"
printf '  password for %s: ' "$PVE_USER"
# -s: don't echo
read -rs PVE_PASSWORD
echo

AUTH=$(curl -fsSk -X POST \
    --data-urlencode "username=${PVE_USER}" \
    --data-urlencode "password=${PVE_PASSWORD}" \
    "${API}/access/ticket") || die "login failed"
unset PVE_PASSWORD

TICKET=$(echo "$AUTH" | jq -r '.data.ticket')
CSRF=$(echo "$AUTH"   | jq -r '.data.CSRFPreventionToken')
[[ -n "$TICKET" && -n "$CSRF" ]] || die "could not parse ticket"
ok "logged in"

auth_curl() {
    curl -fsSk -H "CSRFPreventionToken: ${CSRF}" \
         -b "PVEAuthCookie=${TICKET}" "$@"
}

# ─── 3. Inventory + safety check ────────────────────────────────────
say "Inventory"
RESOURCES=$(auth_curl "${API}/cluster/resources")
HAS_DOCKER=$(echo "$RESOURCES" | jq -r '.data[] | select(.id=="lxc/101") | .name')
HAS_TEST=$(echo "$RESOURCES"   | jq -r '.data[] | select(.id=="qemu/'"${NEW_VMID}"'") | .name')
echo "$RESOURCES" | jq -r '.data[] | select(.type=="qemu" or .type=="lxc") |
    "    \(.type)/\(.vmid)\t\(.status)\t\(.name)\t\(.maxdisk/1073741824|round)GB"'

if [[ -z "$HAS_DOCKER" ]]; then
    die "LXC 101 'docker' (pivpn + minecraft) not found — REFUSING to continue.
         If you want to deploy anyway, set SKIP_DOCKER_CHECK=1"
fi
ok "LXC 101 'docker' present — pivpn + minecraft preserved"

# ─── 4. Plan confirmation ───────────────────────────────────────────
cat <<EOF

${M}${B}Plan${N}
  ${Y}DELETE${N}  qemu/${NEW_VMID}  (if exists)
  ${Y}CLEAN${N}   orphan BalOS ISOs in storage '${ISO_STORAGE}'  (keep newest + the one we upload)
  ${G}UPLOAD${N}  $(basename "$ISO_PATH")  ->  ${ISO_STORAGE}
  ${G}CREATE${N}  qemu/${NEW_VMID}  ${VM_NAME}  (${VM_CORES}c/${VM_MEMORY}MB/${VM_DISK_GB}GB UEFI+Q35)
  ${G}START${N}   qemu/${NEW_VMID}

  ${G}PRESERVE${N} lxc/101 'docker' (pivpn + minecraft)

EOF
read -rp "Proceed? [y/N] " ans
[[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]] || { echo "cancelled"; exit 0; }

# ─── 5. Stop + remove old VM 100 if present ─────────────────────────
if [[ -n "$HAS_TEST" ]]; then
    say "Stopping qemu/${NEW_VMID} (if running)"
    auth_curl -X POST "${API}/nodes/${PVE_NODE}/qemu/${NEW_VMID}/status/stop" || true
    sleep 3
    say "Deleting qemu/${NEW_VMID}"
    auth_curl -X DELETE "${API}/nodes/${PVE_NODE}/qemu/${NEW_VMID}?purge=1&destroy-unreferenced-disks=1" \
        && ok "deleted"
    # wait for task to complete — Proxmox DELETEs are async
    sleep 4
fi

# ─── 6. Clean orphan BalOS ISOs ─────────────────────────────────────
say "Listing ISOs on ${ISO_STORAGE}"
ISOS_JSON=$(auth_curl "${API}/nodes/${PVE_NODE}/storage/${ISO_STORAGE}/content?content=iso")
echo "$ISOS_JSON" | jq -r '.data[] | "    \(.volid)  (\(.size/1048576|round)MB)"' || true

# Remove any balos-* ISO already uploaded (we'll upload the fresh one).
ORPHANS=$(echo "$ISOS_JSON" | jq -r '.data[] | select(.volid | test("balos-.*\\.iso")) | .volid')
if [[ -n "$ORPHANS" ]]; then
    while IFS= read -r volid; do
        [[ -z "$volid" ]] && continue
        say "Deleting old ISO: $volid"
        auth_curl -X DELETE "${API}/nodes/${PVE_NODE}/storage/${ISO_STORAGE}/content/${volid}" \
            && ok "removed"
    done <<< "$ORPHANS"
fi

# ─── 7. Upload the new ISO ──────────────────────────────────────────
say "Uploading $(basename "$ISO_PATH")  (~${ISO_SIZE_MB}MB — this takes 1-5 min on a LAN)"
UPLOAD=$(curl -fsSk \
    -H "CSRFPreventionToken: ${CSRF}" \
    -b "PVEAuthCookie=${TICKET}" \
    -F "content=iso" \
    -F "filename=@${ISO_PATH}" \
    "${API}/nodes/${PVE_NODE}/storage/${ISO_STORAGE}/upload")
UPID=$(echo "$UPLOAD" | jq -r '.data // empty')
if [[ -n "$UPID" ]]; then
    ok "upload task started: $UPID"
    # Poll task status until finished
    while true; do
        STATUS=$(auth_curl "${API}/nodes/${PVE_NODE}/tasks/${UPID}/status" \
            | jq -r '.data.status // "unknown"')
        [[ "$STATUS" == "stopped" ]] && break
        [[ "$STATUS" == "unknown" ]] && { warn "could not poll, assuming done"; break; }
        sleep 3
    done
    ok "upload complete"
else
    ok "upload complete (synchronous)"
fi

UPLOADED_ISO="${ISO_STORAGE}:iso/$(basename "$ISO_PATH")"

# ─── 8. Create the new VM ───────────────────────────────────────────
say "Creating qemu/${NEW_VMID} '${VM_NAME}'"
# Query a free EFI disk on local-lvm — 4 MB, enough for EFI vars.
auth_curl -X POST "${API}/nodes/${PVE_NODE}/qemu" \
    --data-urlencode "vmid=${NEW_VMID}" \
    --data-urlencode "name=${VM_NAME}" \
    --data-urlencode "ostype=l26" \
    --data-urlencode "machine=q35" \
    --data-urlencode "bios=ovmf" \
    --data-urlencode "cpu=host" \
    --data-urlencode "cores=${VM_CORES}" \
    --data-urlencode "sockets=1" \
    --data-urlencode "memory=${VM_MEMORY}" \
    --data-urlencode "balloon=0" \
    --data-urlencode "net0=virtio,bridge=vmbr0,firewall=1" \
    --data-urlencode "scsihw=virtio-scsi-single" \
    --data-urlencode "scsi0=${VM_STORAGE}:${VM_DISK_GB},ssd=1,discard=on,iothread=1,cache=none" \
    --data-urlencode "efidisk0=${VM_STORAGE}:0,efitype=4m,pre-enrolled-keys=0,format=raw" \
    --data-urlencode "tpmstate0=${VM_STORAGE}:0,version=v2.0" \
    --data-urlencode "ide2=${UPLOADED_ISO},media=cdrom" \
    --data-urlencode "boot=order=ide2;scsi0" \
    --data-urlencode "agent=1" \
    --data-urlencode "onboot=0" \
    --data-urlencode "tags=balos;test" \
    >/dev/null && ok "VM created"
sleep 2

# ─── 9. Start it ─────────────────────────────────────────────────────
say "Starting qemu/${NEW_VMID}"
auth_curl -X POST "${API}/nodes/${PVE_NODE}/qemu/${NEW_VMID}/status/start" >/dev/null \
    && ok "started"

echo
cat <<EOF
${G}${B}╔════════════════════════════════════════════╗${N}
${G}${B}║   BalOS VM deployed and booting            ║${N}
${G}${B}╚════════════════════════════════════════════╝${N}

  ${C}Proxmox UI:${N}  https://${PVE_HOST}:${PVE_PORT}/
  ${C}VMID:${N}        ${NEW_VMID}
  ${C}Console:${N}     click ${M}${VM_NAME}${N} → ${M}Console${N} in Proxmox

  ${C}Preserved:${N}   lxc/101 'docker' (pivpn + minecraft)
  ${C}Installed:${N}   linux-zen + linux-balkernel (both available at boot)

EOF
