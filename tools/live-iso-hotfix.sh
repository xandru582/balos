#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# BalOS — live-iso-hotfix.sh
#
# Parchea la ISO vieja que ya tienes en el pen para que `balos-install`
# funcione, sin esperar a un rebuild completo. Aplica los mismos fixes
# que el PR #1:
#
#   1. Monta @log antes de crear /mnt/var/log  (fix del crash al montar)
#   2. Habilita [multilib]                    (steam, wine-staging)
#   3. Instala blackarch strap.sh             (metasploit, exploitdb, …)
#   4. Refresca mirrorlist con reflector      (por si estaba vacía)
#   5. Sincroniza bases de datos de pacman
#
# Idempotente — puedes ejecutarlo las veces que quieras.
#
# Uso (dentro de la sesión live, como root):
#     curl -fsSL https://raw.githubusercontent.com/xandru582/balos/\
#       claude/fix-iso-installation-O8vtH/tools/live-iso-hotfix.sh | sudo bash
#
#   o bien, si ya lo tienes descargado:
#     sudo bash live-iso-hotfix.sh
#
# Después:
#     sudo balos-install
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; C='\033[0;36m'; N='\033[0m'; B='\033[1m'
step() { echo -e "${G}[$(date +%H:%M:%S)]${N} ${B}$*${N}"; }
warn() { echo -e "${Y}[warn]${N} $*"; }
die()  { echo -e "${R}[fatal]${N} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Ejecútame con sudo / como root."

INSTALLER=/usr/bin/balos-install
[[ -f "$INSTALLER" ]] || die "$INSTALLER no existe — ¿estás dentro de la ISO de BalOS?"

# ── 0. Limpia montajes y LUKS de intentos previos ────────────────────
step "Limpiando montajes de intentos previos..."
umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true
cryptsetup close balos_root 2>/dev/null || true

# ── 1. Parchea balos-install (bug del mount de @log) ─────────────────
step "Parcheando $INSTALLER..."
if grep -qF 'mkdir -p /mnt/{boot,home,var,var/log,.snapshots,swap}' "$INSTALLER"; then
    # Quita var/log del mkdir inicial (lo ocultaba el mount de @var)
    sed -i 's|mkdir -p /mnt/{boot,home,var,var/log,.snapshots,swap}|mkdir -p /mnt/{boot,home,var,.snapshots,swap}|' "$INSTALLER"
    # Inserta mkdir /mnt/var/log *después* de montar @var
    sed -i '/subvol=@var"/a mkdir -p /mnt/var/log' "$INSTALLER"
    echo "  → parche de @log aplicado"
else
    echo "  → ya estaba parcheado"
fi

# ── 2. [multilib] ────────────────────────────────────────────────────
step "Comprobando [multilib]..."
if grep -qE '^\[multilib\]' /etc/pacman.conf; then
    echo "  → ya habilitado"
else
    cat >> /etc/pacman.conf <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
    echo "  → añadido"
fi

# ── 3. [blackarch] vía strap.sh ──────────────────────────────────────
step "Comprobando [blackarch]..."
if grep -qE '^\[blackarch\]' /etc/pacman.conf; then
    echo "  → ya habilitado"
else
    pacman-key --init >/dev/null 2>&1 || true
    TMP=$(mktemp)
    if ! curl -fsSL https://blackarch.org/strap.sh -o "$TMP"; then
        warn "No he podido bajar strap.sh — ¿tienes red?"
        warn "Prueba: ping -c1 1.1.1.1  y  nmcli device status"
        die  "Sin red, no puedo instalar blackarch."
    fi
    bash "$TMP"
    rm -f "$TMP"
    echo "  → blackarch instalado"
fi

# ── 4. Mirrorlist ────────────────────────────────────────────────────
step "Refrescando mirrorlist (reflector)..."
if command -v reflector >/dev/null 2>&1; then
    reflector --latest 20 --protocol https --sort rate \
              --save /etc/pacman.d/mirrorlist 2>/dev/null \
        && echo "  → OK" \
        || warn "reflector falló — si /etc/pacman.d/mirrorlist ya tiene servers sin # saltando esto está bien"
else
    warn "reflector no instalado — saltando"
fi

# ── 5. Sync ──────────────────────────────────────────────────────────
step "pacman -Syy..."
pacman -Syy

# ── 6. Check sanity ──────────────────────────────────────────────────
step "Verificando que los paquetes críticos se resuelven..."
ALL_OK=true
for p in metasploit steam wine-staging nmap hashcat; do
    if pacman -Si "$p" >/dev/null 2>&1; then
        echo -e "  ${G}✓${N} $p"
    else
        echo -e "  ${Y}✗${N} $p (no encontrado — ignora si no usas el perfil que lo pide)"
        ALL_OK=false
    fi
done

echo ""
if $ALL_OK; then
    echo -e "${G}${B}Listo.${N} Ahora lanza el instalador:"
else
    echo -e "${Y}${B}Hay avisos arriba${N} — pero el instalador debería funcionar para perfiles normales."
fi
echo -e "    ${C}sudo balos-install${N}"
