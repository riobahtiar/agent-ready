# What gets installed where

Three machines, one repo. The VPS uses the **server** profile
(`./setup-server.sh`); Omarchy and the Mac use **desktop**
(`./setup-desktop.sh`). The rules behind each row are in
[08 Multi-OS](08-multi-os.md). `./install.sh --status` shows the live answer on
any machine.

Legend: ✅ installed/configured by this repo · ☑️ already there (kept, only
adjusted where noted) · ➖ skipped on purpose · ⚙️ opt-in toggle in config.env

## At a glance

| | Ubuntu 26.04 LTS VPS (server + remote dev) | Omarchy (desktop) | macOS (desktop) |
|---|---|---|---|
| Entry point | `bootstrap.sh` (as root) → `setup-server.sh` | `setup-desktop.sh` | `setup-desktop.sh` |
| Package manager | apt | pacman (`-Syu`, never partial) | Homebrew |
| Runs stages | 05 10 20 30 40 50 60 65 70 75 80 90 (all 12) | 05 30 50 60 65 70 75 90 | 05 50 60 65 70 75 |
| Needs sudo | yes (re-execs itself with sudo) | yes (re-execs itself with sudo) | only for `chsh` and `/etc/shells`; runs as you |
| Rough time / disk | 15–25 min · ~8 GB | 10–15 min · ~6 GB | 10–15 min · ~6 GB |

## System and security

| Item | Ubuntu VPS | Omarchy | macOS | Notes |
|---|---|---|---|---|
| Full OS upgrade during setup | ✅ `apt full-upgrade` | ➖ (`pacman -Syu` only to keep Arch consistent) | ➖ (`brew update` only) | Desktop upgrades stay your call (`update-all`, `omarchy update`) |
| Base build tools + ops CLIs | ✅ build-essential, git-lfs, jq, btop, ncdu, duf, tmux, mosh, dnsutils, sqlite… | ✅ the same via `base-devel`, `bind`, … (most ☑️ already) | ✅ the Homebrew equivalents (Xcode CLT provides the compiler) | Debian names mapped in `lib/pkg.sh` |
| Timezone, locale, hostname | ✅ | ➖ | ➖ | The desktop installer already set them |
| zram + swapfile, sysctl, limits, journald caps | ✅ | ➖ | ➖ | Tuned for 6 GB and many agents |
| Unattended security upgrades | ✅ (no auto-reboot) | ➖ | ➖ | Arch has no safe unattended upgrades |
| Lingering user services | ✅ | ➖ | ➖ | Agents/timers keep running after logout |
| SSH hardening (key-only, no root) | ✅ | ➖ | ➖ | Skipped if you have no authorized_keys |
| Firewall | ✅ ufw: 22, 80, 443 (+ mosh ⚙️) | ☑️ Omarchy's ufw untouched | ➖ macOS firewall untouched | |
| fail2ban | ✅ sshd + recidive | ➖ | ➖ | |

## Shell and dotfiles

