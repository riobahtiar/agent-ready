# AgentReady guides — AI coding environments on macOS and Linux

**Your machine, ready for agentic development.** These guides cover setting up, operating, and customizing AgentReady for AI coding agents on Ubuntu servers, macOS, Linux desktops, and WSL. On an installed machine, run `vps docs` (or `vps` → Guides) to read any guide in the terminal.

| # | Guide | When to read it |
|---|---|---|
| 01 | [Ubuntu server and first setup](01-first-setup.md) | Provisioning a fresh Ubuntu LTS server (or setting up a desktop) |
| 02 | [Daily workflow](02-daily-workflow.md) | SSH config, `herdr`, project helpers, git worktrees, previews, remote editors |
| 03 | [Commands and automation](03-commands.md) | Interactive menu and CLI flag reference for every command |
| 04 | [Shell and prompt](04-shell-and-prompt.md) | `fish`, the `easy-eel` prompt and right-prompt sections, login summary, abbreviations |
| 05 | [Hosting sites](05-hosting-sites.md) | Publishing apps, static/SPA builds, and PHP sites with `nginx` + Let's Encrypt |
| 06 | [Tools and agents](06-tools-and-agents.md) | Managing `mise` tool groups (`conf.d/`), `agents.d/` modules, cloud CLIs, and hooks |
| 07 | [Networking](07-networking.md) | Tailscale setup and choosing the right `tunnel` provider |
| 08 | [macOS and Linux platform setup](08-multi-os.md) | `server` vs `desktop` profiles across Ubuntu LTS, macOS, Arch/Omarchy, Fedora, and WSL |
| 09 | [Sandboxing](09-sandboxing.md) | Isolating agents and untrusted commands with `srt`, bubblewrap/Seatbelt, and containers |
| 10 | [Reference](10-reference.md) | All `config.env` & environment variables, file layout, stage headers, and module APIs |
| 11 | [Hermes + Telegram](11-hermes-telegram.md) | Optional Hermes web dashboard (`$HERMES_DOMAIN`), Cloudflare Access, Telegram bot, and `notify` |
| 12 | [Maintenance and upgrades](12-maintenance.md) | Adopting AgentReady, updates, `--changed` vs `--renew`, `cleanup`, health checks, and backups |
| 13 | [Recommended tools](13-recommended-tools.md) | Optional self-hosted and remote-dev additions for an agent server |
| 14 | [Troubleshooting](14-troubleshooting.md) | Symptom-by-symptom fixes for setup, SSH, TLS, Docker, `mise`, and tunnels |
| 15 | [Installed tools and desktop apps](15-what-gets-installed.md) | Ubuntu LTS Server vs Arch/Omarchy Desktop vs macOS, plus the optional desktop app IDs and package-source matrix |
| 16 | [Setup & installation FAQ](16-faq.md) | Common questions before and during setup, customization, safety, and uninstalling |

## CLI commands (`bin/`)

Most management commands open menus when run without arguments in a terminal. Pass explicit flags for scripts and AI agents. `doctor` and `motd` print status; `notify` requires a message.

| Command | Purpose |
|---|---|
| `vps` | AgentReady's unified interactive dashboard for health, updates, sites, tunnels, agents, logs, and guides |
| `doctor` | Health check: services, memory, disk, agents; public port exposure and TLS certificates (`server` profile) |
| `update-all` | Upgrade OS packages, `mise` runtimes/CLIs, agent CLIs, and Fisher plugins |
| `cleanup` | Reclaim disk & memory: caches, Docker artifacts, merged/stale git worktrees, orphaned processes |
| `site` | Manage `nginx` virtual hosts and Let's Encrypt TLS certificates (`server` profile) |
| `tunnel` | Share local dev ports via Tailscale, SSH, Cloudflare, zrok, or Pinggy |
| `sandbox` | Run commands or agents inside `srt` (bubblewrap/Seatbelt) or disposable containers |
| `agents` | Install, update, sign in, scaffold, or retire coding agent CLIs (`agents.d/`) |
| `hermes-up` | Install/start the Hermes Telegram gateway service and check dashboard status (`server` profile) |
| `notify "msg"` | Send yourself a Telegram notification via your configured bot |
| `motd` | Print the fast SSH login summary (last login, load, memory, disk, containers, agents) |
| `./install.sh` | Run provisioning stages (`--configure`, `--changed`, `--renew`, `--status`, `--list`) |

## Rules of thumb

- **Re-running is safe:** Every stage and CLI command is idempotent.
- **Edit the source, not `/etc`:** Modify templates/configs in `~/.dotfiles` and re-run the stage (`./install.sh --changed`), rather than hand-editing stage-managed files under `/etc`.
- **Keep secrets out of git:** Machine settings live in `~/.dotfiles/config.env` (git-ignored), API keys in `~/.config/secrets.env` (`0600`), and OAuth sessions in each tool's login store.

## Stable paths when adopting AgentReady

The conventional checkout `~/.dotfiles`, backups in `~/.dotfiles-backup`, repository
state in `.state`, and runtime paths under `~/.config/dotfiles` and
`~/.local/state/dotfiles` are deliberately unchanged. The `fish/cloud` directory,
`cloud-cleanup` services, and managed system fragment names are stable operational
identifiers, not repository branding. **No directory move is needed.** The CLI
remains `vps`; see [the upgrade note](12-maintenance.md#adopting-agentready) for
the remote URL and environment-variable transition.
