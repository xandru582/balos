# BalOS

> **hack · play · evade · endure**
> A from-scratch Linux distribution for laptops that refuses to compromise.

<p align="center">
  <img src="https://img.shields.io/badge/base-Arch%20Linux-1793d1?logo=archlinux&logoColor=white" />
  <img src="https://img.shields.io/badge/kernel-linux--zen%20%2B%20BalKernel-00ff88" />
  <img src="https://img.shields.io/badge/DE-KDE%20Plasma%206-1d99f3?logo=kde&logoColor=white" />
  <img src="https://img.shields.io/badge/AI-Qwen2.5--1.5B%20offline-b580ff" />
  <img src="https://github.com/xandru582/balos/actions/workflows/lint.yml/badge.svg" />
  <img src="https://img.shields.io/badge/license-MIT-00ff88" />
  <img src="https://img.shields.io/badge/status-alpha-ff8800" />
</p>

```
  ┌─┐┌─┐┬  ┌─┐┌─┐
  ├┴┐├─┤│  │ │└─┐
  └─┘┴ ┴┴─┘└─┘└─┘
```

BalOS is an opinionated Arch-based distribution built around four promises that
most distros force you to trade against each other:

| Pillar     | What it means in BalOS                                                               |
|------------|---------------------------------------------------------------------------------------|
| **hack**   | BlackArch's 2800+ pentest tools, tmux-based workspaces, reverse-shell toolkit, IDS    |
| **play**   | Steam + Proton + Wine-Staging, 6 per-game performance profiles, 256µs PipeWire audio  |
| **evade**  | 4-tier nftables firewall, Tor transparent proxy, MAC rotation, anti-forensics layer   |
| **endure** | TLP + auto-cpufreq + powertop, target: **2× battery life vs. stock Arch**             |
| **assist** | **BalAI** — 1.5 B offline LLM (Qwen2.5) as your command-line co-pilot, zero cloud     |

Everything is glued together by a single CLI — `bal` — plus a dashboard
(`balmonitor`), a dialog-based installer, and a KDE Plasma + Matrix-themed
desktop.

---

## Table of contents

