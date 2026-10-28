#!/usr/bin/env bash
# stage-user: root
# stage-os: debian+systemd+nowsl
# stage-profile: server
# stage-desc: Hermes agent + web dashboard behind nginx/TLS at HERMES_DOMAIN, Telegram credentials
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/nginx.sh"
source "$DOTFILES_DIR/lib/agents.sh"
load_config

if ! is_true "$HERMES"; then
    step "HERMES=false — skipping"
    exit 0
fi
if [[ -z $HERMES_DOMAIN ]]; then
    warn "HERMES_DOMAIN is empty in config.env — skipping Hermes (set it, then: ./install.sh hermes)"
    exit 0
fi
if ! have nginx; then
    warn "nginx is missing — run ./install.sh web, then ./install.sh hermes"
    exit 0
fi

hermes_env="$TARGET_HOME/.hermes/.env"
port="$HERMES_DASHBOARD_PORT"
public_url="https://$HERMES_DOMAIN"

log "Hermes agent"
run_as_user bash -c "source '$DOTFILES_DIR/lib/common.sh'; source '$DOTFILES_DIR/lib/agents.sh'; agent_install hermes"
hermes_bin="$(run_as_user bash -lc 'command -v hermes' || true)"
[[ -x $hermes_bin ]] || hermes_bin="$TARGET_HOME/.local/bin/hermes"
[[ -x $hermes_bin ]] || die "hermes binary not found after install — check the installer output above"
ok "$hermes_bin ($(run_as_user "$hermes_bin" --version 2>/dev/null | head -1))"
if [[ -x $TARGET_HOME/.local/bin/herdr ]]; then
    run_as_user "$TARGET_HOME/.local/bin/herdr" integration install hermes >/dev/null 2>&1 &&
        step "herdr ↔ hermes" || warn "herdr integration install hermes failed"
fi

# Values in ~/.hermes/.env override config.yaml and are what the systemd unit
# loads. Written as root (secrets never hit a command line), then handed back.
set_env() {
    env_set "$hermes_env" "$1" "$2"
    chown "$TARGET_USER:" "$hermes_env"
}
get_env() { env_get "$hermes_env" "$1"; }
run_as_user install -d -m 700 "$TARGET_HOME/.hermes"

log "Telegram"
if [[ -n ${TELEGRAM_BOT_TOKEN:-} ]]; then
    set_env TELEGRAM_BOT_TOKEN "$TELEGRAM_BOT_TOKEN"
    if [[ -n ${TELEGRAM_ALLOWED_USERS:-} ]]; then
        set_env TELEGRAM_ALLOWED_USERS "$TELEGRAM_ALLOWED_USERS"
        ok "bot token + allowlist ($TELEGRAM_ALLOWED_USERS) written to ~/.hermes/.env"
    else
        warn "TELEGRAM_ALLOWED_USERS empty — strangers must be approved with 'hermes pairing approve telegram <code>'"
    fi
elif [[ -z $(get_env TELEGRAM_BOT_TOKEN) ]]; then
    warn "TELEGRAM_BOT_TOKEN not set — configure later with 'hermes gateway setup' (choose Telegram)"
fi

log "Dashboard auth"
# A non-loopback public_url makes Hermes require an auth provider; we use its
# built-in username/password provider (scrypt hash, signed sessions).
set_env HERMES_DASHBOARD_BASIC_AUTH_USERNAME "$HERMES_DASHBOARD_USER"
[[ -n $(get_env HERMES_DASHBOARD_BASIC_AUTH_SECRET) ]] ||
    set_env HERMES_DASHBOARD_BASIC_AUTH_SECRET "$(openssl rand -hex 32)"

if [[ -z $(get_env HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH) || ${HERMES_RESET_PASSWORD:-0} == 1 ]]; then
    password="${HERMES_DASHBOARD_PASSWORD:-}"
    if [[ -z $password ]]; then
        has_tty || die "No TTY to prompt for the dashboard password — set HERMES_DASHBOARD_PASSWORD in config.env"
        read -r -s -p "Hermes dashboard password for '$HERMES_DASHBOARD_USER' (min 12 chars): " password </dev/tty && echo >&2
        read -r -s -p "Repeat: " again </dev/tty && echo >&2
        [[ $password == "$again" ]] || die "passwords differ"
    fi
    ((${#password} >= 12)) || die "dashboard password must be at least 12 characters"
    hash="$(printf '%s' "$password" | run_as_user "$DOTFILES_DIR/scripts/hermes-hash-password.sh")" ||
        die "could not hash the password with Hermes' own helper — see scripts/hermes-hash-password.sh"
    set_env HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH "$hash"
    unset password again hash
    ok "password hash stored (plaintext never written)"
    [[ -n ${HERMES_DASHBOARD_PASSWORD:-} ]] && warn "remove HERMES_DASHBOARD_PASSWORD from config.env now that it's hashed"
else
    step "password hash already set (HERMES_RESET_PASSWORD=1 ./install.sh hermes to change it)"
fi

log "Dashboard behind the proxy"
run_as_user "$hermes_bin" config set dashboard.public_url "$public_url" >/dev/null ||
    warn "'hermes config set dashboard.public_url' failed — set it in ~/.hermes/config.yaml"

render "$DOTFILES_DIR/systemd/hermes-dashboard.service" \
    USER="$TARGET_USER" HOME="$TARGET_HOME" HERMES_BIN="$hermes_bin" PORT="$port" |
    as_root tee /etc/systemd/system/hermes-dashboard.service >/dev/null
as_root systemctl daemon-reload
as_root systemctl enable hermes-dashboard >/dev/null 2>&1
as_root systemctl restart hermes-dashboard

for _ in {1..20}; do
    curl -fsS "http://127.0.0.1:$port/api/status" >/dev/null 2>&1 && break
    sleep 1
done
if status="$(curl -fsS "http://127.0.0.1:$port/api/status" 2>/dev/null)"; then
    ok "dashboard up on 127.0.0.1:$port (auth_required=$(jq -r '.auth_required | tostring' <<<"$status"))"
else
    warn "dashboard not answering yet — journalctl -u hermes-dashboard -n 50"
fi

log "nginx + TLS for $HERMES_DOMAIN"
allow=''
if [[ -n $HERMES_ALLOW_IPS ]]; then
    for ip in $HERMES_ALLOW_IPS; do allow+="    allow $ip;"$'\n'; done
    allow+="    deny all;"$'\n'
fi
# Hermes is optional: a missing certificate (DNS not propagated yet) must not
# stop the remaining stages. The dashboard still runs on 127.0.0.1.
if cert_issue "$HERMES_DOMAIN"; then
    site_write "$HERMES_DOMAIN" hermes PORT="$port" ALLOW="$allow" ||
        warn "nginx rejected the Hermes vhost — previous config kept"
else
    warn "no public dashboard yet — once DNS for $HERMES_DOMAIN points here: ./install.sh hermes"
fi

cat >&2 <<EOF

${C_BOLD}Hermes is installed.${C_RESET} Finish as $TARGET_USER (interactive, needs a model sign-in):
  1. hermes setup              # pick a model/provider (e.g. --portal for Nous Portal)
  2. hermes-up                 # installs + starts the Telegram gateway as a boot service
  3. open $public_url  → log in as '$HERMES_DASHBOARD_USER'
Strongly recommended: put Cloudflare Access (or Tailscale) in front of $HERMES_DOMAIN —
the dashboard includes a web terminal on this machine.
EOF
