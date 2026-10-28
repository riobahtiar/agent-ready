# shellcheck shell=bash
# Stage metadata and run state for install.sh. Source after lib/common.sh.
#
# Every stages/NN-name.sh starts with:
#   # stage-user: root|user        root stages run as root (as the user on macOS)
#   # stage-os: <spec>             see os_matches in lib/os.sh (any, linux+systemd, debian+nowsl, …)
#   # stage-profile: all|server|desktop
#   # stage-desc: one line for menus
#   # stage-inputs: dir …          optional: extra repo paths whose changes mean "re-apply me"
#
# After a stage succeeds, install.sh records a digest of its inputs (the stage
# file, every $DOTFILES_DIR/… path it names, lib/, config.env and its
# stage-inputs) in .state/stages/<name>. A different digest = "changed".

STAGE_STATE_DIR="$DOTFILES_DIR/.state/stages"

stage_files() { printf '%s\n' "$DOTFILES_DIR"/stages/[0-9]*.sh; }
stage_name() { basename "$1" .sh; }
_stage_header() { sed -n "s/^# stage-$2: *//p" "$1" | head -1; }
stage_user() { _stage_header "$1" user; }
stage_desc() { _stage_header "$1" desc; }
stage_os() {
    local v
    v="$(_stage_header "$1" os)"
    printf '%s' "${v:-any}"
}
stage_profile() {
    local v
    v="$(_stage_header "$1" profile)"
    printf '%s' "${v:-all}"
}

# stage_skip_reason <file> — why this stage doesn't apply here (empty = it applies).
stage_skip_reason() {
    local f=$1 profile
    local spec
    spec="$(stage_os "$f")"
    if ! os_matches "$spec"; then
        local why=()
        [[ $spec == *systemd* && $HAS_SYSTEMD == 0 ]] && why+=("needs systemd")
        [[ $spec == *nowsl* && $IS_WSL == 1 ]] && why+=("not on WSL")
        [[ $spec != *"$OS_FAMILY"* && $spec != *"$OS_KIND"* && $spec != any* ]] && why+=("not for $OS_PRETTY")
        ((${#why[@]})) || why=("not for $OS_PRETTY")
        echo "skipped here: $(
            IFS=,
            echo "${why[*]}" | sed 's/,/ · /g'
        ) [$spec]"
        return
    fi
    profile="$(stage_profile "$f")"
    [[ $profile == all || $profile == "$PROFILE" ]] || echo "$profile profile only (this is $PROFILE)"
}
stage_applies() { [[ -z $(stage_skip_reason "$1") ]]; }

stage_hash() {
    local f=$1 p
    local -a inputs=("$f" "$DOTFILES_DIR"/lib/*.sh "${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env}")
    while read -r p; do
        [[ -n $p ]] || continue
        p="$DOTFILES_DIR/${p#\$DOTFILES_DIR/}"
        if [[ -d $p ]]; then
            while IFS= read -r -d '' x; do inputs+=("$x"); done < <(find "$p" -type f -print0 | sort -z)
        elif [[ -f $p ]]; then
            inputs+=("$p")
        fi
    done < <({
        grep -oE '\$DOTFILES_DIR/[A-Za-z0-9_./-]+' "$f"
        for p in $(_stage_header "$f" inputs); do echo "\$DOTFILES_DIR/$p"; done
    } | sort -u)
    os_sha256 "${inputs[@]}"
}

# stage_last <file> — "timestamp rev digest" of the last successful run, or nothing.
stage_last() { cat "$STAGE_STATE_DIR/$(stage_name "$1")" 2>/dev/null || true; }

stage_mark() {
    local f=$1 rev
    rev="$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo -)"
    mkdir -p "$STAGE_STATE_DIR"
    printf '%s %s %s\n' "$(date -u '+%Y-%m-%dT%H:%MZ')" "$rev" "$(stage_hash "$f")" >"$STAGE_STATE_DIR/$(stage_name "$f")"
}

stage_changed() {
    local last
    last="$(stage_last "$1")"
    [[ -z $last || ${last##* } != "$(stage_hash "$1")" ]]
}

# setup_done — some stage has completed on this machine before.
setup_done() { compgen -G "$STAGE_STATE_DIR/*" >/dev/null; }
setup_last_run() { cat "$STAGE_STATE_DIR"/* 2>/dev/null | sort | tail -1 | cut -d' ' -f1-2; }

stages_status() {
    local f name last reason state color
    printf '%-17s %-6s %-9s %-17s %s\n' STAGE AS STATE "LAST RUN" DESCRIPTION
    while read -r f; do
        name="$(stage_name "$f")" last="$(stage_last "$f")" reason="$(stage_skip_reason "$f")"
        if [[ -n $reason ]]; then
            state=skipped color=$C_DIM
        elif [[ -z $last ]]; then
            state=never color=$C_YELLOW
        elif stage_changed "$f"; then
            state=changed color=$C_YELLOW
        else
            state=applied color=$C_GREEN
        fi
        # Pad before colouring so the columns line up with or without a TTY.
        printf '%-17s %-6s %s%-9s%s %-17s %s\n' "$name" "$(stage_user "$f")" "$color" "$state" "$C_RESET" "${last%% *}" \
            "${reason:-$(stage_desc "$f")}"
    done < <(stage_files)
}
