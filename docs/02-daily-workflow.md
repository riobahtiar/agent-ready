# Daily workflow with AI coding agents

Use your AgentReady environment for remote development, agent worktrees, and app previews.

## Connect

```sshconfig
# local ~/.ssh/config
Host cloud
    HostName 203.0.113.10    # or cloud.<tailnet>.ts.net
    User deploy
    ServerAliveInterval 30
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
    # Forward your laptop's agent only if you push with laptop keys:
    # ForwardAgent yes
```

- **mosh** survives sleep and network changes: `OPEN_MOSH=true` in config.env,
  `./install.sh security`, then `mosh cloud`.
- **Tailscale** gives the server a private name and lets you skip public SSH
  entirely: [07 Networking](07-networking.md).
- Ghostty installs its terminfo on the server automatically (`ssh-terminfo`).

## Work inside herdr

`herdr` is the agent-aware multiplexer: panes survive disconnects and the
sidebar shows each agent's state (working, waiting for you, done).

```fish
herdr                  # attach (creates the session the first time)
# ctrl+b then q        # detach, everything keeps running
herdr --remote cloud   # from your laptop: thin client, panes stay on the server
```

tmux is installed as a fallback.

## Projects

```fish
clone owner/repo       # → ~/projects/repo
pj                     # fzf jump to a project
z repo                 # zoxide jump
```

Per-project runtimes: `mise use node@22` in the repo writes `mise.toml`, and
every shell and agent in that directory gets that version. `.nvmrc` and
`.python-version` are honoured too.

## One task per worktree

Parallel agents must not switch branches under each other:

```fish
wt feat/cart           # creates <repo>/.worktrees/feat/cart on a new branch
cd .worktrees/feat/cart; claude
```

The prompt shows `⎇ worktree` while you're inside one. When the branch is
merged or abandoned: `git worktree remove .worktrees/feat/cart`, or let
`cleanup worktrees` sweep the clean, merged and stale ones. It never touches
dirty worktrees or unpushed commits.

## Preview a dev server

| You want | Do |
|---|---|
| See it on your laptop, privately | `tunnel 5173 ssh` prints the `ssh -L` line, or `tunnel 5173 tailscale` |
| Show someone for an hour | `tunnel 5173 cloudflare` (random https URL, no account) |
| A webhook to hit it | `tunnel 3000 cloudflare` or `tunnel 3000 pinggy` |
| Keep it up on a real domain | `site add app.example.com --proxy 3000` |

Bind dev servers to `127.0.0.1` (Vite: `--host 127.0.0.1`). `doctor` flags
anything listening publicly.

## Editors

- **VS Code / Cursor / Windsurf**: Remote-SSH to `cloud`. The remote server process
  runs on your server (~300–500 MB RAM).
- **Zed**: `zed ssh://cloud/~/projects/app`, a lighter remote server.
- **Neovim** on the server: `nvim` (installed by mise).

## Get pinged when an agent finishes

```fish
long-task; notify "long-task exited $status"
```

For Claude Code hooks, see [06 Tools and agents](06-tools-and-agents.md#get-pinged).

## Sharing server resources

- One heavy build at a time; stop dev servers and watchers you started.
- `free -h` before starting large builds. The login summary (`motd`) shows memory usage.
- `cleanup procs` finds orphaned MCP servers and headless browsers.
