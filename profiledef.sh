#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="balos"
iso_label="BALOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="BalOS Project <https://balos.io>"
iso_application="BalOS — The Hacker's Operating System"
iso_version="1.0.0-dark"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux'
    'uefi.systemd-boot'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '22' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-22' '--ultra')

file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/sudoers.d/10-balos"]="0:0:440"
    ["/root"]="0:0:750"
    ["/root/.automated_script.sh"]="0:0:755"
    ["/root/customize_airootfs.sh"]="0:0:755"
    ["/usr/bin/bal"]="0:0:755"
    ["/usr/bin/balshield"]="0:0:755"
    ["/usr/bin/balstealth"]="0:0:755"
    ["/usr/bin/balhack"]="0:0:755"
    ["/usr/bin/balboost"]="0:0:755"
    ["/usr/bin/balsaver"]="0:0:755"
    ["/usr/bin/balmonitor"]="0:0:755"
    ["/usr/bin/balpanic"]="0:0:755"
    ["/usr/bin/balinit"]="0:0:755"
    ["/usr/bin/balnet"]="0:0:755"
    ["/usr/bin/balkernel-build"]="0:0:755"
    ["/etc/skel/.zshrc"]="0:0:644"
    ["/etc/skel/.config"]="0:0:755"
)
