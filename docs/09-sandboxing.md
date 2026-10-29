# Sandboxing agents and untrusted code

Agents run shell commands, often in bypass mode, on a machine that holds your
SSH keys, cloud tokens and the Hermes `.env`. Sandboxing shrinks what a bad
command (a prompt injection, a malicious package, an over-eager agent) can
reach. The layers below are ordered from lightest to strongest.

## The layers

| Layer | Isolates | Cost | How |
|---|---|---|---|
| **Agent's own sandbox** | each shell command the agent runs | none | Claude Code: on by default here (`AGENT_SANDBOX=true` → `sandbox.enabled`; `/sandbox` in a session). Codex: Landlock + seccomp (Linux) / Seatbelt (macOS); keep `--sandbox workspace-write` |
| **srt** (Anthropic sandbox-runtime) | a whole process tree: any agent, `npm install`, a script | none (bubblewrap/Seatbelt) | `sandbox run <cmd>`, `sandbox agent <name>` |
| **Container** | separate filesystem and processes, shared kernel | a container | `sandbox box` (devcontainer base image, 2 CPU / 2 GB, `no-new-privileges`) |
| **gVisor container** | the same with a user-space kernel, so syscalls don't hit the host kernel | some CPU overhead | `GVISOR=true` → `sandbox box` uses `--runtime runsc` |
| **Separate machine** | everything | a VM/VPS | for truly untrusted work |

`sandbox check` shows which of these work on the current machine.

## srt policy

`~/.srt-settings.json` (from `home/.srt-settings.json`) is the policy for
`sandbox run` and `sandbox agent`:

- **Environment:** a clean one (`PATH`, `HOME`, locale, terminal). The API keys
  your shells export are **not** passed in; `sandbox agent X` adds only X's own
  key (the module's `env=`).
- **Network:** only GitHub, the npm/PyPI/Go/Packagist/pub registries, Bun, and
  the model APIs (Anthropic, OpenAI, xAI, OpenRouter, Gemini). Everything else
  is blocked. This limits *where* data can go, not *whether*: anything with a
  token for an allowed site (a git push, a gist, an npm publish) can still
  carry data out.
- **Reads:** everything except credentials: `~/.ssh`, `~/.aws`, `~/.gnupg`,
  `~/.kube`, `~/.docker`, `~/.cloudflared`, `~/.config/rclone`, `~/.config/gh`,
  wrangler, `~/.npmrc`, `~/.git-credentials`, `~/.netrc`, zrok,
  `~/.config/secrets.env`, `~/.dotfiles/config.env`, all of `~/.hermes`, the
  Claude/Codex OAuth files and shell history. `sandbox agent X` may read X's
  own config dir (sign-in) but write only the session/log paths its module
  lists (`state=`, an allowlist, refused if any is a symlink). Claude goes
  further: it runs on a throwaway `CLAUDE_CONFIG_DIR` (sign-in and hook-free
  settings copied in), because its shell snapshots and project memory are
  sourced/loaded by later sessions; jailed transcripts aren't kept. Settings, hooks, plugins, skills, MCP config
  (`~/.claude.json`) and the agent's code stay read-only, so a jailed agent
  can't plant something for its next unjailed run. The price: an agent can't
  change its own settings, or refresh an expired OAuth token, while jailed. For
  Claude Code, its built-in sandbox (below) is usually the better fit.
- **Writes:** the current directory, `/tmp`, and the npm/pnpm stores
  (content-addressed, integrity-checked), and never `.env`, `.git/hooks` or
  `.git/config`. Tool installs and caches that run unsandboxed later (mise,
  `~/.bun`, `~/.cache`, the Go module cache) are read-only; sandboxed commands
  get throwaway caches in a private temp dir instead (`$TMPDIR/sandbox-cache-<uid>`).

Need another domain (your API, a CDN)? Add it to `allowedDomains` in
`home/.srt-settings.json`. It's linked, so it applies immediately.

```bash
sandbox run npm install          # a package's postinstall can't read ~/.ssh or phone home
sandbox run bash -c 'make test'
cd ~/projects/shop && sandbox agent codex --full-auto   # agent in bypass mode, but jailed
```

## Containers

```bash
sandbox box                                       # mcr.microsoft.com/devcontainers/base:ubuntu
sandbox box node:24                               # any image
SANDBOX_IMAGE=oven/bun:1 sandbox box
```

Only the current directory is shared (at `/work`). Nothing is published, and
the container is deleted on exit. For repos with `.devcontainer/`:
`devcontainer up --workspace-folder .`.

gVisor (`GVISOR=true`, then `./install.sh docker`) installs `runsc` from the
gVisor apt repo and registers it in daemon.json. `sandbox box` picks it up
automatically, and you can use it anywhere with `docker run --runtime runsc …`.

## Ubuntu's user-namespace restriction

Ubuntu 24.04+ blocks unprivileged user namespaces unless AppArmor allows them,
which breaks bubblewrap (and with it Claude Code's sandbox and srt). Stage 65
tests bwrap and, if needed, loads Ubuntu's own `bwrap-userns-restrict` profile
(userns for bwrap, but no capabilities for what runs inside). Only where the
distro has none does it install `system/apparmor-bwrap`. It never flips the
system-wide `kernel.apparmor_restrict_unprivileged_userns` switch.

With `FULL_CONTROL=true` (playground mode) none of this is on by default:
agents are meant to run the box. `sandbox run` / `sandbox agent` still work
when you want them for one untrusted thing.

## Claude Code's own sandbox

On by default unless `FULL_CONTROL=true` (`sandbox.enabled`), plus `permissions.deny` Read rules for
the same credential files (Claude's sandbox doesn't read `~/.srt-settings.json`).
Two things to know:

- With `allowUnsandboxedCommands` (Claude's default), Claude may ask to run a
  command outside the sandbox, and in bypass mode (`b-claude`) that's approved
  automatically. Set `"sandbox": {"allowUnsandboxedCommands": false}` in
  `~/.claude/settings.json` for a hard boundary (docker and friends then fail
  inside Claude).
- Your shells export every key in `~/.config/secrets.env`, so any agent's `env`
  shows them. Leave keys you don't need there empty.

## mise trust

Only `~/.dotfiles` is trusted. A project's `mise.toml` can run code (`[env]`
exec templates, `_.source`, hooks), so a freshly cloned repo is untrusted until
you've read its config: `mise trust` in the repo (the `clone` helper shows the
file and offers it). Agents that hit "config not trusted" should ask you.

## Limits, honestly

- The agent's own sandbox covers the commands it runs, not the agent process
  itself. srt or a container covers the whole thing.
- Containers share the host kernel; gVisor narrows that, and a VM removes it.
- A sandboxed agent with your GitHub token in its environment can still push.
  Scope tokens (fine-grained, per repo) for anything automated.
- Docker group membership is root-equivalent. Agents that can run `docker`
  can escape any of the above, which is why the desktop profile leaves you out
  of the group by default.
