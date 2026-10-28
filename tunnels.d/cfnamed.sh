# shellcheck shell=bash
# Cloudflare named tunnel: a stable hostname on a domain you have on
# Cloudflare (e.g. dev.ciptalogi.com), with Access policies if you want them.
# One-time: cloudflared tunnel login  (writes ~/.cloudflared/cert.pem)
tunnel_define cfnamed title="Cloudflare named tunnel (public · your own stable hostname)" reach=public rank=40 auto=no \
    setup="cloudflared tunnel login  (once; pick the zone)"

cfnamed_ready() {
    have cloudflared || {
        echo "cloudflared missing: mise install"
        return 1
    }
    [[ -f $HOME/.cloudflared/cert.pem ]] || {
        echo "run once: cloudflared tunnel login"
        return 1
    }
}
cfnamed_start() {
    local port=$1 host=${2:-}
    if [[ -z $host ]]; then
        ui_interactive || die "cfnamed needs a hostname: tunnel $port cfnamed dev.example.com"
        host="$(ui_input "Hostname on your Cloudflare zone" "" "dev.ciptalogi.com")" || return 1
    fi
    local name="dev-${host//./-}"
    cloudflared tunnel info "$name" >/dev/null 2>&1 || cloudflared tunnel create "$name" >/dev/null || return 1
    cloudflared tunnel route dns --overwrite-dns "$name" "$host" >/dev/null 2>&1 ||
        warn "couldn't route $host (is the zone on this Cloudflare account?)"
    tunnel_bg cfnamed "$port" 'Registered tunnel connection' \
        cloudflared tunnel --no-autoupdate run --url "http://127.0.0.1:$port" "$name" >/dev/null || return 1
    tunnel_record cfnamed "$port" "https://$host"
    echo "https://$host"
}
