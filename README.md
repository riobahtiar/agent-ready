# dotfiles-cloud

Idempotent dotfiles and provisioning stages for machines that run AI coding agents—from remote Linux servers to daily-driver laptops and desktops.

One repository supports two profiles:

- **`server`** — Provisioned and **tested on the latest Ubuntu LTS** for running multiple AI coding agents side by side (Claude Code, Codex, OpenCode, omp, Grok, Muse, Hermes) and hosting web apps behind `nginx` + Let's Encrypt TLS, with SSH hardening, `ufw`, `fail2ban`, localhost-bound Docker, and `zram` + swap.
- **`desktop`** — For machines you work on directly: **macOS** (Homebrew + `mise`), **Arch / Omarchy**, **Ubuntu or Fedora desktop**, and **WSL2**. Installs the same shell, `mise` runtimes, modern CLI tools, coding agents, sandboxing, and dev tunnels—while leaving desktop firewalls, web servers, and OS tuning untouched.

> **Documentation:** Start with **[01 First setup](docs/01-first-setup.md)** and the **[Setup & Installation FAQ](docs/16-faq.md)**, or browse **[all guides in `docs/`](docs/README.md)** (on an installed machine: `vps docs`).

> **Review before running:** Server setup defaults to `FULL_CONTROL=true` (passwordless sudo, unattended agent permissions) and `DOCKER_SUDOLESS=true` (`docker` group membership, which is root-equivalent). For password-gated sudo and agent approvals, set `FULL_CONTROL=false DOCKER_SUDOLESS=false AGENT_SANDBOX=true` at bootstrap (see [SECURITY.md](SECURITY.md)). Download and inspect scripts before running them as root; use a disposable machine first.

---

## Quick Start

### 1. Fresh Linux Server (`server` profile)

Run `bootstrap.sh` once as `root`, or with `sudo` from a cloud default login (for example `ssh ubuntu@203.0.113.10`), to create your admin user, copy SSH keys, clone this repository to `~/.dotfiles`, and generate `config.env`:

```bash
# Replace 'deploy' with your preferred non-root username (as root, drop 'sudo')
curl -fsSL https://raw.githubusercontent.com/riobahtiar/dotfiles-cloud/main/bootstrap.sh | sudo bash -s -- --user deploy

# Reconnect in a new terminal with your SSH key (keep the root session open until verified), then run:
ssh deploy@203.0.113.10
~/.dotfiles/setup-server.sh
```

### 2. macOS / Linux Desktop / WSL2 (`desktop` profile)

```bash
git clone https://github.com/riobahtiar/dotfiles-cloud ~/.dotfiles
~/.dotfiles/setup-desktop.sh
```

On first run in a terminal, an interactive wizard prompts for your settings (Git identity, enabled features, agents, optional domains) and writes `~/.dotfiles/config.env` (`0600`, git-ignored). Subsequent runs are state-aware and idempotent:

```bash
./install.sh --changed      # re-apply only stages whose files or config.env changed
./install.sh --renew        # re-apply all stages + upgrade all tools/agents + re-render sites
./install.sh --status       # inspect applied, changed, incomplete, or skipped stages
```

Desktop setup also offers an explicit optional-app selection (or opt out of all).
`DESKTOP_APPS` defaults to empty, so no desktop apps are installed unless selected.
For example:

```bash
DESKTOP_APPS='zed ghostty obsidian' ~/.dotfiles/setup-desktop.sh desktop-apps -y
```

