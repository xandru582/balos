# Security Policy

## Reporting a vulnerability

Please **do not open a public GitHub Issue** for security vulnerabilities in
BalOS itself (the `bal*` tools, default firewall/IDS config, installer, or
build pipeline).

Instead, email **xandru2222+balos-sec@gmail.com** with:

- A description of the vulnerability
- Steps to reproduce (or a PoC)
- Affected versions / commit SHA
- Your assessment of impact
- Whether you'd like public credit in the advisory

We aim to acknowledge reports within **72 hours** and issue a fix or
mitigation within **14 days** for severe issues.

## Scope

In scope:

- `bal*` CLI tools (`airootfs/usr/bin/bal*`)
- Default configs under `airootfs/etc/`
- Build pipeline (`Dockerfile`, `build.sh`, `profiledef.sh`)
- `balos-install` installer
- Polkit rules, udev rules, systemd units shipped by BalOS

**Out of scope** (report these upstream):

- Vulnerabilities in Arch packages (→ Arch Security Team)
- Vulnerabilities in the Linux kernel (→ security@kernel.org)
- Vulnerabilities in BlackArch packages (→ BlackArch upstream)
- Vulnerabilities in DE components (KDE, Plasma) (→ KDE Security)

## Supported versions

BalOS is currently alpha. Only the latest tagged release receives security
fixes.

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅ yes    |
| < 1.0   | ❌ no     |

## Hardening defaults

BalOS ships with a deliberate set of defaults you should understand before
changing:

- nftables in `normal` mode (inbound blocked except loopback/LAN DHCP)
- DNSCrypt-proxy is the resolver; /etc/resolv.conf points at 127.0.0.1
- SSH is **not** enabled by default
- User is in `wheel`; PolicyKit grants `wheel` passwordless access to power
  profile switching (`balboost`, `balsaver`) — but **not** `balpanic`,
  installer, or any destructive tool
- `balpanic`, `balrescue`, `balshield`, `balstealth` require real `sudo`
- BalKernel compiles with `mitigations=auto`; the live ISO boots with the
  same

## Not secrets

These are not a security bug — please don't file reports for them:

- Default passwords on the Live ISO (`balos`/`balos`)
- The fact that installed pentest tools can attack the local network
- `hashcat` uses your GPU
- Open ports in `fortress` mode are still reachable over `wg0`

## Reproducible builds

We're working toward it. Current build is deterministic modulo timestamps and
mirror selection. If reproducibility matters to your use case, pin your
mirrors in `pacman.conf` and `build.sh`.
