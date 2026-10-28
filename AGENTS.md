# AGENTS.md — working on this repo

This repo sets up machines that run coding agents: a **server** (the Ubuntu
26.04 VPS: 4 vCPU / 6 GB / 100 GB, agents + small sites) and **desktops**
(macOS with Homebrew + mise, Omarchy/Arch, Ubuntu/Fedora desktop, WSL). It
lives at `~/.dotfiles`. Its files are **live**: `home/` is symlinked into `~`,
and `bin/` is on PATH. User docs live in `docs/` (index: `docs/README.md`);
this file covers how to change things safely.

> Different file: `agents/AGENTS.global.md` is the *machine* guide every agent
> on a set-up box reads (linked into `~/.claude/CLAUDE.md` etc.). Edit it when
> the box's rules change, not this repo's conventions.

## Map
- `setup-server.sh` / `setup-desktop.sh` pin `PROFILE` and exec `install.sh`.
- `install.sh` runs `stages/NN-name.sh` in order, filtered by the headers
  `# stage-user: root|user`, `# stage-os: <spec>`, `# stage-profile:
  all|server|desktop`, optional `# stage-inputs:` and `# stage-desc:`
  (`lib/stages.sh`). It records each successful stage in `.state/stages/`
  (digest of its inputs) for `--changed`, `--status` and the re-run guard.
  User stages run as `TARGET_USER` through `run_as_user`. On macOS everything
  runs as the user.
- `lib/common.sh` holds logging, `as_root`, `run_as_user`, `confirm`, `link_file`,
  `render`, `env_set`/`env_get` and `load_config` (**all defaults live here**).
  `lib/os.sh` sets `OS_KIND OS_FAMILY OS_ID IS_WSL IS_OMARCHY HAS_SYSTEMD` and
  the default profile. `lib/pkg.sh` maps Debian package names to
  pacman/dnf/brew (`PKG_TABLE`). `lib/ui.sh` holds menus (gum or plain),
  `lib/configure.sh` the config wizard.
- `agents.d/<name>.sh` is one module per agent (`agent_define` + hooks), loaded
  by `lib/agents.sh`. `tunnels.d/<id>.sh` is one module per tunnel provider,
  loaded by `lib/tunnels.sh`. `_template.sh` in each shows the contract, and
  `agents.d/retired/` is never loaded.
- `home/.config/mise/conf.d/*.toml` holds global tools in groups. `config.toml`
  is deliberately **not** in the repo (it's the user's/Omarchy's).
- `bin/` holds user commands (`vps doctor update-all cleanup site tunnel
  sandbox agents notify hermes-up`). They resolve `lib/` through `readlink -f "$0"`.
- `home/` is mirrored into `~` as **per-file** symlinks (stage 50 also prunes
  links whose source was deleted, and leaves "soft" files like
  `starship.toml` alone when the user has their own).
- `nginx/templates/*.conf`: line 1 must be `# site: __DOMAIN__ type=…`
  (`site ls` and `site renew` parse it).
- `system/`, `systemd/` and `shell/` are fragments the stages install; each
  starts with a `Managed by ~/.dotfiles (<path>)` comment.

## Rules
- **Idempotent or it doesn't ship.** Every stage and command must be safe to
  re-run. Check before you change anything (`have`, `grep -q`, `cmp -s`).
- **Never leave a service broken.** Validate before reload/restart (`nginx -t`,
  `sshd -t`, `dockerd --validate`) and roll back on failure.
- **Merge, don't clobber, on desktops.** Other tools own config there
  (Omarchy, Docker Desktop, the user). Example: daemon.json is merged with jq.
- **Optional things warn, they don't abort.** Use `pkg_install` (skips missing
  packages), and `cmd || warn "…"` for vendor installers.
- **Menus for humans, flags for machines.** Prompt only when `ui_interactive`
  is true and no arguments were given. Every menu action must also be reachable
  with flags, because agents have no TTY.