Or set `DESKTOP_APPS="zed ghostty obsidian"` in private `config.env`, then run
`~/.dotfiles/setup-desktop.sh desktop-apps -y`; use `./install.sh --configure` with the
desktop profile to change the selection interactively. Unselecting an app does
not uninstall it. Stage 85 never runs for servers. See the
[desktop app platform matrix](docs/15-what-gets-installed.md#optional-desktop-apps-stage-85)
for all IDs, package sources, and limitations.

### Environment Variable & Headless Configuration

Personal settings in [`config.env.example`](config.env.example) use dummy or empty values. You can configure them with `config.env`, the settings wizard, or exported environment variables:

```bash
# Bootstrap a custom fork and user non-interactively (plain 'sudo KEY=value' may be stripped; use 'sudo env')
sudo env TARGET_USER=deploy \
    DOTFILES_REPO=https://github.com/your-org/dotfiles-cloud.git \
    TIMEZONE=UTC \
    HERMES=false \
    bash bootstrap.sh

# Run unattended server provisioning
GIT_NAME="Jane Doe" \
GIT_EMAIL="jane@example.com" \
HERMES=false \
~/.dotfiles/setup-server.sh --all -y
```

Start from an existing private `config.env` (created by bootstrap or `cp config.env.example config.env; chmod 600 config.env`); with `--all`/`-y` and no `config.env`, the installer stops before saving anything. During installation, **nonempty exported overrides are validated and then saved to that file, including secret overrides**; they are not temporary. `--help`, `--list`, and `--status` do not save them. Values inherited from a parent dotfiles process (for example after the settings wizard or from `vps`), values equal to those in `~/.config/secrets.env`, and a `PROJECTS_DIR` equal to the shell-exported `~/.config/dotfiles/projects_dir` are not treated as overrides; to change those, edit `config.env` or run `./install.sh --configure`. To clear a value, edit the file or use the wizard. Use your fork's actual URL in place of the dummy fork URL above.

---

## What You Get

| Area | Included | Profile |
|---|---|---|
| **Coding Agents** | Claude Code, Codex, OpenCode, omp, Grok Build, Muse Code, Hermes — modular via `agents.d/` (`agents new` / `agents retire`) | `server` & `desktop` (Hermes service: `server`) |
| **Agent Multiplexer** | [Herdr](https://herdr.dev) + `tmux` fallback: persistent sessions across SSH drops with live agent status in the sidebar | `server` & `desktop` |
| **Runtimes (`mise`)** | Node LTS, Bun, Go, Python 3.13 + `uv`, `pnpm`, Flutter, TypeScript, `gopls`, `golangci-lint`, `ruff`, grouped in `~/.config/mise/conf.d/` | `server` & `desktop` |
| **Modern CLI** | `rg`, `fd`, `fzf`, `bat`, `eza`, `zoxide`, `ast-grep`, `difftastic`, `delta`, `jq`, `yq`, `gh`, `lazygit`, `lazydocker`, `just`, `watchexec`, `glow`, `gum`, `neovim` | `server` & `desktop` |
| **Quality & Delivery** | `shellcheck`, `shfmt`, `hadolint`, `gitleaks`, `biome`, `ty`, `hurl`, `oha`, `duckdb`, `usql`, `process-compose`, `sops` + `age`, `trivy`, `osv-scanner`, `act`, `dive`, `lnav` | `server` & `desktop` |
| **AI & Cloud CLIs** | `ccusage`, `repomix`, `aws-cli`, `s5cmd`, `rclone`, Cloudflare `cf` + `wrangler` + `cloudflared`, OpenTofu | `server` & `desktop` |
| **Shell & Prompt** | `fish` login shell + [`easy-eel`](https://github.com/pgolebiowski/theme-easy-eel) left prompt + zero-subprocess toolchain right prompt (`bash` + `starship` parity kept for scripts/agents) | `server` & `desktop` |
| **Sandboxing** | `srt` (`bubblewrap` / macOS Seatbelt) via `sandbox run` / `sandbox agent`, disposable `sandbox box` containers, optional gVisor (`runsc`), Claude Code sandbox toggle | `server` & `desktop` |
| **Networking & Tunnels** | Optional Tailscale + unified `tunnel` CLI across Tailscale Serve/Funnel, SSH port-forwarding, Cloudflare Quick/Named Tunnels, zrok, and Pinggy | `server` & `desktop` |
| **Optional Desktop Apps** | OrbStack, TablePro, Zed, Ghostty, Tailscale, ChatGPT desktop, Claude desktop, Helium Browser, Cloudflare WARP, Obsidian, and Mole maintenance — explicit `DESKTOP_APPS` selection; empty by default | `desktop` only; platform-dependent |
| **Containers** | Docker Engine + Compose + Buildx with merged loopback defaults for the default bridge and new user-defined bridges; existing networks are not migrated | Linux |
| **Web Hosting** | `nginx` + Let's Encrypt TLS via `site add` (`--proxy`, `--static` / `--spa`, `--php` with distro PHP-FPM + Composer) | `server` |
| **Server Hardening** | Lockout-safe key-only SSH, disabled root login, `ufw` (22/80/443), `fail2ban`, unattended security upgrades, `zram` + swapfile | `server` |
| **Hermes & Alerts** | Optional Hermes web dashboard at `https://$HERMES_DOMAIN` (TLS + `scrypt` login + IP/Cloudflare Access controls), Telegram gateway, and `notify` CLI | `server` (`notify`: both) |
| **Maintenance** | `doctor` health checks, `update-all`, safe `cleanup` (caches, Docker, merged worktrees, orphan processes), weekly `systemd` timer | `server` & `desktop` (timer: `server`) |

---

## Commands

Commands accept flags for scripts and AI agents; most management commands also open menus when run without arguments in a terminal. `doctor` and `motd` print status, while `notify` requires a message ([03 Commands](docs/03-commands.md)).

`vps` · `doctor` · `update-all` · `cleanup` · `site` · `tunnel` · `sandbox` · `agents` · `hermes-up` · `notify` · `motd` · `./install.sh` · `./setup-server.sh` · `./setup-desktop.sh`

---

## Repository Layout

```text
bootstrap.sh         first-time root bootstrap for a fresh Linux server (user, SSH keys, clone, config.env)
setup-server.sh      pins PROFILE=server and runs install.sh
setup-desktop.sh     pins PROFILE=desktop and runs install.sh
install.sh           idempotent stage runner (--configure, --all, --changed, --renew, --status, --list)
config.env.example   machine configuration template (dummy defaults; copied to git-ignored config.env)
secrets.env.example  API key template for ~/.config/secrets.env (0600, untracked)
stages/              provisioning stages (05-packages .. 90-maintenance) filtered by OS & profile headers
lib/                 shared bash libraries: os, pkg (apt/pacman/dnf/brew), stages, ui, configure, agents, tunnels, nginx
agents.d/            one self-contained module per coding agent CLI (_template.sh, retired/)
tunnels.d/           one self-contained module per dev tunnel provider (_template.sh)
bin/                 operational CLIs on PATH (menus for humans, flags for scripts/agents)
home/                mirrored into ~ as per-file symlinks (fish, mise conf.d, git, starship, srt policy)
agents/              AGENTS.global.md — shared machine rules linked into global agent configs
nginx/ system/ systemd/ shell/   system config templates and shell startup hooks
docs/                user and operator guides (01-first-setup.md .. 16-faq.md)
```

Full architecture, `config.env` keys, and module contracts: **[10 Reference](docs/10-reference.md)**.

---

## Platform Support

- **Server (`./setup-server.sh`):** The repository's recorded end-to-end testing covers **Ubuntu 26.04 LTS, the latest Ubuntu LTS**, in a systemd container, including stage re-runs. This is not a guarantee for every provider or workload. Real agent sign-ins, Telegram delivery, Let's Encrypt with public DNS, and nested gVisor execution were not covered by that run.
- **Desktop (`./setup-desktop.sh`):** Targets macOS (Homebrew + `mise`), Arch Linux & [Omarchy](https://omarchy.org/), Ubuntu/Debian & Fedora desktops, and WSL2 (`systemd=true`). Arch package/dotfile stages have container coverage; macOS, Omarchy, and WSL have not been end-to-end verified. Existing conflicting dotfiles are backed up to `~/.dotfiles-backup/<timestamp>/`.

See **[08 Multi-OS](docs/08-multi-os.md)** and **[15 What gets installed where](docs/15-what-gets-installed.md)** for full OS-by-OS details.

---

## FAQ & Troubleshooting

New to setting up this repo? Read **[16 Setup & installation FAQ](docs/16-faq.md)** for answers on:
- Running without a domain, Hermes, or Telegram (`HERMES=false`)
- Passing environment variables vs `config.env`
- How SSH lockout protection and `FULL_CONTROL` work
- How existing dotfiles, `~/.config/mise/config.toml`, Docker, and `nginx` are preserved
- Uninstalling or reverting changes

Hit an issue during or after install? Run `doctor` and `./install.sh --status`, then check **[14 Troubleshooting](docs/14-troubleshooting.md)**.

---

## Contributing & Security

- **Contributing:** See **[CONTRIBUTING.md](CONTRIBUTING.md)** and **[AGENTS.md](AGENTS.md)**. Run `mise run fmt` and `mise run check` before opening a pull request.
- **Security policy:** Please report security issues privately via **[SECURITY.md](SECURITY.md)** rather than public issues.

---

## Disclaimer & License

> **Use at Your Own Risk:** These scripts modify system, network, authentication, firewall (`ufw`), privilege (`sudoers`), web server (`nginx`), and container settings, and configure autonomous AI coding agents capable of executing commands on your machine. Review the scripts and your `config.env` settings (especially `FULL_CONTROL` and `SSH_HARDEN`), keep a backup SSH session open during server setup, and test in a disposable VM or container before running on critical systems.
>
> This software is provided **"AS IS"**, without warranty or a support commitment. To the fullest extent permitted by applicable law, the authors and copyright holders disclaim liability as set out in the MIT License, including for lockouts, data loss, security incidents, third-party software behavior, cloud/API charges, and other side effects. No license can guarantee immunity from every legal claim.

Released under the **[MIT License](LICENSE)** — free to use, modify, fork, and distribute under its terms.
