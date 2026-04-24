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

# Stage the kernel recipe into airootfs/ so customize_airootfs.sh can see
# it at /root/kernel inside the chroot. The source lives at the repo
# root (kernel/) so makepkg can also consume it outside the ISO. Prior
# to this fix, the kernel recipe was silently missing from every ISO
# because `cp -r /root/kernel/* ...` had `|| true` on the end.
#
# Also stage the extra pacman repos used at install time:
#   - /balos-repo        → custom AUR-compiled packages (auto-cpufreq, proton-ge, …)
#   - blackarch-mirrorlist → needed so the live ISO's pacman can sync [blackarch]
#   - pacman.conf        → copied verbatim to /etc/pacman.conf so `balos-install`
#                          can pacstrap metasploit/AUR-built tools against the
#                          same repo set used to build the ISO.
# Without these, the live ISO has only core/extra and pacstrap fails with
# "target not found: metasploit" (and similar for every AUR-compiled pkg).
CMD ["bash", "-c", "\
    set -e; \
    mkdir -p /build/profile/airootfs/root/kernel; \
    cp -r /build/profile/kernel/. /build/profile/airootfs/root/kernel/; \
    mkdir -p /build/profile/airootfs/etc/pacman.d /build/profile/airootfs/balos-repo /build/profile/airootfs/usr/share/balos; \
    cp /etc/pacman.d/blackarch-mirrorlist /build/profile/airootfs/etc/pacman.d/blackarch-mirrorlist; \
    cp -a /balos-repo/. /build/profile/airootfs/balos-repo/; \
    cp /build/profile/pacman.conf /build/profile/airootfs/etc/pacman.conf; \
    cp /build/profile/packages.x86_64 /build/profile/airootfs/usr/share/balos/packages.x86_64; \
    mkarchiso -v -w /tmp/balos-work -o /output /build/profile/; \
    echo '=== BALOS BUILD SUCCESS ==='"]
