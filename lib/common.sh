# shellcheck shell=bash
# Shared helpers for install.sh, stages/*.sh and bin/*. Source it, don't run it.
# Everything here must be idempotent and safe to source more than once.

[[ -n ${__CLOUD_COMMON_LOADED:-} ]] && return 0
__CLOUD_COMMON_LOADED=1

# bash ≥ 4 for every command, also when /bin/bash (3.2) comes first on macOS's
# PATH: re-exec the calling script with Homebrew's bash. (Plain 3.2 syntax up
# to here; "$0"/"$@" are the sourcing script's.)
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    for __b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [ -x "$__b" ] && exec "$__b" "$0" "$@"
    done
    echo "needs bash 4+ (macOS: brew install bash)" >&2
    exit 1
fi

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
export DOTFILES_DIR
# shellcheck source=lib/os.sh
source "$DOTFILES_DIR/lib/os.sh"
# Flutter publishes no linux-arm64 SDK: don't let mise fail on it forever.
if [[ $OS_KIND == linux && $(uname -m) == aarch64 && ${MISE_DISABLE_TOOLS:-} != *flutter* ]]; then
    export MISE_DISABLE_TOOLS="${MISE_DISABLE_TOOLS:+$MISE_DISABLE_TOOLS,}flutter"
fi

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
# fetch <url> [file] — download with connect/total timeouts and retries.
# Provider networks stall and drop transfers (seen: getcomposer.org on a
# fresh VPS); a stalled download is retried, never waited on forever. Always
# via a temp file, so a retried transfer can't duplicate data on stdout.
fetch() {
    local url=$1 out=${2:-} tmp
    tmp="$(mktemp)"
    if ! curl -fsSL --connect-timeout 15 --max-time "${FETCH_TIMEOUT:-300}" \
        --retry 4 --retry-delay 3 --retry-all-errors -o "$tmp" "$url"; then
        rm -f "$tmp"
        warn "download failed after retries: $url"
        return 1
    fi
    if [[ -n $out ]]; then mv -f "$tmp" "$out"; else cat "$tmp" && rm -f "$tmp"; fi
}

# retry <tries> <cmd…> — run a flaky step (an installer that downloads
# things itself) again after a pause.
retry() {
    local tries=$1 n=1
    shift
    until "$@"; do
        ((n >= tries)) && return 1
        warn "attempt $n of $tries failed — retrying in $((n * 10))s: $1"
        sleep $((n * 10))
        n=$((n + 1))
    done
}

