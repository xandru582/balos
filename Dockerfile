FROM archlinux:latest

# Enable multilib
RUN echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

# Core update + build tools (include syslinux/grub/mtools for mkarchiso bootmodes)
RUN pacman -Syu --noconfirm --needed \
    base-devel git archiso wget curl sudo python rsync \
    syslinux mtools dosfstools grub libisoburn \
    && pacman -Scc --noconfirm

# ── Chaotic-AUR keyring + mirrorlist ──────────────────────────────
RUN pacman-key --init && \
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key 3056513887B78AEB && \
    pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || \
    echo "Chaotic-AUR setup failed, continuing without it"

# ── BlackArch keyring + mirrorlist ────────────────────────────────
RUN curl -O https://blackarch.org/strap.sh && \
    chmod +x strap.sh && \
    ./strap.sh || echo "BlackArch setup will retry in chroot"

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
