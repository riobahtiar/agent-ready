# dotfiles-cloud

Dotfiles for machines that run AI coding agents. One repo covers two kinds:

- **server**: an Ubuntu 26.04 VPS (4 vCPU / 6 GB / 100 GB) that runs Claude Code,
  Codex, OpenCode, omp, Grok, Muse and Hermes side by side and hosts small sites.
- **desktop**: a laptop or desktop you sit at: macOS (Homebrew + mise),
  Omarchy/Arch, Ubuntu or Fedora desktop, WSL. Same shell, tools and agents,
  none of the server parts.

It's the cloud counterpart of the laptop config
([riobahtiar/dotfiles](https://github.com/riobahtiar/dotfiles)): same fish
setup, abbreviations, `b-*` wrappers and mise-first runtimes.

**All guides are in [docs/](docs/README.md)**; start with
[01 First setup](docs/01-first-setup.md). On the machine: `vps docs`.

## Quick start

```bash
# VPS, as root (creates your user, copies SSH keys, clones the repo)
curl -fsSL https://raw.githubusercontent.com/riobahtiar/dotfiles-cloud/main/bootstrap.sh | bash -s -- --user rio
# then, as rio, from a new terminal
~/.dotfiles/setup-server.sh

# Laptop / desktop / WSL
git clone https://github.com/riobahtiar/dotfiles-cloud ~/.dotfiles
~/.dotfiles/setup-desktop.sh
```

The first run asks for your settings, then installs everything that fits the
machine. Later runs know they've run: re-apply what changed (`--changed`),
renew everything (`--renew`), or pick stages.

## What you get

| Area | What | Profile |
|---|---|---|
| **Agents** | Claude Code, Codex, OpenCode, omp, Grok Build, Muse Code, Hermes, as one module each in `agents.d/` (`agents new` / `agents retire`) | both (Hermes dashboard: server) |
| **Agent workspace** | [Herdr](https://herdr.dev): sessions survive SSH drops, agent state in the sidebar | both |
| **Runtimes** | Node LTS, Bun, Go, Python 3.13 + uv, pnpm, Flutter, TypeScript via [mise](https://mise.jdx.dev), grouped in `conf.d/` | both |
| **Cloud** | aws-cli, s5cmd, rclone, Cloudflare `cf` + wrangler + cloudflared, OpenTofu | both |
| **Delivery** | hurl, oha, duckdb, usql, process-compose, biome, ty, sops + age, trivy, osv-scanner, act, dive, lnav, ccusage, repomix | both |
| **Modern CLI** | rg, fd, fzf, bat, eza, zoxide, ast-grep, difftastic, delta, jq, yq, gh, lazygit, lazydocker, just, watchexec, glow, gum, neovim… | both |
| **Shell** | fish + the [easy-eel](https://github.com/pgolebiowski/theme-easy-eel) prompt with a full-stack right prompt (exit code, duration, worktree, node/bun/go/php/python/flutter/compose) | both |
| **Sandboxing** | Claude Code sandbox on, `srt` jail for any agent/command, `sandbox box` containers, optional gVisor | both |
| **Network** | Tailscale; `tunnel` over Tailscale Serve/Funnel, Cloudflare quick/named, zrok, Pinggy or SSH | both |
| **Containers** | Docker Engine + compose, ports bound to 127.0.0.1 | Linux |
| **Hosting** | nginx + Let's Encrypt via `site add` (proxy, static/SPA, PHP 8.5) | server |
| **Hardening** | key-only SSH, ufw (22/80/443), fail2ban, unattended security upgrades, zram + swap | server |
| **Hermes** | dashboard at **https://h.ciptalogi.com** (TLS + login), Telegram gateway, `notify` | server |
| **Housekeeping** | `doctor`, `update-all`, `cleanup` (caches, Docker, finished agent worktrees, orphans), weekly timer | both (timer: server) |

## Commands

Each opens a menu when run bare in a terminal and takes flags otherwise
([03 Commands](docs/03-commands.md)):

`vps` · `doctor` · `update-all` · `cleanup` · `site` · `tunnel` · `sandbox` ·
`agents` · `notify` · `hermes-up` · `./install.sh` · `./setup-server.sh` · `./setup-desktop.sh`

## Layout

```
setup-server.sh  setup-desktop.sh  install.sh  bootstrap.sh
stages/      one concern per stage; headers say who runs it, on which OS, for which profile
lib/         shared bash: os, pkg (apt/pacman/dnf/brew), stages, ui, agents, tunnels, nginx…
agents.d/    one module per agent CLI          tunnels.d/   one module per tunnel provider
bin/         the commands above                home/        symlinked into ~ (fish, mise conf.d, git…)
docs/        every guide                       agents/AGENTS.global.md   what agents read about this box
```

Full layout and module APIs: [10 Reference](docs/10-reference.md). Working on
the repo itself (conventions, checks): [AGENTS.md](AGENTS.md).

## Status

Tested in containers: the full server install on Ubuntu 26.04 (systemd, all
12 stages, re-runs with `--changed` and `--renew`), real Cloudflare and Pinggy
tunnels, the srt sandbox policy, and the menus driven through a pseudo-terminal. On Arch:
detection, package mapping and stages 05 + 50. Not yet run on real hardware:
macOS, Omarchy, WSL. Also not run: agent sign-ins, the Telegram gateway with a
real token, Let's Encrypt with real DNS, and a gVisor container (the nested test
container can't run containers at all). See [08 Multi-OS](docs/08-multi-os.md).
