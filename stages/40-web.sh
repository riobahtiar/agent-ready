#!/usr/bin/env bash
# stage-user: root
# stage-os: debian+systemd+nowsl
# stage-profile: server
# stage-inputs: nginx
# stage-desc: nginx + certbot (webroot), php-fpm + composer — host mini projects with `site add`
set -Eeuo pipefail
source "$AGENT_READY_DIR/lib/common.sh"
source "$AGENT_READY_DIR/lib/nginx.sh"
load_config

log "nginx + certbot"
apt_install nginx certbot >/dev/null
as_root install -d -m 755 "$ACME_WEBROOT"

# Snapshot the whole config: if our files make `nginx -t` fail, everything
# this stage changed goes back, not just one file.
if ! pre_out="$(as_root nginx -t 2>&1)"; then
    printf '%s\n' "$pre_out" >&2
    die "nginx -t already fails before this stage changes anything — fix that first, then: ./install.sh web"
fi
snapshot="$(mktemp)"
as_root tar -C /etc -czf "$snapshot" nginx

# Only the untouched Ubuntu welcome site goes (a link to the package's
# default that still serves /var/www/html); an edited one is someone's site.
default_site=/etc/nginx/sites-enabled/default
if as_root test -L "$default_site"; then
    if as_root grep -q 'root /var/www/html;' "$default_site" && ! as_root grep -qE '^[[:space:]]*(proxy_pass|server_name[[:space:]]+[^_])' "$default_site"; then
        as_root rm -f "$default_site"
    else
        warn "kept sites-enabled/default: it was edited (serves something besides the welcome page)"
    fi
fi
install_file "$AGENT_READY_DIR/nginx/cloud.conf" /etc/nginx/conf.d/cloud.conf
for snippet in "$AGENT_READY_DIR"/nginx/snippets/*.conf; do
    install_file "$snippet" "/etc/nginx/snippets/$(basename "$snippet")"
done
install_file "$AGENT_READY_DIR/nginx/default.conf" /etc/nginx/sites-available/00-default.conf
as_root ln -sfn /etc/nginx/sites-available/00-default.conf /etc/nginx/sites-enabled/00-default.conf

if ! test_out="$(as_root nginx -t 2>&1)"; then
    printf '%s\n' "$test_out" >&2
    as_root rm -rf /etc/nginx.rejected
    as_root mv /etc/nginx /etc/nginx.rejected
    as_root tar -C /etc -xzf "$snapshot"
    rm -f "$snapshot"
    die "nginx rejected the new config — restored /etc/nginx as it was (rejected copy: /etc/nginx.rejected)"
fi
rm -f "$snapshot"
as_root systemctl enable --now nginx >/dev/null 2>&1
nginx_reload
ok "$(nginx -v 2>&1)"

# Renewals run from certbot.timer; reload nginx so new certs are picked up.
install_file "$AGENT_READY_DIR/system/certbot-reload-nginx.sh" /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh 0755
as_root systemctl enable --now certbot.timer >/dev/null 2>&1 || true

if is_true "$PHP"; then
    log "PHP (Ubuntu default branch) + composer"
    # Unversioned names follow the release's default (8.5 on 26.04). For a
    # project pinned to another version, run it in Docker instead.
    apt_install_available php-fpm php-cli php-common php-mbstring php-xml php-curl php-zip \
        php-gd php-intl php-bcmath php-mysql php-pgsql php-sqlite3 php-redis php-imagick
    php_ver="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
    for sapi in fpm cli; do
        [[ -d /etc/php/$php_ver/$sapi/conf.d ]] &&
            install_file "$AGENT_READY_DIR/system/php.ini" "/etc/php/$php_ver/$sapi/conf.d/90-cloud.ini"
    done
    as_root systemctl enable --now "php$php_ver-fpm" >/dev/null 2>&1
    as_root systemctl restart "php$php_ver-fpm"
    ok "PHP $php_ver · fpm socket $(php_fpm_socket)"

    # Composer is optional: a slow or broken download (getcomposer.org) leaves
    # the stage incomplete for --changed to retry, it never stops the install.
    install_composer() {
        local tmp expected actual rc=0
        tmp="$(mktemp -d)"
        expected="$(fetch https://composer.github.io/installer.sig)" &&
            fetch https://getcomposer.org/installer "$tmp/composer-setup.php" || rc=1
        if ((rc == 0)); then
            actual="$(php -r "echo hash_file('sha384', '$tmp/composer-setup.php');")"
            if [[ $expected != "$actual" ]]; then
                warn "composer installer checksum mismatch — not running it"
                rc=1
            else
                # The installer downloads composer.phar itself: retry that step too.
                # (This stage runs as root; `timeout` can't run shell functions like as_root.)
                retry 3 with_timeout 300 php "$tmp/composer-setup.php" --quiet --install-dir=/usr/local/bin --filename=composer || rc=1
            fi
        fi
        rm -rf "$tmp"
        return $rc
    }
    if ! have composer && ! install_composer; then
        stage_incomplete "composer not installed (download failed) — retry later: ./install.sh web"
    elif have composer; then
        ok "$(composer --version 2>/dev/null | head -1)"
    fi
fi

as_root install -d -m 2775 -o "$TARGET_USER" -g www-data "$WWW_DIR"
ok "Static/PHP sites live under $WWW_DIR/<domain> — create them with: site add"
