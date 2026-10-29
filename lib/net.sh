# shellcheck shell=bash
# Network helpers shared by `site` and `tunnel`. Source after lib/common.sh.

# net_local_ports — "port|port  process" for local TCP listeners (dev servers),
# skipping ssh/http(s)/dns. Linux: ss; macOS: lsof.
net_local_ports() {
    if have ss; then
        ss -ltnpH 2>/dev/null | awk '{
            n = split($4, a, ":"); port = a[n]
            if (port ~ /^(22|80|443|53)$/ || seen[port]++) next
            proc = "?"
            if (match($0, /\(\("[^"]+"/)) proc = substr($0, RSTART + 3, RLENGTH - 4)
            printf "%s|%-6s %s\n", port, port, proc
        }' | sort -t'|' -k1,1n
    elif have lsof; then
        lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 {
            n = split($9, a, ":"); port = a[n]
            if (port ~ /^(22|80|443|53)$/ || seen[port]++) next
            printf "%s|%-6s %s\n", port, port, $1
        }' | sort -t'|' -k1,1n
    fi
}

# net_pick_port <header> — choose a listening port, or type one.
net_pick_port() {
    local -a items=()
    local line port
    while read -r line; do [[ -n $line ]] && items+=("$line"); done < <(net_local_ports)
    port="$(ui_choose "$1" "${items[@]}" "other|Another port…")" || return 1
    [[ $port == other ]] && { port="$(ui_input "Port" "3000")" || return 1; }
    [[ $port =~ ^[0-9]+$ ]] && ((port > 0 && port < 65536)) || die "not a port: $port"
    printf '%s\n' "$port"
}

# net_answers <port> — something is listening on 127.0.0.1:<port>.
net_answers() { curl -s -o /dev/null --max-time 3 "http://127.0.0.1:$1/"; }
