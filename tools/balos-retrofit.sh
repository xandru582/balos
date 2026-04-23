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

# ── Herramientas mínimas para el resto del script ──────────────────
step "Instalando herramientas base del retrofit..."
pacman -Sy --needed --noconfirm rsync git curl 2>&1 | tail -3

# ── Asegurar [blackarch] en pacman.conf (para metasploit, etc.) ─────
if ! grep -qE '^\[blackarch\]' /etc/pacman.conf; then
    step "Añadiendo repo [blackarch]..."
    pacman-key --init >/dev/null 2>&1 || true
    TMP=$(mktemp)
    if curl -fsSL https://blackarch.org/strap.sh -o "$TMP" && bash "$TMP"; then
        echo "  → blackarch instalado"
    else
        warn "No pude instalar strap.sh (¿sin red?). Los paquetes de pentest no se instalarán."
    fi
    rm -f "$TMP"
fi

# ── Skippeo de paquetes compilados en [balos] (repo no disponible) ──
# Esos 6 paquetes AUR los compila el Dockerfile y viven en /balos-repo
# en el live. Desde una instalación vanilla no están accesibles.
BALOS_REPO_PKGS=(auto-cpufreq proton-ge-custom-bin ananicy-cpp nohang heroic-games-launcher-bin undervolt)
BALOS_REPO_AVAILABLE=false
if grep -qE '^\[balos\]' /etc/pacman.conf && [[ -f /balos-repo/balos.db ]]; then
    BALOS_REPO_AVAILABLE=true
fi

# ── Clonar los archivos del repo ────────────────────────────────────
step "Clonando el repo en $WORKDIR..."
rm -rf "$WORKDIR"
git clone -b "$REPO_BRANCH" --depth 1 https://github.com/xandru582/balos "$WORKDIR" 2>&1 | tail -3

SRC="$WORKDIR/airootfs"
[[ -d "$SRC/usr/bin" ]] || die "Contenido del repo inesperado ($SRC)"

# ── Instalar los 480+ paquetes BalOS declarados en packages.x86_64 ──
MANIFEST="$WORKDIR/packages.x86_64"
if [[ -r "$MANIFEST" ]]; then
    step "Instalando el stack completo de BalOS (~480 paquetes)..."
    SKIP_RE='^(arch-install-scripts|mkinitcpio-archiso|mkinitcpio-nfs-utils|syslinux)$'
    if ! $BALOS_REPO_AVAILABLE; then
        SKIP_RE="$SKIP_RE|^($(IFS='|'; echo "${BALOS_REPO_PKGS[*]}"))$"
        warn "Sin [balos] repo activo — saltando: ${BALOS_REPO_PKGS[*]}"
    fi
    mapfile -t MANIFEST_PKGS < <(
        grep -vE '^\s*(#|$)' "$MANIFEST" | grep -vE "$SKIP_RE"
    )
    # pacman -S es idempotente con --needed; --noconfirm evita prompts.
    # Si algún paquete falla (típicamente blackarch si la mirror está caída)
    # no paramos el retrofit — seguimos con lo copiable.
    pacman -S --needed --noconfirm "${MANIFEST_PKGS[@]}" 2>&1 | tail -5 \
        || warn "pacman reportó errores — revisa arriba (suele ser [blackarch] o repos que faltan)."
else
    warn "packages.x86_64 no encontrado en el repo; instalando sólo lo crítico."
    pacman -S --needed --noconfirm ollama zsh-autosuggestions \
        zsh-syntax-highlighting zsh-history-substring-search \
        fastfetch kitty starship reflector 2>&1 | tail -5
fi

# ── Lista de rutas a portar ─────────────────────────────────────────
PATHS=(
    usr/bin/bal*
    usr/share/applications/bal*.desktop
    usr/share/icons/hicolor/scalable/apps/balai.svg
    usr/share/kio/servicemenus/balai.desktop
    usr/share/krunner/dbusplugins/balai.desktop
    usr/share/dbus-1/services/com.balos.BalAIRunner.service
    usr/share/bash-completion/completions/bal
    usr/share/zsh/site-functions/_bal
    usr/share/zsh/site-functions/_balai
    usr/share/man/man1/bal.1
    usr/share/man/man1/balai.1
    usr/share/man/man1/balai-chat.1
    usr/share/balos
    usr/share/sddm/themes/balos-matrix
    etc/skel/.
    etc/zsh/zshrc.d
    etc/profile.d/balos-motd.sh
    etc/motd
    etc/issue
    etc/os-release
    etc/environment
    etc/balos
    etc/nftables.conf
    etc/sudoers.d/10-balos
    etc/security/limits.d/99-balos.conf
    etc/polkit-1/actions/org.balos.policy
    etc/polkit-1/rules.d/49-balos.rules
    etc/udev/rules.d/70-balos-usb-ducky.rules
    etc/udev/rules.d/99-balos.rules
    etc/usbguard
    etc/proxychains.conf
    etc/dnscrypt-proxy/dnscrypt-proxy.toml
    etc/unbound/unbound.conf
    etc/tor/torrc
    etc/suricata/balos.yaml
    etc/modprobe.d/balos.conf
    etc/sysctl.d/99-balos.conf
    etc/auto-cpufreq.conf
    etc/gamemode.ini
    etc/tlp.conf
    etc/default/earlyoom
    etc/pipewire/pipewire.conf.d/10-balos-gaming.conf
    etc/systemd/zram-generator.conf
    etc/mkinitcpio.d/linux-zen.preset
    etc/sddm.conf.d/balos.conf
    etc/NetworkManager/conf.d/balos.conf
    etc/systemd/user/balai-serve.service
    etc/systemd/system/balos-firstboot.service
    etc/systemd/system/balos-suricata.service
    etc/systemd/system/balos-welcome.service
    etc/snapper/configs/root
    etc/snapper/configs/home
    etc/conf.d/snapper
    etc/pacman.d/hooks/zzz-balai-summary.hook
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

# ── Recargar subsistemas que leen archivos en caliente ──────────────
step "Recargando udev / systemd / polkit / man-db..."
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
systemctl reload polkit 2>/dev/null || true
mandb -q 2>/dev/null || true

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
