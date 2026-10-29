# Optional tools for remote development and AI coding workflows

Ideas for extending your AgentReady server or workstation with optional tools, grouped by
use case. Some built-in opt-ins and already-installed tools are included for
context and labelled below.

## Access and editing

| Tool | Why | Add |
|---|---|---|
| **Tailscale** | private access from laptop and phone, private dev URLs, optional keyless SSH | `TAILSCALE=true`, `./install.sh network` (built in) |
| **mosh** | a terminal that survives Wi-Fi changes and laptop sleep | `OPEN_MOSH=true`, `./install.sh security` (built in) |
| **Zed remote** | full editor with the server part on your server, lighter than VS Code | on your laptop: `zed ssh://cloud/~/projects/app` |
| **VS Code / Cursor Remote-SSH** | familiar, with extensions | laptop extension; uses ~400 MB RAM on the server per window |
| **Blink Shell / Termius** (iPad, phone) | mosh + herdr from anywhere | app stores |
| **code-server** | VS Code in a browser tab | only behind Cloudflare Access or Tailscale: `curl -fsSL https://code-server.dev/install.sh \| sh`, then `tunnel 8080 tailscale` |

## Seeing what's going on

| Tool | Why | Add |
|---|---|---|
| **Beszel** | a lightweight dashboard (CPU, RAM, disk, Docker) with alerts; agent ~10 MB RAM | Docker compose on 127.0.0.1, `site add` behind Cloudflare Access |
| **Uptime Kuma** | uptime checks for your sites, Telegram alerts | `louislam/uptime-kuma:2` container |
| **Dozzle** | live Docker logs in a browser | `amir20/dozzle` container, Tailscale-only |
| **ccusage** | what agents cost per day/session | installed (`35-ai.toml`) |

## Shipping

| Tool | Why | Add |
|---|---|---|
| **Mailpit** | catch outgoing email from apps in dev | `axllent/mailpit` container |
| **Postgres / Redis (Valkey)** | dev databases | per project in `compose.yaml`, ports on 127.0.0.1, `mem_limit` set |
| **lazysql / pgcli** | database TUIs | `mise use -g github:jorgerojas26/lazysql`, `mise use -g pipx:pgcli` |
| **jj (Jujutsu)** | Git-compatible VCS that many find easier for juggling agent branches | `jj = "latest"` in `40-cli.toml` |
| **goreleaser, sqlc, atlas, dbmate** | Go releases, typed SQL, schema migrations | per project via `mise use` |
| **k6** | scripted load tests (heavier than `oha`) | `k6 = "latest"` in `47-delivery.toml` |
| **Doppler / Infisical / 1Password CLI** | team secrets instead of `.env` files | `doppler`, `infisical` or `1password-cli` in mise |

## Agents and LLMs

| Tool | Why | Add |
|---|---|---|
| **Playwright MCP** | agents drive a real browser for UI checks (~300 MB each, so one at a time) | uncomment in `35-ai.toml` |
| **container-use** (Dagger) | each agent gets its own container + git branch over MCP | uncomment in `46-sandbox.toml` (needs the Dagger engine) |
| **ai-jail** | bubblewrap + Landlock wrapper made for agents | `cargo install ai-jail`, or keep `sandbox agent` |
| **llm** | quick prompts and pipes (`git diff \| llm "review"`) | uncomment `pipx:llm` in `35-ai.toml` |
| **Another agent CLI** | Kimi, Qwen, Cursor agent, Crush… | `agents new <name>` ([06](06-tools-and-agents.md)) |

## Safety nets

| Tool | Why | Add |
|---|---|---|
| **restic** or **rclone** nightly | a single server disk is a single point of failure | [12 Maintenance](12-maintenance.md#backups) |
| **earlyoom** | kills the largest process before the whole server stalls if RAM runs out | `sudo apt install earlyoom` (zram + swap already cover most cases) |
| **Cloudflare Access** | an identity check in front of any dashboard you expose | Zero Trust → Access → Applications |
