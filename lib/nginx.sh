# shellcheck shell=bash
# nginx + Let's Encrypt helpers shared by stages/40-web.sh, stages/80-hermes.sh
# and bin/site. Requires lib/common.sh.
#
# Flow for every site: issue the cert first (webroot, served by the default
# server's ACME location), then write the full 80+443 vhost, then `nginx -t`.
# A failed test removes the new vhost so nginx never stays broken.

ACME_WEBROOT=/var/www/letsencrypt
NGINX_TEMPLATES="$AGENT_READY_DIR/nginx/templates"

nginx_reload() {
    if as_root nginx -t 2>/dev/null; then
        as_root systemctl reload nginx
    else
        as_root nginx -t || true
        return 1
    fi
}

cert_exists() { as_root test -f "/etc/letsencrypt/live/$1/fullchain.pem"; }

# cert_issue <domain> — obtain (or keep) a Let's Encrypt cert via webroot.
# Warns and returns 1 on failure; callers decide whether that's fatal.
cert_issue() {
    local domain=$1
    if [[ -z ${ACME_EMAIL:-} || $ACME_EMAIL == you@example.com ]]; then
        warn "set ACME_EMAIL in config.env"
        return 1
    fi
    if cert_exists "$domain"; then
        step "certificate for $domain already present"
        return 0
    fi
    local ip
    ip="$(getent ahostsv4 "$domain" | awk 'NR==1{print $1}')"
    if [[ -z $ip ]]; then
        warn "$domain does not resolve — create its DNS A record first"
        return 1
    fi
    step "$domain → $ip; requesting certificate"
    as_root certbot certonly --webroot -w "$ACME_WEBROOT" -d "$domain" \
        --non-interactive --agree-tos -m "$ACME_EMAIL" --keep-until-expiring --quiet || {
        warn "certbot failed for $domain (DNS → this server? port 80 open? Cloudflare proxy in 'Full' mode?)"
        return 1
    }
    ok "certificate issued for $domain"
}

# site_write <domain> <template> KEY=VALUE... — render a vhost and enable it.
site_write() {
    local domain=$1 template=$2
    shift 2
    local avail="/etc/nginx/sites-available/$domain.conf"
    local enabled="/etc/nginx/sites-enabled/$domain.conf"
    local backup=''
    if as_root test -f "$avail"; then
        backup="$(mktemp)"
        as_root cp "$avail" "$backup"
    fi
    render "$NGINX_TEMPLATES/$template.conf" DOMAIN="$domain" "$@" | as_root tee "$avail" >/dev/null
    as_root ln -sfn "$avail" "$enabled"
    if nginx_reload; then
        ok "https://$domain is live"
        [[ -n $backup ]] && rm -f "$backup"
        return 0
    fi
    if [[ -n $backup ]]; then
        as_root cp "$backup" "$avail" && rm -f "$backup"
        warn "nginx rejected the new $domain config — restored the previous one"
    else
        as_root rm -f "$enabled" "$avail"
        warn "nginx rejected the $domain config — removed it"
    fi
    nginx_reload || true
    return 1
}

php_fpm_socket() {
    local sock
    sock="$(compgen -G '/run/php/php*-fpm.sock' | sort -V | tail -1 || true)"
    [[ -n $sock ]] || die "php-fpm socket not found — is PHP=true and the web stage installed?"
    printf '%s\n' "$sock"
}
