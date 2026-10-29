#!/usr/bin/env bash
# install.sh — set up this machine from the stages in ./stages.
#
#   ./install.sh                 at a terminal: settings wizard (first run), then a menu
#   ./install.sh -a, --all       every stage that applies to this OS/profile, in order
#   ./install.sh --changed       only stages that never ran, failed, or whose files/config changed
#   ./install.sh --renew         everything again + upgrade all tools/agents + re-render sites
#   ./install.sh docker web      just these stages (name or number)
#   ./install.sh -s, --status    what ran when, what changed, what's skipped here and why
#   ./install.sh -c, --configure edit config.env through prompts
#   ./install.sh -l, --list      stages with their OS/profile rules
#   -y, --yes                   yes to every question (non-interactive)
#   ./setup-server.sh / ./setup-desktop.sh select the corresponding profile
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
SELF="$DOTFILES_DIR/install.sh" # absolute: `bash install.sh` re-execs too
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/ui.sh"
source "$DOTFILES_DIR/lib/configure.sh"
source "$DOTFILES_DIR/lib/stages.sh"

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
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
# Modes don't combine (`docker --changed` would silently mean "every changed stage").
set_mode() {
    [[ -z $MODE || $MODE == "$1" ]] || die "pick one: stage names, --all, --changed or --renew"
    MODE=$1
}
while (($#)); do
    case $1 in
    -h | --help) usage ;;
    -l | --list) list_stages && exit 0 ;;
    -s | --status) load_config && stages_status && exit 0 ;;
    -a | --all) set_mode all ;;
    --changed) set_mode changed ;;
    --renew) set_mode renew ;;
    -c | --configure) CONFIGURE=1 ;;
    -y | --yes) export ASSUME_YES=1 ;;
    -*) usage 2 ;;
    *)
        set_mode pick
        selected+=("$1")
        ;;
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
    if ((CONFIGURE)) || ui_confirm "Set up machine configuration (identity, features, optional domains) now?" yes; then
        configure_wizard || die "settings wizard cancelled"
    fi
    if ((CONFIGURE)) && [[ -z $MODE ]]; then
        { ui_interactive && ui_confirm "Run the installer now?" yes; } || exit 0
    fi
fi
[[ -f ${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env} ]] ||
    die "Missing config.env — run: ./install.sh --configure (or cp config.env.example config.env)"
load_config
id "$TARGET_USER" >/dev/null 2>&1 || die "User '$TARGET_USER' does not exist — run bootstrap.sh first"
# Save caller overrides (config_snapshot_env) once load_config has accepted
# them, so --changed hashes the settings actually used and root reads them
# after sudo. Secrets travel this way too, never on a sudo/env command line.
CONFIG_FILE="${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env}"
for var in "${!CONFIG_ENV_OVERRIDES[@]}"; do
    config_set_owned "$CONFIG_FILE" "$var" "${!var}"
done

# The profile is always written down once decided: auto-detection can change
# under it (an `ssh -X` session, a package that installs a desktop session).
if [[ -n ${PROFILE_OVERRIDE:-} && $PROFILE_OVERRIDE != "$PROFILE" ]] && [[ -n $(config_value PROFILE) ]] && setup_done; then
    # Never auto-answered by -y: switching skips (or adds) whole server stages.
    has_tty || die "this machine is set up as '$PROFILE' — switching to '$PROFILE_OVERRIDE' needs you at a terminal"
    ASSUME_YES=0 ui_confirm "This machine is set up as '$PROFILE'. Switch it to '$PROFILE_OVERRIDE'? (stages for '$PROFILE' are not undone)" ||
        die "kept profile '$PROFILE'"
fi
if [[ -n ${PROFILE_OVERRIDE:-} ]]; then PROFILE=$PROFILE_OVERRIDE; fi
if [[ $(config_value PROFILE) != "$PROFILE" ]]; then
    config_set "$CONFIG_FILE" PROFILE "$PROFILE"
    step "profile: $PROFILE (saved in config.env)"
fi
export PROFILE

# Everything (shell hooks, PATH, the cleanup timer, the sandbox policy) expects
# the repo at ~/.dotfiles. Elsewhere, link it there rather than half-work.
if [[ $DOTFILES_DIR != "$TARGET_HOME/.dotfiles" ]]; then
    if [[ ! -e $TARGET_HOME/.dotfiles && ! -L $TARGET_HOME/.dotfiles ]]; then
        run_as_user ln -s "$DOTFILES_DIR" "$TARGET_HOME/.dotfiles"
        step "linked ~/.dotfiles → $DOTFILES_DIR"
    elif [[ $(readlink -f "$TARGET_HOME/.dotfiles") != "$DOTFILES_DIR" ]]; then
        die "~/.dotfiles is another checkout — run install.sh from there, or move it aside"
    fi
