# AgentReady configuration, environment variables, and stage APIs

## config.env

`./install.sh --configure` writes `config.env`; the table below lists every key.
An empty value means "use the default". Because `config.env` is an input to every
stage, editing `config.env` marks all stages as changed: `./install.sh --changed`
re-runs all applicable stages, whereas `./install.sh <stage>` (e.g.
`./install.sh hermes`) re-runs just one stage.

Any `config.env` key can also be passed as a nonempty exported environment
variable override (for example, `HERMES=false TIMEZONE=UTC ./install.sh --all -y`).
Overrides need an existing `config.env` (from bootstrap, the wizard, or
`cp config.env.example config.env`); with `--all`/`-y` and no `config.env`,
`install.sh` stops before saving anything. On installation runs, overrides are
**saved to the private `config.env` after `load_config` validates them and before
sudo escalation** (secrets are written by the owning user, never passed on a
command line), so later runs retain them and `--changed` detects updated
settings. Empty values do not override. `--status`, `--list`, and `--help` do not
save overrides; `--configure` saves them only if you proceed into installation
after the wizard. Machine commands use overrides for that invocation; bootstrap
seeds every nonempty key into a new `config.env`.

Values that are not your explicit choice are **not** treated as overrides:

- anything inherited from a parent AgentReady process (`load_config` exports
  `AGENT_READY_CONFIG_LOADED=1`), so `install.sh` relaunched after the wizard or from
  `vps` reads `config.env` fresh;
- a key whose environment value equals its value in `~/.config/secrets.env`
  (your login shell exports that file);
- `PROJECTS_DIR` when it equals what the shell exports from
  `~/.config/dotfiles/projects_dir`.

To change such a value, edit `config.env` or run `./install.sh --configure`.

Secret keys (`GITHUB_TOKEN`, `TAILSCALE_AUTHKEY`, `HERMES_DASHBOARD_PASSWORD`,
`TELEGRAM_BOT_TOKEN`) are unexported by `load_config` under those names. However,
`load_config` exports `GITHUB_TOKEN` as `MISE_GITHUB_TOKEN` to every stage and
machine command, so all of their child processes can read it.

| Key | Default | Used by |
|---|---|---|
| `TARGET_USER` | the invoking user | everything: owner of projects and agents |
| `GIT_NAME`, `GIT_EMAIL` | — | 50: `~/.config/git/local` |
| `GITHUB_TOKEN` | — | 60: lifts GitHub's 60/h API limit for mise (copied to secrets.env) |
| `PROFILE` | desktop on macOS/WSL/GUI Linux, else server | which stages run ([08](08-multi-os.md)) |
| `TIMEZONE`, `LOCALE` | UTC, en_US.UTF-8 | 10 |
| `HOSTNAME_FQDN` | keep | 10 |
| `LOGIN_SHELL` | fish | 05 |
| `LOGIN_GREETING` | true | 10 (server): only toggles Ubuntu's own login messages — update-motd scripts (dpkg-statoverride), motd-news (and its timer, masked) and the provider's `/etc/motd` (backed up to `/etc/motd.dotfiles-orig`) off; `wtmpdb` for "Last login". `bin/motd` runs on every SSH login shell regardless, unless `AGENT_READY_GREETING=off` |
| `CLOUD_INIT_LOCK` | true | 10 (server): `/etc/cloud/cloud-init.disabled` after first boot, so provider boot commands stop |
| `SWAP_SIZE_GB`, `ZRAM` | 4, true | 10 (server) |
| `SSH_HARDEN`, `SSH_DISABLE_ROOT`, `OPEN_MOSH` | true, true, false | 20 (server); `SSH_HARDEN=force` skips the "key login seen" check |
| `F2B_IGNORE_IPS` | — | 20: never banned (plus loopback, Tailscale, the installing IP) |
| `TAILSCALE`, `TAILSCALE_SSH`, `TAILSCALE_AUTHKEY` | false, false, — | 75 |
| `TUNNEL_DEFAULT` | auto | `tunnel` |
| `FULL_CONTROL` | true on server, false on desktop | 05: passwordless sudo (visudo-checked `/etc/sudoers.d`), Claude `bypassPermissions` + Codex `never`/`danger-full-access` defaults, `b-claude`/`b-codex` skip the prompt; turns `AGENT_SANDBOX` off by default. Turning it off later does not revert docker membership or agent bypass settings already written ([16](16-faq.md)) |
| `DOCKER` | true | 30 |
| `DOCKER_SUDOLESS` | true on server (regardless of `FULL_CONTROL`), false on desktop | 30: docker group (root-equivalent) |
| `GVISOR` | false | 30: runsc runtime |
| `AGENT_SANDBOX` | true (false with `FULL_CONTROL`) | 70: Claude Code `sandbox.enabled` (only if unset) |
| `ACME_EMAIL` | — | 40, 80, `site add` |
| `PHP`, `WWW_DIR` | true, /srv/www | 40 |
| `PROJECTS_DIR` | ~/projects | 05, prompt, cleanup |
| `FLUTTER_LINUX_DESKTOP` | false | 05, 60 |
| `AGENTS` | claude codex opencode omp grok muse herdr | 70 (module names in agents.d/) |
| `DESKTOP_APPS` | empty (install none) | 85, desktop only: whitespace-separated IDs `orbstack tablepro zed ghostty tailscale chatgpt claude helium cloudflare-warp obsidian mole`; select in `./install.sh --configure` or edit private `config.env`; unselecting does not uninstall |
| `CLEANUP_TIMER` | true on server, false on desktop | 90 |
| `HERMES`, `HERMES_DOMAIN`, `HERMES_DASHBOARD_USER`, `HERMES_DASHBOARD_PORT` | true, —, `$TARGET_USER`, 9119 | 80; with `HERMES_DOMAIN` empty stage 80 skips Hermes entirely (no CLI, no Telegram credentials, no dashboard) — CLI only: `agents install hermes`; `HERMES=false` also skips it |
| `HERMES_DASHBOARD_PASSWORD` | prompted | 80 (only the scrypt hash is stored) |
| `HERMES_ALLOW_IPS` | — | 80: nginx allowlist |
| `HERMES_CLOUDFLARE_ONLY` | false | 80: accept only Cloudflare's IP ranges (use with Cloudflare Access) |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS` | — | 80 → `~/.hermes/.env`, `notify` |