# with_timeout <secs> <cmd…> — GNU timeout, Homebrew's gtimeout, or (macOS without coreutils) no limit.
with_timeout() {
    local secs=$1
    shift
    # timeout(1) execs a program: a shell function (as_root, run_as_user) would
    # fail instantly with "No such file". Run those as they are.
    if declare -F "$1" >/dev/null; then
        "$@"
        return
    fi
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
    # Not `set -a`: config.env holds tokens (Telegram, Tailscale, GitHub), and
    # exporting them would hand them to every child: vendor installers, npm
    # postinstalls, sandboxed commands. Only the keys below are exported.
    if [[ -f $file ]]; then
        # shellcheck disable=SC1090
        source "$file"
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

    # As root (sudo), ~ and $HOME in config.env must mean the user's home.
    if is_root && [[ -f $file && $TARGET_HOME != "$HOME" ]]; then
        local real_home=$HOME
        HOME=$TARGET_HOME
        # shellcheck disable=SC1090
        source "$file"
        HOME=$real_home
    fi

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
    # FULL_CONTROL: a playground box. Passwordless sudo for TARGET_USER, and
    # Claude + Codex in YOLO mode by default. Outside protection (SSH keys,
    # firewall, fail2ban, dashboard auth) is unchanged.
    # Empty = on for a server (the playground VPS), off for a desktop/laptop.
    if [[ -z ${FULL_CONTROL:-} ]]; then
        FULL_CONTROL=false
        [[ $PROFILE == server ]] && FULL_CONTROL=true
    fi
    if is_true "$FULL_CONTROL"; then : "${AGENT_SANDBOX:=false}"; else : "${AGENT_SANDBOX:=true}"; fi
    : "${DOCKER:=true}"
    : "${LOGIN_GREETING:=true}"
    : "${CLOUD_INIT_LOCK:=true}"
    # The docker group is root-equivalent; Omarchy leaves users out on purpose.
    if [[ -z ${DOCKER_SUDOLESS:-} ]]; then
        DOCKER_SUDOLESS=false
        [[ $PROFILE == server ]] || is_true "$FULL_CONTROL" && DOCKER_SUDOLESS=true
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
    : "${HERMES_CLOUDFLARE_ONLY:=false}"
    : "${F2B_IGNORE_IPS:=}"
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
    as_root apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
        install -y --no-install-recommends "$@"
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

# install_changed <src> <dst> [mode] — install only when different; true when
# it changed something (so callers restart services only then).
install_changed() {
    as_root cmp -s "$1" "$2" 2>/dev/null && return 1
    install_file "$@"
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

# safe_target <file> — refuse to write through a symlink or into a non-file:
# a user-owned path written by root must never redirect to /etc/shadow & co.
safe_target() {
    if [[ -L $1 ]] || [[ -e $1 && ! -f $1 ]]; then
        die "refusing to write $1: it is a symlink or not a regular file"
    fi
}

# atomic_replace <file> <tmp> — move tmp over file (same directory, so mv
# replaces the name, never follows a link), keeping mode 600.
atomic_replace() {
    chmod 600 "$2"
    mv -f "$2" "$1"
}

# env_set <file> <KEY> <value> — upsert KEY='value' (dotenv + systemd compatible).
# Run it as the file's owner (see stage 80): written atomically, never through a symlink.
env_set() {
    local file=$1 key=$2 value=$3 tmp
    [[ $value == *"'"* ]] && die "env_set: single quotes are not supported in $key"
    safe_target "$file"
    tmp="$(mktemp "$(dirname "$file")/.env_set.XXXXXX")"
    [[ -f $file ]] || : >"$file.missing" # (awk needs an input file)
    K="$key" L="$key='$value'" awk '
        index($0, ENVIRON["K"] "=") == 1 { print ENVIRON["L"]; done = 1; next }
        { print }
        END { if (!done) print ENVIRON["L"] }
    ' "$([[ -f $file ]] && echo "$file" || echo "$file.missing")" >"$tmp"
    rm -f "$file.missing"
    atomic_replace "$file" "$tmp"
}

# full_control_sudo <user> <on|off> — passwordless sudo for <user> via
# /etc/sudoers.d, validated with visudo first: a broken sudoers file would
# lock everyone out of sudo. Linux only. Run as root.
FULL_CONTROL_SUDOERS=/etc/sudoers.d/90-dotfiles-full-control
full_control_sudo() {
    local user=$1 state=$2 tmp
    [[ $(uname -s) == Linux ]] || return 0
    if [[ $state != on ]]; then
        if [[ -e $FULL_CONTROL_SUDOERS ]]; then rm -f "$FULL_CONTROL_SUDOERS" && step "passwordless sudo removed"; fi
        return 0
    fi
    [[ $user =~ ^[a-z_][a-z0-9_-]*$ ]] || die "full_control_sudo: bad user name '$user'"
    tmp="$(mktemp)"
    printf '# Managed by ~/.dotfiles (FULL_CONTROL=true in config.env)\n%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$user" >"$tmp"
    chmod 0440 "$tmp"
    if ! visudo -cf "$tmp" >/dev/null 2>&1; then
        rm -f "$tmp"
        warn "visudo rejected the passwordless-sudo rule — sudo left as it was"
        return 1
    fi
    if cmp -s "$tmp" "$FULL_CONTROL_SUDOERS" 2>/dev/null; then
        rm -f "$tmp"
    else
        install -m 0440 -o root -g root "$tmp" "$FULL_CONTROL_SUDOERS" && rm -f "$tmp"
        ok "passwordless sudo for $user (FULL_CONTROL)"
    fi
}

# stage_incomplete <reason> — inside a stage: finish, but don't record the stage
# as applied, so `install.sh --changed` retries it.
stage_incomplete() {
    warn "$*"
    [[ -n ${STAGE_INCOMPLETE_FILE:-} ]] && printf '%s\n' "$*" >>"$STAGE_INCOMPLETE_FILE"
    return 0
}

# env_get <file> <KEY> — print the unquoted value, empty if missing.
env_get() {
    [[ -f $1 ]] || return 0
    awk -v k="$2" 'index($0, k "=") == 1 { v = substr($0, length(k) + 2); gsub(/^["'\'']|["'\'']$/, "", v); print v; exit }' "$1"
}
