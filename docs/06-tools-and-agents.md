# AI coding agent CLIs, runtimes, and developer tools

AgentReady installs two modular groups for your developer environment:

| Kind | Lives in | Add one | Retire one |
|---|---|---|---|
| CLI tools and runtimes | `home/.config/mise/conf.d/*.toml` (mise) | add a line, `mise install` | delete the line, `mise prune` |
| Agent CLIs | `agents.d/<name>.sh` (one module each) | `agents new <name>` | `agents retire <name>` |

## CLI tools (mise)

Every runtime and CLI comes from [mise](https://mise.jdx.dev), grouped into
drop-in files:

| File | Contents |
|---|---|
| `00-settings.toml` | mise settings (4 parallel jobs, trusted paths, auto-install) |
| `10-runtimes.toml` | node (LTS), bun, go, python 3.13, uv, pnpm, flutter |
| `20-languages.toml` | gopls, golangci-lint, ruff, typescript |
| `30-agents.toml` | agent CLIs that ship as packages: codex |
| `35-ai.toml` | ccusage (token/cost reports), repomix (repo → one LLM-ready file); more ideas commented out |
| `40-cli.toml` | rg, fd, fzf, bat, eza, zoxide, starship, jq, yq, ast-grep, difftastic, delta, sd, xh, gh, lazygit, lazydocker, dust, hyperfine, just, watchexec, scc, glow, gum, neovim, usage |
| `45-cloud.toml` | aws-cli, s5cmd, rclone, wrangler, cf, opentofu |
| `46-sandbox.toml` | srt (Anthropic sandbox-runtime), devcontainer CLI |
| `47-delivery.toml` | hurl, oha, duckdb, usql, process-compose, air, act, biome, ty, sops, age, trivy, osv-scanner, dive, lnav |
| `50-quality.toml` | shellcheck, shfmt, hadolint, gitleaks |
| `60-network.toml` | cloudflared, zrok |

`~/.config/mise/config.toml` is **not** managed: it's yours (and Omarchy's on
Omarchy). `mise use -g <tool>` writes there, and anything in it overrides the
conf.d files.

```bash
# add a tool for everyone on this config: edit the right group, then
mise install
# try one without committing to it
mise use -g ripgrep-all
# retire: delete its line, then
mise prune --yes
# what's outdated
update-all --check
```

An unknown tool name makes **all** of `mise install` fail, so check the name
first: `mise registry | grep <name>`, or use a backend prefix (`npm:`,
`pipx:`, `github:owner/repo`).

Per-project versions belong in the project (`mise use node@22` writes
`mise.toml`), and every agent in that directory gets them.

## Agent CLIs (agents.d)

Each agent is one file that declares what it is and how to install it:

```bash
agent_define claude \
    title="Claude Code (Anthropic)" \
    wrapper=b-claude \                 # fish bypass wrapper, or -
    herdr=claude \                     # herdr integration target, or -
    guide="~/.claude/CLAUDE.md" \      # gets agents/AGENTS.global.md linked
    login="claude   then type /login" \
    paths="~/.local/bin/claude ~/.local/share/claude" \   # removed on uninstall
    config="~/.claude ~/.claude.json"                     # removed only with --purge

claude_install() { _vendor_script https://claude.ai/install.sh; }
claude_update() { claude update; }
claude_configure() { …; }              # optional: settings after install
```

Everything else reads this registry: stage 70, `update-all`, `agents`,
`doctor`, `vps`, the herdr hooks, and the shared `agents/AGENTS.global.md` links
(for agents that declare `guide=`: `claude`, `codex`, `opencode`).

### Add an agent

```bash
agents new kimi          # writes agents.d/kimi.sh from agents.d/_template.sh, opens it
# fill in title, login, paths and kimi_install (usually its vendor install script)
agents install kimi      # installs, adds it to AGENTS in config.env, herdr hook, shared guide
```

If it ships as an npm/pip package, add it to `conf.d/30-agents.toml` and make
`kimi_install` run `mise install npm:<pkg>` (see `agents.d/codex.sh`). For
a `b-kimi` bypass wrapper, copy one in `home/.config/fish/cloud/ai_bypass.fish`.
Commit `~/.dotfiles` when it works.

### Retire (sunset) an agent

```bash
agents retire muse
```

