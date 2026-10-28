#!/usr/bin/env bash
# stage-user: root
# stage-os: debian+systemd+nowsl
# stage-profile: server
# stage-inputs: nginx/templates systemd scripts agents.d/hermes.sh
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
valid_domain() { [[ $1 =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; }
valid_cidr() { [[ $1 =~ ^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$ ]]; }
# Both end up in the nginx vhost: no value may smuggle in directives.
valid_domain "$HERMES_DOMAIN" || die "HERMES_DOMAIN is not a domain: '$HERMES_DOMAIN'"
for ip in ${HERMES_ALLOW_IPS:-}; do valid_cidr "$ip" || die "HERMES_ALLOW_IPS: '$ip' is not an IP or CIDR"; done

if ! have nginx; then
    warn "nginx is missing — run ./install.sh web, then ./install.sh hermes"
    exit 0
fi

hermes_env="$TARGET_HOME/.hermes/.env"
port="$HERMES_DASHBOARD_PORT"
public_url="https://$HERMES_DOMAIN"

log "Hermes agent"
run_as_user bash -c "source '$DOTFILES_DIR/lib/common.sh'; source '$DOTFILES_DIR/lib/agents.sh'; agent_install hermes" ||
    warn "the Hermes installer reported a failure"
hermes_bin="$(run_as_user bash -lc 'command -v hermes' || true)"
[[ -x $hermes_bin ]] || hermes_bin="$TARGET_HOME/.local/bin/hermes"
if [[ ! -x $hermes_bin ]]; then
    stage_incomplete "hermes binary not found after install — check the output above, then: ./install.sh hermes"
    exit 0
fi
ok "$hermes_bin ($(run_as_user "$hermes_bin" --version 2>/dev/null | head -1))"
if [[ -x $TARGET_HOME/.local/bin/herdr ]]; then
    run_as_user "$TARGET_HOME/.local/bin/herdr" integration install hermes >/dev/null 2>&1 &&
        step "herdr ↔ hermes" || warn "herdr integration install hermes failed"
fi

# Values in ~/.hermes/.env override config.yaml and are what the systemd unit
# loads. Read and written AS THE USER: the directory is the user's, and root
# writing there would follow a planted symlink (e.g. .env → /etc/shadow).
# Values travel on stdin, never on a command line.
set_env() {
    printf '%s' "$2" | run_as_user bash -c 'source "$DOTFILES_DIR/lib/common.sh"; env_set "$1" "$2" "$(cat)"' _ "$hermes_env" "$1"
}
get_env() { run_as_user bash -c 'source "$DOTFILES_DIR/lib/common.sh"; env_get "$1" "$2"' _ "$hermes_env" "$1"; }
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
        # Unattended run: the rest of the install goes on; Hermes waits for you.
        if ! has_tty; then
            stage_incomplete "no dashboard password yet — at a terminal run: ~/.dotfiles/install.sh hermes"
            exit 0
        fi
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
auth_required=unknown
if status="$(curl -fsS "http://127.0.0.1:$port/api/status" 2>/dev/null)"; then
    auth_required="$(jq -r '.auth_required | tostring' <<<"$status")"
    ok "dashboard up on 127.0.0.1:$port (auth_required=$auth_required)"
else
    warn "dashboard not answering yet — journalctl -u hermes-dashboard -n 50"
fi

# unpublish — when the dashboard may not be public, a vhost left from an earlier
# run must not keep serving it.
unpublish() {
    if as_root test -e "/etc/nginx/sites-enabled/$HERMES_DOMAIN.conf"; then
        as_root rm -f "/etc/nginx/sites-enabled/$HERMES_DOMAIN.conf"
        nginx_reload || true
        warn "took the existing public dashboard at $HERMES_DOMAIN offline"
    fi
}

log "nginx + TLS for $HERMES_DOMAIN"
allow=''
if is_true "${HERMES_CLOUDFLARE_ONLY:-false}"; then
    # Behind Cloudflare (Access): only Cloudflare may connect, or anyone who
    # knows the VPS IP walks around Access with `curl --resolve`.
    cf_ips="$(
        curl -fsS --max-time 15 https://www.cloudflare.com/ips-v4
        echo
        curl -fsS --max-time 15 https://www.cloudflare.com/ips-v6
    )" || cf_ips=''
    for ip in $cf_ips; do valid_cidr "$ip" && allow+="    allow $ip;"$'\n'; done
    if [[ -z $allow ]]; then
        unpublish
        stage_incomplete "couldn't fetch Cloudflare's IP ranges — not publishing the dashboard (fail closed)"
        exit 0
    fi
fi
for ip in ${HERMES_ALLOW_IPS:-}; do allow+="    allow $ip;"$'\n'; done
[[ -n $allow ]] && allow+="    deny all;"$'\n'

# Never put a dashboard on the internet unless Hermes itself demands a login:
# it's a web terminal on this machine.
if [[ $auth_required != true ]]; then
    unpublish
    stage_incomplete "dashboard auth_required=$auth_required — NOT publishing $HERMES_DOMAIN (fix auth, then: ./install.sh hermes)"
elif cert_issue "$HERMES_DOMAIN"; then
    # Hermes is optional: a missing certificate (DNS not propagated yet) must
    # not stop the remaining stages. The dashboard still runs on 127.0.0.1.
    site_write "$HERMES_DOMAIN" hermes PORT="$port" ALLOW="$allow" ||
        stage_incomplete "nginx rejected the Hermes vhost — previous config kept"
else
    stage_incomplete "no public dashboard yet — once DNS for $HERMES_DOMAIN points here: ./install.sh hermes"
fi

cat >&2 <<EOF

${C_BOLD}Hermes is installed.${C_RESET} Finish as $TARGET_USER (interactive, needs a model sign-in):
  1. hermes setup              # pick a model/provider (e.g. --portal for Nous Portal)
  2. hermes-up                 # installs + starts the Telegram gateway as a boot service
  3. open $public_url  → log in as '$HERMES_DASHBOARD_USER'
Strongly recommended: put Cloudflare Access (or Tailscale) in front of $HERMES_DOMAIN —
the dashboard includes a web terminal on this machine.
EOF
