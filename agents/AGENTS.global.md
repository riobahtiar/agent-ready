# This machine

Global instructions for every coding agent on this box (Claude Code, Codex,
OpenCode, omp, Grok, Muse, Hermes). Linked from `~/.dotfiles/agents/AGENTS.global.md`.
A project's own AGENTS.md / CLAUDE.md overrides this file.

This file applies to server and desktop profiles, including Linux, macOS and
WSL. Use the configured `PROFILE` when available; do not read credential-bearing
configuration to discover it. Installed tools and services depend on the profile
and selected toggles.

## Shared resources
- Before heavy jobs, check `nproc`, `free -h` and `df -h /` where available; on macOS use `sysctl -n hw.ncpu` and `vm_stat` when the Linux commands are absent.
- Run one heavy job at a time: full builds, container builds and large test suites. Prefer a targeted file or package.
- Choose parallelism and memory limits from available resources, allowing room for other agents and services.
- Stop watchers and development servers you started when the task is complete.

## Runtimes and packages
- Every runtime comes from **mise**: node (LTS), bun, go, python, uv, pnpm, flutter. Pin per project with `mise use node@22` etc. (writes `mise.toml`). Never `apt install` a language runtime, never `curl | sh` a second version manager (nvm, pyenv, gvm).
- No global `npm i -g`. Use `bunx`/`npx` for one-offs, or `mise use -g npm:<pkg>` for tools you need permanently.
- Python: `uv` (`uv run`, `uv add`, `uv tool run`). Never `pip install` into the system Python. Lint and format with `ruff`.
- PHP uses the system PHP/FPM and Composer where installed. Check the installed version; use a container if the project requires a different version.
- Check tools before relying on them. Flutter can run headlessly for tests and web builds; devices and emulators are not assumed.

## Available tool groups (check installation before use)
- Search/edit: `rg`, `fd`, `ast-grep` (`sg`, structural search and replace), `sd`, `jq`, `yq`, `difft`, `delta`.
- Git/GitHub: `gh`, `lazygit`, `gitleaks`. HTTP: `xh`, `hurl` (assertions in plain files: prefer it for API checks), `oha` (load).
- Data: `duckdb` (SQL over CSV/JSON/Parquet), `usql` (any SQL database).
- Quality: `biome` (JS/TS format + lint), `ruff` + `ty` (Python), `golangci-lint`, `shellcheck`, `shfmt`, `hadolint`, `trivy`, `osv-scanner`.
- Run things: `just`, `watchexec`, `process-compose`, `air` (Go), `act` (GitHub Actions locally), `docker compose`.
- Cloud: `aws`, `s5cmd`, `rclone`, `wrangler`, `cf`, `tofu`. Authentication is user-managed; never run `login` or `configure` without authorization.
- Secrets in git: `sops` + `age`.

## Git and worktrees
- Do parallel work in **git worktrees**, not by switching branches under another agent. Use `wt <branch>` (fish), which creates `<repo>/.worktrees/<branch>`, or your tool's own worktree feature.
- **Remove your worktree when the task is merged or abandoned** (`git worktree remove <path>`). `cleanup worktrees` sweeps clean, merged or stale ones, but it never touches a dirty one.
- Run `gitleaks protect --staged` before committing in repos that handle credentials. Never commit `.env` files.

## Docker
- Use explicit **127.0.0.1** port bindings (`-p 127.0.0.1:3000:3000`, Compose `"127.0.0.1:3000:3000"`). Daemon loopback defaults only cover the default bridge and newly created user-defined bridges; existing networks are not migrated. Docker bypasses ufw. Never use public binds; require Engine 28+ to avoid its documented older-engine L2 exposure.
- Give containers memory limits (`mem_limit` / `deploy.resources.limits.memory`), and use `restart: unless-stopped` only for things meant to stay up.
- `docker compose down` what you started for testing. Never `docker volume prune` or delete volumes you didn't create.

## Hosting (nginx, server profile only)
- Public sites: run the app on `127.0.0.1:<port>`, then `site add <domain> --proxy <port>`. Static: `site add <domain> --static <dir>`. PHP: `site add <domain> --php <dir>/public`.
- Don't hand-edit `/etc/nginx`. Change `~/.dotfiles/nginx/templates/` and run `site renew`.
- See which ports are taken with `site ls` and `ss -tln`. Pick a free port in 3000–3999 for new apps.

## Secrets — never print, copy or commit
`~/.config/secrets.env`, `~/.hermes/.env`, `~/.dotfiles/config.env`, `~/.ssh/`, `~/.claude/.credentials.json`, `~/.codex/auth.json`.
Read keys from the environment. Don't echo them into logs, commits, issues or chat.

## Ops commands (in `~/.dotfiles/bin`, on PATH)
Run bare in a terminal they open menus for the human. **You have no TTY, so
always pass arguments**; a missing one fails fast instead of prompting.
- `doctor` checks health: services, memory, disk, public ports, certificates and agents.
- `cleanup <caches|docker|worktrees|agents|projects|system|procs> --dry-run` shows what it would reclaim. Show the user before running it for real.
- `site add <domain> --proxy <port>` / `site ls` / `site logs <domain>` manage nginx vhosts and TLS (server only).
- `tunnel <port> <provider>` shares a dev server (`tunnel providers`, `tunnel ls`, `tunnel stop <port>`). Public providers (`cloudflare`, `pinggy`, `zrok`, `funnel`) expose the port to anyone and need `-y` without a terminal: ask the user first, every time.
- `sandbox run <cmd…>` runs a command with project-only writes, an allowlisted network and secrets hidden. Use it for untrusted installs and scripts.
- `notify "<message>"` pings the user on Telegram (when a long task finishes or you're blocked).
- `update-all --check` lists what's outdated. Leave upgrades themselves to the user.
- `agents` lists the agent CLIs and their versions.

## mise trust
- Only `~/.dotfiles` is trusted. If mise says a project's config isn't trusted, stop and ask the user to review and `mise trust` it. Never run `mise trust` yourself.

## Sandboxing
- Claude Code's sandbox setting depends on `AGENT_SANDBOX` and the effective `~/.claude/settings.json`. Do not assume it is enabled; existing user settings are preserved.
- `AGENT_SANDBOX=false` skips enabling the sandbox; it does not remove credential read-deny rules. These rules are always merged, including with `FULL_CONTROL=true`.
- Permission approval modes and OS-level sandbox isolation are different controls. Full control or permission bypass does not authorize bypassing security isolation or accessing credentials.
- If an operation is blocked by isolation or a network policy, report it rather than finding a workaround.
- Never read or copy `~/.ssh`, `~/.aws`, `~/.config/rclone`, `~/.cloudflared` or the secret files above, even when technically accessible.

## Full control
`FULL_CONTROL=true` configures supported agent permission-bypass defaults and
passwordless sudo. A successful `sudo -n true` alone does not establish this
configuration or authorize unrelated changes. Within the user's task, full
control permits package installation, managed system configuration changes and
service restarts. It does not waive credential protections, isolation, or these
network safety rules:
- Do not weaken SSH authentication or remove authorized keys.
- Do not disable or loosen the firewall or fail2ban, or open additional public ports without explicit authorization.
- Do not publish containers on all interfaces or expose services without TLS and appropriate authentication.
- Ask before starting public tunnels.
Prefer changing `~/.dotfiles` and re-running the relevant stage over editing
generated system files that a stage will overwrite.

## Things that need a human
- Without full control, `sudo` asks for a password: stop and tell the user the exact command.
- Don't reboot unless asked: other agents' sessions die with it.
- Ask before deleting data you didn't create (databases, volumes, other worktrees).
