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
# We pull qwen2.5:0.5b (~400 MB Q4) while the chroot still has network.
# After this, `balai` works 100% offline. Non-fatal if pull fails —
# user can run `balai setup` after first boot with internet.
if command -v ollama &>/dev/null; then
    echo "[balai] pulling model into squashfs (this takes a few minutes)…"
    export OLLAMA_MODELS=/var/lib/ollama/models
    mkdir -p "$OLLAMA_MODELS"
    # Start ollama in background inside chroot
    ollama serve >/tmp/ollama-build.log 2>&1 &
    OLLAMA_PID=$!
    # Wait for it to respond (up to 20 s)
    for i in {1..40}; do
        curl -fsS --max-time 1 http://127.0.0.1:11434/api/tags &>/dev/null && break
        sleep 0.5
    done
    if curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags &>/dev/null; then
        ollama pull qwen2.5:0.5b-instruct-q4_K_M 2>&1 | tail -5 || \
            echo "[balai] model pull failed — user can run 'balai setup' later"
    else
        echo "[balai] ollama serve didn't come up in chroot — skipping pre-bake"
    fi
    kill "$OLLAMA_PID" 2>/dev/null || true
    wait "$OLLAMA_PID" 2>/dev/null || true
    # Fix ownership (ollama user gets created by its package)
    if id ollama &>/dev/null; then
        chown -R ollama:ollama /var/lib/ollama 2>/dev/null || true
    fi
fi

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
mkdir -p /usr/share/balos/kernel
cp -r /root/kernel/* /usr/share/balos/kernel/ 2>/dev/null || true

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