This asks, uninstalls the binaries (optionally its settings and history too),
removes it from `AGENTS`, and `git mv`s the module to `agents.d/retired/` so
the recipe is kept. `agents restore muse` brings it back. Leftovers it points
out: a `b-*` wrapper, or a line in `conf.d/30-agents.toml`.

### Included agent modules

| Agent | Installed by | Sign in |
|---|---|---|
| Claude Code | [native installer](https://code.claude.com/docs/en/setup) (self-updating) | `claude`, then `/login` |
| Codex | [official npm package](https://github.com/openai/codex) via [mise's npm backend](https://mise.jdx.dev/dev-tools/backends/npm.html) | `codex login --device-auth` |
| OpenCode 1 | [vendor V1 installer](https://opencode.ai/docs/) (not an automatic V2 migration) | `opencode auth login` |
| oh-my-pi (omp) | [upstream installer source](https://github.com/can1357/oh-my-pi/blob/main/scripts/install.sh) | `omp`, then `/login` |
| Grok Build | [vendor installer](https://docs.x.ai/build/overview) | `grok login --device-auth` |
| Muse Code | [Bash installer source](https://dev.meta.ai/install.sh) | `muse`, then `/login` ([upstream authentication](https://dev.meta.ai/docs/muse-code/auth)) |
| Hermes | [vendor installer](https://hermes-agent.nousresearch.com/install.sh), stage 80 for the server dashboard | `hermes setup` |
| Herdr | [vendor installer and updater](https://herdr.dev/tui/docs/install/) | n/a |

`agents login` gives you a menu of these.

Installation endpoints and relevant flags were checked against these current
primary sources during release preparation. Vendor scripts and package metadata
can change independently of this repository; review downloaded scripts before
running them. Hermes supports the noninteractive/headless flags in its installer.
Muse's installer is Bash even where a short upstream example uses `sh`.

## Cloud CLIs

| Tool | What for | Sign in (headless-friendly) |
|---|---|---|
| `aws` | S3, everything AWS | `aws configure sso --use-device-code` (or `aws configure` for keys) |
| `s5cmd` | very fast S3/R2 copy and sync | uses the AWS credentials/profile |
| `rclone` | sync or mount S3, R2, B2, Drive, SFTP (and backups) | `rclone config` |
| `cf` | Cloudflare's new all-API CLI (beta, Wrangler's successor) | `cf auth login --no-browser` |
| `wrangler` | Workers, Pages, R2, D1, KV, Queues (`wrangler dev/deploy`) | `wrangler login` (needs `ssh -L 8976:127.0.0.1:8976` from your laptop) |
| `cloudflared` | Cloudflare Tunnel | `cloudflared tunnel login` |
| `tofu` | infrastructure as code (DNS, buckets) | provider env vars |

`vps` → **Cloud CLIs** runs each sign-in for you. For scripts and CI, put
tokens in `~/.config/secrets.env` (`CLOUDFLARE_API_TOKEN`,
`CLOUDFLARE_ACCOUNT_ID`, `AWS_PROFILE`). `cf cli search "create a DNS record"`
finds the right `cf` command. Telemetry is off (`DO_NOT_TRACK=1`).

## LLM tooling worth knowing

- `ccusage`: what your Claude Code / Codex sessions cost, per day or session.
- `repomix`: pack a repo (or part of one) into a single file to paste into a chat model.
- `hurl`: HTTP tests as plain text files that agents can read and write.
- `ast-grep` (`sg`): structural search-and-replace, safer than regex for agents.
- `difft` / `delta`: readable diffs of what an agent changed.
- Commented in `35-ai.toml`: Playwright MCP, the MCP inspector, `llm`, `crush`.

## Get pinged

`notify "text"` sends a Telegram message using `TELEGRAM_BOT_TOKEN` from
`~/.config/secrets.env`, then `~/.hermes/.env`, and `NOTIFY_TELEGRAM_CHAT` (same
order), falling back to the first ID in `TELEGRAM_ALLOWED_USERS`. To have
Claude Code ping you when it needs input or finishes a task, add this to
`~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [{ "hooks": [{ "type": "command", "command": "notify \"Claude needs you in $(basename \"$PWD\")\"" }] }],
    "Stop":         [{ "hooks": [{ "type": "command", "command": "notify \"Claude finished in $(basename \"$PWD\")\"" }] }]
  }
}
```

For anything else: `long-command; notify "done: $status"`.
