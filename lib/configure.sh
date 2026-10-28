# shellcheck shell=bash
# config.env wizard — asks for the settings that differ per person/machine and
# writes them into config.env in place (comments and other keys stay as they
# are). Used by `install.sh --configure` and `vps` → Settings. Source after
# lib/common.sh and lib/ui.sh.

# config_set <file> <KEY> <value> — replace KEY's value, keep its trailing comment.
config_set() {
    local file=$1 key=$2 value=$3 quoted tmp line done=0
    quoted="'${value//\'/\'\\\'\'}'"
    safe_target "$file"
    tmp="$(mktemp "$(dirname "$file")/.config_set.XXXXXX")"
    while IFS= read -r line || [[ -n $line ]]; do
        if ((! done)) && [[ $line == "$key="* ]]; then
            local comment=''
            [[ $line =~ [[:space:]]+(#.*)$ ]] && comment="    ${BASH_REMATCH[1]}"
            printf '%s=%s%s\n' "$key" "$quoted" "$comment"
            done=1
        else
            printf '%s\n' "$line"
        fi
    done <"$file" >"$tmp"
    ((done)) || printf '%s=%s\n' "$key" "$quoted" >>"$tmp"
    # Keep the file's owner when root edits the user's config.env.
    if is_root && [[ -f $file ]]; then chown -h "$(os_owner "$file")" "$tmp"; fi
    atomic_replace "$file" "$tmp"
}

# config_value <KEY> — current value from config.env (sourced in a subshell).
config_value() {
    (
        set +u
        # shellcheck disable=SC1090
        source "$CONFIG_FILE" >/dev/null 2>&1
        printf '%s' "${!1:-}"
    )
}

# _ask <KEY> <header> [fallback] [placeholder] — prompt with the current value.
_ask() {
    local key=$1 header=$2 current
    current="$(config_value "$key")"
    case $current in "Your Name" | you@example.com) current='' ;; esac
    ui_input "$header" "${current:-${3:-}}" "${4:-}"
}

# _ask_secret <KEY> <header> — keep the stored secret unless a new one is typed.
_ask_secret() {
    local key=$1 header=$2 current value
    current="$(config_value "$key")"
    [[ -n $current ]] && header="$header (set — Enter keeps it)"
    value="$(ui_password "$header")" || return 1
    printf '%s' "${value:-$current}"
}

configure_wizard() {
    CONFIG_FILE="${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env}"
    if [[ ! -f $CONFIG_FILE ]]; then
        cp "$DOTFILES_DIR/config.env.example" "$CONFIG_FILE"
    fi
    chmod 600 "$CONFIG_FILE"

    local v toggles picked item
    ui_title "Machine settings → ${CONFIG_FILE/#$HOME/\~}   (Enter keeps the shown value)"

    v="$(_ask TARGET_USER "User that owns projects and agents" "$(id -un)")" || return 1
    config_set "$CONFIG_FILE" TARGET_USER "$v"
    local profile_now
    profile_now="$(config_value PROFILE)"
    if [[ -n ${PROFILE_OVERRIDE:-} ]]; then
        v=$PROFILE_OVERRIDE # setup-server.sh / setup-desktop.sh decided
    else
        v="$(ui_choose "Profile for this machine ($OS_PRETTY$([[ $IS_WSL == 1 ]] && echo ' · WSL'); suggested: $(os_default_profile))" \
            "${profile_now:-$(os_default_profile)}|Keep: ${profile_now:-$(os_default_profile)}" \
            "server|server — VPS: hardening · nginx/TLS · Hermes dashboard · swap tuning" \
            "desktop|desktop — laptop/desktop/WSL: packages · shell · tools · agents · tunnels (no nginx/firewall/tuning)")" || return 1
    fi
    config_set "$CONFIG_FILE" PROFILE "$v"
    local profile=$v
    v="$(_ask GIT_NAME "Git author name" "" "Rio Bahtiar")" || return 1
    config_set "$CONFIG_FILE" GIT_NAME "$v"
    v="$(_ask GIT_EMAIL "Git author email" "" "you@example.com")" || return 1
    config_set "$CONFIG_FILE" GIT_EMAIL "$v"
    v="$(_ask ACME_EMAIL "Let's Encrypt email (certificate expiry notices)" "$v")" || return 1
    config_set "$CONFIG_FILE" ACME_EMAIL "$v"
    v="$(_ask TIMEZONE "Timezone" "Asia/Jakarta")" || return 1
    config_set "$CONFIG_FILE" TIMEZONE "$v"
    v="$(_ask HOSTNAME_FQDN "Hostname (empty = keep the provider's)" "" "cloud.ciptalogi.com")" || return 1
    config_set "$CONFIG_FILE" HOSTNAME_FQDN "$v"
    v="$(_ask_secret GITHUB_TOKEN "GitHub token (optional · lifts the 60/h API limit for installs)")" || return 1
    config_set "$CONFIG_FILE" GITHUB_TOKEN "$v"

    local current_agents name
    local -a agent_items=()
    current_agents="$(config_value AGENTS)"
    declare -F agent_define >/dev/null || source "$DOTFILES_DIR/lib/agents.sh"
    for name in "${AGENT_NAMES[@]}"; do
        [[ $(agent_get "$name" managed) == stage:* ]] && continue # hermes: the HERMES feature below
        agent_items+=("$name|$(agent_get "$name" title)")
    done
    picked="$(ui_multi "Agent CLIs to install (modules in agents.d/)" "${current_agents:-claude codex opencode omp grok muse herdr}" \
        "${agent_items[@]}")" || return 1
    config_set "$CONFIG_FILE" AGENTS "$(tr '\n' ' ' <<<"$picked" | sed 's/ *$//')"

    local -a features=(
        "FULL_CONTROL|Full control inside: passwordless sudo · Claude + Codex in YOLO mode (outside stays locked)"
        "TAILSCALE|Tailscale: private network to your laptop/phone + private dev URLs"
        "TAILSCALE_SSH|Tailscale SSH (log in over the tailnet without keys)"
        "DOCKER|Docker Engine (Linux; off if you use Podman or Docker Desktop)"
        "AGENT_SANDBOX|Claude Code sandbox on by default (bubblewrap/Seatbelt)"
        "GVISOR|gVisor runtime for 'sandbox box' containers (Debian/Ubuntu)"
        "CLEANUP_TIMER|Weekly safe cleanup (Sunday 04:00)"
        "FLUTTER_LINUX_DESKTOP|Flutter Linux desktop build deps (GTK · clang)"
    )
    [[ $profile == server ]] && features=(
        "HERMES|Hermes agent + web dashboard + Telegram bot"
        "PHP|PHP-FPM 8.5 + composer"
        "ZRAM|Compressed RAM swap (recommended on 6 GB)"
        "SSH_DISABLE_ROOT|Block root SSH logins"
        "OPEN_MOSH|Open UDP 60000-61000 for mosh"
        "${features[@]}"
    )
    toggles=''
    for item in "${features[@]}"; do
        v=${item%%|*}
        is_true "$(config_value "$v")" && toggles+="$v "
    done
    [[ -z $(config_value AGENT_SANDBOX) ]] && toggles+="AGENT_SANDBOX "
    [[ -z $(config_value DOCKER) ]] && toggles+="DOCKER "
    [[ -z $(config_value CLEANUP_TIMER) && $profile == server ]] && toggles+="CLEANUP_TIMER "
    [[ -z $(config_value FULL_CONTROL) && $profile == server ]] && toggles+="FULL_CONTROL "
    picked="$(ui_multi "Features" "$toggles" "${features[@]}")" || return 1
    for item in "${features[@]}"; do
        v=${item%%|*}
        if grep -qx "$v" <<<"$picked"; then config_set "$CONFIG_FILE" "$v" true; else config_set "$CONFIG_FILE" "$v" false; fi
    done

    if grep -qx TAILSCALE <<<"$picked"; then
        v="$(_ask_secret TAILSCALE_AUTHKEY "Tailscale auth key (optional · empty = log in with a URL later)")" || return 1
        config_set "$CONFIG_FILE" TAILSCALE_AUTHKEY "$v"
    fi
    v="$(ui_choose "Default for 'tunnel <port>' (sharing a dev server)" \
        "auto|auto — first ready: Tailscale → Cloudflare quick → …" \
        "tailscale|tailscale — private to your tailnet" \
        "cloudflare|cloudflare — public random trycloudflare.com URL" \
        "zrok|zrok — public · open source" \
        "pinggy|pinggy — public over SSH · no install")" || return 1
    config_set "$CONFIG_FILE" TUNNEL_DEFAULT "$v"

    if [[ $profile == server ]] && grep -qx HERMES <<<"$picked"; then
        ui_title "Hermes"
        v="$(_ask HERMES_DOMAIN "Dashboard domain (A record → this VPS)" "h.ciptalogi.com")" || return 1
        config_set "$CONFIG_FILE" HERMES_DOMAIN "$v"
        v="$(_ask HERMES_DASHBOARD_USER "Dashboard login name" "$(config_value TARGET_USER)")" || return 1
        config_set "$CONFIG_FILE" HERMES_DASHBOARD_USER "$v"
        v="$(_ask HERMES_ALLOW_IPS "Only allow these IPs/CIDRs (space-separated · empty = anyone with the password)")" || return 1
        config_set "$CONFIG_FILE" HERMES_ALLOW_IPS "$v"
        v="$(_ask_secret TELEGRAM_BOT_TOKEN "Telegram bot token from @BotFather (empty = set up later)")" || return 1
        config_set "$CONFIG_FILE" TELEGRAM_BOT_TOKEN "$v"
        v="$(_ask TELEGRAM_ALLOWED_USERS "Your numeric Telegram id(s), comma-separated (@userinfobot)")" || return 1
        config_set "$CONFIG_FILE" TELEGRAM_ALLOWED_USERS "$v"
        step "the dashboard password is asked during the hermes stage (never stored in config.env)"
    fi
    # Written as root (install.sh run directly by root): hand it back to the repo owner.
    if is_root; then chown -h "$(os_owner "$DOTFILES_DIR")" "$CONFIG_FILE"; fi
    ok "saved ${CONFIG_FILE/#$HOME/\~} — re-run the stages that use what you changed"
}

# config_looks_unset — true while config.env is missing or still has placeholders.
config_looks_unset() {
    local file="${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env}"
    [[ ! -f $file ]] || grep -qE '^(GIT_EMAIL|ACME_EMAIL)="?you@example\.com' "$file"
}