Additional environment knobs:

| Variable | Default | Purpose |
|---|---|---|
| `AGENT_READY_DIR` | resolved checkout root | Shared helpers and commands locate repository files here; the conventional checkout is `~/.dotfiles` |
| `AGENT_READY_REPO` | `https://github.com/riobahtiar/agent-ready.git` | `bootstrap.sh`: repository URL to clone (`--repo`) |
| `AGENT_READY_BRANCH` | `main` | `bootstrap.sh`: branch to clone (`--branch`) |
| `BOOTSTRAP_INSTALL` | `0` | `bootstrap.sh`: set to `1` to run `setup-server.sh` immediately (`--install`) |
| `AGENT_READY_CONFIG` | `~/.dotfiles/config.env` | Path to an alternate `config.env` file |
| `ASSUME_YES` | `0` | Set to `1` for non-interactive confirmation (`-y` / `--yes`) |
| `AGENT_READY_UI` | auto | Set to `plain` to force numbered prompts instead of `gum` |
| `HERMES_RESET_PASSWORD` | `0` | Set to `1` with `./install.sh hermes` to prompt for a new dashboard password |
| `SANDBOX_IMAGE` | `mcr.microsoft.com/devcontainers/base:ubuntu` | Default container image for `sandbox box` |
| `SANDBOX_CPUS` | `min(2, host_cpus)` | CPU limit for `sandbox box` |
| `SANDBOX_MEMORY` | `2g` | Memory limit for `sandbox box` |
| `AGENT_READY_PROMPT_RIGHT` | `status duration jobs worktree node bun go php python flutter docker` | Fish right-prompt section order; see [04 Shell and prompt](04-shell-and-prompt.md) |
| `AGENT_READY_PROMPT_SLOW_MS` | `3000` | Minimum command duration in milliseconds for the fish right prompt |
| `AGENT_READY_GREETING` | `status` in fish; SSH summary in bash | Set to `off` to disable the SSH login summary; fish also accepts `eel` for the theme greeting |

## Secrets: where they live

| File | Holds | Mode |
|---|---|---|
| `~/.dotfiles/config.env` | machine settings, Telegram token, Tailscale key | 600, git-ignored |
| `~/.config/secrets.env` | API keys for shells and agents (`ANTHROPIC_API_KEY`, `CLOUDFLARE_API_TOKEN`, `TELEGRAM_BOT_TOKEN`, `NOTIFY_TELEGRAM_CHAT`, …) | 600 |
| `~/.hermes/.env` | Hermes keys, dashboard hash and secret, Telegram | 600 |
| each tool's own store | `~/.aws`, `~/.config/rclone`, `~/.cloudflared`, wrangler/cf/gh logins, agent OAuth | tool-managed |

## Layout

