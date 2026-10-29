# What gets installed where

Three reference environments, one repository. Headless Linux servers use the
**server** profile (`./setup-server.sh`, **tested on the latest Ubuntu LTS**);
Omarchy/Arch and macOS machines use the **desktop** profile
(`./setup-desktop.sh`). The rules behind each row are in
[08 Multi-OS](08-multi-os.md). `./install.sh --status` shows the live answer on
any machine.

Legend: ✅ installed/configured by this repo · ☑️ already there (kept, only
adjusted where noted) · ➖ skipped on purpose · ⚙️ opt-in toggle in config.env

## At a glance

| | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) |
|---|---|---|---|
| Entry point | `bootstrap.sh` (as root) → `setup-server.sh` | `setup-desktop.sh` | `setup-desktop.sh` |
| Package manager | apt | pacman (`-Syu`, never partial) | Homebrew |
| Runs stages | 05 10 20 30 40 50 60 65 70 75 80 90 (12 of 13) | 05 30 50 60 65 70 75 85 90 | 05 50 60 65 70 75 85 |
| Needs sudo | yes (re-execs itself with sudo) | yes (re-execs itself with sudo) | only for `chsh` and `/etc/shells`; runs as you |
| Rough time / disk | 15–25 min · ~8 GB | 10–15 min · ~6 GB | 10–15 min · ~6 GB |

## System and security

| Item | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) | Notes |
|---|---|---|---|---|
| Full OS upgrade during setup | ✅ `apt full-upgrade` | ➖ (`pacman -Syu` only to keep Arch consistent) | ➖ (`brew update` only) | Desktop upgrades stay your call (`update-all`, `omarchy update`) |
| Base build tools + ops CLIs | ✅ build-essential, git-lfs, jq, btop, ncdu, duf, tmux, mosh, dnsutils, sqlite… | ✅ the same via `base-devel`, `bind`, … (most ☑️ already) | ✅ the Homebrew equivalents (Xcode CLT provides the compiler) | Debian names mapped in `lib/pkg.sh` |
| Timezone, locale, hostname | ✅ | ➖ | ➖ | The desktop installer already set them |
| zram + swapfile, sysctl, limits, journald caps | ✅ | ➖ | ➖ | Tuned for running multiple agents |
| Unattended security upgrades | ✅ (no auto-reboot) | ➖ | ➖ | Arch has no safe unattended upgrades |
| Lingering user services | ✅ | ➖ | ➖ | Agents/timers keep running after logout |
| SSH hardening (key-only, no root) | ✅ | ➖ | ➖ | Password login goes off once a key login was seen |
| Unattended mode (`FULL_CONTROL`: passwordless sudo, Claude + Codex unattended defaults) | ✅ `FULL_CONTROL=true` | ⚙️ | ⚙️ (agent defaults only; no sudoers change on macOS) | Perimeter security unchanged |
| Firewall | ✅ ufw: 22, 80, 443 (+ mosh ⚙️) | ☑️ Omarchy's ufw untouched | ➖ macOS firewall untouched | |
| fail2ban | ✅ sshd + recidive | ➖ | ➖ | |

## Shell and dotfiles

