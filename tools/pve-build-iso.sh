#!/usr/bin/env bash
# pve-build-iso.sh
#
# Builds the BalOS ISO on a Proxmox host using the on-host Docker
# toolchain (native x86_64 — much faster than CI or an Apple-Silicon
# Mac). Uploads the resulting ISO to storage 'local' when done.
#
# USAGE (from your Mac / workstation):
#
#   ssh root@<pve-ip> \
#       'bash -s' < tools/pve-build-iso.sh
#
# Or copy-paste once onto the PVE shell:
#
#   curl -fsSL https://raw.githubusercontent.com/xandru582/balos/main/tools/pve-build-iso.sh | bash
#
# Parameters (env vars, all optional):
#   REPO_URL    git repo to clone    (default: xandru582/balos)
#   REPO_BRANCH branch to build       (default: main)
#   ISO_STORAGE Proxmox storage id    (default: local)
#   WORK_DIR    host scratch dir      (default: /var/balos-build)
#
# Prerequisites on the PVE host (installed/ensured by the script):
#   - git
#   - docker (Debian package 'docker.io' or official CE)
#
# The script leaves /var/balos-build/output/balos-*.iso on the host and
# also copies it into Proxmox storage 'local' so it's immediately
# selectable when creating a VM.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/xandru582/balos.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"
ISO_STORAGE="${ISO_STORAGE:-local}"
WORK_DIR="${WORK_DIR:-/var/balos-build}"

G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'
B='\033[1m'; D='\033[2m'; N='\033[0m'
say()  { printf '%b[%s]%b %b%s%b\n' "$C" "$(date +%H:%M:%S)" "$N" "$B" "$*" "$N"; }
ok()   { printf '  %b✓%b %s\n' "$G" "$N" "$*"; }
die()  { printf '%b✗ %s%b\n' "$R" "$*" "$N" >&2; exit 1; }

# ── 0. Sanity checks ────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "run as root on the PVE host"
[[ -d /etc/pve ]] || die "this doesn't look like a Proxmox host (/etc/pve missing)"

say "Preparing build environment"

# ── 1. Install dependencies on the host if missing ──────────────────
command -v git    >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq git; }
command -v docker >/dev/null 2>&1 || {
    say "Installing Docker (official get.docker.com script)"
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
}

# ── 2. Clone or refresh the repo ────────────────────────────────────
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
if [[ -d balos/.git ]]; then
    say "Refreshing existing clone"
    cd balos
    git fetch origin "$REPO_BRANCH"
    git reset --hard "origin/${REPO_BRANCH}"
else
    say "Cloning ${REPO_URL} (${REPO_BRANCH})"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" balos
    cd balos
fi
ok "repo at $(git rev-parse --short HEAD)"

# ── 3. Disk-space preflight ─────────────────────────────────────────
# mkarchiso + pacman cache + squashfs staging needs ~30 GB.
avail_gb=$(df -BG --output=avail "$WORK_DIR" | tail -1 | tr -d 'G ')
if (( avail_gb < 30 )); then
    die "only ${avail_gb} GB free in $WORK_DIR — need at least 30 GB"
fi
ok "${avail_gb} GB free"

# ── 4. Build — delegate to build.sh (uses Docker under the hood) ───
say "Running build.sh (this takes 20-40 min on native x86_64)"
chmod +x ./build.sh
./build.sh

# ── 5. Locate the produced ISO ──────────────────────────────────────
ISO_PATH=$(ls -t output/balos-*.iso 2>/dev/null | head -1 || true)
[[ -n "$ISO_PATH" && -f "$ISO_PATH" ]] || die "no ISO produced"
ISO_SIZE_MB=$(( $(stat -c%s "$ISO_PATH") / 1048576 ))
ok "ISO: $(basename "$ISO_PATH") (${ISO_SIZE_MB} MB)"

# ── 6. Copy into Proxmox storage 'local' so it's visible in the UI ─
PVE_ISO_DIR="/var/lib/vz/template/iso"
# Resolve the storage's actual ISO directory via pvesm (handles NFS /
# other backends too). Fallback to the well-known local path.
if STORAGE_PATH=$(pvesm path "${ISO_STORAGE}:" 2>/dev/null); then
    # pvesm path returns something like /var/lib/vz/ for 'local'
    PVE_ISO_DIR="${STORAGE_PATH%/}/template/iso"
fi
if [[ ! -d "$PVE_ISO_DIR" ]]; then
    mkdir -p "$PVE_ISO_DIR"
fi

# Remove any previous balos-*.iso so VMs created with the old one
# break cleanly rather than silently using stale content.
ls "${PVE_ISO_DIR}"/balos-*.iso 2>/dev/null && {
    say "Removing previous BalOS ISOs in ${ISO_STORAGE}"
    rm -f "${PVE_ISO_DIR}"/balos-*.iso
}

say "Publishing ISO to Proxmox storage ${ISO_STORAGE}"
cp "$ISO_PATH" "${PVE_ISO_DIR}/"
ok "available at ${ISO_STORAGE}:iso/$(basename "$ISO_PATH")"

# ── 7. Tell the user exactly how to proceed ────────────────────────
cat <<EOF

${G}${B}╔═══════════════════════════════════════════════════════════╗${N}
${G}${B}║   BalOS ISO built and published to Proxmox                ║${N}
${G}${B}╚═══════════════════════════════════════════════════════════╝${N}

  ${C}file:${N}     ${PVE_ISO_DIR}/$(basename "$ISO_PATH")
  ${C}storage:${N}  ${ISO_STORAGE}:iso/$(basename "$ISO_PATH")
  ${C}size:${N}     ${ISO_SIZE_MB} MB

  Next steps — create a test VM in Proxmox UI:
    Create VM → OS → ISO image → ${ISO_STORAGE} → $(basename "$ISO_PATH")
        System:  Machine q35,  BIOS ovmf (UEFI),  SCSI Controller VirtIO SCSI single
        Disk:    40 GB, local-lvm, ssd=on, discard=on
        CPU:     host, 4 cores
        Memory:  6144 MB (balloon off for accurate benchmarks)
        Network: virtio, vmbr0
    Start and enjoy.

EOF
