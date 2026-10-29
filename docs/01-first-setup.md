# First setup

From a fresh Ubuntu LTS VPS to agents running, in about 30 minutes. Laptops
(macOS, Arch/Omarchy, WSL) skip step 1: see [08 Multi-OS](08-multi-os.md).

## 0. Before you start (on your laptop)

- [ ] An SSH key on the VPS's root account (most providers add it at creation).
- [ ] Optional DNS: `hermes.example.com` → the VPS IP (A record). Check: `dig +short hermes.example.com`.
- [ ] Optional but recommended: a GitHub token with no permissions
      ([fine-grained](https://github.com/settings/personal-access-tokens)). mise pulls
      ~70 tools from GitHub, and anonymous access allows 60 API calls an hour.
- [ ] For Hermes on Telegram: a bot token from **@BotFather** and your numeric id
      from **@userinfobot**. (You can add these later.)
- [ ] Optional: a [Tailscale](https://tailscale.com) account (free) for private access.

## 1. Bootstrap (as root, once)

```bash
ssh root@<vps-ip>
curl -fsSL https://raw.githubusercontent.com/riobahtiar/dotfiles-cloud/main/bootstrap.sh | bash -s -- --user deploy
```

This creates `deploy` (sudo group), copies root's SSH keys to it, asks for a sudo
password, clones the repo to `/home/deploy/.dotfiles` and creates `config.env`.
Local copy? `scp -r dotfiles-cloud root@<vps-ip>:/root/` and run
`bash /root/dotfiles-cloud/bootstrap.sh --user deploy`.

It strips cloud-image forced-command stubs from the copied keys, so the key
logs you in as `deploy`.

**Keep this root session open** until step 3 has passed.

## 2. Install (as deploy, from a new terminal)

Log in **with your SSH key** as `deploy` first: the hardening step turns password
login off only after it has seen a key login by `deploy` (so it can't lock you out).

```bash
ssh deploy@<vps-ip>
~/.dotfiles/setup-server.sh
```

The first run asks your settings (name, email, profile, which agents, Hermes,
Tailscale, sandboxing, default tunnel…), writes `config.env`, and offers
**Everything in order**. With `FULL_CONTROL=true` (the default for this VPS)
sudo never asks for a password and Claude/Codex start in YOLO mode; the
Hermes stage still asks for a dashboard password (twice, 12+ characters).

It takes 15–25 minutes, mostly mise downloads and Flutter. If a stage fails,
fix what it printed and run `./install.sh --changed`: completed stages are
skipped.

Non-interactive alternative: edit `config.env` yourself, then
`./install.sh --all -y`.

## 3. Check you can still log in

In another terminal: `ssh deploy@<vps-ip>` must work. Root login and password
auth are now off, and fail2ban never bans the IP you installed from (add more in
`F2B_IGNORE_IPS`). If the install said "SSH password login still on", log in
once with your key and run `./install.sh --changed`. Then close the root session.

## 4. Log out and back in

The docker group and fish as your login shell take effect on the next login.
You'll see the box summary under the prompt.

## 5. Sign in to everything

Run these inside `herdr` so a dropped connection doesn't kill a login flow:

```fish
herdr                      # agent workspace; detach: ctrl+b then q
agents login               # menu: claude, codex, opencode, omp, grok, muse
gh auth login && gh auth setup-git
vps                        # → Cloud CLIs: aws, cf, wrangler, rclone, tailscale, zrok
```

Headless OAuth: agents print a URL or device code. Open it on your laptop and
paste the code back.

## 6. Hermes and Telegram

```fish
hermes setup               # pick a model provider
hermes-up                  # Telegram gateway as a boot service + dashboard restart
```

Open `https://$HERMES_DOMAIN` (e.g. `https://hermes.example.com`) and log in. Message your bot. Before you rely on
the dashboard, put Cloudflare Access or an IP allowlist in front of it: see
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