| Item | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) | Notes |
|---|---|---|---|---|
| fish 4 as login shell | ✅ | ✅ (`LOGIN_SHELL=bash` keeps Omarchy's bash) | ✅ (brew fish) | |
| easy-eel prompt + full-stack right prompt | ✅ | ✅ | ✅ | `home/.config/fish/cloud/prompt.fish` |
| System summary (`motd`) on login | ✅ over SSH | ➖ (local terminals stay quiet) | ➖ | Shows again when you SSH in (`motd` runs it manually) |
| fisher plugins (fzf.fish, autopair, sponge, puffer-fish) | ✅ | ✅ | ✅ | |
| bash parity (PATH, mise shims, secrets) | ✅ `~/.profile`, top of `~/.bashrc` | ✅ one line at the top of your `~/.bashrc` | ✅ also `~/.zshenv` and `~/.bash_profile` | Agents spawn bash/zsh |
| starship (bash prompt) | ✅ | ☑️ yours kept if `~/.config/starship.toml` exists | ☑️ same rule | "soft" file |
| git config (delta, zdiff3, rerere, worktree-friendly) | ✅ | ✅ | ✅ | identity in `~/.config/git/local` |
| `BROWSER=echo` for headless OAuth | ✅ | ➖ real browser | ➖ real browser | |
| `DO_NOT_TRACK=1` | ✅ | ✅ | ✅ | cf, wrangler, Next.js, Homebrew |

## Runtimes and tools (mise)

| Item | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) | Notes |
|---|---|---|---|---|
| mise itself | ✅ apt repo (signed) | ☑️ Omarchy's (pacman) | ✅ Homebrew | |
| Where our tools are declared | `~/.config/mise/conf.d/*.toml` | same; **Omarchy's `config.toml` and preinstalls untouched** and win on conflicts | same | |
| Node LTS, Bun, Go, Python 3.13, uv, pnpm | ✅ | ✅ | ✅ | |
| Flutter | ✅ x86-64; auto-skipped on Linux arm64 | ✅ | ✅ Apple Silicon & Intel | Linux desktop build deps: ⚙️ `FLUTTER_LINUX_DESKTOP` |
| PHP-FPM + Composer (distro default PHP) | ✅ (apt, for nginx) | ➖ (use `mise use php` or Laravel Sail/Docker) | ➖ (same) | ⚙️ `PHP=false` skips |
| gopls, golangci-lint, ruff, typescript | ✅ | ✅ | ✅ | |
| Modern CLI (rg, fd, fzf, bat, eza, zoxide, ast-grep, difftastic, delta, jq, yq, gh, lazygit, lazydocker, just, watchexec, glow, gum, neovim…) | ✅ | ✅ (some ☑️ from Omarchy; mise copies take precedence in mise-activated shells) | ✅ | |
| Cloud: aws-cli, s5cmd, rclone, `cf`, wrangler, cloudflared, OpenTofu | ✅ | ✅ | ✅ | Sign in: `vps` → Cloud CLIs |
| Delivery: hurl, oha, duckdb, usql, process-compose, air, act, biome, ty, sops, age, trivy, osv-scanner, dive, lnav | ✅ | ✅ | ✅ | |
| LLM tooling: ccusage, repomix | ✅ | ✅ | ✅ | More in `35-ai.toml` |
| Lint/security: shellcheck, shfmt, hadolint, gitleaks | ✅ | ✅ | ✅ | |

## Containers and sandboxing

| Item | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) | Notes |
|---|---|---|---|---|
| Docker Engine + compose + buildx | ✅ (`docker-ce`, falling back to `docker.io` when upstream repo lacks a brand-new Ubuntu release) | ☑️ Omarchy's | ➖ use OrbStack or Docker Desktop | ⚙️ `DOCKER=false` skips |
| daemon.json (127.0.0.1 binds, log rotation, live-restore) | ✅ | ✅ **merged** with whatever is there | ➖ | |
| You in the `docker` group | ✅ | ➖ (Omarchy's choice; ⚙️ `DOCKER_SUDOLESS`) | n/a | The group is root-equivalent |
| gVisor (`runsc`) for `sandbox box` | ⚙️ `GVISOR=true` | ➖ (AUR `gvisor-bin` by hand) | ➖ | |
| bubblewrap + socat | ✅ + AppArmor profile for bwrap | ✅ | ➖ Seatbelt is built in | Needed by Claude Code's sandbox and srt |
| `srt` + policy `~/.srt-settings.json` | ✅ | ✅ | ✅ | `sandbox run`, `sandbox agent` |
| Claude Code sandbox | ⚙️ off when `FULL_CONTROL=true`, on for desktop | ✅ | ✅ | ⚙️ `AGENT_SANDBOX` (`true` overrides `FULL_CONTROL`) |
| devcontainer CLI | ✅ | ✅ | ✅ | |

## Agents

| Item | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) | Notes |
|---|---|---|---|---|
| Claude Code, OpenCode, omp, Grok, Muse, Herdr | ✅ vendor installers | ✅, or ☑️ if Omarchy's mise already provides one (kept, not duplicated) | ✅ vendor installers | `AGENTS` in config.env picks which |
| Codex | ✅ via mise | ✅ via mise | ✅ via mise | |
| Shared `AGENTS.md` (machine rules) linked into agents | ✅ | ✅ | ✅ | `agents/AGENTS.global.md` → `claude`, `codex`, `opencode` |
| herdr sidebar hooks | ✅ | ✅ | ✅ | |
| Hermes agent | ✅ when `HERMES=true`; CLI, optional dashboard and Telegram gateway | ➖ (`agents install hermes` for the CLI) | ➖ (same) | Dashboard needs `HERMES_DOMAIN`; Telegram needs bot configuration |

## Optional desktop apps (stage 85)

`DESKTOP_APPS` is a whitespace-separated list, empty by default: **install none**.
The desktop setup wizard offers explicit selection or opt-out; revisit it with
`./install.sh --configure` while using the desktop profile. For example:

