#!/usr/bin/env bash
# BalOS live — auto-start script.
# Runs on root's first TTY login (via .zlogin / .bash_profile in the live image).
# Kept intentionally minimal: the real work happens in systemd units and the
# interactive `bal` menu.

set -eu

# Only run once per boot.
FLAG=/run/balos-autostart.done
[ -e "$FLAG" ] && exit 0
touch "$FLAG"

# Welcome banner (non-fatal if fastfetch not installed yet).
if command -v fastfetch >/dev/null 2>&1; then
    fastfetch --logo arch 2>/dev/null || true
fi

cat <<'EOF'

  [0;32mBalOS live[0m — hack · play · evade · endure

  Type [1;36mbal[0m for the interactive menu
  Type [1;36mbalos-install[0m to install to disk
  Type [1;36mexit[0m to return to the login prompt

EOF
