# shellcheck shell=bash
# Pinggy: a tunnel over plain SSH (port 443), nothing to install or sign up
# for. Free tunnels last 60 minutes — fine for a quick webhook test.
tunnel_define pinggy title="Pinggy over SSH (public · no install · 60 min free)" reach=public rank=60 \
    setup="nothing — needs outbound SSH on port 443"

pinggy_ready() { have ssh; }
pinggy_start() {
    tunnel_bg pinggy "$1" 'https://[a-z0-9]+-[0-9-]+\.[a-z0-9.-]*pinggy[a-z0-9.-]*' \
        ssh -T -p 443 -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes \
        -R0:127.0.0.1:"$1" a.pinggy.io
}