```
setup-server.sh / setup-desktop.sh   entry points (pin the profile, then install.sh)
install.sh             runs stages/ for this OS + profile; --changed / --renew / --status
bootstrap.sh           fresh Linux server, as root: user, keys, clone, config.env
config.env.example     → config.env      secrets.env.example → ~/.config/secrets.env
stages/NN-name.sh      one concern each; headers declare user/os/profile
lib/
  common.sh            logging, run_as_user, link_file, render, env_set, load_config (all defaults)
  os.sh                OS_KIND / OS_FAMILY / IS_WSL / IS_OMARCHY / HAS_SYSTEMD, profiles
  pkg.sh               apt · pacman · dnf · brew behind pkg_install (Debian names + PKG_TABLE)
  stages.sh            stage headers, applicability, run state, change detection
  ui.sh                menus/prompts (gum, plain fallback)
  configure.sh         config.env wizard
  desktop-apps.sh      optional desktop app registry, platform checks and installs (stage 85)
  agents.sh            agent registry (loads agents.d/)
  tunnels.sh           tunnel registry (loads tunnels.d/)
  nginx.sh, net.sh     vhosts + certs; local ports
agents.d/<name>.sh     one module per agent CLI (_template.sh, retired/)
tunnels.d/<id>.sh      one module per tunnel provider (_template.sh)
bin/                   vps doctor update-all cleanup site tunnel sandbox agents notify hermes-up motd
home/                  mirrored into ~ as per-file symlinks (fish, mise conf.d, git, starship, srt policy)
agents/AGENTS.global.md   the machine guide linked into agents that support global instruction files (claude, codex, opencode)
nginx/ system/ systemd/ shell/   fragments the stages install
docs/                  these guides
.state/                run state (git-ignored)
```

## Stage headers

```bash
#!/usr/bin/env bash
# stage-user: root|user          # root on Linux (re-exec via sudo); always the user on macOS
# stage-os: debian+systemd,arch+systemd   # terms: any linux macos debian arch fedora systemd wsl nowsl; "," or, "+" and
# stage-profile: all|server|desktop
# stage-inputs: agents.d         # optional extra paths for change detection
# stage-desc: one line for menus
```

A stage is **changed** when the digest of its inputs differs from its last
successful run: the stage file, every `$AGENT_READY_DIR/…` path it mentions,
`lib/*.sh`, config.env and `stage-inputs`. State lives in `.state/stages/<name>`.

## Module APIs

**Agents** (`agents.d/<name>.sh`): `agent_define <name> title= bin= wrapper=
herdr= guide= login= paths= config= os= managed= env= state=` plus
`<name>_install` (required), `_update`, `_uninstall`, `_version`, `_configure`,
and `<name>_jail <dir>` (optional custom sandbox setup). See [06](06-tools-and-agents.md).

**Tunnels** (`tunnels.d/<id>.sh`): `tunnel_define <id> title= reach= rank=
auto= setup=` plus `<id>_ready`, `<id>_start <port> [name]` (print the URL),
optional `<id>_stop`. Helpers: `tunnel_bg <id> <port> <url-regex> <cmd…>`,
`tunnel_record`. See [07](07-networking.md).

**UI** (`lib/ui.sh`): `ui_interactive`, `ui_choose header "value|Label"…`,
`ui_multi header "defaults" items…`, `ui_input header [default] [placeholder]`,
`ui_password`, `ui_confirm question [yes|no]`. Show a menu only when
`ui_interactive` is true and no arguments were given.

## Design notes

- **mise for runtimes and CLIs, the OS for system services.** apt/pacman lag;
  mise gives per-project pins that agents honour (interactive fish uses
  `mise activate`, everything else gets shims). PHP-FPM and Docker stay on the OS.
- **fish is the login shell, bash stays first-class.** Agents run `bash -c`, so
  `~/.profile` and the top of `~/.bashrc` load the same PATH, shims and secrets.
- **Docker uses loopback defaults for the default bridge and newly created user-defined bridges.** Existing networks, explicit public bindings, and Swarm service exposure are not changed. Bind Compose ports explicitly (`127.0.0.1:3000:3000`), and use Engine 28+ to avoid the documented older-engine L2 exposure.
- **zram + swapfile on the server.** Multiple agents plus LSPs plus a build
  quickly exhaust modest server RAM. zram absorbs spikes; Hermes' dashboard is capped at 1 GB.
- **No auto-reboot. Passwordless sudo only by choice.** `FULL_CONTROL=true`
  enables unattended mode for agents and sudo inside the server; perimeter
  protection (SSH keys, firewall, fail2ban, dashboard auth) never depends on it.
- **Per-file symlinks**, so fisher, agents and installers can write adjacent files without changing the repo. Vendor installers receive `SHELL=/bin/bash` as a preference, not a guarantee: some also write `fish/conf.d` fragments.
- **Menus for humans, flags for machines.** A command prompts only when it was
  run bare at a TTY, so agents never hang on one.
