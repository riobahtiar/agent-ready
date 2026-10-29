# Troubleshooting

Start with `doctor` and `./install.sh --status`: most problems show up in one of them. For general questions, see [16 FAQ](16-faq.md).

| Symptom | Fix |
|---|---|
| "SSH password login still on" | Hardening waits for proof that your key works: log in as the user with your key, then `./install.sh --changed` (or `SSH_HARDEN=force`) |
| A stage says "incomplete" | It finished but something was left (a tool, DNS, a login); fix what it printed, `./install.sh --changed` retries it |
| `mise: config not trusted` in a project | Expected for cloned repos: read its `mise.toml`, then `mise trust` |
| Docker "NOT restarted" | Containers were running: `sudo systemctl restart docker` when convenient |
| The provider's panel can't reset the password / inject keys | cloud-init is locked after first boot (`CLOUD_INIT_LOCK`): set it to false and `./install.sh system`, use the panel, then lock again |
| `cloud-init-main.service` failed | Provider boot commands failed after SSH hardening; `./install.sh system` locks cloud-init |
| A stage failed mid-install | Fix what it printed, then `./install.sh --changed`. Stages that completed are skipped |
| `setup already ran here` | It's the guard: pick `--changed`, `--all` or `--renew` (or run it in a terminal for the menu) |
| mise: `API rate limit exceeded` | Set `GITHUB_TOKEN` in config.env, then `./install.sh tools` |
| mise: one tool fails and others are missing | A bad tool name fails the whole install. `mise ls --missing`, then fix the name in `conf.d/` (`mise registry \| grep <name>`) |
| `flutter: No URL for platform …` | Linux ARM64 is automatically skipped via `MISE_DISABLE_TOOLS=flutter` (upstream publishes Linux x86-64 only), and Intel macOS has `macos-x64` configured in `10-runtimes.toml`. If you hit this on an older checkout, pull the latest repo and run `./install.sh dotfiles tools` |
| Agent can't find `node`/`go` in a subshell | `mise doctor`; check `bash -lc 'echo $PATH'` includes `~/.local/share/mise/shims` |
| Prompt isn't easy-eel | `fisher update` (or `./install.sh tools`), then `exec fish`. Check `functions -D fish_prompt` |
| Right prompt shows `node` without a version | That shell uses shims, not `mise activate` (non-interactive). Interactive fish shows the version |
| `ERR_TOO_MANY_REDIRECTS` / "Cloudflare SSL/TLS mode is Flexible" behind Cloudflare | Set Cloudflare → SSL/TLS → Overview → **Full (strict)**. In Flexible mode, Cloudflare connects to the origin over HTTP, causing standard HTTP→HTTPS redirects (`site add`) to loop. (For the Hermes vhost, `HERMES_CLOUDFLARE_ONLY=true` also tolerates Flexible mode, though **Full (strict)** is still recommended.) |
| certbot fails | DNS must point here (`dig +short <domain>`), port 80 open. Behind Cloudflare: SSL **Full (strict)** |
| Dashboard `400 Invalid Host header` | `hermes update`; confirm `hermes config get dashboard.public_url` matches `https://$HERMES_DOMAIN` ([issue #34390](https://github.com/NousResearch/hermes-agent/issues/34390)) |
| Dashboard won't start | `journalctl -u hermes-dashboard -n 50`; usually auth: `HERMES_RESET_PASSWORD=1 ./install.sh hermes` |
| `docker: permission denied` | Server: log out and back in (docker group). Desktop: `sudo docker …`, or `DOCKER_SUDOLESS=true` + `./install.sh docker` |
| `sandbox check`: bubblewrap blocked | `./install.sh sandbox` (AppArmor profile). In a container or a hardened kernel it may stay blocked |
| `tunnel`: "no provider is ready" | `tunnel providers` lists what each needs; `tunnel 3000 ssh` always works |
| Tailscale serve: "access denied" | `sudo tailscale set --operator=$USER` |
| Funnel fails | Allow Funnel for the node in the tailnet policy; the first attempt prints the link |
| `zrok: run once: zrok2 enable` | Create an account at zrok.io, then `vps` → Cloud CLIs → zrok |
| wrangler login hangs on a VPS | Its callback is `localhost:8976`: `ssh -N -L 8976:127.0.0.1:8976 cloud` from the laptop first, or use `CLOUDFLARE_API_TOKEN` |
| `zram module unavailable` | Install `linux-modules-extra-$(uname -r)`, then `./install.sh system` |
| `~/.dotfiles` shows changes after an update | An installer edited a linked file: `git -C ~/.dotfiles diff`, keep what's useful |
| A menu doesn't appear | Menus need a real terminal and no arguments. `CLOUD_UI=plain` swaps gum for numbered prompts |
| Omarchy reset a config after `omarchy update` | `./install.sh dotfiles` re-links it (`--changed` only notices repo changes); linked files are listed in `home/` |
| macOS: `install.sh needs bash 4+` | Install Homebrew; install.sh then installs bash and re-launches itself |
