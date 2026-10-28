# Multi-OS: server and desktop

One repo sets up two kinds of machine. The **profile** decides what's worth
installing, and each stage's OS rule decides what's possible.

| | `server` | `desktop` |
|---|---|---|
| For | this VPS, any headless Linux box | a laptop or desktop you sit at: macOS, Omarchy/Arch, Ubuntu/Fedora desktop, WSL |
| Entry point | `./setup-server.sh` | `./setup-desktop.sh` |
| Default when | Linux with no graphical session installed | macOS, WSL, or Linux with a Wayland/X session |

`setup-*.sh` pin the profile (saved as `PROFILE` in config.env) and then run
`install.sh` with your flags, so `./setup-desktop.sh --changed` works.
Switching an already set up machine asks first, and stages from the old
profile are not undone.

## What each stage does where

(For the item-by-item comparison of the VPS, Omarchy and macOS, see
[15 What gets installed where](15-what-gets-installed.md).)

| Stage | server | desktop | OS rule |
|---|---|---|---|
| 05 packages (apt/pacman/dnf/brew), mise, fish | ✓ (+ full upgrade on Debian) | ✓ (no forced full upgrade) | any |
| 10 system: zram, swap, sysctl, journald, unattended upgrades, linger | ✓ | – | Linux + systemd, not WSL |
| 20 security: SSH hardening, ufw, fail2ban | ✓ | – | Debian/Arch + systemd, not WSL |
| 30 Docker Engine + daemon.json (merged, 127.0.0.1 binds) | ✓ (you in docker group) | ✓ (`DOCKER=true`; group only if `DOCKER_SUDOLESS=true`) | Linux + systemd |
| 40 nginx, certbot, PHP-FPM | ✓ | – | Debian/Ubuntu |
| 50 dotfiles links, git identity, shell hooks | ✓ | ✓ | any |
| 60 mise tools, fisher plugins | ✓ | ✓ | any |
| 65 sandbox: bubblewrap, socat, AppArmor fix | ✓ | ✓ | any (macOS: Seatbelt built in) |
| 70 agent CLIs, herdr hooks | ✓ | ✓ | any |
| 75 Tailscale + tunnels | ✓ | ✓ | any |
| 80 Hermes dashboard + nginx/TLS | ✓ | – | Debian/Ubuntu |
| 90 cleanup timer, doctor | ✓ (timer on) | ✓ (timer off: a laptop is asleep at 04:00) | Linux + systemd |

`./install.sh --status` shows the same thing for the machine you're on,
including why a stage is skipped ("needs systemd", "server profile only", …).
`./install.sh --list` shows every stage's rule.

## macOS: Homebrew + mise

```bash
# Homebrew first: https://brew.sh
git clone https://github.com/riobahtiar/dotfiles-cloud ~/.dotfiles
~/.dotfiles/setup-desktop.sh
```

- System packages, a current bash (macOS ships 3.2), fish and **mise itself**
  come from Homebrew. Runtimes and CLIs come from mise, as on Linux.
- Run it as yourself, not with sudo (Homebrew refuses root); it asks for your
  password only for `chsh` and `/etc/shells`.
- Docker: use OrbStack or Docker Desktop (stage 30 is Linux-only).
- Sandboxing: Seatbelt is built in; Claude Code, Codex and `srt` use it.
- **You already have dotfiles** ([riobahtiar/dotfiles](https://github.com/riobahtiar/dotfiles))
  in `~/.config/fish`. Linking backs up anything in the way to
  `~/.dotfiles-backup/<time>/`. Decide which repo owns fish on the laptop before you
  run this there.

## Omarchy (and Arch)

[Omarchy](https://omarchy.org/manual/) is Arch + Hyprland with its own
opinions, and this setup is built to sit alongside them:

| Omarchy already does | So this setup |
|---|---|
| ufw firewall on, SSH + LocalSend open | skips stage 20 (desktop profile) |
| mise for languages and preinstalled agent CLIs | adds its tools only in `~/.config/mise/conf.d/`; your/Omarchy's `config.toml` is never touched and wins on conflicts. Agents already on PATH (e.g. Omarchy's claude) are kept, not reinstalled |
| Docker installed, you **not** in the docker group (it's root-equivalent) | keeps it that way (`DOCKER_SUDOLESS=false` on desktop); daemon.json is merged, never replaced |
| bash with a Starship prompt, `~/.bashrc` is yours | adds one line at the top of `~/.bashrc`; keeps your `~/.config/starship.toml` |
| updates via `omarchy update` | `update-all` covers what this repo installed; run both |

```bash
git clone https://github.com/riobahtiar/dotfiles-cloud ~/.dotfiles
~/.dotfiles/setup-desktop.sh
```

`LOGIN_SHELL=fish` makes fish your login shell. Omarchy's terminal keybinding
then opens fish with the easy-eel prompt. Set `LOGIN_SHELL=bash` to keep
Omarchy's bash. Package names are mapped in `lib/pkg.sh` (e.g. `build-essential` →
`base-devel`, `bind9-dnsutils` → `bind`). Updates use `pacman -Syu`, never a
partial `-Sy`.

## Ubuntu / Debian / Fedora desktop

Same as above with apt or dnf. On a GUI Linux the default profile is already
`desktop`; `./setup-desktop.sh` makes it explicit.

## WSL (Windows)

Use WSL 2 with systemd (`/etc/wsl.conf`: `[boot]` `systemd=true`), Ubuntu as
the distro, then `./setup-desktop.sh`. Docker: if Docker Desktop's WSL
integration is on, stage 30 skips the engine. Tailscale: run it on Windows. The
browser stays Windows' (no `BROWSER=echo`).

## Adding OS support

- A package with a different name: add a row to `PKG_TABLE` in `lib/pkg.sh`.
- A stage that only makes sense somewhere: set `# stage-os:` (e.g.
  `debian+systemd,arch+systemd`) and `# stage-profile:`.
- Branch inside a stage with `$OS_FAMILY` (`debian arch fedora macos`),
  `$IS_WSL`, `$IS_OMARCHY`, `$HAS_SYSTEMD`, `$PROFILE`.

Tested: Ubuntu 26.04 server end to end (systemd container), Arch Linux stages
05 + 50 (container), plus OS detection and package mapping. macOS and Omarchy
on real hardware haven't been run yet, so treat the first run there as a
dry run you watch.