fi

# Server profile somewhere only part of it is supported: say so up front.
if [[ $PROFILE == server && $OS_FAMILY != debian ]]; then
    warn "server profile on $OS_PRETTY: SSH hardening/firewall run only on Debian/Ubuntu and Arch; nginx, Let's Encrypt and Hermes only on Debian/Ubuntu (docs/08-multi-os.md)"
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
    configure) configure_wizard && exec "$SELF" ;;
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
    # Explicit config overrides were saved before sudo. Do not pass derived
    # defaults as if they were explicit overrides and freeze auto settings.
    passthrough=()
    # (SSH_CONNECTION: stage 20 never lets fail2ban ban the address you're installing from.)
    # DOTFILES_CONFIG only from inside the repo: root sources that file.
    if [[ -n ${DOTFILES_CONFIG:-} && $(readlink -f "$DOTFILES_CONFIG") != "$DOTFILES_DIR"/* ]]; then
        die "DOTFILES_CONFIG must point inside $DOTFILES_DIR (root sources it)"
    fi
    for var in HERMES_RESET_PASSWORD ASSUME_YES DOTFILES_CONFIG PROFILE_OVERRIDE SSH_CONNECTION CLOUD_UI; do
        [[ -v $var ]] && passthrough+=("$var=${!var}")
    done
    exec sudo -- env "${passthrough[@]}" "$SELF" "${orig_args[@]}"
fi
[[ $OS_KIND == macos ]] && is_root && die "on macOS run install.sh as yourself, not with sudo (Homebrew refuses root)"

[[ $MODE == renew ]] && export RENEW=1
export INSTALL_MODE=$MODE

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
incomplete=()
skipped_server=()
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
        [[ $(stage_profile "$stage") == server && $PROFILE == server ]] && skipped_server+=("$name")
        skipped=$((skipped + 1))
        continue
    fi
    user="$(stage_user "$stage")"
    current=$name
    log "${C_BOLD}$name${C_RESET} ($user) — $(stage_desc "$stage")"
    # A stage can finish but report work left undone (stage_incomplete):
    # then it isn't recorded as applied, and --changed retries it.
    # Owned by whoever runs the stage: root may not write a user's file in
    # /tmp (fs.protected_regular), and root shouldn't write into user paths.
    if [[ $user == user ]]; then
        STAGE_INCOMPLETE_FILE="$(run_as_user mktemp)"
    else
        STAGE_INCOMPLETE_FILE="$(mktemp)"
    fi
    export STAGE_INCOMPLETE_FILE
    # "$BASH": the bash ≥ 4 we run in, not whichever bash comes first on PATH.
    case $user in
    root) "$BASH" "$stage" ;;
    user) run_as_user env STAGE_INCOMPLETE_FILE="$STAGE_INCOMPLETE_FILE" "$BASH" "$stage" ;;
    *) die "$name: missing '# stage-user: root|user' header" ;;
    esac
    if [[ -s $STAGE_INCOMPLETE_FILE ]]; then
        incomplete+=("$name")
        warn "$name finished with work left — not marked applied; --changed will retry it"
    else
        stage_mark "$stage"
    fi
    rm -f "$STAGE_INCOMPLETE_FILE"
    ran=$((ran + 1))
done
current=''

if ((ran == 0)); then
    case $MODE in
    changed) ok "nothing changed since the last run" && exit 0 ;;
    pick) die "No stage matched: ${selected[*]} (see --list)" ;;
    esac
fi
ok "Done: $ran stage(s) in $((SECONDS - started))s$( ((skipped)) && echo " · $skipped not for this machine")"
((${#incomplete[@]})) && warn "incomplete (re-run with --changed once fixed): ${incomplete[*]}"
((${#skipped_server[@]})) && warn "server stages NOT applied on this OS: ${skipped_server[*]} — this box lacks that protection"

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
    if [[ $PROFILE == server ]]; then
        cat >&2 <<EOF

Next steps (docs/01-first-setup.md, step 5 onwards):
  1. Log out and back in (group membership + login shell take effect)
  2. Run:                 vps
  3. Sign in to agents:   agents login
  4. Health check:        doctor
EOF
        if is_true "$HERMES"; then
            printf '  5. Hermes:              hermes setup  then  hermes-up\n' >&2
        fi
    else
        cat >&2 <<EOF

Next steps (docs/08-multi-os.md):
  1. Open a new terminal (shell and PATH changes take effect)
  2. Sign in to agents:   agents login
  3. Health check:        doctor
  4. Changed settings?    ./setup-desktop.sh --changed
EOF
    fi
fi
