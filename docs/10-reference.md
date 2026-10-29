# Reference

## config.env

`./install.sh --configure` writes it; this is every key. Empty means "use the
default". Change a value, then `./install.sh --changed`, which re-runs every
stage, because config.env is an input to all of them.

| Key | Default | Used by |
|---|---|---|
| `TARGET_USER` | the invoking user | everything: owner of projects and agents |
| `GIT_NAME`, `GIT_EMAIL` | — | 50: `~/.config/git/local` |
| `GITHUB_TOKEN` | — | 60: lifts GitHub's 60/h API limit for mise (copied to secrets.env) |
| `PROFILE` | desktop on macOS/WSL/GUI Linux, else server | which stages run ([08](08-multi-os.md)) |
| `TIMEZONE`, `LOCALE` | UTC, en_US.UTF-8 | 10 |
| `HOSTNAME_FQDN` | keep | 10 |
| `LOGIN_SHELL` | fish | 05 |
| `LOGIN_GREETING` | true | 10 (server): `bin/motd` on SSH login; Ubuntu's update-motd scripts (dpkg-statoverride), motd-news (and its timer, masked) and the provider's `/etc/motd` (backed up to `/etc/motd.dotfiles-orig`) off; `wtmpdb` for "Last login" |
| `CLOUD_INIT_LOCK` | true | 10 (server): `/etc/cloud/cloud-init.disabled` after first boot, so provider boot commands stop |
| `SWAP_SIZE_GB`, `ZRAM` | 4, true | 10 (server) |
| `SSH_HARDEN`, `SSH_DISABLE_ROOT`, `OPEN_MOSH` | true, true, false | 20 (server); `SSH_HARDEN=force` skips the "key login seen" check |
| `F2B_IGNORE_IPS` | — | 20: never banned (plus loopback, Tailscale, the installing IP) |
| `TAILSCALE`, `TAILSCALE_SSH`, `TAILSCALE_AUTHKEY` | false, false, — | 75 |
| `TUNNEL_DEFAULT` | auto | `tunnel` |
| `FULL_CONTROL` | true on server, false on desktop | 05: passwordless sudo (visudo-checked `/etc/sudoers.d`), Claude `bypassPermissions` + Codex `never`/`danger-full-access` defaults, `b-claude`/`b-codex` skip the prompt; turns `DOCKER_SUDOLESS` on and `AGENT_SANDBOX` off by default |
| `DOCKER` | true | 30 |
| `DOCKER_SUDOLESS` | true on server, false on desktop | 30: docker group |
| `GVISOR` | false | 30: runsc runtime |
| `AGENT_SANDBOX` | true (false with `FULL_CONTROL`) | 70: Claude Code `sandbox.enabled` (only if unset) |
| `ACME_EMAIL` | — | 40, 80, `site add` |
| `PHP`, `WWW_DIR` | true, /srv/www | 40 |
| `PROJECTS_DIR` | ~/projects | 05, prompt, cleanup |
| `FLUTTER_LINUX_DESKTOP` | false | 05, 60 |
| `AGENTS` | claude codex opencode omp grok muse herdr | 70 (module names in agents.d/) |
| `CLEANUP_TIMER` | true on server, false on desktop | 90 |
| `HERMES`, `HERMES_DOMAIN`, `HERMES_DASHBOARD_USER`, `HERMES_DASHBOARD_PORT` | true, —, `$TARGET_USER`, 9119 | 80 |
| `HERMES_DASHBOARD_PASSWORD` | prompted | 80 (only the scrypt hash is stored) |
| `HERMES_ALLOW_IPS` | — | 80: nginx allowlist |
| `HERMES_CLOUDFLARE_ONLY` | false | 80: accept only Cloudflare's IP ranges (use with Cloudflare Access) |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS` | — | 80 → `~/.hermes/.env`, `notify` |

Environment-only knobs: `HERMES_RESET_PASSWORD=1 ./install.sh hermes`,
`ASSUME_YES=1` (= `-y`), `DOTFILES_CONFIG=/path` (another config file),
`CLOUD_UI=plain` (no gum), `SANDBOX_IMAGE`.

## Secrets: where they live

| File | Holds | Mode |
|---|---|---|
| `~/.dotfiles/config.env` | machine settings, Telegram token, Tailscale key | 600, git-ignored |
| `~/.config/secrets.env` | API keys for shells and agents (`ANTHROPIC_API_KEY`, `CLOUDFLARE_API_TOKEN`, …) | 600 |
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
  agents.sh            agent registry (loads agents.d/)
  tunnels.sh           tunnel registry (loads tunnels.d/)
  nginx.sh, net.sh     vhosts + certs; local ports
agents.d/<name>.sh     one module per agent CLI (_template.sh, retired/)
tunnels.d/<id>.sh      one module per tunnel provider (_template.sh)
bin/                   vps doctor update-all cleanup site tunnel sandbox agents notify hermes-up
home/                  mirrored into ~ as per-file symlinks (fish, mise conf.d, git, starship, srt policy)
agents/AGENTS.global.md   the machine guide every agent reads
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
successful run: the stage file, every `$DOTFILES_DIR/…` path it mentions,
`lib/*.sh`, config.env and `stage-inputs`. State lives in `.state/stages/<name>`.

## Module APIs

**Agents** (`agents.d/<name>.sh`): `agent_define <name> title= bin= wrapper=
herdr= guide= login= paths= config= os= managed=` plus `<name>_install`
(required), `_update`, `_uninstall`, `_version`, `_configure`. See
[06](06-tools-and-agents.md).

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
- **Docker binds to 127.0.0.1.** Docker bypasses ufw, so a casual `-p 5432:5432`
  would otherwise be public. nginx is the only public entry point, and `doctor` flags the rest.
- **zram + swapfile on the server.** Multiple agents plus LSPs plus a build
  quickly exhaust modest server RAM. zram absorbs spikes; Hermes' dashboard is capped at 1 GB.
- **No auto-reboot. Passwordless sudo only by choice.** `FULL_CONTROL=true`
  hands agents root on purpose (a playground box); the outside protection
  (SSH keys, firewall, fail2ban, dashboard auth) never depends on it.
- **Per-file symlinks**, so fisher, agents and installers write next to their
  configs without dirtying the repo. Vendor installers run with `SHELL=bash` so
  their PATH lines land in `~/.bashrc`.
- **Menus for humans, flags for machines.** A command prompts only when it was
  run bare at a TTY, so agents never hang on one.
