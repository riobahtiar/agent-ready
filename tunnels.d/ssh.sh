# shellcheck shell=bash
# Plain SSH port forwarding: the most private option, nothing to install.
# Prints the command to run on your laptop; the dev server stays on 127.0.0.1.
tunnel_define ssh title="SSH forward to your laptop (private · nothing to set up)" reach=private rank=90 auto=no

ssh_ready() { return 0; }
ssh_start() {
    local host=${HOSTNAME_FQDN:-}
    [[ -n $host ]] || host="$(hostname -f 2>/dev/null || hostname)"
    printf 'On your laptop:  ssh -N -L %s:127.0.0.1:%s %s@%s   then open http://localhost:%s\n' "$1" "$1" "$(id -un)" "$host" "$1"
}
