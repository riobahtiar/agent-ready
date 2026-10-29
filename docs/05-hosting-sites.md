# Hosting sites (server profile)

nginx is the only public entry point (ports 80/443). Apps listen on
`127.0.0.1:<port>`, and `site` writes a vhost and gets a Let's Encrypt
certificate. Docker publishes ports on 127.0.0.1 by default (daemon.json), so a
container is never accidentally public.

## Before you add a site

1. DNS: an A record for the domain → the VPS IP (`dig +short app.example.com`).
   Behind Cloudflare's proxy (orange cloud) use SSL mode **Full (strict)**.
2. The app is running on a free port in 3000–3999 (`ss -tln`, or `site add`
   lists what's listening).

## Add one

```bash
site add          # wizard: domain → what it serves → port/dir → confirm
```

Or directly:

```bash
site add app.example.com --proxy 3001                 # Node · Bun · Go · Python · a container
site add www.example.com --static /srv/www/example    # plain files
site add dash.example.com --static ~/projects/dash/dist --spa   # unknown paths → index.html
site add api.example.com --php ~/projects/api/public  # Laravel / PHP-FPM
```

A failed `nginx -t` restores the previous config (or removes the new one), so
a typo never takes nginx down.

## Keep the app running

**Docker Compose**: `"3002:3000"` already binds to 127.0.0.1.

```yaml
services:
  api:
    build: .
    ports: ["3002:3000"]
    restart: unless-stopped
    mem_limit: 512m
```

**systemd user service** (no root, starts at boot because lingering is on):

```ini
# ~/.config/systemd/user/shop.service
[Unit]
Description=shop (bun)
[Service]
WorkingDirectory=%h/projects/shop
ExecStart=%h/.local/share/mise/shims/bun run start --port 3001
Restart=on-failure
Environment=NODE_ENV=production
MemoryMax=512M
[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload && systemctl --user enable --now shop
journalctl --user -u shop -f
```

**Laravel**: `site add api.example.com --php ~/projects/api/public`, then
`chmod o+x ~ ~/projects ~/projects/api` (or deploy under `/srv/www`, which is
group `www-data`). `site add` warns when www-data can't reach the directory.

## Manage

```bash
site ls                       # domain, type, target, certificate expiry
site logs app.example.com   # follow the access log (add `error` for the error log)
site rm app.example.com --purge-cert
site renew                    # after editing nginx/templates/*.conf: re-render every site
```

Certificates renew automatically (`certbot.timer`), and the deploy hook
reloads nginx.

## Change the templates

`nginx/templates/{proxy,static,php,hermes}.conf` use `__PLACEHOLDER__` tokens.
Line 1 must stay `# site: __DOMAIN__ type=…` because `site ls` and `site renew`
read it. Edit the template, then `site renew`.

## Not public yet?

Share a dev build without DNS: `tunnel 3001 cloudflare` (random URL), or
`tunnel 3001 cfnamed dev.example.com` for a stable hostname through
Cloudflare. See [07 Networking](07-networking.md).
