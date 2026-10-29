# Guides — start here

Everything about using and changing these dotfiles lives in this folder. On the
machine, `vps docs` (or `vps` → Guides) opens any of these in the terminal.

| # | Guide | Read it when |
|---|---|---|
| 01 | [First setup](01-first-setup.md) | You have a fresh VPS (or laptop) and want it ready |
| 02 | [Daily workflow](02-daily-workflow.md) | Connecting, herdr, projects, worktrees, previews, editors |
| 03 | [Commands](03-commands.md) | What every command does, menu and flag forms |
| 04 | [Shell and prompt](04-shell-and-prompt.md) | fish, the easy-eel prompt and its sections, abbreviations |
| 05 | [Hosting sites](05-hosting-sites.md) | Putting a project on a domain with TLS |
| 06 | [Tools and agents](06-tools-and-agents.md) | Adding or retiring a CLI tool or an agent, cloud CLIs, LLM tooling |
| 07 | [Networking](07-networking.md) | Tailscale, and which dev tunnel to use when |
| 08 | [Multi-OS](08-multi-os.md) | macOS, Arch/Omarchy, WSL, Fedora; server vs desktop profiles |
| 09 | [Sandboxing](09-sandboxing.md) | Isolating agents and untrusted code |
| 10 | [Reference](10-reference.md) | config.env keys, file layout, module APIs, design notes |
| 11 | [Hermes + Telegram](11-hermes-telegram.md) | The Hermes web dashboard and Telegram bot |
| 12 | [Maintenance](12-maintenance.md) | Updates, renew, cleanup, health, backups |
| 13 | [Recommended tools](13-recommended-tools.md) | More things worth adding to a VPS you code on |
| 14 | [Troubleshooting](14-troubleshooting.md) | Something's wrong |
| 15 | [What gets installed where](15-what-gets-installed.md) | Ubuntu VPS vs Omarchy vs macOS, side by side |

## The ten commands you'll use

Every one opens a menu when you run it bare in a terminal, and takes flags
when a script or an agent calls it (no TTY, no prompts, no hanging).

| Command | For |
|---|---|
| `vps` | One menu for everything below |
| `doctor` | Is the box healthy? (services, memory, disk, exposure, certs, agents) |
| `update-all` | Upgrade apt, mise tools, every agent CLI, fish plugins |
| `cleanup` | Reclaim disk: caches, Docker junk, finished agent worktrees, orphans |
| `site` | Put an app on a domain with Let's Encrypt |
| `tunnel` | Share a dev server: Tailscale, Cloudflare, zrok, Pinggy, SSH |
| `sandbox` | Run an agent or a command with less reach |
| `agents` | Install, update, sign in, add or retire agent CLIs |
| `notify "msg"` | Ping yourself on Telegram (via the Hermes bot) |
| `./install.sh` | Set up, re-apply what changed, or renew everything |

## Rules of thumb

- Re-running anything is safe: stages and commands are idempotent.
- Change the source in `~/.dotfiles`, never the files under `/etc` it installed.
- Secrets live in `~/.dotfiles/config.env`, `~/.config/secrets.env` and each
  tool's own login store, never in git.
