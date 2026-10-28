# shellcheck shell=bash
# Not a tunnel: a real vhost on this server's public IP with Let's Encrypt
# (`site add`). Use it when the app should stay up on your own domain.
tunnel_define nginx title="nginx + Let's Encrypt on your domain (permanent · server profile)" reach=permanent rank=80 auto=no

nginx_ready() {
    [[ $PROFILE == server ]] && have nginx || {
        echo "server profile with nginx only (./install.sh web)"
        return 1
    }
}
nginx_start() {
    local args=("$DOTFILES_DIR/bin/site" add)
    [[ -n ${2:-} ]] && args+=("$2" --proxy "$1")
    "${args[@]}"
}
nginx_stop() { warn "permanent site — remove it with: site rm <domain>"; }
