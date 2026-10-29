#!/usr/bin/env bash
# setup-server.sh — AgentReady setup for a VPS / headless Linux server: everything in
# setup-desktop.sh plus SSH hardening, ufw + fail2ban, zram/swap and kernel
# tuning, nginx + Let's Encrypt, PHP-FPM, the Hermes dashboard and a weekly
# cleanup timer. Takes the same flags as install.sh (--changed, --renew, -y, <stage>…).
#
#   ~/.dotfiles/setup-server.sh            first run: settings wizard, then everything
#   ~/.dotfiles/setup-server.sh --changed  later: re-apply what changed
#
# Fresh VPS as root? Run bootstrap.sh first (creates your user). docs/01-first-setup.md
set -eu
for arg in "$@"; do
    case $arg in
    -h | --help)
        sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
        printf '\nInstaller flags:\n'
        sed -n '2,/^$/p' "$(dirname "$0")/install.sh" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    esac
done
if [ "$(uname -s)" = Darwin ]; then
    echo "setup-server.sh is for Linux servers — on a Mac use ./setup-desktop.sh" >&2
    exit 1
fi
cd "$(dirname "$0")"
PROFILE_OVERRIDE=server exec ./install.sh "$@"