| Item | Ubuntu VPS | Omarchy | macOS | Notes |
|---|---|---|---|---|
| fish 4 as login shell | ✅ | ✅ (`LOGIN_SHELL=bash` keeps Omarchy's bash) | ✅ (brew fish) | |
| easy-eel prompt + full-stack right prompt | ✅ | ✅ | ✅ | `home/.config/fish/cloud/prompt.fish` |
| Box summary on login | ✅ over SSH | ➖ (local terminals stay quiet) | ➖ | Shows again when you SSH in |
| fisher plugins (fzf.fish, autopair, sponge, puffer-fish) | ✅ | ✅ | ✅ | |
| bash parity (PATH, mise shims, secrets) | ✅ `~/.profile`, top of `~/.bashrc` | ✅ one line at the top of your `~/.bashrc` | ✅ also `~/.zshenv` and `~/.bash_profile` | Agents spawn bash/zsh |
| starship (bash prompt) | ✅ | ☑️ yours kept if `~/.config/starship.toml` exists | ☑️ same rule | "soft" file |
| git config (delta, zdiff3, rerere, worktree-friendly) | ✅ | ✅ | ✅ | identity in `~/.config/git/local` |
| `BROWSER=echo` for headless OAuth | ✅ | ➖ real browser | ➖ real browser | |
| `DO_NOT_TRACK=1` | ✅ | ✅ | ✅ | cf, wrangler, Next.js, Homebrew |

## Runtimes and tools (mise)

| Item | Ubuntu VPS | Omarchy | macOS | Notes |
|---|---|---|---|---|
| mise itself | ✅ apt repo (signed) | ☑️ Omarchy's (pacman) | ✅ Homebrew | |
| Where our tools are declared | `~/.config/mise/conf.d/*.toml` | same; **Omarchy's `config.toml` and preinstalls untouched** and win on conflicts | same | |
| Node LTS, Bun, Go, Python 3.13, uv, pnpm | ✅ | ✅ | ✅ | |
| Flutter | ✅ on x86-64 (❌ arm64 VPS: no SDK) | ✅ | ✅ Apple silicon | Linux desktop build deps: ⚙️ `FLUTTER_LINUX_DESKTOP` |
| PHP 8.5 + php-fpm + composer | ✅ (apt, for nginx) | ➖ (use `mise use php` or Laravel Sail/Docker) | ➖ (same) | |
| gopls, golangci-lint, ruff, typescript | ✅ | ✅ | ✅ | |
| Modern CLI (rg, fd, fzf, bat, eza, zoxide, ast-grep, difftastic, delta, jq, yq, gh, lazygit, lazydocker, just, watchexec, glow, gum, neovim…) | ✅ | ✅ (some ☑️ from Omarchy; mise copies take precedence in mise-activated shells) | ✅ | |
| Cloud: aws-cli, s5cmd, rclone, `cf`, wrangler, cloudflared, OpenTofu | ✅ | ✅ | ✅ | Sign in: `vps` → Cloud CLIs |
| Delivery: hurl, oha, duckdb, usql, process-compose, air, act, biome, ty, sops, age, trivy, osv-scanner, dive, lnav | ✅ | ✅ | ✅ | |
| LLM tooling: ccusage, repomix | ✅ | ✅ | ✅ | More in `35-ai.toml` |
| Lint/security: shellcheck, shfmt, hadolint, gitleaks | ✅ | ✅ | ✅ | |

## Containers and sandboxing

| Item | Ubuntu VPS | Omarchy | macOS | Notes |
|---|---|---|---|---|
| Docker Engine + compose + buildx | ✅ (`docker.io` until Docker publishes a 26.04 suite) | ☑️ Omarchy's | ➖ use OrbStack or Docker Desktop | ⚙️ `DOCKER=false` skips |
| daemon.json (127.0.0.1 binds, log rotation, live-restore) | ✅ | ✅ **merged** with whatever is there | ➖ | |
| You in the `docker` group | ✅ | ➖ (Omarchy's choice; ⚙️ `DOCKER_SUDOLESS`) | n/a | The group is root-equivalent |
| gVisor (`runsc`) for `sandbox box` | ⚙️ `GVISOR=true` | ➖ (AUR `gvisor-bin` by hand) | ➖ | |
| bubblewrap + socat | ✅ + AppArmor profile for bwrap | ✅ | ➖ Seatbelt is built in | Needed by Claude Code's sandbox and srt |
| `srt` + policy `~/.srt-settings.json` | ✅ | ✅ | ✅ | `sandbox run`, `sandbox agent` |
| Claude Code sandbox on by default | ✅ | ✅ | ✅ | ⚙️ `AGENT_SANDBOX` |
| devcontainer CLI | ✅ | ✅ | ✅ | |

## Agents

| Item | Ubuntu VPS | Omarchy | macOS | Notes |
|---|---|---|---|---|
| Claude Code, OpenCode, omp, Grok, Muse, Herdr | ✅ vendor installers | ✅, or ☑️ if Omarchy's mise already provides one (kept, not duplicated) | ✅ vendor installers (not yet run on a Mac) | `AGENTS` in config.env picks which |
| Codex | ✅ via mise | ✅ via mise | ✅ via mise | |
| Shared `AGENTS.md` (machine rules) linked into each agent | ✅ | ✅ | ✅ | `agents/AGENTS.global.md` |
| herdr sidebar hooks | ✅ | ✅ | ✅ | |
| Hermes agent | ✅ CLI + dashboard + Telegram gateway | ➖ (`agents install hermes` for the CLI) | ➖ (same) | |

## Network and hosting

| Item | Ubuntu VPS | Omarchy | macOS | Notes |
|---|---|---|---|---|
| Tailscale | ⚙️ `TAILSCALE=true` (+ operator, ufw rule) | ⚙️ same | ⚙️ prints a pointer to the Mac app | |
| `tunnel` (Tailscale, Cloudflare, zrok, Pinggy, SSH) | ✅ | ✅ | ✅ | `nginx` provider: server only |
| nginx + Let's Encrypt + `site` | ✅ | ➖ | ➖ | Desktops share with `tunnel` |
| Hermes dashboard at h.ciptalogi.com | ✅ | ➖ | ➖ | |
| `notify` (Telegram) | ✅ | ✅ (needs the bot token in secrets.env) | ✅ (same) | |

## Maintenance

| Item | Ubuntu VPS | Omarchy | macOS | Notes |
|---|---|---|---|---|
| Weekly `cleanup --auto` timer | ✅ Sunday 04:00 | ➖ (⚙️ `CLEANUP_TIMER=true`) | ➖ (no systemd) | Run `cleanup` by hand |
| `doctor` | ✅ full (services, exposure, certs) | ✅ (services that apply) | ✅ reduced (load, disk, tools, agents) | |
| `update-all` | apt + mise + agents + fisher + composer | pacman + mise + agents + fisher | brew + mise + agents + fisher | On Omarchy also run `omarchy update` |
| `cleanup system` | apt autoremove/clean, journal vacuum, snaps | paccache, orphans, journal | `brew cleanup` | |

## Notes

- **Re-running is safe everywhere.** `./setup-*.sh --changed` applies only
  what changed. Desktops never get server stages, even by `--all`.
- **Your existing dotfiles:** anything a link would replace is moved to
  `~/.dotfiles-backup/<time>/`. On the Mac that includes the fish config from
  [riobahtiar/dotfiles](https://github.com/riobahtiar/dotfiles); decide which
  repo owns fish there first.
- **Omarchy updates** may restore some of its defaults. `./install.sh dotfiles`
  re-links ours; Omarchy's own files under `~/.config/hypr` etc. are never touched.
- **Tested:** the Ubuntu column end to end in a systemd container; on Arch,
  detection, package mapping and stages 05 + 50. The Omarchy and macOS columns
  follow from the stage rules and the Omarchy manual, but haven't run on that
  hardware yet.
