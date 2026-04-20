FROM archlinux:latest

# Enable multilib AND disable pacman's seccomp sandbox.
# DisableSandbox is required when building under QEMU/Rosetta emulation
# (arm64 host → amd64 container): the pacman 'alpm' sandbox user uses
# syscalls that aren't properly translated, producing:
#   "error restricting syscalls via seccomp: 22"
# Harmless on native x86_64 — disables only pacman's internal privsep,
# not the container's own sandboxing.
RUN echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf && \
    sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf

# Core update + build tools (include syslinux/grub/mtools for mkarchiso bootmodes)
RUN pacman -Syu --noconfirm --needed \
    base-devel git archiso wget curl sudo python rsync \
    syslinux mtools dosfstools grub libisoburn \
    && pacman -Scc --noconfirm

# ── Init pacman keyring (needed for BlackArch strap.sh below) ─────
RUN pacman-key --init

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
