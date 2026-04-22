#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# BalOS — customize_airootfs.sh
# Runs INSIDE the ISO build chroot. Sets up the live environment.
# ═══════════════════════════════════════════════════════════════
set -e -u

echo "▶ BalOS customization starting..."

# ── Locale ──────────────────────────────────────────────────────
sed -i 's/#\(en_US\.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/#\(es_ES\.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/#\(de_DE\.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/#\(fr_FR\.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# ── Hostname ────────────────────────────────────────────────────
echo balos > /etc/hostname
cat > /etc/hosts << 'EOF'
127.0.0.1   localhost
::1         localhost
127.0.1.1   balos.localdomain balos
EOF

# ── Time / clock ────────────────────────────────────────────────
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# ── Default shell → zsh ─────────────────────────────────────────
chsh -s /bin/zsh root 2>/dev/null || true

# ── Live user (no password; for ISO demo) ───────────────────────
useradd -m -G wheel,audio,video,input,storage,optical,kvm,scanner,gamemode,wireshark -s /bin/zsh balos 2>/dev/null || true
echo "balos:balos" | chpasswd 2>/dev/null || true
echo "root:balos"  | chpasswd 2>/dev/null || true

# Copy /etc/skel into existing live user
cp -rT /etc/skel /home/balos/
chown -R balos:balos /home/balos

# ── Sudo: wheel + live user ─────────────────────────────────────
mkdir -p /etc/sudoers.d
cat > /etc/sudoers.d/10-balos << 'EOF'
%wheel ALL=(ALL:ALL) ALL
balos  ALL=(ALL:ALL) NOPASSWD: ALL
Defaults lecture=never
Defaults insults
EOF
chmod 440 /etc/sudoers.d/10-balos

# ── Services — enable ──────────────────────────────────────────
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable bluetooth
systemctl enable tlp
systemctl enable thermald           2>/dev/null || true
# auto-cpufreq not packaged — tlp + power-profiles-daemon handle this.
systemctl enable fstrim.timer
systemctl enable systemd-timesyncd
systemctl enable reflector.timer    2>/dev/null || true
systemctl enable nftables
systemctl enable dnscrypt-proxy
systemctl enable irqbalance         2>/dev/null || true
systemctl enable earlyoom           2>/dev/null || true
systemctl enable fail2ban           2>/dev/null || true
systemctl enable apparmor           2>/dev/null || true
systemctl enable systemd-zram-setup@zram0.service 2>/dev/null || true
systemctl enable ollama                            2>/dev/null || true

# Mask things we don't want
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask NetworkManager-wait-online.service   2>/dev/null || true

# ── Make BalOS tools executable ─────────────────────────────────
chmod +x /usr/bin/bal* 2>/dev/null || true

# ── Pre-bake small LLM for balai (offline AI assistant) ─────────
# We pull qwen2.5:1.5b (~1GB Q4) while the chroot still has network.
# After this, `balai` works 100% offline. Non-fatal if pull fails —
# user can run `balai setup` after first boot with internet.
#
# Path alignment: ollama's systemd service in Arch runs as user `ollama`
# with HOME=/var/lib/ollama, so it reads models from
# /var/lib/ollama/.ollama/models. We bake there so both the service and
# balai's user-level fallback see the same model store.
if command -v ollama &>/dev/null; then
    echo "[balai] pulling model into squashfs (this can take 5-10 min)…"
    BALAI_MODEL_BAKE="qwen2.5:1.5b-instruct-q4_K_M"
    BALAI_MODELS_DIR="/var/lib/ollama/.ollama/models"
    mkdir -p "$BALAI_MODELS_DIR"

    # Make sure the ollama user exists (the pacman post-install hook
    # usually creates it; belt-and-braces here for chroot race conditions).
    id ollama &>/dev/null || useradd -r -s /usr/bin/nologin -d /var/lib/ollama ollama 2>/dev/null || true

    # Start ollama in background in the chroot. Export HOME so the
    # default model path matches the service's path.
    export HOME=/var/lib/ollama
    export OLLAMA_MODELS="$BALAI_MODELS_DIR"
    ollama serve >/tmp/ollama-build.log 2>&1 &
    OLLAMA_PID=$!

    # Wait up to 20 s for the API to come up
    for i in {1..40}; do
        curl -fsS --max-time 1 http://127.0.0.1:11434/api/tags &>/dev/null && break
        sleep 0.5
    done

    if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags &>/dev/null; then
        if ollama pull "$BALAI_MODEL_BAKE" 2>&1 | tail -5; then
            echo "[balai] model baked: $BALAI_MODEL_BAKE"
        else
            echo "[balai] WARN: model pull failed — user can run 'balai setup' after first boot"
        fi
    else
        echo "[balai] WARN: ollama serve didn't come up in chroot — skipping pre-bake"
    fi

    kill "$OLLAMA_PID" 2>/dev/null || true
    wait "$OLLAMA_PID" 2>/dev/null || true

    # Fix ownership so the systemd service (running as user ollama) can read.
    if id ollama &>/dev/null; then
        chown -R ollama:ollama /var/lib/ollama 2>/dev/null || true
    fi
    unset HOME OLLAMA_MODELS
fi

