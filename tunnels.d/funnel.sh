# shellcheck shell=bash
# Tailscale Funnel: the same as Serve, but public. Funnel only offers HTTPS
# ports 443, 8443 and 10000; 443 is nginx's here, so this uses 8443, then 10000.
tunnel_define funnel title="Tailscale Funnel (public URL on your ts.net name)" reach=public rank=30 \
    setup="Tailscale ready, and Funnel allowed in the tailnet policy (first use prints a link)"

funnel_ready() { tailscale_ready; }
funnel_start() {
    local https
    for https in 8443 10000; do
        [[ -n $(tunnels_active | awk -v p="$https" '$1 == "funnel" && $3 ~ ":" p "$"') ]] && continue
        tailscale funnel --bg --yes --https="$https" "http://127.0.0.1:$1" >/dev/null || return 1
        echo "$https" >"$(_tunnel_file funnel "$1" https)"
        tunnel_record funnel "$1" "https://$(_ts_dns):$https"
        echo "https://$(_ts_dns):$https"
        return 0
    done
    die "both Funnel ports (8443, 10000) are in use — tunnel stop one first"
}
funnel_stop() {
    local f https
    f="$(_tunnel_file funnel "$1" https)"
    https="$(cat "$f" 2>/dev/null || echo 8443)"
    tailscale funnel --https="$https" off >/dev/null 2>&1 || true
    rm -f "$f"
}