```bash
DESKTOP_APPS='zed ghostty obsidian' ./setup-desktop.sh desktop-apps -y
```

Equivalent private `config.env` configuration:

```bash
DESKTOP_APPS="zed ghostty obsidian"
```

Then run `./setup-desktop.sh desktop-apps -y`. Unselecting an app does not
uninstall it. This stage never installs anything on the server profile.

| ID / app | macOS (Homebrew) | Ubuntu / Debian | Fedora | Arch / Omarchy | WSL |
|---|---|---|---|---|---|
| `orbstack` / OrbStack | [Cask `orbstack`](https://formulae.brew.sh/cask/orbstack) | Skip | Skip | Skip | Skip |
| `tablepro` / TablePro | [Cask `tablepro`](https://formulae.brew.sh/cask/tablepro) | Skip | Skip | Skip | Skip |
| `zed` / Zed | [Cask `zed`](https://formulae.brew.sh/cask/zed) | No native mapping | `zed` with configured Terra source | `zed` | Follows distro; GUI required |
| `ghostty` / Ghostty | [Cask `ghostty`](https://formulae.brew.sh/cask/ghostty) | `ghostty` on Ubuntu 26.04+; availability checked elsewhere | `ghostty` with configured source | `ghostty` | Follows distro; GUI required |
| `tailscale` / Tailscale | [Cask `tailscale-app`](https://formulae.brew.sh/cask/tailscale-app) | `tailscale` with configured vendor source | `tailscale` with configured vendor source | `tailscale` | Native Linux client only; prefer Windows host app for host networking |
| `chatgpt` / ChatGPT desktop | [Cask `chatgpt`](https://formulae.brew.sh/cask/chatgpt) | Skip | Skip | Skip | Skip |
| `claude` / Claude desktop | [Cask `claude`](https://formulae.brew.sh/cask/claude) | Skip | Skip | Skip | Skip |
| `helium` / Helium Browser | [Cask `helium-browser`](https://formulae.brew.sh/cask/helium-browser) | `helium-bin` with configured vendor source | `helium-bin` with configured vendor source | No native mapping | Follows distro; GUI required |
| `cloudflare-warp` / WARP | [Cask `cloudflare-warp`](https://formulae.brew.sh/cask/cloudflare-warp) | `cloudflare-warp` with configured vendor source | `cloudflare-warp` with configured vendor source | No native mapping | Native Linux client only; not a Windows VPN installer |
| `obsidian` / Obsidian | [Cask `obsidian`](https://formulae.brew.sh/cask/obsidian) | Existing Flathub `md.obsidian.Obsidian` | Existing Flathub `md.obsidian.Obsidian` | `obsidian`, or existing Flathub | Follows distro; GUI required |
| `mole` / Mole CLI | [Formula `mole`](https://formulae.brew.sh/formula/mole) | Skip | Skip | Skip | Skip |

Linux package availability depends on already-configured repositories. Setup
does not add vendor repositories/COPRs, AUR helpers, Flatpak, or Flatpak remotes.
An unavailable supported package warns and leaves the stage incomplete for a
later retry; unsupported platforms warn and skip. Linux GUI apps require
`x86_64` or `aarch64`; WARP also requires one of those architectures, whereas
Tailscale uses architectures supported by the native package source. On WSL,
GUI app installation additionally requires an existing DISPLAY/Wayland/WSLg
session. Homebrew enforces each macOS package's current architecture and minimum
OS requirements; do not assume Intel/Apple Silicon support is identical.
OrbStack, TablePro, ChatGPT desktop, and Claude desktop are macOS-only choices
in this registry (not Linux wrappers). Current Homebrew metadata offers Intel
and Apple Silicon builds: OrbStack requires macOS 14+, while TablePro, ChatGPT,
and Claude require macOS 13+. These vendor requirements can change; Homebrew's
current cask metadata is authoritative.
The current machine-readable requirements are recorded in the official
Homebrew API entries for [OrbStack](https://formulae.brew.sh/api/cask/orbstack.json),
[TablePro](https://formulae.brew.sh/api/cask/tablepro.json),
[ChatGPT](https://formulae.brew.sh/api/cask/chatgpt.json), and
[Claude](https://formulae.brew.sh/api/cask/claude.json).

Stage 85 only installs packages: it does not launch GUI apps, explicitly
start/enable services, authenticate, log in, connect Tailscale/WARP, or change
VPN routes/DNS. Native package-manager install hooks may start a background
daemon; setup does not override vendor service policy.
`DESKTOP_APPS=tailscale` is separate from stage 75's `TAILSCALE` networking
configuration; opting into that setting can have its own networking behavior.
Mole requires macOS 12 or later on Intel or Apple Silicon; setup never runs
Mole cleanup or other destructive maintenance commands.

Desktop app licenses, subscriptions, and vendor terms are separate from this
repository's MIT license. Package availability is not an end-to-end desktop
testing claim; the testing caveats below still apply.

Upstream platform/package references: [Homebrew casks](https://formulae.brew.sh/cask/),
[Zed Linux](https://zed.dev/docs/linux),
[Ghostty binaries](https://ghostty.org/docs/install/binary),
[Tailscale packages](https://pkgs.tailscale.com/stable/),
[Helium Linux](https://github.com/imputnet/helium-linux),
[WARP packages](https://pkg.cloudflareclient.com/),
[Obsidian on Arch](https://archlinux.org/packages/extra/x86_64/obsidian/),
[Obsidian Flatpak](https://flathub.org/apps/md.obsidian.Obsidian),
and [Mole](https://github.com/tw93/mole).
Native Arch package listings:
[Zed](https://archlinux.org/packages/extra/x86_64/zed/),
[Ghostty](https://archlinux.org/packages/extra/x86_64/ghostty/),
and [Tailscale](https://archlinux.org/packages/extra/x86_64/tailscale/).
Fedora's Zed source is documented upstream via
[Terra's package definition](https://github.com/terrapkg/packages/tree/frawhide/anda/devs/zed/stable).
[Flatpak's official installation reference](https://docs.flatpak.org/en/latest/using-flatpak.html)
documents remote/app-ID and user/system installation scopes.

Native Windows is not an installation target for these Bash stages. Windows
users can run the Linux desktop profile inside WSL, but that does not install
Windows applications. No `.exe`, WinGet, Chocolatey, or unofficial Linux
ChatGPT/Claude wrapper is invoked. “No native mapping” means setup will not guess
a similarly named package; it warns and leaves a requested supported install
incomplete so you can configure a documented source and retry.

## Network and hosting

| Item | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) | Notes |
|---|---|---|---|---|
| Tailscale | ⚙️ `TAILSCALE=true` (+ operator, ufw rule) | ⚙️ same | ⚙️ prints a pointer to the Mac app | |
| `tunnel` (Tailscale, Cloudflare, zrok, Pinggy, SSH) | ✅ | ✅ | ✅ | `nginx` provider: server only |
| nginx + Let's Encrypt + `site` | ✅ | ➖ | ➖ | Desktops share with `tunnel` |
| Hermes dashboard at `$HERMES_DOMAIN` | ✅ (when `HERMES=true` and `HERMES_DOMAIN` set) | ➖ | ➖ | Optional; leave `HERMES_DOMAIN` empty or `HERMES=false` to skip |
| `notify` (Telegram) | ✅ | ✅ | ✅ | Uses `TELEGRAM_BOT_TOKEN` + `NOTIFY_TELEGRAM_CHAT` in `secrets.env` (or `TELEGRAM_ALLOWED_USERS`) |

## Maintenance

| Item | Ubuntu LTS Server | Omarchy / Arch (desktop) | macOS (desktop) | Notes |
|---|---|---|---|---|
| Weekly `cleanup --auto` timer | ✅ Sunday 04:00 | ➖ (⚙️ `CLEANUP_TIMER=true`) | ➖ (no systemd) | Run `cleanup` by hand |
| `doctor` | ✅ full (services, exposure, certs) | ✅ (services that apply) | ✅ reduced (load, disk, tools, agents) | |
| `update-all` | apt + mise + agents + fisher + composer | pacman + mise + agents + fisher | brew + mise + agents + fisher | On Omarchy also run `omarchy update` |
| `cleanup system` | apt autoremove/clean, journal vacuum, snaps | paccache, orphans, journal | `brew cleanup` | |

## Notes

- **Re-running is safe everywhere.** `./setup-*.sh --changed` applies only
  what changed. Desktops never get server stages, even by `--all`.
- **Your existing dotfiles:** anything a link would replace is moved to
  `~/.dotfiles-backup/<time>/`.
- **Omarchy updates** may restore some of its defaults. `./install.sh dotfiles`
  re-links ours; Omarchy's own files under `~/.config/hypr` etc. are never touched.
- **Testing status:** prior repository records document end-to-end testing of the
  `server` profile on **Ubuntu 26.04 (the latest Ubuntu LTS) in systemd containers**,
  not a full production deployment or hardware certification. Arch Linux
  container checks cover OS detection, package mapping, and core stages.
  **Omarchy and macOS have not been verified end to end**; those columns describe
  intended behaviour from stage rules and merge logic, not observed desktop runs.
