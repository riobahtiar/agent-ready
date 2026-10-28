# shellcheck shell=bash
# Shared helpers for install.sh, stages/*.sh and bin/*. Source it, don't run it.
# Everything here must be idempotent and safe to source more than once.

[[ -n ${__CLOUD_COMMON_LOADED:-} ]] && return 0
__CLOUD_COMMON_LOADED=1

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
export DOTFILES_DIR
# shellcheck source=lib/os.sh
source "$DOTFILES_DIR/lib/os.sh"

# ─── Output ───
if [[ -t 2 ]]; then
    C_RESET=$'\e[0m' C_DIM=$'\e[2m' C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_BLUE=$'\e[34m' C_BOLD=$'\e[1m'
else
    C_RESET='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD=''
fi

log() { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*" >&2; }
step() { printf '%s  ->%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2; }
ok() { printf '%s  ✓%s %s\n' "$C_GREEN" "$C_RESET" "$*" >&2; }
warn() { printf '%s  !%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die() {
    printf '%s  ✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }
# with_timeout <secs> <cmd…> — GNU timeout, Homebrew's gtimeout, or (macOS without coreutils) no limit.
with_timeout() {
    local secs=$1
    shift
    if have timeout; then
        timeout "$secs" "$@"
    elif have gtimeout; then
        gtimeout "$secs" "$@"
    else
        "$@"
    fi
}
is_root() { [[ $EUID -eq 0 ]]; }
is_true() { [[ ${1:-} =~ ^([Tt]rue|[Yy]es|1|on)$ ]]; }
# has_tty — a controlling terminal we can actually open. (`-r /dev/tty` is
# true even without one, e.g. under ssh -T, cron or `docker run` without -t.)
has_tty() { { : </dev/tty; } 2>/dev/null; }

# as_root <cmd...> — run as root (directly when we already are).
as_root() {
    if is_root; then "$@"; else sudo "$@"; fi
}

# confirm "Question? [y/N] " — default no. Reads the TTY, never piped stdin.
# ASSUME_YES=1 answers yes; no TTY answers no.
confirm() {
    [[ ${ASSUME_YES:-0} == 1 ]] && return 0
    has_tty || return 1
    local answer=''
    read -r -p "$1" answer </dev/tty || true
    [[ $answer =~ ^[Yy]$ ]]
}

# ─── Config ───
# config.env is git-ignored KEY=VALUE (bash syntax). Defaults live here so a
# missing key never breaks a stage.
load_config() {
    local file="${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env}"
    if [[ -f $file ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$file"
        set +a
    fi

    if [[ -z ${TARGET_USER:-} ]]; then
        if is_root; then TARGET_USER="${SUDO_USER:-rio}"; else TARGET_USER="$(id -un)"; fi
    fi
    [[ $TARGET_USER == root ]] && die "TARGET_USER must be a regular user, not root"

    if [[ $TARGET_USER == "$(id -un)" ]]; then
        TARGET_HOME=$HOME
    elif [[ $OS_KIND == macos ]]; then
        TARGET_HOME="$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
    else
        TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6 || true)"
    fi
    : "${TARGET_HOME:=/home/$TARGET_USER}"

    : "${PROFILE:=$(os_default_profile)}"
    [[ $PROFILE == workstation ]] && PROFILE=desktop # old name
    [[ $PROFILE == server || $PROFILE == desktop ]] || die "PROFILE must be server or desktop (got '$PROFILE')"

    : "${TIMEZONE:=Asia/Jakarta}"
    : "${LOCALE:=en_US.UTF-8}"
    : "${LOGIN_SHELL:=fish}"
    : "${SWAP_SIZE_GB:=4}"
    : "${ZRAM:=true}"
    : "${SSH_HARDEN:=true}"
    : "${SSH_DISABLE_ROOT:=true}"
    : "${OPEN_MOSH:=false}"
    : "${TAILSCALE:=false}"
    : "${TAILSCALE_SSH:=false}"
    : "${TUNNEL_DEFAULT:=auto}"
    : "${AGENT_SANDBOX:=true}"
    : "${DOCKER:=true}"
    # The docker group is root-equivalent; Omarchy leaves users out on purpose.
    if [[ -z ${DOCKER_SUDOLESS:-} ]]; then
        DOCKER_SUDOLESS=false
        [[ $PROFILE == server ]] && DOCKER_SUDOLESS=true
    fi
    : "${GVISOR:=false}"
    : "${PHP:=true}"
    : "${FLUTTER_LINUX_DESKTOP:=false}"
    : "${PROJECTS_DIR:=$TARGET_HOME/projects}"
    : "${WWW_DIR:=/srv/www}"
    : "${AGENTS:=claude codex opencode omp grok muse herdr}"
    : "${HERMES:=true}"
    : "${HERMES_DOMAIN:=}"
    : "${HERMES_DASHBOARD_USER:=$TARGET_USER}"
    : "${HERMES_DASHBOARD_PORT:=9119}"
    : "${HERMES_ALLOW_IPS:=}"
    # A laptop is asleep at 04:00 and would run it on wake, mid-work.
    if [[ -z ${CLEANUP_TIMER:-} ]]; then
        CLEANUP_TIMER=false
        [[ $PROFILE == server ]] && CLEANUP_TIMER=true
    fi

    # mise reads MISE_GITHUB_TOKEN; unauthenticated GitHub allows 60 API calls/h,
    # which a fresh install of ~40 tools will exhaust.
    if [[ -n ${GITHUB_TOKEN:-} && -z ${MISE_GITHUB_TOKEN:-} ]]; then
        export MISE_GITHUB_TOKEN="$GITHUB_TOKEN"
    fi

    export TARGET_USER TARGET_HOME PROJECTS_DIR WWW_DIR PROFILE
}

# ─── Users ───
# run_as_user <cmd...> — run as TARGET_USER with a clean login-like env.
# Uses runuser (util-linux) rather than sudo so it behaves the same under
# Ubuntu 26.04's sudo-rs.
run_as_user() {
    if [[ $(id -un) == "$TARGET_USER" ]]; then
        "$@"
        return
    fi
    local uid
    uid="$(id -u "$TARGET_USER")"
    runuser -u "$TARGET_USER" -- env -i \
        HOME="$TARGET_HOME" USER="$TARGET_USER" LOGNAME="$TARGET_USER" \
        SHELL=/bin/bash TERM="${TERM:-xterm-256color}" LANG="${LANG:-C.UTF-8}" \
        PATH="$TARGET_HOME/.local/bin:$TARGET_HOME/.local/share/mise/shims:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_CONFIG="${DOTFILES_CONFIG:-$DOTFILES_DIR/config.env}" \
        ASSUME_YES="${ASSUME_YES:-0}" RENEW="${RENEW:-0}" PROFILE="${PROFILE:-}" \
        "$@"
}

# ─── apt ───
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

apt_install() {
    as_root apt-get install -y --no-install-recommends "$@"
}

# apt_install_available <pkg...> — install what exists in this release, warn on the rest.
apt_install_available() {
    local pkgs=() p
    for p in "$@"; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            pkgs+=("$p")
        else
            warn "apt: '$p' not available on this release — skipped"
        fi
    done
    ((${#pkgs[@]})) && apt_install "${pkgs[@]}"
    return 0
}

ubuntu_codename() {
    # shellcheck disable=SC1091
    (. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
}

# ─── Files ───
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"

# link_file <src> <dst> — symlink, backing up anything real that is in the way.
link_file() {
    local src=$1 dst=$2
    mkdir -p "$(dirname "$dst")"
    if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then
        return 0
    fi
    if [[ -e $dst || -L $dst ]]; then
        local backup="$BACKUP_DIR/${dst#"$HOME"/}"
        mkdir -p "$(dirname "$backup")"
        mv "$dst" "$backup"
        warn "backed up $dst -> $backup"
    fi
    ln -s "$src" "$dst"
    step "linked ${dst/#$HOME/\~}"
}

# install_file <src> <dst> [mode] — copy a managed file into place (root-owned targets).
install_file() {
    local src=$1 dst=$2 mode=${3:-0644}
    # mkdir + install rather than `install -D`, which BSD install (macOS) lacks.
    as_root mkdir -p "$(dirname "$dst")"
    as_root install -m "$mode" "$src" "$dst"
}

# render <template> KEY=VALUE... — replace __KEY__ placeholders, print result.
# bash 5.2+ would expand `&` in the replacement to the match; values are literal.
shopt -u patsub_replacement 2>/dev/null || true
render() {
    local content kv key value
    content="$(<"$1")"
    shift
    for kv in "$@"; do
        key=${kv%%=*}
        value=${kv#*=}
        content=${content//"__${key}__"/$value}
    done
    printf '%s\n' "$content"
}

# env_set <file> <KEY> <value> — upsert KEY='value' (dotenv + systemd compatible).
env_set() {
    local file=$1 key=$2 value=$3 tmp
    [[ $value == *"'"* ]] && die "env_set: single quotes are not supported in $key"
    touch "$file"
    chmod 600 "$file"
    tmp="$(mktemp)"
    K="$key" L="$key='$value'" awk '
        index($0, ENVIRON["K"] "=") == 1 { print ENVIRON["L"]; done = 1; next }
        { print }
        END { if (!done) print ENVIRON["L"] }
    ' "$file" >"$tmp"
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

# env_get <file> <KEY> — print the unquoted value, empty if missing.
env_get() {
    [[ -f $1 ]] || return 0
    awk -v k="$2" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2); gsub(/^["'\'']|["'\'']$/, "", v); print v; exit }' "$1"
}
