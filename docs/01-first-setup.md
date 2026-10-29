# Ubuntu server setup for AI coding agents

Set up an AgentReady developer environment on a fresh Ubuntu LTS server.
Prior repository records document end-to-end testing on **Ubuntu 26.04, the
latest Ubuntu LTS, in systemd containers**. Laptops and desktops (macOS,
Arch/Omarchy, Ubuntu/Fedora desktop, WSL) skip step 1: see
[08 Multi-OS](08-multi-os.md). For common questions before installing, see
[16 FAQ](16-faq.md).

Desktop users run `./setup-desktop.sh`; the wizard offers optional app selection
or opt-out, with none selected by default (`DESKTOP_APPS=""`). To install only
an explicit selection later:

```bash
DESKTOP_APPS='zed ghostty obsidian' ./setup-desktop.sh desktop-apps -y
```

Alternatively set that whitespace list in private `config.env`, or revisit
`./install.sh --configure` with the desktop profile. Unselecting never uninstalls
an app. See [the platform and package-source matrix](15-what-gets-installed.md#optional-desktop-apps-stage-85)
before selecting; stage 85 is never applied to servers.

## 0. Before you start (on your local machine)

- [ ] An SSH public key on the server's `root` or default sudo user account
      (most cloud providers add this at creation).
- [ ] Optional but recommended: a GitHub token with no permissions
      ([fine-grained](https://github.com/settings/personal-access-tokens)). mise pulls
      ~70 tools from GitHub, and anonymous access is rate-limited to 60 API calls/hour.
- [ ] Optional DNS: if you want to host sites or the Hermes web dashboard on a
      custom domain, point an A record (e.g. `hermes.example.com` or
      `app.example.com`) at your server IP (`203.0.113.10`). Check with
      `dig +short hermes.example.com`. Custom domains are completely optional.
- [ ] Optional for Hermes / Telegram notifications: a bot token from **@BotFather**
      and your numeric user ID from **@userinfobot**. You can skip Hermes
      (`HERMES=false`) or add these later.
- [ ] Optional: a [Tailscale](https://tailscale.com) account (free) for private mesh access.
## 1. Bootstrap (as root, once)

```bash
ssh root@203.0.113.10
curl -fsSL https://raw.githubusercontent.com/riobahtiar/agent-ready/main/bootstrap.sh | bash -s -- --user deploy
```

On providers that give you a non-root sudo user (e.g. `ubuntu`), run it through sudo:

```bash
ssh ubuntu@203.0.113.10
curl -fsSL https://raw.githubusercontent.com/riobahtiar/agent-ready/main/bootstrap.sh | sudo bash -s -- --user deploy
```

To seed settings, pass them with `sudo env KEY=value bash …` (plain
`sudo KEY=value` may be stripped by sudo's environment policy).

`bootstrap.sh` creates the target user (`deploy`, in the `sudo` group), copies
SSH keys from `/root/.ssh/authorized_keys` (or `~$SUDO_USER/.ssh/authorized_keys`
when run via `sudo` from a default cloud login), strips cloud-image forced-command
stubs so your key logs in directly, clones the repository to
`/home/deploy/.dotfiles`, and writes an initial `config.env`. With the server
default `FULL_CONTROL=true`, it installs a validated passwordless sudo rule.
With `FULL_CONTROL=false`, it prompts for a sudo password at a TTY; without a
TTY, set one as root with `passwd deploy` before relying on password-based sudo.

Useful `bootstrap.sh` options and environment variables:

| Flag | Env var | Description |
|---|---|---|
| `--user <name>` | `TARGET_USER` (or `BOOTSTRAP_USER`) | Target non-root Linux username; defaults to `SUDO_USER` via sudo, otherwise prompts at a TTY (default `deploy`); required non-interactively |
| `--repo <url>` | `AGENT_READY_REPO` | Custom fork or repository URL (default: `https://github.com/riobahtiar/agent-ready.git`) |
| `--branch <name>` | `AGENT_READY_BRANCH` | Git branch to clone (default: `main`) |
| `--install` | `BOOTSTRAP_INSTALL=1` | Immediately launch `setup-server.sh` after bootstrapping |

Any configuration key from `config.env.example` passed in the environment (such
as `TIMEZONE=UTC` or `HERMES=false`) is automatically seeded into the new
`config.env`:

```bash
curl -fsSL https://raw.githubusercontent.com/riobahtiar/agent-ready/main/bootstrap.sh | \
    TIMEZONE=UTC HERMES=false bash -s -- --user deploy
```

Deploying from a local checkout instead? Copy the folder up (`scp -r agent-ready root@203.0.113.10:/root/`)
and run `bash /root/agent-ready/bootstrap.sh --user deploy`.

**Keep this root session open** until step 3 has passed.
## 2. Install (as deploy, from a new terminal)

Log in **with your SSH key** as `deploy` first: SSH hardening disables password
authentication only after it detects a key login by `deploy` (preventing lockout).

```bash
ssh deploy@203.0.113.10
~/.dotfiles/setup-server.sh
```

On the first interactive run, the configuration wizard asks for your settings
(Git name/email, timezone, which agents to install, whether to enable Hermes,
Tailscale, sandboxing, default tunnel provider), writes `~/.dotfiles/config.env`,
and offers **Everything in order**.

- **Unattended mode (`FULL_CONTROL`):** On the `server` profile, `FULL_CONTROL=true`
  is the default: bootstrap installs a `visudo`-validated passwordless sudo rule
  for `TARGET_USER`, Stage 05 maintains it, and agent configuration enables
  unattended Claude Code and Codex permissions. On servers `DOCKER_SUDOLESS`
  also defaults to true regardless of `FULL_CONTROL` (the `docker` group is
  root-equivalent). For password-gated sudo and prompting agents, set
  `FULL_CONTROL=false DOCKER_SUDOLESS=false AGENT_SANDBOX=true`, ideally at
  bootstrap (it seeds every nonempty setting from its environment), e.g.
  `curl -fsSL …/bootstrap.sh | sudo env FULL_CONTROL=false DOCKER_SUDOLESS=false bash -s -- --user deploy`.
  Switching off later: set a password first (`sudo passwd deploy`), because
  Stage 05 removes this repository's passwordless sudo rule. Nothing reverts
  existing `docker` group membership (`sudo gpasswd -d deploy docker`) or agent
  bypass settings already written (Claude `permissions.defaultMode:
  "bypassPermissions"` in `~/.claude/settings.json`; Codex `approval_policy =
  "never"` / `sandbox_mode = "danger-full-access"` in `~/.codex/config.toml`);
  remove those by hand. Other sudoers policies still apply; SSH and firewall
  rules are unaffected.
- **Optional Hermes & domains:** If `HERMES=true` and `HERMES_DOMAIN` is set
  (e.g. `hermes.example.com`), Stage 80 prompts for a dashboard password (12+
  characters, stored only as a scrypt hash) and provisions TLS. Set
  `HERMES=false` to skip Hermes. With `HERMES_DOMAIN` empty, Stage 80 skips
  Hermes entirely (no CLI, no Telegram credentials, no dashboard); for just the
  CLI run `agents install hermes`.

Installation takes 15–25 minutes (mostly downloading runtimes via `mise`). If a
stage fails or reports incomplete, fix what it printed and run
`./install.sh --changed`: completed stages are skipped.

**Non-interactive / automated alternative:** edit `config.env` (or pass exported
environment overrides, which need an existing `config.env`) and run with `--all -y`:

```bash
GIT_NAME="Your Name" GIT_EMAIL="you@example.com" HERMES=false \
    ~/.dotfiles/setup-server.sh --all -y
```

Installation saves explicit nonempty exported configuration overrides to the
private `config.env`, so they also apply to later runs. For details and read-only
exceptions, see [10 Reference](10-reference.md#configenv).

## 3. Check you can still log in

In another terminal, verify `ssh deploy@203.0.113.10` logs in cleanly. Root SSH
login and password authentication are now disabled, and `fail2ban` automatically
allowlists the IP you connected from (add static IPs in `F2B_IGNORE_IPS`). If the
installer printed "SSH password login still on", log in once with your SSH key
and run `~/.dotfiles/install.sh --changed`. Once verified, close the root session.

## 4. Log out and back in

Your `docker` group membership and `fish` login shell take effect on the next login.
On SSH login you will see the system status summary (`motd`) above the prompt.

## 5. Sign in to everything

Run these inside `herdr` so a dropped connection doesn't kill a login flow:

```fish
herdr                      # agent workspace; detach: ctrl+b then q
agents login               # menu: claude, codex, opencode, omp, grok, muse
gh auth login && gh auth setup-git
vps                        # → Cloud CLIs: aws, cf, wrangler, rclone, tailscale, zrok
```

Headless OAuth: agents print a login URL or device code. Open it in your local
browser and paste the code back.

## 6. Hermes and Telegram (optional)

Only if `HERMES=true` and `HERMES_DOMAIN` is set (otherwise Stage 80 skipped
Hermes; `agents install hermes` gives you just the CLI):

```fish
hermes setup               # pick a model provider
hermes-up                  # Telegram gateway as a boot service + dashboard restart
```

If you configured `HERMES_DOMAIN` (e.g. `https://hermes.example.com`), open it
and sign in. Message your Telegram bot to test the gateway. Before relying on a
public dashboard, put Cloudflare Access or an IP allowlist in front of it: see
[11 Hermes + Telegram](11-hermes-telegram.md).
## 7. Verify

```fish
doctor                     # expect "all good" (or only yellow notes)
./install.sh --status      # every stage "applied" or "skipped" with a reason
tunnel providers           # which dev tunnels are ready
sandbox check              # which isolation layers work
```

## Later runs

`./install.sh` knows it already ran. It offers **re-apply changed stages**
(recommended), **renew everything**, **re-apply all**, or **pick**. Without a
terminal it refuses to re-run silently: pass `--changed`, `--all` or `--renew`.
See [12 Maintenance](12-maintenance.md).