# ── Systemd drop-in to harden ollama for BalOS ──────────────────
# Keeps the model store path explicit and disables the phone-home.
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/balos.conf << 'DROPIN'
[Service]
# Explicit model path — matches where customize_airootfs.sh bakes models.
Environment="OLLAMA_MODELS=/var/lib/ollama/.ollama/models"
# Bind to loopback only — no remote inference.
Environment="OLLAMA_HOST=127.0.0.1:11434"
# Disable ollama.com cloud and telemetry.
Environment="OLLAMA_NO_CLOUD=true"
Environment="OLLAMA_ORIGINS=http://localhost,http://127.0.0.1"
# Keep model loaded in RAM for 15 min after last request. Cold-start for
# Qwen2.5-1.5B is ~4 s; sequences like `balai tip` → `balai doctor` used
# to pay it twice in quick succession. 15m covers an average session.
Environment="OLLAMA_KEEP_ALIVE=15m"
# Cap parallel requests to 1 — this box might also be gaming; we'd
# rather the single request run fast than two compete.
Environment="OLLAMA_NUM_PARALLEL=1"
# Only one model resident at a time (saves 1-4 GB RAM when people
# experiment with a 3B alongside the default 1.5B).
Environment="OLLAMA_MAX_LOADED_MODELS=1"
# Accept requests only from the loopback interface. Belt-and-braces
# complement to OLLAMA_HOST=127.0.0.1.
Environment="OLLAMA_ORIGINS=http://localhost,http://127.0.0.1,http://[::1]"
DROPIN

# ── Wordlists: stable symlink so balhack / balrecon hints resolve ──
# seclists ships rockyou under /usr/share/seclists/Passwords/Leaked-Databases/.
mkdir -p /usr/share/wordlists
for wl in \
    "Passwords/Leaked-Databases/rockyou.txt:rockyou.txt" \
    "Discovery/Web-Content/common.txt:common.txt" \
    "Discovery/Web-Content/big.txt:big.txt"
do
    src="/usr/share/seclists/${wl%%:*}"
    dst="/usr/share/wordlists/${wl##*:}"
    [[ -e "$src" ]] && ln -sf "$src" "$dst" 2>/dev/null || true
done

# ── Place kernel recipe for post-install build ──────────────────
# The Dockerfile CMD copies kernel/ into airootfs/root/kernel before
# mkarchiso runs, so the tree MUST exist here. Fail loudly if it
# doesn't — silent skips in this branch were why earlier ISOs
# shipped an empty /usr/share/balos/kernel.
if [ ! -d /root/kernel ] || [ -z "$(ls -A /root/kernel 2>/dev/null)" ]; then
    echo "✗ kernel recipe missing at /root/kernel — aborting build" >&2
    exit 1
fi
mkdir -p /usr/share/balos/kernel
cp -r /root/kernel/. /usr/share/balos/kernel/
# Stage the post-install side-effects that ship with linux-balkernel so
# the running live ISO already benefits from the hardening sysctl and
# udev I/O rules (without needing to rebuild the kernel first).
install -Dm644 /root/kernel/balos-sysctl.conf /usr/lib/sysctl.d/99-balos-kernel.conf
install -Dm644 /root/kernel/99-balos-io-scheduler.rules \
    /usr/lib/udev/rules.d/99-balos-io-scheduler.rules
install -Dm644 /root/kernel/balos-mkinitcpio.conf \
    /usr/share/balos/mkinitcpio.conf.example
install -Dm644 /root/kernel/balos-kernel-cmdline.conf \
    /usr/lib/balos/kernel-cmdline.conf
chmod 644 /usr/lib/sysctl.d/99-balos-kernel.conf \
          /usr/lib/udev/rules.d/99-balos-io-scheduler.rules

# ── Plymouth (boot splash) with BalOS theme ─────────────────────
if command -v plymouth-set-default-theme &>/dev/null; then
    plymouth-set-default-theme -R spinner 2>/dev/null || true
fi

# ── Default editor ──────────────────────────────────────────────
ln -sf /usr/bin/nvim /usr/local/bin/vi 2>/dev/null || true
ln -sf /usr/bin/nvim /usr/local/bin/vim 2>/dev/null || true

# ── Flathub for easy app install ────────────────────────────────
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ── Password policy (live: lenient; installed: user sets via balinit) ──
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 0/' /etc/login.defs

# ── Reseed pacman keys (needed after chroot) ────────────────────
pacman-key --init        || true
pacman-key --populate    || true

# ── Regenerate initramfs for zen kernel ─────────────────────────
mkinitcpio -P 2>/dev/null || true

# ── Copy install script to live root desktop ───────────────────
mkdir -p /home/balos/Desktop
cat > /home/balos/Desktop/install-balos.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install BalOS to disk
Comment=Run the BalOS installer (wipes the chosen disk!)
Icon=system-software-install
Exec=kitty --hold sudo /usr/bin/balos-install
Terminal=false
Categories=System;
EOF
chmod +x /home/balos/Desktop/install-balos.desktop
chown balos:balos /home/balos/Desktop/install-balos.desktop

# ── Friendly fortune / banner on first login of live session ───
cat > /home/balos/.config/balos/firstrun << 'EOF'
Welcome to BalOS Live.

This is a LIVE environment — changes are lost on reboot.
To install to disk: double-click "Install BalOS to disk" on the desktop.

Explore:
  bal              — command overview
  bal hack         — pentest workspaces
  bal boost|saver  — power profiles
  fastfetch        — system info

Default credentials:  balos / balos     (root password: balos)
EOF
chown -R balos:balos /home/balos/.config

echo "▶ BalOS customization complete."
