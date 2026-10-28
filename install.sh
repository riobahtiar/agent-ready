#!/usr/bin/env bash
# install.sh — set up this machine from the stages in ./stages.
#
#   ./install.sh                 at a terminal: settings wizard (first run), then a menu
#   ./install.sh --all           every stage that applies to this OS/profile, in order
#   ./install.sh --changed       only stages that never ran, failed, or whose files/config changed
#   ./install.sh --renew         everything again + upgrade all tools/agents + re-render sites
#   ./install.sh docker web      just these stages (name or number)
#   ./install.sh --status        what ran when, what changed, what's skipped here and why
#   ./install.sh --configure     edit config.env through prompts
#   ./install.sh --list          stages with their OS/profile rules
#   -y                           yes to every question (non-interactive)
#
# Stages are idempotent: re-running one is always safe. Once setup has run,
# install.sh won't silently re-run everything without a TTY: pass --all,
# --changed or --renew. Runs on Ubuntu/Debian (server or desktop), Arch
# and Omarchy, Fedora, WSL and macOS (Homebrew + mise) — see docs/08-multi-os.md.

# ─── bash ≥ 4 (macOS ships 3.2) — before anything that needs it ───
if [ -z "${BASH_VERSINFO:-}" ] || [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    for b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [ -x "$b" ] && exec "$b" "$0" "$@"
    done
    # Never install anything unasked (not even for --status): ask on a TTY.
    if command -v brew >/dev/null 2>&1; then
        answer=n
        if [ -t 0 ] && [ -t 1 ]; then
            printf 'install.sh needs bash 4+ (macOS ships 3.2). Install it with Homebrew now? [Y/n] ' >&2
            read -r answer || answer=n
            [ -z "$answer" ] && answer=y
        fi
        case $answer in
        [Yy]*) brew install bash && exec "$(brew --prefix)/bin/bash" "$0" "$@" ;;
        esac
        echo "install.sh needs bash 4+: brew install bash, then re-run." >&2
        exit 1
    fi
    echo "install.sh needs bash 4+. On macOS: install Homebrew (https://brew.sh), then re-run." >&2
    exit 1
fi
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export DOTFILES_DIR
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/ui.sh"
source "$DOTFILES_DIR/lib/configure.sh"
source "$DOTFILES_DIR/lib/stages.sh"

usage() {
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

list_stages() {
    local f
    printf '  %-16s %-5s %-34s %-12s %s\n' STAGE AS OS PROFILE DESCRIPTION
    while read -r f; do
        printf '  %-16s %-5s %-34s %-12s %s\n' "$(stage_name "$f")" "$(stage_user "$f")" "$(stage_os "$f")" \
            "$(stage_profile "$f")" "$(stage_desc "$f")"
    done < <(stage_files)
}

orig_args=("$@")
selected=()
MODE='' CONFIGURE=0 # MODE: all | changed | renew | pick
while (($#)); do
    case $1 in
    -h | --help) usage ;;
    -l | --list) list_stages && exit 0 ;;
    -s | --status) load_config && stages_status && exit 0 ;;
    -a | --all) MODE=all ;;
    --changed) MODE=changed ;;
    --renew) MODE=renew ;;
    -c | --configure) CONFIGURE=1 ;;
    -y | --yes) export ASSUME_YES=1 ;;
    -*) usage 2 ;;
    *) selected+=("$1") MODE=pick ;;
    esac
    shift
done
# The wizard runs once, here; don't repeat it after the sudo re-exec.
for i in "${!orig_args[@]}"; do
    [[ ${orig_args[$i]} == -c || ${orig_args[$i]} == --configure ]] && unset 'orig_args[i]'
done
orig_args=("${orig_args[@]}")

# ─── Questions: before the sudo re-exec, as the user (whose mise has gum) ───
asking() { [[ -z $MODE && ${ASSUME_YES:-0} != 1 ]] && ui_interactive; }

