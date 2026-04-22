# ═══════════════════════════════════════════════════════════════
# BalOS · balai — shell integration for zsh
# Sourced from ~/.zshrc via the `for f in /etc/zsh/zshrc.d/*.zsh` hook.
# Exposes `?`, `wtf`, the Alt-E widget, and gentle failure hints.
# ═══════════════════════════════════════════════════════════════

# Only set this up for interactive shells; scripts don't need it.
[[ -o interactive ]] || return 0
command -v balai &>/dev/null || return 0

# ── `?` — one-shot query ────────────────────────────────────────
# Usage:  ? how do I enable stealth mode
# Usage:  ? what's my battery
? () {
    if [[ $# -eq 0 ]]; then
        echo "usage: ? <your question>  (e.g.  ? how do I enable stealth)"
        return 1
    fi
    balai "$*"
}

# ── `??` — generate + confirm + run a command ──────────────────
# Usage:  ?? find all python files modified today
?? () {
    if [[ $# -eq 0 ]]; then
        echo "usage: ?? <intent>  (e.g.  ?? zip my Downloads folder)"
        return 1
    fi
    balai cmd "$*"
}

# ── `wtf` — explain the last command (or its error) ─────────────
# No arg → explain last history line.
# With arg → explain that text / file.
# Piped stdin → explain the piped content.
wtf () {
    if [[ ! -t 0 ]]; then
        balai explain
        return
    fi
    if [[ $# -eq 0 ]]; then
        balai explain --last
    else
        balai explain "$@"
    fi
}

# Longer aliases for discoverability.
alias ai='balai'
alias howto='balai'
alias explain='balai explain'

# ── `aifix` — diagnose the LAST failed command (or given text) ──
# With no args: feed balai the last command + its exit status so it has
# full context without the user having to paste anything.
aifix () {
    if [[ $# -gt 0 ]]; then
        balai fix "$*"
        return
    fi
    local last_cmd="${BALAI_LAST_CMD:-}"
    local last_exit="${BALAI_LAST_EXIT:-?}"
    if [[ -z "$last_cmd" ]]; then
        last_cmd=$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//')
    fi
    if [[ -z "$last_cmd" ]]; then
        echo "aifix: no previous command recorded; paste the error or pipe it"
        balai fix
        return
    fi
    balai fix "Command: $last_cmd
Exit status: $last_exit
(Please diagnose what likely failed and propose a concrete fix.)"
}

# ── Alt-E widget: send current command line to `balai cmd` ──────
# Writes whatever is in ZLE's buffer to `balai cmd` as the intent, then
# lets balai stream the suggestion. Bound to ^[e (Alt-E).
balai-cmd-widget () {
    local intent="$BUFFER"
    if [[ -z "$intent" ]]; then
        zle -M "balai: type an intent first, then press Alt-E"
        return 0
    fi
    zle -I
    print -P "%F{magenta}%B▸ balai cmd:%b%f $intent"
    balai cmd "$intent"
    zle reset-prompt
}
zle -N balai-cmd-widget
bindkey '^[e' balai-cmd-widget

# ── Alt-? widget: send current command line to `balai` (explain) ─
# Useful when you typed something like `git rebase -i HEAD~5` and
# want the AI to sanity-check before pressing Enter.
balai-explain-widget () {
    local line="$BUFFER"
    if [[ -z "$line" ]]; then
        zle -M "balai: type a command first, then press Alt-?"
        return 0
    fi
    zle -I
    print -P "%F{magenta}%B▸ balai explain:%b%f $line"
    balai explain "$line"
    zle reset-prompt
}
zle -N balai-explain-widget
bindkey '^[?' balai-explain-widget

# ── Command-not-found → offer AI-based guess ────────────────────
# Plasma's package-query hook may already be bound; we chain politely.
if ! typeset -f command_not_found_handler > /dev/null 2>&1; then
    command_not_found_handler () {
        local cmd="$1"
        echo "zsh: command not found: $cmd" >&2
        # If it looks like the user wanted a bal subcommand, surface it.
        if [[ "$cmd" =~ ^(hak|hack|panic|shield|stealth|boost|saver|vpn|monitor|status|ai) ]]; then
            echo "did you mean:  bal $cmd   ?" >&2
        fi
        # Don't auto-run balai — just hint. Running a 1.5 B model on every typo
        # would be obnoxious.
        echo "hint: run  ? $cmd  to ask BalAI what this is" >&2
        return 127
    }
fi

# ── Postcommand hook — hint when something fails ────────────────
# ONE compact line after a non-zero exit, pointing at wtf/aifix.
# Noisy-command-allowlist: don't bark on grep/test/[ exits.
autoload -Uz add-zsh-hook

# Stash every command as it runs so `aifix` (no args) has perfect context.
_balai_preexec_capture () {
    export BALAI_LAST_CMD="$1"
}
add-zsh-hook preexec _balai_preexec_capture

# Capture the exit status right after each command completes.
_balai_precmd_capture_exit () {
    export BALAI_LAST_EXIT=$?
}
add-zsh-hook precmd _balai_precmd_capture_exit

_balai_precmd_hint () {
    local exit=${BALAI_LAST_EXIT:-0}
    [[ $exit -eq 0 ]] && return
    # Skip SIGINT/SIGPIPE and common "this isn't an error" exits (grep 1, test 1).
    case $exit in
        1|130|141) return ;;
    esac
    local last="${BALAI_LAST_CMD:-}"
    # Skip balai's own commands and empty lines
    [[ -z "$last" || "$last" == balai* || "$last" == '?'* || "$last" == 'wtf'* || "$last" == 'aifix'* ]] && return
    print -P "%F{yellow}▸%f exit $exit — try  %F{cyan}wtf%f  (explain) or  %F{cyan}aifix%f  (suggest a fix)"
}
# Only enable hint if user opted in — default off to stay quiet.
if [[ "${BALAI_ERROR_HINT:-0}" == "1" ]]; then
    add-zsh-hook precmd _balai_precmd_hint
fi
