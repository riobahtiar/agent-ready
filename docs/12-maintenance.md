# Maintenance

## The routine

| How often | Do | Why |
|---|---|---|
| Weekly (automatic on servers) | `cleanup --auto` via `cloud-cleanup.timer`, Sunday 04:00 | caches, Docker build cache, agent logs; reports stale worktrees, deletes none |
| Weekly | `update-all` | agents ship updates weekly; apt security fixes |
| After pulling this repo | `./install.sh --changed` | applies only stages whose files changed |
| Monthly, or after a big change | `./install.sh --renew` | re-applies everything, upgrades all tools and agents, re-renders sites |
| When it feels slow or full | `doctor`, then `cleanup` | |
| When `doctor` says so | reboot (when agents are idle) | kernel/libc updates; nothing auto-reboots |

## Update vs renew

- **`update-all`** upgrades software: apt (or pacman/dnf/brew), every mise tool,
  every installed agent CLI, fish plugins, composer, uv tools, gh extensions.
  It doesn't touch configuration.
- **`./install.sh --changed`** re-applies configuration from the repo: only
  stages whose inputs (stage file, the files it installs, `lib/`, config.env)
  changed since their last successful run.
- **`./install.sh --renew`** does both, for everything: every stage again with
  agents and mise tools upgraded in place, then composer/uv/gh extensions, then
  `site renew` (every vhost re-rendered from the current templates) and
  `certbot renew`. Use it after a long gap, or when you're not sure what
  drifted. Safe to run on a live box; agents keep running.

Interactive `./install.sh` on a set-up machine offers exactly these choices.
Without a terminal it refuses to re-run silently and tells you to pick
`--changed`, `--all` or `--renew`.

## Status at a glance

```bash
./install.sh --status   # per stage: applied / changed / never / skipped (+ why), last run
doctor                  # health
update-all --check      # outdated mise tools, agent versions, apt upgrades
tunnel ls               # anything still exposed?
```

## Cleanup

```bash
cleanup                 # menu → preview → apply
cleanup worktrees -n    # what's finished: merged, upstream gone, or stale with nothing unpushed
cleanup procs           # orphaned MCP servers, headless browsers, watchers
cleanup all --deep      # big reclaim (Go modcache, unused images, old tool versions)
```

Never deleted: dirty worktrees, worktrees with nested checkouts or ignored
secrets, branches without proof of merge, named Docker volumes, stopped
containers (unless you confirm the list), agent session history. `--auto` (the
weekly timer) only reports worktrees: no repair, no prune, no removal. Local
git tags are never pruned by fetches (`fetch.pruneTags` is off).

## Backups

The repo is the config. What isn't in git:

| What | Where | Suggestion |
|---|---|---|
| Unpushed work | `~/projects` | push often; `cleanup` shows unpushed branches |
| Agent sessions and memory | `~/.claude`, `~/.codex`, `~/.hermes` | rclone to R2/S3/B2 nightly |
| Secrets | config.env, secrets.env, `~/.hermes/.env` | a password manager, not a bucket |
| Databases in Docker volumes | named volumes | `docker run --rm -v vol:/v alpine tar c /v` → rclone |

A minimal nightly backup with rclone (after `rclone config` creates a remote
`r2`):

```bash
# ~/.config/systemd/user/backup.service + backup.timer, or crontab -e:
15 3 * * * rclone sync ~/.hermes r2:backups/hermes --exclude ".env" --fast-list -q
```

## Reboots

`unattended-upgrades` installs security fixes without rebooting. `doctor`, the
SSH login summary and `update-all` all tell you when `/var/run/reboot-required`
exists. Detach herdr, check `doctor` for running agents, then `sudo reboot`.
herdr sessions don't survive a reboot; agent transcripts do.
