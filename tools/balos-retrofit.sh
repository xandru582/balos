#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# BalOS — balos-retrofit.sh
#
# Añade la personalidad BalOS (bal* tools, tema SDDM matrix, dotfiles
# zsh/kitty/fastfetch/starship, balai+ollama, MOTD, servicios) a una
# instalación creada con una ISO vieja que NO portó estos archivos.
#
# Ejecuta DESDE la instalación (no desde el live USB):
#   sudo bash -c "curl -fsSL https://raw.githubusercontent.com/\
# xandru582/balos/claude/fix-iso-installation-O8vtH/tools/\
# balos-retrofit.sh | bash"
#
# Tras ejecutarlo: cierra sesión / reinicia.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'; N='\033[0m'; B='\033[1m'
step() { echo -e "${G}[$(date +%H:%M:%S)]${N} ${B}$*${N}"; }
warn() { echo -e "${Y}[warn]${N} $*"; }
die()  { echo -e "${R}[fatal]${N} $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Ejecútame con sudo."

REPO_BRANCH="claude/fix-iso-installation-O8vtH"
WORKDIR=/tmp/balos-retrofit
TARGET_USER="${SUDO_USER:-}"
[[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]] && \
    TARGET_USER=$(awk -F: '$3 >= 1000 && $3 < 65000 {print $1; exit}' /etc/passwd || true)

step "Retrofit de BalOS — usuario objetivo: ${TARGET_USER:-<ninguno>}"

# ── Paquetes que faltan en una instalación "base" ───────────────────
step "Instalando paquetes faltantes..."
pacman -Sy --needed --noconfirm \
    ollama \
    zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
    rsync git reflector fastfetch kitty starship \
    2>&1 | tail -5

# ── Clonar los archivos del repo ────────────────────────────────────
step "Clonando el repo en $WORKDIR..."
rm -rf "$WORKDIR"
git clone -b "$REPO_BRANCH" --depth 1 https://github.com/xandru582/balos "$WORKDIR" 2>&1 | tail -3

SRC="$WORKDIR/airootfs"
[[ -d "$SRC/usr/bin" ]] || die "Contenido del repo inesperado ($SRC)"

# ── Lista de rutas a portar ─────────────────────────────────────────
PATHS=(
    usr/bin/bal*
    etc/skel/.
    etc/zsh/zshrc.d
    etc/profile.d/balos-motd.sh
    etc/balos
    etc/sddm.conf.d/balos.conf
    etc/motd
    etc/issue
    etc/os-release
    etc/environment
    etc/nftables.conf
    etc/sysctl.d/99-balos.conf
    etc/auto-cpufreq.conf
    etc/gamemode.ini
    etc/tlp.conf
    etc/proxychains.conf
    etc/dnscrypt-proxy/dnscrypt-proxy.toml
    etc/unbound/unbound.conf
    etc/tor/torrc
    etc/suricata/balos.yaml
    etc/usbguard
    etc/snapper/configs/root
    etc/snapper/configs/home
    etc/conf.d/snapper
    etc/systemd/user/balai-serve.service
    etc/systemd/system/balos-firstboot.service
    etc/systemd/system/balos-suricata.service
    etc/systemd/system/balos-welcome.service
    etc/mkinitcpio.d/linux-zen.preset
    usr/share/balos
    usr/share/sddm/themes/balos-matrix
    usr/share/applications/bal*.desktop
)

step "Copiando archivos BalOS al sistema..."
copied=0
skipped=0
cd "$SRC"
for pattern in "${PATHS[@]}"; do
    # shellcheck disable=SC2086  # want glob expansion
    for src_item in $pattern; do
        [[ -e "$src_item" ]] || { skipped=$((skipped+1)); continue; }
        rsync -a --relative "$src_item" / 2>/dev/null
        copied=$((copied+1))
    done
done
echo "  → $copied copiados / $skipped no encontrados"

# ── chmod +x de los bal* scripts (por si acaso) ─────────────────────
chmod +x /usr/bin/bal* 2>/dev/null || true

# ── Repoblar home del usuario desde /etc/skel ───────────────────────
if [[ -n "$TARGET_USER" ]] && id "$TARGET_USER" &>/dev/null; then
    step "Re-populando ~$TARGET_USER desde /etc/skel (no sobrescribe)..."
    home=$(eval echo "~$TARGET_USER")
    cp -rn /etc/skel/. "$home/" 2>/dev/null || true
    chown -R "$TARGET_USER:$TARGET_USER" "$home"
fi

# ── Activar servicios ──────────────────────────────────────────────
step "Activando servicios BalOS..."
for svc in ollama.service balos-firstboot.service balos-welcome.service; do
    systemctl enable "$svc" 2>/dev/null && echo "  → $svc" || warn "skip $svc"
done
systemctl --global enable balai-serve.service 2>/dev/null || true
systemctl start ollama.service 2>/dev/null || true

# ── Bajar el modelo balai (Qwen2.5:1.5b, ~1GB) ─────────────────────
step "Descargando modelo de balai (Qwen2.5:1.5b, ~1GB — puede tardar)..."
if systemctl is-active --quiet ollama.service; then
    sudo -u ollama ollama pull qwen2.5:1.5b-instruct-q4_K_M 2>&1 | tail -3 \
        || warn "fallo bajando el modelo — puedes hacerlo luego: sudo -u ollama ollama pull qwen2.5:1.5b-instruct-q4_K_M"
else
    warn "ollama no arrancó — el modelo se bajará al primer uso de balai"
fi

# ── Limpieza ────────────────────────────────────────────────────────
rm -rf "$WORKDIR"

echo ""
echo -e "${G}${B}✓ Retrofit completado.${N}"
echo -e "Cierra sesión y vuelve a entrar (o reinicia) para ver el tema Matrix de SDDM"
echo -e "y que el zsh cargue los plugins + los aliases ${C}?${N}/${C}??${N} de balai."
