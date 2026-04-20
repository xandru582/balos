# ═══════════════════════════════════════════════════════════════
# BalOS · ~/.zshrc — the hacker's shell
# ═══════════════════════════════════════════════════════════════

# ── History ──────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS
setopt SHARE_HISTORY EXTENDED_HISTORY INC_APPEND_HISTORY

# ── Completion ───────────────────────────────────────────────────
autoload -Uz compinit && compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Zsh plugins ─────────────────────────────────────────────────
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -r /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Custom syntax highlighting — green on black hacker vibe
ZSH_HIGHLIGHT_STYLES[default]=none
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=magenta,bold'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red,bold'
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#3a7040'

# ── Keybindings ─────────────────────────────────────────────────
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^R' history-incremental-search-backward

# ── Aliases ─────────────────────────────────────────────────────
# Modern replacements
alias ls='eza --icons --group-directories-first'
alias ll='eza -la --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --style=plain --paging=never'
alias catt='bat'
alias grep='rg'
alias find='fd'
alias du='dust'
alias top='btop'
alias vim='nvim'
alias vi='nvim'

# BalOS shortcuts
alias b='bal'
alias bs='bal status'
alias bm='bal monitor'
alias boost='bal boost'
alias saver='bal saver'
alias shield='bal shield'
alias stealth='bal stealth'
alias hack='bal hack'
alias panic='bal panic'
alias myip='bal net ip'

# Pacman ergonomics
alias pi='sudo pacman -S'
alias pu='sudo pacman -Syu'
alias pr='sudo pacman -Rns'
alias ps='pacman -Ss'
alias pq='pacman -Qs'
alias orphans='pacman -Qtdq | sudo pacman -Rns -'

# Git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit -v'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate --all'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Quick pentest
alias nse='sudo nmap --script vuln'
alias portscan='sudo nmap -sV -sC -T4'
alias wifi-scan='nmcli device wifi list --rescan yes'
alias listen='sudo ss -tulnp'
alias connections='sudo ss -tupn state established'
alias reqip='curl -s ifconfig.me; echo'

# Hackery
alias rot13='tr "A-Za-z" "N-ZA-Mn-za-m"'
alias urlencode='python3 -c "import sys, urllib.parse as u; print(u.quote(sys.argv[1]))"'
alias urldecode='python3 -c "import sys, urllib.parse as u; print(u.unquote(sys.argv[1]))"'
alias b64='base64'
alias unb64='base64 -d'
alias hexd='xxd'
alias unhex='xxd -r -p'
alias sniff='sudo tcpdump -i any -nn -s 0 -w -'

# ── Directory navigation ─────────────────────────────────────────
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
alias -- -='cd -'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# fzf (ctrl+T files, ctrl+R history, alt+C cd)
[[ -r /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -r /usr/share/fzf/completion.zsh ]]   && source /usr/share/fzf/completion.zsh
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=fg:#a0ffb0,bg:#000000,hl:#00ff88,fg+:#ffffff,bg+:#0f2015,hl+:#00ffaa,info:#b580ff,prompt:#00ff88,pointer:#00ff88,marker:#b580ff,spinner:#b580ff,header:#3a7040'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'

# zoxide (smart cd) — z <query>
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# direnv (per-dir env)
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ── Prompt ──────────────────────────────────────────────────────
# Starship (fast, cross-shell) — theme defined in ~/.config/starship.toml
command -v starship &>/dev/null && eval "$(starship init zsh)"

# Fallback prompt if starship missing
if ! command -v starship &>/dev/null; then
    autoload -Uz vcs_info
    precmd() { vcs_info }
    zstyle ':vcs_info:git:*' formats ' %F{cyan}%b%f'
    setopt PROMPT_SUBST
    PROMPT='%F{green}╭─[%F{magenta}%n%F{green}@%F{cyan}%m%F{green}]─[%F{yellow}%~%F{green}]${vcs_info_msg_0_}
%F{green}╰─%F{green}▶%f '
fi

# ── One-shot greet on fresh login ───────────────────────────────
if [[ -z "$BALOS_GREETED" && -o interactive ]]; then
    export BALOS_GREETED=1
    command -v fastfetch &>/dev/null && fastfetch 2>/dev/null
fi
