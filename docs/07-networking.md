# Developer networking: Tailscale and app preview tunnels

## Tailscale

Tailscale puts your server, laptop, and phone on one private WireGuard mesh
network (a "tailnet"). You get:

- SSH to your server from anywhere without exposing a public SSH port (optionally
  using **Tailscale SSH** with no SSH keys to manage).
- Private HTTPS URLs for dev servers: `tunnel 5173 tailscale`.
- Private access to internal tools or IP-allowlisted endpoints (see
  [11 Hermes + Telegram](11-hermes-telegram.md) for how Tailscale interacts with
  Let's Encrypt and the Hermes dashboard).

### Turn it on

```bash
./install.sh --configure        # tick "Tailscale" (and "Tailscale SSH" if you want it)
./install.sh network            # installs tailscaled, lets you run `tailscale serve` without sudo
sudo tailscale up               # prints a login URL (or set TAILSCALE_AUTHKEY for unattended)
```

On a server with ufw, stage 75 also allows inbound traffic on `tailscale0`
(peers are already authenticated). On WSL, run Tailscale on Windows. On macOS,
install the app from https://tailscale.com/download/mac.

## Which tunnel when

`tunnel` exposes a local dev server (`127.0.0.1:<port>`). Providers are
modules in `tunnels.d/`, one file each.

| Provider | Reach | URL | Needs | Pick it when |
|---|---|---|---|---|
| `tailscale` | **private** (your tailnet) | `https://cloud.<tailnet>.ts.net:5173` | Tailscale up | Default for your own previews: real HTTPS, nothing public |
| `ssh` | **private** (just you) | `http://localhost:5173` on the laptop | nothing | Zero setup; prints the `ssh -L` command |
| `cloudflare` | public | random `*.trycloudflare.com` | nothing (cloudflared via mise) | Show someone quickly, webhooks, mobile testing |
| `cfnamed` | public | **your stable hostname** (`dev.example.com`) | `cloudflared tunnel login` once; zone on Cloudflare | Long-lived previews, OAuth callbacks that need a fixed URL, Cloudflare Access in front |
| `funnel` | public | `https://cloud.<tailnet>.ts.net:8443` | Tailscale + Funnel allowed in the tailnet policy | Public, but on your ts.net name |
| `zrok` | public | `*.share.zrok.io` | free account, `zrok2 enable <token>` | Open-source alternative; you can self-host the server |
| `pinggy` | public | `*.free.pinggy.net` | outbound SSH | No install at all; free tunnels last 60 minutes |
| `nginx` | public, **permanent** | `https://app.example.com` | server profile + DNS | It's not a preview any more: use `site add` |

`tunnel <port>` with no provider uses `TUNNEL_DEFAULT` (config.env), or else
the first ready **private** one: Tailscale Serve, else the SSH forward. Going
public is never automatic: name the provider, and confirm (or pass `-y` in a
script). The Hermes dashboard port is refused outright, because nginx publishes it with its
allowlist. `tunnel providers` shows what each still needs.

```bash
tunnel                          # menu
tunnel 5173                     # default provider
tunnel 3000 cloudflare
tunnel 3000 cfnamed dev.example.com
tunnel ls                       # running tunnels + URLs
tunnel stop <port|all> [provider] # e.g. tunnel stop 3000 cloudflare
tunnel logs 3000 [provider]
```

Background tunnels keep a pid, log and URL in `~/.local/state/dotfiles/tunnels/`.
Tailscale Serve/Funnel are kept by `tailscaled` itself, so they survive
reboots until you `tunnel stop` them.

### Safety

- **Public means public**: anyone with the URL reaches your dev server, with
  whatever auth it has (often none). `tunnel` warns every time.
- Dev servers should still bind to `127.0.0.1`. The tunnel connects locally,
  and `doctor` flags anything listening on a public address.
- Want auth on a public preview? Use `cfnamed` and add a Cloudflare Access
  application for that hostname (email OTP or GitHub login).

### Why these, and what else exists

The [awesome-tunneling](https://github.com/anderspitman/awesome-tunneling)
list recommends Cloudflare Tunnel for most people. For self-hosted production
it recommends frp and Pangolin, and you don't need either on a server that already has a
public IP and nginx. Tailscale covers private access, zrok is the strongest
open-source public option, and Pinggy is the no-install fallback. To add another
(ngrok, localhost.run, bore…), copy `tunnels.d/_template.sh`: define `_ready`
and `_start`, then use `tunnel_bg` for long-running clients.

## Cloudflare named tunnel, step by step

```bash
cloudflared tunnel login               # pick the zone (example.com); writes ~/.cloudflared/cert.pem
tunnel 3000 cfnamed dev.example.com    # creates tunnel "dev-dev-example-com", routes DNS, runs it
```

Re-running reuses the tunnel and the DNS record. To remove one for good:
`cloudflared tunnel delete dev-dev-example-com` and delete the CNAME
(`cf dns records list` / `cf dns records delete`).