if ((CONFIGURE)) || { asking && config_looks_unset; }; then
    if ((CONFIGURE)) || ui_confirm "config.env still has placeholders — fill it in now?" yes; then
        configure_wizard || die "settings wizard cancelled"
    fi
    if ((CONFIGURE)) && [[ -z $MODE ]]; then
        { ui_interactive && ui_confirm "Run the installer now?" yes; } || exit 0
    fi
fi
[[ -f ${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env} ]] ||
    die "Missing config.env — run: ./install.sh --configure (or cp config.env.example config.env)"
load_config

# setup-server.sh / setup-desktop.sh pin the profile and record it in config.env.
if [[ -n ${PROFILE_OVERRIDE:-} && $PROFILE_OVERRIDE != "$PROFILE" ]]; then
    CONFIG_FILE="${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env}"
    if [[ -n $(config_value PROFILE) ]] && setup_done; then
        ui_confirm "This machine is set up as '$PROFILE'. Switch it to '$PROFILE_OVERRIDE'? (stages for '$PROFILE' are not undone)" ||
            die "kept profile '$PROFILE'"
    fi
    config_set "$CONFIG_FILE" PROFILE "$PROFILE_OVERRIDE"
    is_root && chown "$(os_owner "$DOTFILES_DIR")" "$CONFIG_FILE"
    PROFILE=$PROFILE_OVERRIDE
    export PROFILE
    step "profile: $PROFILE (saved in config.env)"
fi

count_changed() {
    local f n=0
    while read -r f; do
        if stage_applies "$f" && stage_changed "$f"; then n=$((n + 1)); fi
    done < <(stage_files)
    echo "$n"
}

if asking; then
    ui_title "$OS_PRETTY$([[ $IS_WSL == 1 ]] && echo ' · WSL') · profile: $PROFILE · user: $TARGET_USER"
    if setup_done; then
        changed="$(count_changed)"
        step "already set up — last run $(setup_last_run) · $changed stage(s) changed or never applied since"
        choice="$(ui_choose "This machine is already set up. What now?" \
            "changed|Re-apply the $changed changed stage(s) (recommended)" \
            "renew|Renew everything: all stages + upgrade every tool and agent + re-render sites" \
            "all|Re-apply every stage (no upgrades)" \
            "pick|Choose stages…" \
            "status|Show stage status" \
            "configure|Edit settings first" \
            "quit|Quit")" || exit 0
    else
        choice="$(ui_choose "First-time setup" \
            "all|Everything for this machine in order (recommended)" \
            "pick|Choose stages…" \
            "status|Show what would run here" \
            "quit|Quit")" || exit 0
    fi
    case $choice in
    all | changed | renew) MODE=$choice ;;
    pick)
        items=()
        while read -r f; do
            stage_applies "$f" || continue
            items+=("$(stage_name "$f")|$(stage_name "$f") — $(stage_desc "$f" | tr ',' ' ')")
        done < <(stage_files)
        picked="$(ui_multi "Which stages?" "" "${items[@]}")" || exit 0
        [[ -n $picked ]] || exit 0
        mapfile -t selected <<<"$picked"
        MODE=pick
        ;;
    status) stages_status && exit 0 ;;
    configure) configure_wizard && exec "$0" ;;
    *) exit 0 ;;
    esac
    if [[ $MODE == renew ]]; then
        ui_confirm "Renew re-applies every stage and upgrades everything (20+ min; agents keep running). Go?" yes || exit 0
    fi
    orig_args=(--"$MODE")
    [[ $MODE == pick ]] && orig_args=("${selected[@]}")
fi

# ─── Guard: never re-run a finished setup by accident ───
if [[ -z $MODE ]]; then
    if setup_done; then
        die "setup already ran here (last: $(setup_last_run)). Choose: --changed · --all · --renew · <stage>   (--status shows what changed)"
    fi
    MODE=all
    orig_args+=(--all)
fi

if [[ $OS_KIND == linux ]] && ! is_root; then
    log "Re-running with sudo…"
    # sudo resets the environment; carry over the knobs the docs mention.
    passthrough=()
    for var in HERMES_RESET_PASSWORD ASSUME_YES DOTFILES_CONFIG PROFILE_OVERRIDE; do
        [[ -n ${!var:-} ]] && passthrough+=("$var=${!var}")
    done
    exec sudo -- env "${passthrough[@]}" "$0" "${orig_args[@]}"
