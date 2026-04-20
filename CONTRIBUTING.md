# Contributing to BalOS

Thanks for considering a contribution! BalOS grows best when people who
actually use the system extend it to fit their workflows. This document
describes how to get changes merged cleanly.

## Ground rules

- Be nice. Discuss intent before writing a large PR.
- Keep the project's four pillars in mind: **hack · play · evade · endure**.
  A change that hurts battery life needs to meaningfully help one of the
  others.
- Don't add hard dependencies on non-free software. Optional integrations are
  fine.
- BalOS is opinionated. "Just add a config option" is not a reflex answer.

## What we love

- **New `bal*` tools** that capture a repeatable workflow you use daily.
- **Per-game profiles** (`/etc/balos/game-profiles/*.conf`).
- **Geofence presets** (airports, cafés, university networks).
- **USBGuard rules** for common peripherals.
- **Suricata rule additions** relevant to laptop threat model.
- **Screenshots** and demo GIFs for the README.
- **Battery-life benchmarks** on documented hardware.
- **Bug reports** with `journalctl -b` attached.

## What needs discussion first

- Switching a default service on/off.
- Adding a new base package.
- Changing kernel parameters.
- Anything touching the installer's partition logic.

Open an Issue tagged `rfc:` before the PR.

## Development setup

BalOS is built in Docker so you don't need an Arch host.

```bash
git clone https://github.com/xandru582/balos.git
cd balos
./build.sh --clean        # ~20 min on first run
```

For fast iteration on a single tool, just `chmod +x airootfs/usr/bin/<tool>`
and copy it onto a running BalOS install — no rebuild required.

## `bal*` tool style guide

All scripts share a look & feel. Follow it:

1. **Shebang + header**
   ```bash
   #!/usr/bin/env bash
   # baltool — one-line description
   # Optional second line with extra context.
   set -euo pipefail
   ```

2. **ANSI color constants** (always the same set):
   ```bash
   G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'
   M='\033[0;35m'; B='\033[1m'; D='\033[2m'; N='\033[0m'
   ```

3. **Palette**: `#00ff88` green is the BalOS brand color. Prefer cyan/magenta
   for section headers, green for success, yellow for warnings, red for
   destructive/critical.

4. **Usage text** via `usage()` + `cat << EOF`. Every tool must respond to
   `-h | --help | help`.

5. **Subcommand dispatch** via `case "${1:-default}"` at the bottom.

6. **Privilege escalation**: if root is required for an action, `exec sudo
   "$0" "$@"` — don't `sudo` inside the script.

7. **Destructive operations** require confirmation (see `balrescue`).

8. **Banner ASCII art** is optional but welcomed.

9. **No surprise network calls.** If a tool talks to the internet, say so in
   the usage text.

10. **Logs** should go to `logger -t baltool …` or `/var/log/balos/`.

## Filing issues

Good bug report template:

```
Hardware: <vendor/model, CPU, GPU>
BalOS version: <output of `bal version` or ISO filename>
Kernel: <uname -r>

Steps to reproduce:
1. ...
2. ...

Expected:
Actual:

Logs (trim to relevant lines):
<paste journalctl / dmesg>
```

## Commits & PRs

- One logical change per commit.
- Commit message: `<tool>: short imperative` — e.g. `balboost: add
  emulation profile` or `install: fix LUKS UUID detection`.
- Rebase on `main` before opening a PR; no merge commits on your branch.
- CI will run shellcheck on changed scripts; please run it locally too:
  ```bash
  shellcheck airootfs/usr/bin/baltool
  ```
- For doc-only changes, prefix the PR title with `docs:`.

## Security issues

Do **not** file public issues for security problems. See `SECURITY.md`.

## Code of Conduct

Be decent to one another. Harassment, dogpiling, or discrimination of any kind
gets you banned with no warning. Report via the email in `SECURITY.md`.

---

Thank you. See you in the PR queue.
