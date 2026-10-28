# This machine

Global instructions for every coding agent on this box (Claude Code, Codex,
OpenCode, omp, Grok, Muse, Hermes). Linked from `~/.dotfiles/agents/AGENTS.global.md`.
A project's own AGENTS.md / CLAUDE.md overrides this file.

The same file is used on the **server** (the shared Ubuntu VPS) and on
**desktops** (macOS, Omarchy/Arch, WSL). `grep ^PROFILE ~/.dotfiles/config.env`
tells you which one you're on. The resource rules matter most on the server.

## Resource budget — you are not alone
- Ubuntu 26.04, **4 vCPU / 6 GB RAM** (+ zram and a swapfile), 100 GB disk. Several agents run at the same time.
- Run **one heavy job at a time**: full builds, `flutter build`, `docker build`, big test suites. Prefer targeted tests (one file or package) over the whole suite.
- Don't leave watchers or dev servers running when you're done (`vite`, `next dev`, `bun --watch`, `tsc -w`, `flutter run`). Stop what you started.
- Cap parallelism: `go test -p 2`, `pytest -n 2`, `jest --maxWorkers=2`, `NODE_OPTIONS=--max-old-space-size=1536` for big TS builds.
- Check `free -h` before starting something big. If memory is tight, wait or ask.

## Runtimes and packages
- Every runtime comes from **mise**: node (LTS), bun, go, python, uv, pnpm, flutter. Pin per project with `mise use node@22` etc. (writes `mise.toml`). Never `apt install` a language runtime, never `curl | sh` a second version manager (nvm, pyenv, gvm).
- No global `npm i -g`. Use `bunx`/`npx` for one-offs, or `mise use -g npm:<pkg>` for tools you need permanently.
- Python: `uv` (`uv run`, `uv add`, `uv tool run`). Never `pip install` into the system Python. Lint and format with `ruff`.
- PHP: the system **php-fpm + composer** (PHP 8.5). If a project needs another PHP version, run it in Docker.
- Go: `gopls` and `golangci-lint` are installed. Flutter runs headless (no device or emulator). Use `flutter test` and `flutter build web`.

## Tools you can rely on
- Search/edit: `rg`, `fd`, `ast-grep` (`sg`, structural search and replace), `sd`, `jq`, `yq`, `difft`, `delta`.
- Git/GitHub: `gh`, `lazygit`, `gitleaks`. HTTP: `xh`, `hurl` (assertions in plain files: prefer it for API checks), `oha` (load).
- Data: `duckdb` (SQL over CSV/JSON/Parquet), `usql` (any SQL database).
- Quality: `biome` (JS/TS format + lint), `ruff` + `ty` (Python), `golangci-lint`, `shellcheck`, `shfmt`, `hadolint`, `trivy`, `osv-scanner`.
- Run things: `just`, `watchexec`, `process-compose`, `air` (Go), `act` (GitHub Actions locally), `docker compose`.
- Cloud: `aws`, `s5cmd`, `rclone`, `wrangler`, `cf` (Cloudflare, `cf cli search "<what>"` finds commands), `tofu`. They're signed in by the user; never run `login`/`configure` yourself.
- Secrets in git: `sops` + `age`.

## Git and worktrees
- Do parallel work in **git worktrees**, not by switching branches under another agent. Use `wt <branch>` (fish), which creates `<repo>/.worktrees/<branch>`, or your tool's own worktree feature.
- **Remove your worktree when the task is merged or abandoned** (`git worktree remove <path>`). `cleanup worktrees` sweeps clean, merged or stale ones, but it never touches a dirty one.
- Run `gitleaks protect --staged` before committing in repos that handle credentials. Never commit `.env` files.

## Docker
- Published ports bind to **127.0.0.1 by default** (daemon `"ip": "127.0.0.1"`). Docker bypasses the ufw firewall, so never publish `0.0.0.0:` ports. nginx is the only public entry point.
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
- Claude Code's sandbox is on (bubblewrap/Seatbelt). If a command fails with
  "Operation not permitted" or a blocked domain, say so; don't hunt for a way around it.
- Never read or copy `~/.ssh`, `~/.aws`, `~/.config/rclone`, `~/.cloudflared`
  or the secret files above, even when you could.

## Things that need a human
- `sudo` asks for a password. If a step needs root, stop and tell the user the exact command.
- Don't edit `~/.dotfiles` unless asked. It's a git repo of this machine's config. Propose the change instead.
- Don't reboot, and don't restart `nginx`, `docker` or `hermes-*` services, unless the user asked you to.
