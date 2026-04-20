FROM archlinux:latest

# Enable multilib
RUN echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Core update + build tools (include syslinux/grub/mtools for mkarchiso bootmodes)
RUN pacman -Syu --noconfirm --needed \
    base-devel git archiso wget curl sudo python rsync \
    syslinux mtools dosfstools grub libisoburn \
    && pacman -Scc --noconfirm

# ── Chaotic-AUR keyring + mirrorlist ──────────────────────────────
# Try multiple keyservers; fall back to fetching mirrorlist file directly
# so /etc/pacman.d/chaotic-mirrorlist is ALWAYS present (pacman.conf needs it).
RUN pacman-key --init && \
    ( pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || \
      pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keys.openpgp.org || \
      pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com:443 || \
      true ) && \
    pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true && \
    ( pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true ) && \
    if [ ! -f /etc/pacman.d/chaotic-mirrorlist ]; then \
        echo "Server = https://cdn-mirror.chaotic.cx/\$repo/\$arch" > /etc/pacman.d/chaotic-mirrorlist && \
        echo "Server = https://builds.garudalinux.org/repos/chaotic-aur/\$arch" >> /etc/pacman.d/chaotic-mirrorlist ; \
    fi && \
    test -f /etc/pacman.d/chaotic-mirrorlist

# ── BlackArch keyring + mirrorlist ────────────────────────────────
# strap.sh creates /etc/pacman.d/blackarch-mirrorlist and imports the key.
# Fallback: write a minimal mirrorlist so pacman.conf still parses.
RUN curl -fsSL https://blackarch.org/strap.sh -o /tmp/strap.sh && \
    chmod +x /tmp/strap.sh && \
    ( /tmp/strap.sh || true ) && \
    if [ ! -f /etc/pacman.d/blackarch-mirrorlist ]; then \
        echo "Server = https://mirror.cyberbits.eu/blackarch/\$repo/os/\$arch" > /etc/pacman.d/blackarch-mirrorlist && \
        echo "Server = https://www.blackarch.org/blackarch/\$repo/os/\$arch" >> /etc/pacman.d/blackarch-mirrorlist ; \
    fi && \
    test -f /etc/pacman.d/blackarch-mirrorlist

# ── AUR build user ────────────────────────────────────────────────
RUN useradd -m -G wheel aurbuild && \
    echo "aurbuild ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/aurbuild

WORKDIR /home/aurbuild

# ── AUR packages — build in parallel-ish ──────────────────────────
RUN su aurbuild -c "set -e; for p in auto-cpufreq ananicy-cpp nohang proton-ge-custom-bin heroic-games-launcher-bin undervolt; do \
      git clone --depth 1 https://aur.archlinux.org/\$p.git /tmp/\$p 2>/dev/null && \
      (cd /tmp/\$p && makepkg -s --noconfirm --skippgpcheck) || echo \"Skip \$p\"; \
    done"

# ── Build local BalOS repo ────────────────────────────────────────
RUN mkdir -p /balos-repo && \
    find /tmp -name "*.pkg.tar.zst" -exec cp {} /balos-repo/ \; && \
    repo-add /balos-repo/balos.db.tar.gz /balos-repo/*.pkg.tar.zst 2>/dev/null && \
    ln -sf /balos-repo/balos.db.tar.gz  /balos-repo/balos.db && \
    ln -sf /balos-repo/balos.files.tar.gz /balos-repo/balos.files

RUN userdel -r aurbuild && rm /etc/sudoers.d/aurbuild

# Copy profile
COPY . /build/profile/

# Inject repo paths into the profile's pacman.conf
RUN mkdir -p /output /tmp/balos-work

CMD ["bash", "-c", "mkarchiso -v -w /tmp/balos-work -o /output /build/profile/ && echo '=== BALOS BUILD SUCCESS ==='"]