- [Why BalOS?](#why-balos)
- [Screenshots / demo](#screenshots--demo)
- [Feature matrix](#feature-matrix)
- [BalAI — offline AI assistant](#balai--offline-ai-assistant)
- [The `bal` family of tools](#the-bal-family-of-tools)
- [Build the ISO](#build-the-iso)
- [Install to disk](#install-to-disk)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

---

## Why BalOS?

If you've ever tried to daily-drive Kali on a laptop you know the pain: great
tools, terrible battery. Try Pop!\_OS and you get the opposite. SteamOS is
polished but the sandbox is tight. Arch gives you everything but asks you to
spend a weekend configuring it.

BalOS tries to be all four at once, tuned out of the box:

- **Battery:** `linux-zen` + BORE scheduler + TLP + auto-cpufreq + powertop +
  PCIe ASPM + ZRAM zstd swap + aggressive USB autosuspend. Target laptop
  runtime is roughly double stock Arch for identical hardware/workload.
- **Gaming:** `gamemoderun` wires into GameMode, which calls `balboost` with a
  profile that fits the game; PipeWire is pre-configured to 256-sample quantum
  for sub-6ms audio latency; Wine/DXVK/VKD3D are pre-cached.
- **Security:** Default-deny firewall, DNSCrypt-proxy over DoH, optional Tor
  transparent proxy, LUKS2 (argon2id), btrfs subvolumes with snapper, USBGuard
  with a Rubber-Ducky heuristic, Suricata host IDS, firejail sandbox profiles.
- **Pentesting:** BlackArch repo enabled, `balhack` drops you into a 7-pane
  tmux workspace (recon / web / wifi / reverse / forensics / crack / osint),
  `balrecon` runs the full nmap → service → web → report pipeline.
- **AI assistant:** `balai` — a Qwen2.5-1.5B (Q4) model (~1 GB) is pre-baked
  into the squashfs, served locally by ollama on `127.0.0.1:11434`. It
  translates intent into `bal*` commands, explains errors, generates
  reverse-shell payloads, and never leaves the machine. No account, no
  telemetry, no network calls.

No single piece is unique — the integration is.

---

## Screenshots / demo

> The first ISO builds are coming; PRs with screenshots welcome.

```
$ balmonitor
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  BalOS · monitor    profile: boost:competitive   uptime: 2 hours      ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  CPU  gov=performance  boost=1  avg=42%  freq=4.31 GHz  temp= 68°C
┃  c0  ████████░░░░░░░░░░░░░░░░  33%    c4  ██████████░░░░░░░░░░░░  41%
┃  c1  ██████████████░░░░░░░░░░  58%    c5  ████████░░░░░░░░░░░░░░  33%
┃  c2  ██████░░░░░░░░░░░░░░░░░░  25%    c6  █████████████░░░░░░░░░  54%
┃  c3  ███████████████████░░░░░  79%    c7  █████████░░░░░░░░░░░░░  37%
┃  CPU hist  ▂▃▅▆▇▇▆▅▄▃▄▅▆▇▇▆▅▄▃▄
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  Battery ████████████████░░░░  80% ▼   draw=8.3 W   remain=3h 42m
┃  GPU    ██████████░░░░░░░░░░  42%   name=amd  temp= 61°C
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃  NET    iface=wlan0   ip=10.0.0.42   fw=armor  vpn=up  tor=active
┃  ▼ RX  ▂▃▅▆▇▇▆▅▄▃▄▅▆▇▇▆▅▄▃▄  1.2 MB/s
┃  ▲ TX  ▁▂▂▃▄▅▄▃▂▂▁▁▂▃▄▅▄▃▂▁  420.3 KB/s
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

---

## Feature matrix

### Kernel & power
- `linux-zen` default; optional custom **BalKernel** (BORE scheduler, 1000 Hz,
  PREEMPT, BBR, WiFi monitor mode patches for Atheros/Realtek/MT76)
- TLP + auto-cpufreq + powertop auto-tune
- PCIe ASPM powersupersave, SATA ALPM, USB autosuspend
- ZRAM zstd swap in place of disk swap
- Sleep state `s2idle` preferred; configurable to deep via kernel param

### Desktop
- KDE Plasma 6 on Wayland + SDDM
- Matrix-rain SDDM theme (QML Canvas)
- Kitty, Starship, Fastfetch, JetBrainsMono Nerd Font
- Optional Waybar (Hyprland-ready config)
- Kitty, tmux, neovim all themed `#00ff88` on `#020604`

### Network / security
- nftables default-deny, four tiers: `off | normal | armor | fortress`
- Fortress = VPN kill-switch (drops everything except `wg0`)
- DNSCrypt-proxy with DoH (Cloudflare, Quad9, NextDNS)
- Tor client with transparent proxy mode
- NetworkManager MAC randomization + per-SSID geofence (`balgeo`)
- USBGuard with Rubber Ducky / OMG-cable heuristics
- Suricata baseline IDS (`balids`)
- Firejail sandbox profiles (`balsandbox`)
- LUKS2 (argon2id, 4s iter-time) + btrfs subvols + snapper snapshots

### Performance
- GameMode integration (auto-boost on game launch)
- PipeWire 256-sample quantum (low-latency audio)
- Kernel scheduler: `SCHED_LATENCY_NS=3ms` (`SCHED_LATENCY_NS=2ms` in
  competitive profile)
- BBR congestion control, fq qdisc
- AMD GPU `pp_power_profile_mode=5` (VR/Gaming) in cinematic profile
- Transparent huge pages for emulation workloads

### Pentesting
- BlackArch repo pre-configured (2800+ packages)
- `balhack` — tmux workspaces for recon / web / wifi / reverse / forensics /
  crack / osint
- `balrecon` — automated multi-stage enumeration → Markdown report
- `balpwn` — reverse shell toolkit (14 payload languages, PTY upgrade
  cheatsheet, HTTP stager)
- `balids` — Suricata wrapper

### Offline AI assistant
- `balai` — local command-line co-pilot powered by **Qwen2.5-1.5B-Instruct**
  (Q4_K_M, ~1 GB) served by [ollama](https://ollama.com) on `127.0.0.1:11434`
- Model pre-baked into the squashfs during ISO build — works **100 % offline**
  from first boot, no account or network needed
- System prompt pre-loaded with the full `bal*` command surface and 10
  few-shot examples disambiguating common confusions (stealth vs shield,
  saver vs boost, etc.)
- Subcommands: `balai cmd` (intent → one shell command, with destructive-
  pattern blocklist and confirm-before-run), `balai explain` (explain a
  file / last command / piped output), `balai fix` (diagnose an error)
- systemd drop-in hardens ollama: loopback-bind only, cloud/telemetry
  disabled, 5 min keep-alive
- Env overrides: `BALAI_MODEL` (swap model — 3B/7B for more RAM),
  `BALAI_SYSTEM_PROMPT` (custom prompt for advanced users)

---

## BalAI — offline AI assistant

A small fact: local LLMs are finally good enough to run on a laptop and
actually help. BalOS ships one.

```bash
$ balai "how do I enable stealth mode"
bal ▸ ```bash
bal stealth on
```
Tor + DNSCrypt DoH + MAC randomize in one step.

$ balai cmd "find all files modified in the last 10 minutes"
suggested: find . -mmin -10 -type f
run it? [y/N]

$ kubectl get pods 2>&1 | balai explain
The error is "The connection to the server localhost:8080 was refused." …
```

### What's inside
- **Model:** `qwen2.5:1.5b-instruct-q4_K_M` (986 MB). Empirically the
  smallest size that reliably follows the BalOS command surface; 0.5B
  hallucinated invented commands (`bal wipe`, `mkusb`) ~50 % of the time.
- **Runtime:** `ollama serve` via systemd, bound to `127.0.0.1:11434`.
  `balai` will auto-start the service on first use.
- **Storage:** `/var/lib/ollama/.ollama/models` — baked at ISO build time
  so there's nothing to download on first boot.

### Commands

| `balai <cmd>`          | What it does                                                      |
|------------------------|-------------------------------------------------------------------|
| `balai`                | Interactive chat REPL (streaming, `/clear`, `/model`, `/help`)    |
| `balai "question"`     | One-shot query, streams answer and exits                          |
| `balai cmd "intent"`   | Intent → one shell command → confirm → run (destructive blocked)  |
| `balai agent "goal"`   | **Iterative approval loop** — propose → approve → run → observe, until `DONE` |
| `balai explain <file>` | Explain a file, `--last` command, or piped stdin                  |
| `balai explain --diff A B` | Semantic diff of two files — "what really changed"            |
| `balai man <cmd> [q]`  | Inject a man page as authoritative context + optional question    |
| `balai journal "<q>"`  | Natural-language `journalctl` query                              |
| `balai unit <name>`    | Show + explain a systemd unit (security posture, misconfigs)      |
| `balai perf`           | Tokens-per-second benchmark (3 runs)                              |
| `balai serve [addr]`   | OpenAI-compatible proxy on `127.0.0.1:11435` for IDE plugins      |
| `balai thumbs up/down "<r>"` | Feedback; `down` adds a permanent "Do NOT …" note         |
| `balai fix [error]`    | Diagnose an error and suggest a fix                               |
| `balai ctx`            | Dump the live system context balai would inject into your query   |
| `balai doctor`         | Gather diagnostics (failed units, journal, disk, `.pacnew`) + AI summary |
| `balai tip`            | One-line proactive suggestion based on live context (shown in `bal status`) |
| `balai remember "…"`   | Add a persistent note (e.g. preferences) — injected into every prompt |
| `balai memory`         | Show remembered notes                                             |
| `balai forget [pat]`   | Remove matching notes (or wipe all with confirmation)             |
| `balai model list`     | Show locally installed models and sizes                           |
| `balai model pull X`   | Download another Qwen/Llama/Phi model (needs network)             |
| `balai status`         | Service health, active model, RAM                                 |
| `balai setup`          | Re-run first-run setup (enable service, pull default model)       |
| `balai-chat` / `bal chat` | **Graphical chat window** (PySide6) with live system panel     |

`bal ?` is a shortcut: `bal ? "how do I…"` → `balai "how do I…"`.
Even simpler: any unknown multi-word `bal` command is forwarded to balai, so
`bal how do I enable stealth` Just Works.

### Graphical chat app (`balai-chat`)

`balai-chat` (alias: `bal chat`, `Meta+A`) is a PySide6 window that wraps
the same local model in a friendlier interface:

- **Live system panel** on the left — battery, CPU load/governor, RAM,
  disk, network iface/IP/SSID/VPN, firewall tier, power profile, kernel,
  uptime — refreshing every 5 s.
- **Streaming chat** in the centre with markdown rendering (fenced code
  blocks, bullets, bold/inline code).
- **Quick actions** bar: **🩺 Doctor**, **💡 Tip**, **🧭 Context**,
  **🧾 Remember…**, **🧹 Clear**, **■ Stop**.
- **Auto context injection** — when you ask about "my battery", "current
  firewall", etc, the GUI prepends a live snapshot before sending.
- **Ollama reachability** indicator in the status bar.
- **Keyboard shortcuts**: `Enter` send · `Shift+Enter` newline ·
  `Ctrl+L` clear · `Ctrl+D` doctor · `Ctrl+T` tip · `Ctrl+K` context ·
  `Ctrl+S` export to markdown · `Ctrl+,` settings ·
  `Ctrl+Shift+C` copy last code block · `Ctrl+Q` quit.
- **Model dropdown** in the toolbar — live-populated from `ollama list`,
  switch 1.5B ↔ 3B ↔ 7B without restarting.
- **System tray icon** — close-to-tray, right-click for Ask / Doctor /
  Quit, desktop notification when an answer finishes while hidden.
- **Settings dialog** (Ctrl+,) — context mode (auto/always/never),
  temperature, theme. Persisted via `QSettings`.

Dependencies (pulled in by the ISO): `pyside6`, `python-requests`,
`ollama`, `balai`.

### System-wide integration

BalAI is wired into every surface of the OS, not just its own CLI:

- **Shell (zsh)** — sourced from `/etc/zsh/zshrc.d/50-balai.zsh`
  - `?  <question>`     → one-shot query
  - `?? <intent>`        → generate + confirm + run a command
  - `wtf`                → explain the last command (or piped stdin)
  - `Alt-E`              → widget: send current command line to `balai cmd`
  - `Alt-?`              → widget: send current command line to `balai explain`
  - `command_not_found`  → gentle hint suggesting `? <typed-command>`
  - Opt-in post-fail hint (`export BALAI_ERROR_HINT=1`)
- **Neovim** — `:BalAI {ask|cmd|explain|fix}` + buffer/selection support
  - `<leader>ae`  → explain buffer (normal) / selection (visual)
  - `<leader>ac`  → generate command (prompts for intent)
  - `<leader>aa`  → ask (prompts for question)
  - `<leader>af`  → fix
- **KDE Plasma desktop**
  - `Meta+A`          → launch **BalAI chat GUI** (Qt, live system panel, streaming)
  - **KRunner** (`Alt+Space`) → type `? your question` or `ai how do I…` to ask
    directly from the launcher; Enter opens the GUI pre-filled with the
    answer streaming in
  - `Meta+Shift+A`    → ask via `kdialog` (one-shot in kitty)
  - `Meta+Ctrl+A`     → generate a command via `kdialog`
  - `Meta+B`          → bal fzf menu
  - App launcher      → "BalAI" with actions: Terminal chat / Ask / Cmd / Doctor / Status
- **Dolphin (file manager)** — right-click any file → **BalAI ▸ Explain** / **Ask…**
- **`bal` CLI** — unknown multi-word commands auto-route to balai
- **pacman** — optional post-transaction operator summary
  (off by default; enable with `sudo touch /etc/balos/pacman-ai-summary.on`)
- **`balinit`** — first-boot wizard warms the model so first real query is snappy
- **Zsh completions** — `bal ai <TAB>`, `balai <TAB>`, `bal shield <TAB>`, etc.
- **Unified state** — `bal boost|saver|shield|…` publish to `/run/balos/*`, which
  `balai ctx` reads so the model always sees the *current* system, not guesses.
- **`balmonitor` / `bal status`** — appends a one-line AI tip based on the
  current snapshot (disable with `BALOS_STATUS_TIP=0`).
- **`balwatch`** — optional AI auto-explain on critical security alerts
  (`sudo touch /etc/balos/watch-ai-explain.on`) plus `balwatch explain` on
  demand.
- **`balrecon`** — every report gets an AI "Attack Surface / Top 3 Priorities"
  section appended automatically (disable with `--no-ai`).
- **`balupdate`** — on failure, tails pacman log into `balai fix` for
  diagnosis before rolling back. Opt-in post-success summary of what
  changed (`sudo touch /etc/balos/update-ai-summary.on`).
- **`balkernel-build`** — if the compile fails, the tail of the log is
  piped through `balai fix` so you get a diagnosis before scrolling.
- **Smart `aifix`** — with no args, reads the last command + its exit code
  (captured by zsh hooks) and feeds both to the model, so you never paste.
- **TTY login MOTD** — `balai-motd` prints a compact dashboard on first
  interactive shell. Opt-in AI one-liner: `sudo touch /etc/balos/motd-ai.on`.
  Disable entirely: `sudo touch /etc/balos/motd.off`.
- **`balvault strength` / `balvault audit`** — password entropy estimate
  (bits, class mix, dict hits, runs) plus an AI verdict. The raw password
  never leaves the script — only the stats are sent.
- **`bal hack ? …`** — inside a BalHack workspace (recon/web/wifi/…),
  ask for the next step and the model sees which workspace you're in.
- **Persistent memory** — `balai remember "I use btrfs and nvim"`. Notes live
  at `$XDG_STATE_HOME/balai/notes.md` and get prepended to every prompt.
  Wipe all: `balai forget`. Wipe one: `balai forget btrfs`.
- **Waybar / Hyprland** — `custom/balai` module polls `balai tip` every
  15 min; icon class drives color (ok/warn/bad/off). Click opens the
  GUI, right-click runs the doctor.
- **KRunner** (`Alt+Space`) — type `? your question` or `ai: …` and
  press Enter to open the GUI with the answer already streaming.
- **OpenAI-compatible proxy** — `balai serve` (or `systemctl --user
  enable --now balai-serve.service`) exposes `/v1/chat/completions` on
  `127.0.0.1:11435` with BalAI's system prompt and your notes
  pre-applied. Any OpenAI-speaking IDE plugin (Continue, Aider,
  Cursor-alts) can consume it — just point them at the URL.
- **Battery guard** — `balai` refuses to run below 10 % on battery
  (override with `BALAI_FORCE=1`) and warns below 20 %. Cold-start +
  eval of Qwen2.5-1.5B pulls noticeable wattage; this is conscious
  spending.
- **Knowledge injection** — `balai man find "delete files older than 7
  days"` feeds the first 4 KB of `man find` into the prompt, so the
  model quotes real flags instead of hallucinating. Works for any
  installed man page.
- **Journal NL query** — `balai journal "what went wrong last boot"`
  tails `journalctl` (priority ≥ warning, since = 1h) and asks the
  model for an operator summary, ending in a concrete command.
- **Unit explainer** — `balai unit sshd` dumps `systemctl cat` + status
  and asks for a 4-bullet security/misconfig review.
- **Perf benchmark** — `balai perf` runs a fixed prompt 3 times and
  reports tokens/s (mean + best). Quick sanity check after kernel
  upgrades or GPU driver changes.
- **Multi-turn REPL** — `balai chat` now keeps the whole turn history
  within the session (capped at 16 turns). `/clear` resets it, `/save`
  persists the transcript under `~/.local/state/balai/sessions/`.
- **Feedback loop** — `balai thumbs down "suggested rm on the wrong
  dir"` appends a `Do NOT: …` line to `notes.md`, which the model sees
  on every future prompt. `thumbs up` logs what you liked separately
  for auditing.
- **Auto man-page injection in `balai cmd`** — when the intent
  mentions an installed command, BalAI silently tails its man page
  into the prompt so you get real flags, not hallucinated ones.

### Context awareness

When your question mentions *my*, *current*, *what's my…*, etc., balai auto-
injects a short real-time snapshot of your system (firewall tier, power
profile, battery, WiFi SSID, VPN state, CPU governor, RAM, disk, kernel)
before sending the prompt. The model answers with that context instead of
guessing.

```bash
$ balai ctx      # see exactly what gets injected
$ balai "what's my battery"
battery: 14% Discharging, profile: boost
```
```bash
bal saver
```
Battery at 14% while on boost — switch to saver now.

Force-on:  `BALAI_CTX_MODE=always balai "..."`
Force-off: `BALAI_CTX_MODE=never  balai "..."`

### Privacy posture
- No network calls at runtime (checked only when pulling a new model).
- Systemd drop-in `balos.conf` sets `OLLAMA_HOST=127.0.0.1:11434`,
  `OLLAMA_NO_CLOUD=true`, `OLLAMA_ORIGINS=http://localhost,http://127.0.0.1`.
- Chat history in `$XDG_STATE_HOME/balai/history.jsonl` — wiped by
  `bal panic hard`.
- `balai cmd` blocks execution of destructive patterns (`rm -rf /`,
  `mkfs`, `wipefs`, `dd of=/dev/…`, `cryptsetup erase`, fork bombs, …).

### Upgrading the model

Got more RAM? Try a bigger model:

```bash
balai model pull qwen2.5:3b-instruct-q4_K_M        # ~1.9 GB, cleaner output
balai model pull qwen2.5:7b-instruct-q4_K_M        # ~4.4 GB, best quality
echo 'export BALAI_MODEL=qwen2.5:3b-instruct-q4_K_M' >> ~/.zshrc
```

---

## The `bal` family of tools

All commands also dispatch through a single unified CLI: `bal <subcommand>`.

| Command     | Purpose                                                                   |
|-------------|---------------------------------------------------------------------------|
| `bal`       | fzf interactive menu of all subcommands                                   |
| `balboost`  | Gaming performance profiles (competitive / cinematic / esports / …)       |
| `balsaver`  | Extreme battery saver (powersave, SMT off, half cores parked)             |
| `balshield` | Firewall tiers (off / normal / armor / fortress)                          |
| `balstealth`| Tor + DNSCrypt + MAC + camera kill + **leak tests**                       |
| `balgeo`    | Per-SSID geofence — auto-apply profile on WiFi connect                    |
| `balhack`   | Launch 7-pane tmux pentest workspace                                      |
| `balrecon`  | Automated enum: whois → nmap → services → web → report                    |
| `balpwn`    | Reverse shell listener + payload generator                                |
| `balids`    | Suricata host IDS wrapper (on / alerts / watch / update)                  |
| `balvault`  | `pass`(1) wrapper with fzf + QR + git sync                                |
| `balsandbox`| Firejail wrapper with per-app profiles                                    |
| `balclip`   | age-encrypted clipboard history                                           |
| `balmonitor`| Real-time TUI dashboard (per-core bars, sparklines, drain rate)           |
| `balpanic`  | Tiered emergency sanitize: `soft` / `hard` / `nuclear`                    |
| `balrescue` | Anti-forensics: RAM wipe / swap shred / free-space zero / partition burn  |
| `balwatch`  | Daemon: USB / port / SSH / deauth anomaly detection → notify-send         |
| `balupdate` | Snapshot-backed pacman wrapper with auto-rollback                         |
| `balnet`    | Network swiss-army (iface / speed / ports / conns / vpn up-down)          |
| `balai`     | **Local offline LLM assistant** (Qwen2.5-1.5B) — `cmd`, `explain`, `fix` |
| `balkernel-build` | Compile BalKernel from shipped PKGBUILD                             |
| `balos-install`   | Dialog TUI installer (geo-TZ, GPU detect, LUKS2)                    |

Run `bal help` or `<any-tool> --help` for details.

---

## Build the ISO

BalOS is built with `mkarchiso` inside a privileged Docker container, so you
can build on macOS, Linux, or Windows/WSL.

### Requirements
- Docker (or Podman) ~20.10+
- ~30 GB free disk space (ISO + pacman cache + ~1 GB pre-baked AI model)
- ~25 min on a fast connection (first build; subsequent builds use cached
  pacman packages). The AI model pull (~1 GB Qwen2.5-1.5B) adds ~3 min to
  the first build and is cached for subsequent ones.

### Quick build

```bash
git clone https://github.com/xandru582/balos.git
cd balos
./build.sh
```

Output: `output/balos-1.0.0-dark-x86_64.iso`

### Build flags

```
./build.sh --clean        # wipe previous workdir
./build.sh --no-cache     # ignore Docker layer cache (fresh)
./build.sh --with-kernel  # also compile BalKernel (adds ~40 min)
```

### Write to USB

```bash
# Find your USB stick first
lsblk
# Write
sudo dd if=output/balos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Or use `balenaEtcher` / `Ventoy` / `Rufus`.

---

## Install to disk

1. Boot the ISO. Log in as `root` (no password on Live).
2. Connect to Wi-Fi: `nmtui`
3. Run: `balos-install`
4. Answer the prompts — disk, LUKS passphrase, hostname, user, timezone
   (auto-detected from your IP), locale, GPU driver, feature profiles.
5. Reboot.

The installer:
- Wipes the chosen disk, creates ESP + root partitions
- Optionally sets up LUKS2 (argon2id, 4000ms iteration, 512-bit key)
- Creates btrfs subvols `@`, `@home`, `@var`, `@log`, `@snapshots`, `@swap`
- Installs base + GPU driver + selected feature bundles
- Configures systemd-boot with zen kernel + fallback entry
- Enables NetworkManager, SDDM, TLP, nftables, DNSCrypt, snapper timers

First boot lands on SDDM with Matrix rain.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                        USER APPS                                    │
│   Firefox · Steam · Wine · KDE · Kitty · LibreOffice · …            │
├────────────────────────────────────────────────────────────────────┤
│                     bal CLI LAYER                                   │
│   balboost · balsaver · balshield · balstealth · balhack · balai …  │
│   (thin bash scripts that orchestrate the system)                   │
├────────────────────────────────────────────────────────────────────┤
│       SERVICES LAYER                                                │
│  TLP · GameMode · nftables · dnscrypt-proxy · Tor · Suricata ·      │
│  USBGuard · snapper · balwatch · PipeWire · ollama (127.0.0.1)      │
├────────────────────────────────────────────────────────────────────┤
│       KERNEL                                                        │
│  linux-zen (default) / BalKernel (BORE+1kHz+PREEMPT+BBR)            │
│  mitigations=auto · zstd-compressed initramfs · ZRAM swap           │
├────────────────────────────────────────────────────────────────────┤
│       STORAGE                                                       │
│  LUKS2 (argon2id) → btrfs (zstd:2, ssd, space_cache=v2, discard)   │
│  subvols: @ @home @var @log @snapshots @swap                        │
└────────────────────────────────────────────────────────────────────┘
```

### Repository layout

```
.
├── Dockerfile              # build container (archlinux:latest + mkarchiso)
├── build.sh                # host-side build driver
├── profiledef.sh           # archiso profile metadata
├── packages.x86_64         # package manifest (~600 pkgs)
├── pacman.conf             # repos (core, extra, multilib, chaotic-aur, blackarch, balos)
│
├── airootfs/               # everything that goes into the ISO's rootfs
│   ├── etc/                # system configs (nftables, tlp, pipewire, snapper, …)
│   ├── usr/
│   │   ├── bin/            # the bal* CLI tools
│   │   ├── share/          # SDDM themes, desktop entries, docs, skel
│   │   └── lib/
│   └── root/               # first-boot setup
│
├── kernel/                 # BalKernel PKGBUILD + config fragment
├── grub/ efiboot/ syslinux/# bootloader assets for the Live ISO
├── scripts/                # helper scripts (build hooks, etc.)
└── output/                 # ISOs land here
```

---

## Contributing

BalOS is a personal project, but contributions are very welcome. Good places to
start:

- **New `bal*` tools** — pick a workflow you use daily and script it
- **`.desktop` launchers** for existing tools
- **Game profiles** (`/etc/balos/game-profiles/*.conf`)
- **Geofence default rules** for public-WiFi SSIDs
- **USBGuard default rules** for common devices
- **Translations** of `bal` help strings

Please read `CONTRIBUTING.md` before opening a PR.

---

## Roadmap

- [x] Base ISO boots to KDE Plasma
- [x] Full `bal` CLI suite
- [x] Dialog installer
- [x] Snapper + grub-btrfs integration
- [x] Suricata IDS baseline
- [x] Offline AI assistant (`balai`, Qwen2.5-1.5B, pre-baked into squashfs)
- [x] Public CI pipeline (GitHub Actions — lint on every push, nightly + tagged ISO builds)
- [ ] Official binary repo signed by project key
- [ ] Secure Boot with custom MOK
- [ ] Hyprland "blade" edition alongside Plasma
- [ ] BalKernel pre-built binaries
- [ ] Calamares installer alongside `dialog` one

---

## License

MIT. See [LICENSE](LICENSE).

BalOS includes and redistributes software under many other licenses (GPL,
BSD, Apache-2, etc.). The configuration glue and `bal*` tools are MIT; the
kernel is GPL-2; upstream packages retain their own licenses.

---

## Disclaimer

BalOS ships with offensive security tooling (nmap, metasploit, hashcat,
aircrack-ng, …). These are to be used **only on systems you own or have
explicit written authorization to test**. The authors accept no liability for
misuse. Anti-forensics features exist to protect privacy, not to enable
criminal activity.

Stay ethical. Hack what's yours.

---

<p align="center"><i>Built with ☕ and too little sleep.</i></p>