fi
[[ $OS_KIND == macos ]] && is_root && die "on macOS run install.sh as yourself, not with sudo (Homebrew refuses root)"
id "$TARGET_USER" >/dev/null 2>&1 || die "User '$TARGET_USER' does not exist — run bootstrap.sh first"

[[ $MODE == renew ]] && export RENEW=1

wanted() {
    local f=$1 name pick
    name="$(stage_name "$f")"
    case $MODE in
    all | renew) return 0 ;;
    changed) stage_changed "$f" ;;
    pick)
        for pick in "${selected[@]}"; do
            [[ $name == "$pick" || $name == "$pick"-* || $name == *-"$pick" ]] && return 0
        done
        return 1
        ;;
    esac
}

if setup_done && [[ $MODE == all ]]; then
    log "Setup already ran (last: $(setup_last_run)) — re-applying; stages are idempotent"
fi
started=$SECONDS
ran=0 skipped=0
current=''
trap '[[ -n $current ]] && warn "stage $current failed — fix the cause, then: ./install.sh --changed (picks up from there)"' ERR
# Read the list first: a stage that reads stdin (fish -c, installers) must not
# swallow the remaining stage names.
mapfile -t all_stages < <(stage_files)
for stage in "${all_stages[@]}"; do
    name="$(stage_name "$stage")"
    wanted "$stage" || continue
    reason="$(stage_skip_reason "$stage")"
    if [[ -n $reason ]]; then
        [[ $MODE == pick ]] && warn "$name skipped: $reason"
        skipped=$((skipped + 1))
        continue
    fi
    user="$(stage_user "$stage")"
    current=$name
    log "${C_BOLD}$name${C_RESET} ($user) — $(stage_desc "$stage")"
    case $user in
    root) bash "$stage" ;;
    user) run_as_user bash "$stage" ;;
    *) die "$name: missing '# stage-user: root|user' header" ;;
    esac
    stage_mark "$stage"
    ran=$((ran + 1))
done
current=''
if is_root; then chown -R "$(os_owner "$DOTFILES_DIR")" "$DOTFILES_DIR/.state" 2>/dev/null || true; fi

if ((ran == 0)); then
    case $MODE in
    changed) ok "nothing changed since the last run" && exit 0 ;;
    pick) die "No stage matched: ${selected[*]} (see --list)" ;;
    esac
fi
ok "Done: $ran stage(s) in $((SECONDS - started))s$( ((skipped)) && echo " · $skipped not for this machine")"

if [[ $MODE == renew ]]; then
    log "Renew: remaining upgrades and site re-render"
    # Stages already upgraded mise tools and agents. What's left runs here
    # directly: we're root, and a user-side sudo couldn't prompt now.
    run_as_user "$DOTFILES_DIR/bin/update-all" -y extras || warn "update-all extras reported failures"
    if have composer; then
        if [[ $OS_KIND == macos ]]; then composer self-update --quiet; else COMPOSER_ALLOW_SUPERUSER=1 composer self-update --quiet; fi ||
            warn "composer self-update failed"
    fi
    if [[ $PROFILE == server ]] && have nginx; then
        "$DOTFILES_DIR/bin/site" renew || warn "site renew reported failures"
        if have certbot; then certbot renew --quiet || warn "certbot renew failed"; fi
    fi
fi

if [[ $MODE == all && ! -f $DOTFILES_DIR/.state/next-steps-shown ]]; then
    mkdir -p "$DOTFILES_DIR/.state"
    touch "$DOTFILES_DIR/.state/next-steps-shown"
    cat >&2 <<EOF

Next steps (docs/01-first-setup.md, step 5 onwards):
  1. Log out and back in (docker group + login shell take effect)
  2. Run:                 vps        (menu for everything below)
  3. Sign in to agents:   agents login
  4. Hermes:              hermes setup  then  hermes-up
  5. Health check:        doctor
EOF
fi
