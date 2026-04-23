#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# BalOS — fix-boot-entry.sh
#
# Parchea una instalación de BalOS que fue hecha con una ISO con el
# bug del `rd.luks.name=` (sólo `sd-encrypt` lo entiende) cuando los
# HOOKS del initramfs usan el hook legacy `encrypt`. Re-escribe la
# línea `options=` de los entries de systemd-boot para usar la
# sintaxis correcta `cryptdevice=UUID=<LUKS>:balos_root`.
#
# Uso (desde el USB live, como root):
#   curl -fsSL https://raw.githubusercontent.com/xandru582/balos/\
#     claude/fix-iso-installation-O8vtH/tools/fix-boot-entry.sh | sudo bash
#
# Asume:
#   - La instalación vive en /dev/nvme0n1 (si no, pasar DISK=/dev/sdX)
#   - La partición ESP es la primera, la LUKS la segunda
#   - El mapper se llama balos_root (lo que hace balos-install)
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'; B='\033[1m'
step() { echo -e "${G}[$(date +%H:%M:%S)]${N} ${B}$*${N}"; }
warn() { echo -e "${Y}[warn]${N} $*"; }
die()  { echo -e "${R}[fatal]${N} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Ejecútame con sudo / como root."

# ── Detectar disco de instalación ───────────────────────────────────
DISK="${DISK:-}"
if [[ -z "$DISK" ]]; then
    # Busca la partición con label BALOS_LUKS, o la primera NVMe con un LUKS
    for p in $(lsblk -lnpo NAME); do
        lbl=$(lsblk -ndo LABEL "$p" 2>/dev/null || true)
        fstype=$(lsblk -ndo FSTYPE "$p" 2>/dev/null || true)
        if [[ "$lbl" == "BALOS_LUKS" ]] || [[ "$fstype" == "crypto_LUKS" ]]; then
            DISK="${p%p*}"   # nvme0n1p2 → nvme0n1
            [[ "$DISK" == "$p" ]] && DISK="${p%[0-9]}"  # sdX1 → sdX
            LUKS_PART="$p"
            break
        fi
    done
fi
[[ -z "${LUKS_PART:-}" ]] && die "No encuentro ninguna partición LUKS. Pasa DISK=/dev/XXX manualmente."

# Partición ESP (la primera partición del disco)
if [[ "$DISK" =~ nvme ]]; then
    ESP_PART="${DISK}p1"
else
    ESP_PART="${DISK}1"
fi

echo -e "${C}Disco:${N}       $DISK"
echo -e "${C}ESP:${N}         $ESP_PART"
echo -e "${C}LUKS:${N}        $LUKS_PART"
echo ""

# ── Abrir LUKS ───────────────────────────────────────────────────────
if [[ -e /dev/mapper/balos_root ]]; then
    step "balos_root ya está abierto"
else
    step "Abriendo LUKS (te pedirá la passphrase)..."
    cryptsetup open "$LUKS_PART" balos_root
fi

# ── Montar / y /boot ────────────────────────────────────────────────
step "Montando @ y ESP..."
mkdir -p /mnt
findmnt /mnt >/dev/null 2>&1 || mount -o subvol=@ /dev/mapper/balos_root /mnt
findmnt /mnt/boot >/dev/null 2>&1 || mount "$ESP_PART" /mnt/boot

# ── Obtener UUID de la LUKS ─────────────────────────────────────────
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PART")
[[ -n "$LUKS_UUID" ]] || die "No pude leer UUID de $LUKS_PART"
echo -e "${C}LUKS UUID:${N}   $LUKS_UUID"

# ── Parchear las entries ────────────────────────────────────────────
step "Parcheando /mnt/boot/loader/entries/balos*.conf..."
PATCHED=0
for entry in /mnt/boot/loader/entries/balos.conf /mnt/boot/loader/entries/balos-fallback.conf; do
    [[ -f "$entry" ]] || continue
    if grep -q "rd\.luks\.name=" "$entry"; then
        sed -i "s|rd\.luks\.name=[^= ]*=balos_root|cryptdevice=UUID=$LUKS_UUID:balos_root|g" "$entry"
        PATCHED=$((PATCHED+1))
        echo "  → $entry"
    fi
done
[[ $PATCHED -eq 0 ]] && warn "No encontré ninguna entry con rd.luks.name= (¿ya estaba parcheada?)"

# ── Mostrar resultado ────────────────────────────────────────────────
echo ""
step "Resultado:"
for entry in /mnt/boot/loader/entries/balos.conf /mnt/boot/loader/entries/balos-fallback.conf; do
    [[ -f "$entry" ]] || continue
    echo -e "${C}$entry${N}"
    grep -n "options" "$entry" || true
done

# ── Cerrar y ofrecer reboot ─────────────────────────────────────────
echo ""
step "Listo. Desmontando..."
umount -R /mnt
cryptsetup close balos_root

echo ""
echo -e "${G}${B}OK.${N} Saca el USB y reinicia:"
echo -e "    ${C}sudo reboot${N}"
