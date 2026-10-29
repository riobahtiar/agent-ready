# shellcheck shell=bash
# Tailscale Serve: HTTPS on your tailnet only (https://<machine>.<tailnet>.ts.net:<port>).
# Uses the local port number as the HTTPS port so nginx keeps 443.
tunnel_define tailscale title="Tailscale Serve (private to your tailnet · HTTPS)" reach=private rank=10 \
    setup="TAILSCALE=true in config.env, ./install.sh network, then: sudo tailscale up"

_ts_dns() { tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//'; }
tailscale_ready() {
    have tailscale || {
        echo "tailscale not installed (TAILSCALE=true, ./install.sh network)"
        return 1
    }
    [[ -n $(_ts_dns) ]] || {
        echo "not logged in: sudo tailscale up"
        return 1
    }
    tailscale serve status >/dev/null 2>&1 || {
        echo "not allowed: sudo tailscale set --operator=\$USER"
        return 1
    }
}
tailscale_start() {
    tailscale serve --bg --yes --https="$1" "http://127.0.0.1:$1" >/dev/null || return 1
    tunnel_record tailscale "$1" "https://$(_ts_dns):$1"
    echo "https://$(_ts_dns):$1"
}
tailscale_stop() { tailscale serve --https="$1" off >/dev/null 2>&1 || true; }
