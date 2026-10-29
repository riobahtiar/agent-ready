# Hermes: dashboard and Telegram (server profile)

[Hermes Agent](https://hermes-agent.nousresearch.com/docs/) (Nous Research)
runs as an optional Telegram bot and web dashboard, served behind TLS at
`https://$HERMES_DOMAIN` (e.g. `https://hermes.example.com`). With
`HERMES=false` or `HERMES_DOMAIN` empty, stage 80 skips Hermes entirely (no
CLI, no Telegram credentials, no dashboard); for the CLI alone run
`agents install hermes`. The setup below applies only when `HERMES=true` and
`HERMES_DOMAIN` is set.

## How it's wired

- `hermes-dashboard.service` (system unit, runs as `$TARGET_USER`) listens on
  **127.0.0.1:9119** only, capped at 1 GB RAM.
- nginx terminates TLS for `HERMES_DOMAIN` (Let's Encrypt) and proxies to it,
  with WebSockets on and buffering off so streaming and the web terminal work.
- `dashboard.public_url` = `https://$HERMES_DOMAIN`. With a non-loopback URL
  Hermes refuses to start without an auth provider. Stage 80 configures its
  username/password provider and stores only the **scrypt hash** plus a session
  secret in `~/.hermes/.env`; the plaintext is never written.
- The Telegram gateway is a boot-time service installed by Hermes itself
  (`hermes gateway install --system`, via `hermes-up`).

## Set up

```bash
hermes setup        # model provider (e.g. hermes setup --portal)
hermes-up           # Telegram gateway → boot service; restarts the dashboard
```

1. Create a bot with **@BotFather** and copy the token. Get your numeric id
   from **@userinfobot**.
2. Put both in config.env (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`), or
   let `hermes-up` start Hermes' own gateway wizard.
3. Message the bot. Someone not on the allowlist gets a pairing code, which you
   approve with `hermes pairing approve telegram <code>` (or `vps` → Hermes → Approve).

## Lock the dashboard down

> ⚠️ The dashboard is **a shell on this machine**. It has a web terminal and can
> read `~/.hermes/.env`. Hermes' docs say the password provider is meant for
> trusted networks. Add one of these in front:

- **Cloudflare Access** (recommended, free). Proxy the DNS record through
  Cloudflare (orange cloud; SSL/TLS mode **Full (strict)** is recommended), then
  Zero Trust → Access → Applications → add your `HERMES_DOMAIN` (e.g.
  `hermes.example.com`) with an email-OTP or GitHub policy.
  **Also set `HERMES_CLOUDFLARE_ONLY=true`** and run `./install.sh hermes`:
  otherwise anyone who discovers the server IP can reach the dashboard directly
  (`curl --resolve hermes.example.com:443:203.0.113.10 …`) and bypass Access.
  When `HERMES_CLOUDFLARE_ONLY=true` is enabled, the nginx vhost restricts
  connections to Cloudflare IP ranges and also tolerates Cloudflare's Flexible
  SSL mode without redirect loops (though **Full (strict)** remains recommended).
  (Behind the proxy, `HERMES_ALLOW_IPS` only sees Cloudflare's addresses.)
- **IP allowlist**: `HERMES_ALLOW_IPS="203.0.113.7 198.51.100.0/24"` in `config.env`,
  then `./install.sh hermes`.
- **Tailscale:** a tailnet alone does not make the public dashboard domain
  private. Pointing public DNS at a Tailscale `100.x` address breaks Let's
  Encrypt's HTTP validation and renewal. For this repository's domain-based
  dashboard, keep public DNS and use Cloudflare Access or allowlist your devices'
  public egress IPs. Adding a Tailscale IP to the allowlist only helps when
  traffic actually reaches nginx over that tailnet path; it does not change DNS
  or certificate validation.

Stage 80 also refuses to publish the vhost unless the dashboard reports
`auth_required: true`. If Hermes ever starts without auth, the site stays off
and the stage is reported incomplete.

## Operate

| Task | Command |
|---|---|
| Status of both services | `hermes-up status` |
| Logs | `journalctl -u hermes-gateway -f` · `journalctl -u hermes-dashboard -f` |
| Change the dashboard password | `HERMES_RESET_PASSWORD=1 ./install.sh hermes` |
| Update Hermes | `update-all hermes` |
| Everything above in a menu | `vps` → Hermes |

## notify: your own messages through the same bot

`notify "text"` sends a Telegram message. The bot token is read from
`~/.config/secrets.env` first, then `~/.hermes/.env` (so a dedicated notify bot
wins and the Hermes bot is the fallback). The chat id is `NOTIFY_TELEGRAM_CHAT`
(same file order), else the first ID in `TELEGRAM_ALLOWED_USERS`. `config.env`
is never read. It
doesn't interfere with the gateway, which only reads incoming updates. Use it
from hooks, cron, or after long builds ([06](06-tools-and-agents.md#get-pinged)).
