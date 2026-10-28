#!/usr/bin/env bash
# stage-user: root
# stage-os: debian+systemd+nowsl
# stage-profile: server
# stage-desc: nginx + certbot (webroot), php-fpm + composer — host mini projects with `site add`
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/nginx.sh"
load_config

log "nginx + certbot"
apt_install nginx certbot >/dev/null
as_root install -d -m 755 "$ACME_WEBROOT"

# Only the Ubuntu welcome site goes; anything you added by hand stays.
as_root rm -f /etc/nginx/sites-enabled/default
install_file "$DOTFILES_DIR/nginx/cloud.conf" /etc/nginx/conf.d/cloud.conf
for snippet in "$DOTFILES_DIR"/nginx/snippets/*.conf; do
    install_file "$snippet" "/etc/nginx/snippets/$(basename "$snippet")"
done
install_file "$DOTFILES_DIR/nginx/default.conf" /etc/nginx/sites-available/00-default.conf
as_root ln -sfn /etc/nginx/sites-available/00-default.conf /etc/nginx/sites-enabled/00-default.conf

if ! as_root nginx -t 2>/dev/null; then
    as_root nginx -t || true
    as_root rm -f /etc/nginx/conf.d/cloud.conf
    warn "nginx rejected conf.d/cloud.conf (likely a directive Ubuntu's nginx.conf now sets) — removed it"
fi
as_root systemctl enable --now nginx >/dev/null 2>&1
nginx_reload
ok "$(nginx -v 2>&1)"

# Renewals run from certbot.timer; reload nginx so new certs are picked up.
install_file "$DOTFILES_DIR/system/certbot-reload-nginx.sh" /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh 0755
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
            install_file "$DOTFILES_DIR/system/php.ini" "/etc/php/$php_ver/$sapi/conf.d/90-cloud.ini"
    done
    as_root systemctl enable --now "php$php_ver-fpm" >/dev/null 2>&1
    as_root systemctl restart "php$php_ver-fpm"
    ok "PHP $php_ver · fpm socket $(php_fpm_socket)"

    if ! have composer; then
        tmp="$(mktemp -d)"
        expected="$(curl -fsSL https://composer.github.io/installer.sig)"
        curl -fsSL https://getcomposer.org/installer -o "$tmp/composer-setup.php"
        actual="$(php -r "echo hash_file('sha384', '$tmp/composer-setup.php');")"
        [[ $expected == "$actual" ]] || die "composer installer checksum mismatch"
        as_root php "$tmp/composer-setup.php" --quiet --install-dir=/usr/local/bin --filename=composer
        rm -rf "$tmp"
    fi
    ok "$(composer --version 2>/dev/null | head -1)"
fi

as_root install -d -m 2775 -o "$TARGET_USER" -g www-data "$WWW_DIR"
ok "Static/PHP sites live under $WWW_DIR/<domain> — create them with: site add"
