# AgentReady setup FAQ — Ubuntu servers, macOS, and Linux desktops

Answers to common questions before and during developer environment setup with AgentReady. For runtime errors after setup, see [14 Troubleshooting](14-troubleshooting.md).

## Before installing

### Which script should I run: `bootstrap.sh`, `setup-server.sh`, `setup-desktop.sh`, or `install.sh`?

- **Fresh Linux VPS / cloud server (logged in as `root` or a cloud provider's default user):** Run `bootstrap.sh` once with `sudo` or as `root` (`--user <your-user>`), reconnect over SSH as `<your-user>`, then run `~/.dotfiles/setup-server.sh`.
- **Linux VPS that already has your non-root sudo user:** Clone the repo to `~/.dotfiles` and run `~/.dotfiles/setup-server.sh` directly (`bootstrap.sh` is not needed).
- **macOS, WSL, Arch/Omarchy, or Ubuntu/Fedora desktop:** Clone the repo to `~/.dotfiles` and run `~/.dotfiles/setup-desktop.sh`.
- **Re-applying changes later:** Run `./install.sh --changed` (or `./setup-server.sh --changed` / `./setup-desktop.sh --changed`).

### What server operating systems are supported?

The `server` profile is **tested on the latest Ubuntu LTS**. Debian-family servers with `systemd` run all 12 stages (including `nginx`, Let's Encrypt, PHP-FPM, and Hermes). Arch Linux with `systemd` supports packages, SSH hardening, `ufw`, `fail2ban`, Docker, dotfiles, tools, sandboxing, agents, tunnels, and cleanup, while skipping Debian-specific `nginx`/Hermes stages. Run `./install.sh --list` or see [08 Multi-OS](08-multi-os.md) for the exact stage matrix.

### Do I need a custom domain, Hermes, or a Telegram bot to set up a server?

**No.** Everything domain- or bot-related is optional:
- Leave `HERMES_DOMAIN=` empty in `config.env` (the default) or set `HERMES=false`: stage 80 then skips Hermes entirely (no CLI, no Telegram credentials, no dashboard). For the CLI alone, run `agents install hermes`.
- `nginx` and Certbot sit idle until you explicitly add a domain with `site add app.example.com --proxy 3000`.
- For temporary previews without a domain, use `tunnel <port>` (Tailscale, SSH port-forwarding, Cloudflare Quick Tunnel, Pinggy, or zrok).

### How do I customize settings via `config.env` or environment variables?

You have three ways to configure the installer (all personal defaults are empty or dummy placeholders out of the box):
1. **Interactive wizard (default on first terminal run):** Run `./setup-server.sh`, `./setup-desktop.sh`, or `./install.sh --configure`.
2. **Config file:** Copy `cp config.env.example config.env` (`chmod 600 config.env`) and edit values before running `--all -y`.
3. **Environment variable overrides (ideal for automation, cloud-init, and forks):** Nonempty exported `config.env` keys take precedence over the file. After validation (and before sudo escalation) the installer **saves those overrides to the existing private `config.env`, including secret values**, so future runs and `--changed` use the same settings. Overrides need an existing `config.env` (bootstrap, the wizard, or `cp config.env.example config.env`); with `--all`/`-y` and no `config.env`, `install.sh` stops before saving anything. Bootstrap seeds a new config; help/list/status are read-only. Values inherited from a parent AgentReady process, values equal to the ones in `~/.config/secrets.env`, and a `PROJECTS_DIR` equal to `~/.config/dotfiles/projects_dir` are not treated as overrides ([details](10-reference.md#configenv)). To change or clear a value, edit `config.env` or use the wizard:
   ```bash
   # Bootstrap a custom fork and user non-interactively (as a non-root cloud user, e.g. ubuntu)
   curl -fsSL https://raw.githubusercontent.com/riobahtiar/agent-ready/main/bootstrap.sh \
       | sudo env AGENT_READY_REPO=https://github.com/you/agent-ready.git \
           HERMES=false TIMEZONE=UTC bash -s -- --user deploy

   # Run server setup non-interactively with overrides
   GIT_NAME="Jane Doe" GIT_EMAIL="jane@example.com" HERMES=false \
       ~/.dotfiles/setup-server.sh --all -y
   ```
   Use `sudo env KEY=value bash …`; plain `sudo KEY=value` may be stripped by sudo's environment policy.

### Why does setup recommend a `GITHUB_TOKEN`, and what permissions does it need?

Stage 60 uses `mise` to install ~70 CLI tools and runtimes from GitHub Releases. Unauthenticated IP addresses are limited by GitHub to **60 API requests per hour**, which a fresh install can hit. Providing a [fine-grained Personal Access Token](https://github.com/settings/personal-access-tokens) with **zero repository or account permissions** raises your rate limit to 5,000 requests/hour.

---

## Safety, SSH, and permissions

### Will SSH hardening lock me out of my VPS?

Stage 20 (`stages/20-security.sh`) has built-in lockout guards before disabling SSH password authentication or root login:
1. `~<TARGET_USER>/.ssh/authorized_keys` must exist and contain at least one key (`bootstrap.sh` copies keys from `/root/.ssh/authorized_keys` and `~$SUDO_USER/.ssh/authorized_keys`, stripping cloud-image forced-command stubs).
2. `sshd` logs must show at least one verified public-key login by `TARGET_USER`. If you haven't logged in with your SSH key yet, Stage 20 leaves password login enabled, marks the stage `incomplete`, and tells you to reconnect with your key and run `./install.sh --changed`.
3. Root key login is kept as `prohibit-password` if `TARGET_USER` has neither a password nor passwordless `sudo`.

**Best practice:** Always keep your original root/provider SSH terminal open until you verify `ssh <your-user>@<server-ip>` works in a second terminal window.

### What is `FULL_CONTROL`, and should I keep it enabled?

`FULL_CONTROL` controls whether your user and coding agents operate unattended inside the machine:
- **When `FULL_CONTROL=true` (default on `server`, off on `desktop`):**
  - Grants `TARGET_USER` passwordless `sudo` (`/etc/sudoers.d/90-dotfiles-full-control`, validated via `visudo`).
  - `DOCKER_SUDOLESS` defaults to `true` on the server profile **regardless of `FULL_CONTROL`**, adding `TARGET_USER` to the root-equivalent `docker` group.
  - Configures Claude Code (`bypassPermissions`) and Codex (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`) not to pause on permission prompts, and defaults `AGENT_SANDBOX` to `false` (credential read-deny rules in `~/.claude/settings.json` remain active).
  - SSH, firewall, fail2ban, dashboard auth, and Docker loopback **defaults** are configured independently of this toggle. These are not guarantees against an agent with root access, explicit public binds, or existing Docker networks.
- **When `FULL_CONTROL=false` (default on `desktop`):**
  - `sudo` requires your password, agents prompt before privileged actions, and `AGENT_SANDBOX` defaults to `true`.

For password-gated `sudo` and prompting agents on a server, set `FULL_CONTROL=false DOCKER_SUDOLESS=false AGENT_SANDBOX=true`, ideally at bootstrap (it seeds every nonempty key from its environment into the new `config.env`):

```bash
curl -fsSL https://raw.githubusercontent.com/riobahtiar/agent-ready/main/bootstrap.sh \
    | sudo env FULL_CONTROL=false DOCKER_SUDOLESS=false AGENT_SANDBOX=true bash -s -- --user deploy
```

Switching off later: set a password first (`sudo passwd <user>`), because stage 05 removes the passwordless rule. Nothing reverts existing `docker` group membership (`sudo gpasswd -d <user> docker`) or agent bypass settings already written — remove Claude's `permissions.defaultMode: "bypassPermissions"` from `~/.claude/settings.json` and Codex's `approval_policy = "never"` / `sandbox_mode = "danger-full-access"` from `~/.codex/config.toml` by hand.

### Why aren't my Docker container ports (`docker run -p 8080:8080`) reachable from the internet?

Stage 30 merges both `"ip": "127.0.0.1"` (default bridge) and `default-network-opts.bridge.com.docker.network.bridge.host_binding_ipv4 = "127.0.0.1"` (new user-defined bridges) into `/etc/docker/daemon.json`. **Existing networks are not migrated by restarting Docker**, and explicit host bindings override these defaults. Prefer `-p 127.0.0.1:8080:8080` or Compose `"127.0.0.1:8080:8080"` even after setup. Docker may bypass `ufw`; Engine versions older than 28.0.0 also have a documented same-L2 localhost-port exposure. See [Docker's current port-publishing reference](https://docs.docker.com/engine/network/port-publishing/).

To expose a container intentionally:
- **Permanent domain with HTTPS (server):** `site add app.example.com --proxy 8080`
- **Temporary preview URL:** `tunnel 8080` (private via Tailscale/SSH, or public via `cloudflare` / `pinggy` / `zrok`)

---

## Existing files, desktops, and customization

### What happens to my existing dotfiles when I run `setup-desktop.sh` or `setup-server.sh`?

Conflicting home configuration files are backed up before replacement; this is not a backup of your entire machine:
- Files in `home/` are symlinked **individually** (never whole directories), and any existing regular file or foreign symlink in the way is moved to **`~/.dotfiles-backup/<timestamp>/`** first.
- `"Soft"` configs like `~/.config/starship.toml` are left untouched if you already have your own file.
- `~/.config/mise/config.toml` is **never** created or modified by this repo (tools live in `~/.config/mise/conf.d/*.toml`, so your own `config.toml` always wins).
- Existing custom `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, or `~/.config/opencode/AGENTS.md` files are preserved rather than overwritten.
- `~/.bashrc`, `~/.profile`, `~/.bash_profile`, and `~/.zshenv` receive a single guarded `source` line (and are skipped if they are symlinks managed by another dotfiles repo).

### Can I install this on a server that already hosts websites or Docker containers?

Yes:
- **Docker (`stages/30-docker.sh`):** Merges settings into an existing `/etc/docker/daemon.json` with `jq` and asks before restarting Docker if containers are currently running.
- **nginx (`stages/40-web.sh`):** Snapshots `/etc/nginx` before changes, leaves customized default sites untouched, validates with `nginx -t`, and rolls back automatically if validation fails.

### Can I install only specific AI agents or skip tools I don't need?

Yes:
- **Agents:** Pick which agent CLIs to install during `./install.sh --configure`, set `AGENTS="claude codex herdr"` in `config.env`, or manage them anytime with `agents install <name>`, `agents remove <name>`, and `agents retire <name>`.
- **CLI tools & runtimes:** Edit or comment out entries in `home/.config/mise/conf.d/*.toml` before running stage 60 (or run `mise prune` afterward), or disable specific tools via `MISE_DISABLE_TOOLS=flutter,java`.
- **Desktop apps:** The desktop setup wizard offers explicit selection or opt-out.
  `DESKTOP_APPS` defaults to empty (install none). Set, for example,
  `DESKTOP_APPS="zed ghostty obsidian"` in private `config.env`, choose apps via
  `./install.sh --configure` with the desktop profile, or run
  `DESKTOP_APPS='zed ghostty obsidian' ./setup-desktop.sh desktop-apps -y`.
  Stage 85 never runs on servers. Unselecting means “do not install,” not
  uninstall; remove installed apps through their package manager if desired.
  See the [platform matrix](15-what-gets-installed.md#optional-desktop-apps-stage-85)
  for every ID, architecture limits, and package sources. These desktop
  products are distinct from the agent CLIs and have their own licenses.
  Mole is an optional macOS maintenance tool: setup installs it but never runs
  cleanup or other destructive maintenance commands.

### Does this work on ARM64 (`aarch64`) servers and Apple Silicon / Intel Macs?

- **Linux `x86_64` & `aarch64` (ARM64):** Supported. Because Google does not publish an official `linux-arm64` Flutter SDK, `MISE_DISABLE_TOOLS=flutter` is set automatically on Linux ARM64 so `mise install` succeeds cleanly.
- **macOS (`arm64` Apple Silicon & `x86_64` Intel):** Targeted via Homebrew + `mise`, but not yet end-to-end verified. Run `~/.dotfiles/setup-desktop.sh` as your normal user (never with `sudo`).

### Where should I put machine-local overrides so `git pull` stays clean?

- Machine settings: `~/.dotfiles/config.env` (git-ignored)
- API keys & tokens: `~/.config/secrets.env` (`0600`, untracked)
- Git author name/email: `~/.config/git/local` (written from `config.env`, untracked; note that if you also have `~/.gitconfig`, Git reads `~/.gitconfig` after `~/.config/git/config`)
- Personal global `mise` versions/tools: `~/.config/mise/config.toml` (untracked; overrides `conf.d/*.toml`)
- Project-specific tool versions: `<project>/mise.toml`

---

## Updates, re-runs, and uninstalling

### How do I adopt AgentReady on an existing machine?

Keep your existing `~/.dotfiles` checkout and operational paths in place. After
the GitHub repository is renamed, update `origin`, pull, and run
`./install.sh --changed`; see [the upgrade commands](12-maintenance.md#adopting-agentready).
Update project-specific environment settings in shell startup files and
automation to the documented `AGENT_READY_*` names. No compatibility aliases or
directory moves are required or provided.

### What is the difference between `update-all`, `./install.sh --changed`, and `./install.sh --renew`?

| Command | What it does | When to use it |
|---|---|---|
| `update-all` | Upgrades OS packages, `mise` tools, agent CLIs, and Fisher plugins without re-running system stages | Weekly/routine software updates |
| `./install.sh --changed` | Runs only stages that never ran, were marked `incomplete`, or whose stage files / `config.env` changed | After `git pull` in `~/.dotfiles` or editing `config.env` |
| `./install.sh <stage>` | Runs a single named stage (e.g., `./install.sh web` or `./install.sh dotfiles`) | Applying a targeted config tweak quickly |
| `./install.sh --renew` | Re-runs every applicable stage, upgrades all tools/agents, re-renders `nginx` vhosts, and checks TLS renewals | Periodic full system refresh |

*(Note: because `config.env` is hashed as an input to every stage, editing `config.env` marks all applicable stages as changed for `--changed`. All stages are idempotent, or you can run `./install.sh <stage>` to run just one.)*

### How do I uninstall or revert changes?

1. **Restore home dotfiles:** Copy backed-up files back from `~/.dotfiles-backup/<timestamp>/` and delete symlinks pointing into `~/.dotfiles`.
2. **Remove agents or sites:** Run `agents remove <name> --purge` or `site rm <domain> --purge-cert`.
3. **Restore password-gated sudo:** Set a password first (`sudo passwd <user>`), keep another admin session open, set `FULL_CONTROL=false` (and `DOCKER_SUDOLESS=false`) in `config.env`, and run `./install.sh packages` to remove the managed passwordless-sudo rule. Then remove docker group membership (`sudo gpasswd -d <user> docker`) and agent bypass settings by hand (see [FULL_CONTROL](#what-is-full_control-and-should-i-keep-it-enabled)). Do not remove your only working administrative access.
4. **Inspect system fragments (server profile):** Managed fragments carry `Managed by ~/.dotfiles` headers. There is no complete automated uninstaller: package installs, group membership, shell changes, provider/cloud-init settings, and merged service configs may need manual restoration. Restore service configs from backups, validate them before reload, and use a VM snapshot for a complete rollback.
