# Commands

All of these live in `~/.dotfiles/bin` (on PATH in fish, bash and agents'
subshells). **Run one bare in a terminal and you get a menu** (gum when it's
installed, numbered prompts otherwise). With arguments, or without a TTY (cron,
pipes, agents), they never prompt: a missing argument is an error, not a hang.
`<cmd> --help` prints the flag forms.

## vps — the hub

`vps` opens one menu: health, updates, cleanup, sites, agents, Hermes, tunnels,
sandbox, cloud sign-ins, logs, settings and these guides (`vps docs`). Every
entry prints the real command before running it, so you pick up the direct form.

## doctor — health check

```bash
doctor            # full report
doctor --brief    # services, resources and exposure only
```

It checks load, memory, swap, disk, reboot-required, services (by profile),
ufw, **anything listening on a public address**, certificate expiry, Hermes
auth, toolchain versions, agents and disk hogs. It exits non-zero on problems.

## update-all — upgrade agents and tools

```bash
update-all                # menu: everything preselected, untick what to skip
update-all -y             # everything, no questions (the default without a TTY)
update-all agents         # every installed agent CLI
update-all claude codex   # just these
update-all tools shell    # groups: system tools agents shell php extras dotfiles
update-all --check        # what's outdated; changes nothing (exits 1 if a check itself fails)
update-all --quick        # skip apt (no sudo)
update-all -n             # print the plan
```

Agents update through their own updater (`claude update`, `opencode upgrade`,
`herdr update`, `hermes update`, codex via mise) or by re-running the vendor
installer. Afterwards it re-asserts herdr hooks and prints `old → new`
versions. `dotfiles` (git pull + re-link) only runs when you pick it or pass `--self`.

## cleanup — reclaim disk and memory

```bash
cleanup                     # menu: pick targets and options → preview → apply
cleanup worktrees -n        # preview finished agent worktrees/branches
cleanup caches docker       # just these targets
cleanup all --deep -y       # everything incl. Go modcache, unused images, old tool versions
cleanup --auto              # what the weekly timer runs: safe subset, report-only for worktrees
```

Targets: `caches docker worktrees agents projects system procs`. It never
deletes: dirty worktrees, worktrees holding nested checkouts or ignored files
that aren't build output (`.env`, keys, agent memory), branches without proof
their work was merged (on a remote, squash-merged, or a merged GitHub PR),
named Docker volumes, stopped containers (listed, removed only if you confirm),
agent session history. Killing processes and removing orphaned worktrees or
Arch orphan packages always need you at a terminal; `-y` doesn't cover them.

## site — host a project (server profile)

```bash
site                                         # menu
site add                                     # wizard: domain → type → port (from what's listening) → confirm
site add app.ciptalogi.com --proxy 3000      # app on 127.0.0.1:3000
site add docs.ciptalogi.com --static ~/projects/docs/dist --spa
site add api.ciptalogi.com --php ~/projects/api/public
site ls · site logs <d> [error] · site rm <d> [--purge-cert] · site test
site renew                                   # re-render every vhost from the current templates
```

Details: [05 Hosting sites](05-hosting-sites.md).

## tunnel — share a dev server

```bash
tunnel                       # menu: pick the port (from what's listening), then the provider
tunnel 5173                  # TUNNEL_DEFAULT, else the first ready PRIVATE provider (tailscale, else ssh)
tunnel 5173 cloudflare       # public providers ask first; -y to skip (scripts)
tunnel 3000 cfnamed dev.ciptalogi.com
tunnel ls · tunnel stop <port|all> · tunnel logs <port> · tunnel providers
```

Details: [07 Networking](07-networking.md).

## sandbox — less reach for agents and untrusted code

```bash
sandbox                      # menu
sandbox check                # which isolation layers work here
sandbox run npm test         # srt: project-only writes, allowlisted network, secrets hidden
sandbox agent codex          # an agent CLI under srt
sandbox box [image]          # throwaway container with $PWD at /work (gVisor when installed)
```

Details: [09 Sandboxing](09-sandboxing.md).

## agents — the agent CLIs

```bash
agents                       # table: version, path, b-* wrapper
agents install grok          # install + add to AGENTS + herdr hook + shared guide
agents update [name…]        # = update-all agents
agents login [name]          # menu of sign-ins
agents herdr                 # re-install herdr sidebar hooks
agents remove <name> [--purge]
agents new <name>            # scaffold agents.d/<name>.sh
agents retire <name>         # sunset: uninstall, drop from AGENTS, move to agents.d/retired/
agents restore <name>
```

Details: [06 Tools and agents](06-tools-and-agents.md).

## notify — Telegram ping

```bash
notify "deploy finished"
make test; notify "tests exited $?"
journalctl -u app -n 20 | notify
```

Uses the Hermes bot token and the first `TELEGRAM_ALLOWED_USERS` id (or
`NOTIFY_TELEGRAM_CHAT`). The token never goes on a command line.

## hermes-up — Telegram gateway + dashboard

```bash
hermes-up          # install/refresh the gateway as a boot service, restart the dashboard
hermes-up status
```

## install.sh, setup-server.sh, setup-desktop.sh

```bash
./setup-server.sh            # VPS/headless: everything incl. firewall, nginx, Hermes
./setup-desktop.sh           # laptop/desktop/WSL: no nginx/firewall/server tuning
./install.sh                 # menu (first run: settings wizard)
./install.sh --changed       # only stages whose files or config changed (or never ran / failed)
./install.sh --renew         # everything + upgrade all tools/agents + re-render sites
./install.sh --all           # re-apply every stage
./install.sh docker web      # specific stages
./install.sh --status        # what ran when, what changed, what's skipped and why
./install.sh --configure     # settings wizard
./install.sh --list          # stages with OS/profile rules
```

All take `-y` (except switching profile, which always asks at a terminal).
Modes don't combine: give stage names *or* one of `--all/--changed/--renew`.
A stage that finishes with work left (no key login seen yet, a tool that
failed to install, DNS not ready) is reported "incomplete" and `--changed`
retries it. Once setup has run, `install.sh` without a TTY refuses to
re-run everything silently; say which mode you mean.

## Fish helpers

| Helper | Does |
|---|---|
| `wt <branch> [base]` | New worktree at `<repo>/.worktrees/<branch>` for an agent task |
| `pj` | fzf jump to a project in `~/projects` |
| `clone <url\|owner/repo> [dir]` | Clone into `~/projects` and cd |
| `ports [port]` | Listening TCP ports |
| `mkcd`, `path-list`, `fish-reload` | Small conveniences |
| `b-claude`, `b-codex`, `b-opencode`, `b-omp`, `b-grok`, `b-hermes` | Launch with the tool's official bypass flags after a `[y/N]` |

Abbreviations: [04 Shell and prompt](04-shell-and-prompt.md#abbreviations).
