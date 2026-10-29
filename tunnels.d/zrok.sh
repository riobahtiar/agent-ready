# shellcheck shell=bash
# zrok (open source, OpenZiti): public shares on zrok.io or your own zrok
# instance. zrok 2.x installs the command as `zrok2`; 1.x as `zrok`.
# One-time: an account at https://zrok.io, then `zrok2 enable <token>`.
tunnel_define zrok title="zrok share (public · open source · self-hostable)" reach=public rank=50 \
    setup="zrok2 enable <account token>  (once; free account at zrok.io)"

_zrok_bin() { command -v zrok2 || command -v zrok; }
zrok_ready() {
    local bin
    bin="$(_zrok_bin)" || {
        echo "zrok missing: mise install"
        return 1
    }
    if "$bin" status 2>&1 | grep -q 'enable command'; then
        echo "run once: $(basename "$bin") enable <token>"
        return 1
    fi
}
zrok_start() {
    tunnel_bg zrok "$1" 'https://[a-z0-9-]+\.[a-z0-9.-]*zrok\.io' \
        "$(_zrok_bin)" share public --headless "http://127.0.0.1:$1"
}
