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

- **Network:** only GitHub, the npm/PyPI/Go/Packagist/pub registries, Bun, and
  the model APIs (Anthropic, OpenAI, xAI, OpenRouter, Gemini). Everything else
  is blocked.
- **Reads:** everything except `~/.ssh`, `~/.aws`, `~/.gnupg`,
  `~/.cloudflared`, `~/.config/rclone`, `~/.config/secrets.env`,
  `~/.hermes/.env`, `~/.dotfiles/config.env`, gh tokens and Docker credentials.
- **Writes:** the current directory, `/tmp` and package caches only, and never
  `.env`, `.git/hooks` or `.git/config`.

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
tests bwrap and, if needed, installs a profile that grants `userns` to
`/usr/bin/bwrap` only (`system/apparmor-bwrap`). It doesn't flip the
system-wide `kernel.apparmor_restrict_unprivileged_userns` switch.

## Limits, honestly

- The agent's own sandbox covers the commands it runs, not the agent process
  itself. srt or a container covers the whole thing.
- Containers share the host kernel; gVisor narrows that, and a VM removes it.
- A sandboxed agent with your GitHub token in its environment can still push.
  Scope tokens (fine-grained, per repo) for anything automated.
- Docker group membership is root-equivalent. Agents that can run `docker`
  can escape any of the above, which is why the desktop profile leaves you out
  of the group by default.