- **Destructive actions confirm** (`ui_confirm`/`confirm`: TTY only, default
  no, `ASSUME_YES=1` for `-y`). `cleanup` never deletes dirty worktrees,
  unpushed commits or named volumes, and `--auto` stays report-only for
  worktrees and processes.
- **Root never writes into user-owned paths.** `~/.dotfiles`, `~/.hermes`,
  `.state` belong to the user, who may be a prompt-injected agent: write there
  with `run_as_user` (values on stdin), and use `safe_target`/`atomic_replace`
  (no symlinks, temp + `mv`) for any file rewrite.
- **A stage that can't finish says so.** `stage_incomplete "<why>"`: the stage
  still completes, isn't marked applied, and `--changed` retries it. Plain
  `warn` is for things that are fine to leave.
- **No secrets in the repo or on command lines.** `config.env` (git-ignored),
  `~/.config/secrets.env`, tool login stores. Pipe passwords on stdin, and pass
  tokens to curl with `-K -` or through 0600 files.
- **Stages must not read stdin they don't own.** install.sh reads the stage
  list into an array first, because `fish -c` and vendor installers swallow stdin.
- **Platform quirks:** Ubuntu 26.04 has sudo-rs (use `runuser`), uutils
  coreutils, and an nginx.conf that already sets `server_tokens` and friends;
  `patsub_replacement` is off in `common.sh`. macOS ships bash 3.2 (install.sh
  re-execs Homebrew bash; `scripts/check.sh` must stay 3.2-safe), and BSD
  `stat`/`sed` (use `os_owner`, `sed -i.bak`). Arch: never `pacman -Sy` alone.
- **Runtimes come from mise** (`conf.d/`), not the OS package manager. PHP-FPM
  and Docker are the exceptions. Agent CLIs with their own updater use their
  vendor installer.
- **Fish files** follow the laptop repo's conventions: `--description` on every
  function, `set -l`, `command <bin>`, `abbr` over `alias`, `fish_add_path
  --path --move`, no `eval`.
- **Bash style:** `set -Eeuo pipefail`, 4-space indent with case labels not
  indented (`mise run fmt`), `[[ ]]`, quote everything, functions over
  copy-paste, comments only for the why.
- **Docs move with behaviour.** Changing a command, stage or module means
  updating its page in `docs/` (and the tables in `docs/08-multi-os.md` /
  `docs/15-what-gets-installed.md` when it changes what runs where).

## Adding things
- **Agent:** `agents new <name>` → fill `agents.d/<name>.sh` → `agents install <name>`.
- **CLI tool:** add a line to the right `conf.d/*.toml` (`mise registry | grep`
  first: one bad name fails all of `mise install`).
- **Tunnel provider:** copy `tunnels.d/_template.sh`.
- **Stage:** `stages/NN-name.sh` with all headers; `mise run check` enforces them.
- **OS package:** its Debian name in the stage + a `PKG_TABLE` row if other
  families differ.

## Check before you finish
```bash
mise run check        # bash -n, shellcheck, fish -n, stage headers, module contracts, templates, secrets
mise run fmt          # shfmt -i 4
```
Anything that touches stages, nginx templates or `bin/cleanup` should be
exercised in a throwaway container: `ubuntu:26.04` with systemd
(`--privileged`, `/sbin/init`; copy files to `/root`, not `/tmp`, which
systemd mounts over) runs `install.sh --all -y` end to end. `archlinux`
works for pacman paths (under emulation, set `DisableSandbox` in pacman.conf).
Drive menus through a pty (python `pty.fork`) to test them.

## Don't
- Don't hand-edit files under `/etc` that a stage manages. Change the source
  here and re-run the stage.
- Don't add passwordless sudo except through `FULL_CONTROL` (validated with
  `visudo`), and no public Docker port binds or ports beyond 22/80/443 without a
  config toggle (see `OPEN_MOSH`). Full control relaxes the inside, never the
  outside protection.
- Don't commit `config.env`, `.state/`, `.dotfiles-backup/` or anything with a token.
