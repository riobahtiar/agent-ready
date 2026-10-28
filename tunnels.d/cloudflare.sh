# shellcheck shell=bash
# Cloudflare quick tunnel: random https://<words>.trycloudflare.com, no account.
# Great for showing someone a dev server for an hour; the URL changes each run.
tunnel_define cloudflare title="Cloudflare quick tunnel (public · random URL · no account)" reach=public rank=20 \
    setup="cloudflared comes from mise (conf.d/60-network.toml)"

cloudflare_ready() { have cloudflared || {
    echo "cloudflared missing: mise install"
    return 1
}; }
cloudflare_start() {
    tunnel_bg cloudflare "$1" 'https://[a-z0-9-]+\.trycloudflare\.com' \
        cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:$1"
}
