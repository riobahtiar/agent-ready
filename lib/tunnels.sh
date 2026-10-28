# shellcheck shell=bash
# Dev-tunnel registry for `tunnel`. Each provider is one module,
# tunnels.d/<id>.sh, that calls tunnel_define and implements:
#   <id>_ready        exit 0 when usable; otherwise print what's missing
#   <id>_start <port> [name]   start; print the URL (or instructions) on stdout
#   <id>_stop <port>  optional; default: kill the background process
# Background tunnels run through tunnel_bg, which keeps a pid, log and URL in
# ~/.local/state/dotfiles/tunnels/. See docs/07-networking.md.

[[ -n ${__CLOUD_TUNNELS_LOADED:-} ]] && return 0
__CLOUD_TUNNELS_LOADED=1

TUNNEL_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/tunnels"
TUNNEL_IDS=()
declare -gA TUNNEL_META=()

# tunnel_define <id> title=… reach=private|public|permanent rank=<n> setup=<hint>
tunnel_define() {
    local id=$1 kv
    shift
    TUNNEL_IDS+=("$id")
    TUNNEL_META["$id.rank"]=50
    for kv; do TUNNEL_META["$id.${kv%%=*}"]=${kv#*=}; done
}
tunnel_get() { printf '%s' "${TUNNEL_META["$1.$2"]:-}"; }
tunnel_known() { [[ -n ${TUNNEL_META["$1.title"]:-} ]]; }

for __f in "$DOTFILES_DIR"/tunnels.d/*.sh; do
    [[ $(basename "$__f") == _* ]] && continue
    # shellcheck disable=SC1090
    source "$__f"
done
unset __f

# Registry sorted by rank (lower = preferred for "auto").
mapfile -t TUNNEL_IDS < <(for id in "${TUNNEL_IDS[@]}"; do echo "$(tunnel_get "$id" rank) $id"; done | sort -n | cut -d' ' -f2)

tunnel_ready() { "${1}_ready" >/dev/null 2>&1; }

# tunnel_auto — first ready provider that gives a URL without extra prompts.
tunnel_auto() {
    local id
    for id in "${TUNNEL_IDS[@]}"; do
        [[ $(tunnel_get "$id" auto) == no ]] && continue
        tunnel_ready "$id" && echo "$id" && return 0
    done
    return 1
}

_tunnel_file() { printf '%s/%s-%s.%s' "$TUNNEL_STATE" "$1" "$2" "$3"; }

# tunnel_bg <id> <port> <url-regex> <cmd…> — run detached, wait for the URL in its log.
tunnel_bg() {
    local id=$1 port=$2 regex=$3
    shift 3
    mkdir -p "$TUNNEL_STATE"
    local log pidf urlf
    log="$(_tunnel_file "$id" "$port" log)" pidf="$(_tunnel_file "$id" "$port" pid)" urlf="$(_tunnel_file "$id" "$port" url)"
    if [[ -f $pidf ]] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
        cat "$urlf" 2>/dev/null
        return 0
    fi
    : >"$log"
    nohup "$@" >"$log" 2>&1 </dev/null &
    echo $! >"$pidf"
    local i url=''
    for ((i = 0; i < 60; i++)); do
        url="$(grep -oE "$regex" "$log" | head -1 || true)"
        [[ -n $url ]] && break
        kill -0 "$(cat "$pidf")" 2>/dev/null || break
        sleep 0.5
    done
    if [[ -z $url ]]; then
        warn "no URL after 30s — last log lines:"
        tail -5 "$log" | sed 's/^/      /' >&2
        tunnel_kill "$id" "$port"
        return 1
    fi
    echo "$url" >"$urlf"
    echo "$url"
}

tunnel_kill() {
    local pidf
    pidf="$(_tunnel_file "$1" "$2" pid)"
    [[ -f $pidf ]] && kill "$(cat "$pidf")" 2>/dev/null || true
    rm -f "$pidf" "$(_tunnel_file "$1" "$2" url)"
}

# tunnel_record <id> <port> <url> — remember a tunnel another daemon owns (tailscale).
tunnel_record() {
    mkdir -p "$TUNNEL_STATE"
    echo "$3" >"$(_tunnel_file "$1" "$2" url)"
}

tunnel_stop() {
    local id=$1 port=$2
    if declare -F "${id}_stop" >/dev/null; then "${id}_stop" "$port" || true; fi
    tunnel_kill "$id" "$port"
}

# tunnels_active — "id port url" per known tunnel; drops dead background ones.
tunnels_active() {
    local f base id port pidf
    for f in "$TUNNEL_STATE"/*.url; do
        [[ -e $f ]] || continue
        base="$(basename "$f" .url)"
        id=${base%-*} port=${base##*-}
        pidf="$(_tunnel_file "$id" "$port" pid)"
        if [[ -f $pidf ]] && ! kill -0 "$(cat "$pidf")" 2>/dev/null; then
            rm -f "$f" "$pidf"
            continue
        fi
        echo "$id $port $(cat "$f")"
    done
}
