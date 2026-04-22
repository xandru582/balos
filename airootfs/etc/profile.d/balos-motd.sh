# BalOS login greeting — runs once per session, fails silently.
# Skipped outside interactive shells, inside nested subshells, and when
# $SSH_TTY is set (users SSHing in typically have their own MOTD).
case "$-" in *i*) ;; *) return 0 ;; esac
[ -n "${BALOS_MOTD_DONE:-}" ] && return 0
[ -n "${SSH_TTY:-}" ] && return 0
[ -x /usr/bin/balai-motd ] || return 0
BALOS_MOTD_DONE=1
export BALOS_MOTD_DONE
/usr/bin/balai-motd 2>/dev/null || true
