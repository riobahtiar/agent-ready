#!/usr/bin/env bash
# bootstrap.sh — first contact with a fresh Linux server (Ubuntu/Debian, Arch, Fedora). Run as root.
# Laptops, WSL and macOS don't need it: clone the repo to ~/.dotfiles and run
# ./setup-desktop.sh (or ./install.sh — see docs/08-multi-os.md).
#
#   curl -fsSL https://raw.githubusercontent.com/riobahtiar/dotfiles-cloud/main/bootstrap.sh | bash -s -- --user deploy
#   # or, after copying the repo over:  sudo ./bootstrap.sh --user deploy
#
# What it does (and nothing more):
#   1. installs git/curl/sudo, creates the user (sudo group), copies root/sudoer SSH keys
#   2. clones/updates this repo into ~USER/.dotfiles and creates config.env
#   3. sets up passwordless sudo (when FULL_CONTROL is on) or prompts for a sudo password
#   4. with --install (or BOOTSTRAP_INSTALL=1), runs setup-server.sh straight away
#
# Options: --user NAME  --repo URL  --branch NAME  --install
# Env:     TARGET_USER (or BOOTSTRAP_USER), DOTFILES_REPO, DOTFILES_BRANCH, BOOTSTRAP_INSTALL=1
set -Eeuo pipefail

TARGET_USER="${TARGET_USER:-${BOOTSTRAP_USER:-}}"
REPO_URL="${DOTFILES_REPO:-https://github.com/riobahtiar/dotfiles-cloud.git}"
BRANCH="${DOTFILES_BRANCH:-main}"
RUN_INSTALL=0
[[ ${BOOTSTRAP_INSTALL:-0} =~ ^([Tt]rue|[Yy]es|1|on)$ ]] && RUN_INSTALL=1

while (($#)); do
    case $1 in
    --user)
        [[ $# -ge 2 && -n $2 && $2 != --* ]] || { echo "error: --user requires a username" >&2 && exit 2; }
        TARGET_USER=$2 && shift
        ;;
    --user=*)
        TARGET_USER=${1#*=}
        [[ -n $TARGET_USER ]] || {
            echo "error: --user requires a username" >&2
            exit 2
        }
        ;;
    --repo)
        [[ $# -ge 2 && -n $2 && $2 != --* ]] || { echo "error: --repo requires a URL" >&2 && exit 2; }
        REPO_URL=$2 && shift
        ;;
    --repo=*)
        REPO_URL=${1#*=}
        [[ -n $REPO_URL ]] || {
            echo "error: --repo requires a URL" >&2
            exit 2
        }
        ;;
    --branch)
        [[ $# -ge 2 && -n $2 && $2 != --* ]] || { echo "error: --branch requires a branch name" >&2 && exit 2; }
        BRANCH=$2 && shift
        ;;
    --branch=*)
        BRANCH=${1#*=}
        [[ -n $BRANCH ]] || {
            echo "error: --branch requires a branch name" >&2
            exit 2
        }
        ;;
    --install) RUN_INSTALL=1 ;;
    -h | --help)
        sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
    *) echo "unknown option: $1" >&2 && exit 2 ;;
    esac
    shift
done
say() { printf '\e[1;34m==>\e[0m %s\n' "$*"; }
[[ $EUID -eq 0 ]] || {
    echo "bootstrap.sh must run as root (try: sudo bash bootstrap.sh)" >&2
    exit 1
}
if [[ -z $TARGET_USER ]]; then
    if [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]]; then
        TARGET_USER=$SUDO_USER
    elif { : </dev/tty; } 2>/dev/null; then
        read -r -p "Username to create/configure [deploy]: " TARGET_USER </dev/tty || true
        TARGET_USER="${TARGET_USER:-deploy}"
    else
        echo "error: pass --user <name> or set TARGET_USER=<name>" >&2
        exit 2
    fi
fi
if [[ ! $TARGET_USER =~ ^[a-z_][a-z0-9_-]*$ || $TARGET_USER == root ]]; then
    echo "error: invalid TARGET_USER '$TARGET_USER' (must be a non-root lowercase username)" >&2
    exit 2
fi

# shellcheck disable=SC1091
. /etc/os-release
[[ $ID == ubuntu ]] || echo "note: tested on Ubuntu LTS; on $PRETTY_NAME some server stages may skip (docs/08-multi-os.md)" >&2
if id "$TARGET_USER" >/dev/null 2>&1 && [[ -d $(getent passwd "$TARGET_USER" | cut -d: -f6)/.dotfiles/.git ]]; then
    say "Already bootstrapped ($TARGET_USER and ~/.dotfiles exist) — only updating the repo and keys"
fi

say "Installing bootstrap packages"
admin_group=sudo
case " $ID ${ID_LIKE:-} " in
*" debian "* | *" ubuntu "*)
    export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
    apt-get update -qq
    apt-get install -y -qq git curl ca-certificates sudo >/dev/null
    ;;
*" arch "*)
    pacman -Syu --noconfirm --needed git curl ca-certificates sudo >/dev/null
    admin_group=wheel
    # Arch ships %wheel commented out in /etc/sudoers.
    echo '%wheel ALL=(ALL:ALL) ALL' >/etc/sudoers.d/10-wheel && chmod 440 /etc/sudoers.d/10-wheel
    ;;
*" fedora "* | *" rhel "*)
    dnf -y -q install git curl ca-certificates sudo
    admin_group=wheel
    ;;
*) echo "unsupported distro $PRETTY_NAME — install git, curl and sudo, then re-run" >&2 && exit 1 ;;
esac

if ! id "$TARGET_USER" >/dev/null 2>&1; then
    say "Creating user $TARGET_USER"
    useradd --create-home --shell /bin/bash --groups "$admin_group" "$TARGET_USER"
else
    usermod -aG "$admin_group" "$TARGET_USER"
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# Hand root's (and any cloud default sudoer's) authorized keys to the user so
# SSH hardening can disable root login without locking anyone out.
key_sources=(/root/.ssh/authorized_keys /root/.ssh/authorized_keys2)
if [[ -n ${SUDO_USER:-} && $SUDO_USER != root && $SUDO_USER != "$TARGET_USER" ]]; then
    sudo_home="$(getent passwd "$SUDO_USER" | cut -d: -f6 || true)"
    [[ -n $sudo_home ]] && key_sources+=("$sudo_home/.ssh/authorized_keys" "$sudo_home/.ssh/authorized_keys2")
fi
# Cloud images put command="echo 'Please login as the user …';exit 142"
# on root's key: copied as-is it would lock the user out after hardening,
# so only that stub is stripped. Every other option (from=, restrict,
# no-*, other forced commands) is a deliberate restriction and stays.
usable_keys="$(cat "${key_sources[@]}" 2>/dev/null | awk '
    /^[[:space:]]*(#|$)/ { next }
    /command="[^"]*Please login as/ {
        sub(/command="[^"]*Please login as[^"]*",?/, "")
        sub(/,[[:space:]]+/, " ")
    }
    { print }' || true)"
if [[ -n $usable_keys ]]; then
    install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.ssh"
    touch "$TARGET_HOME/.ssh/authorized_keys"
    while IFS= read -r key; do
        [[ -z $key ]] && continue
        grep -qxF "$key" "$TARGET_HOME/.ssh/authorized_keys" || echo "$key" >>"$TARGET_HOME/.ssh/authorized_keys"
    done <<<"$usable_keys"
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh/authorized_keys"
    chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
    say "Copied SSH keys to $TARGET_USER"
fi

DOTFILES_DIR="$TARGET_HOME/.dotfiles"
if [[ -d $DOTFILES_DIR/.git ]]; then
    say "Updating $DOTFILES_DIR"
    runuser -u "$TARGET_USER" -- git -C "$DOTFILES_DIR" pull --ff-only || echo "warning: git pull failed — continuing with local copy" >&2
elif [[ -f "$(dirname "$(readlink -f "$0")")/install.sh" && $(dirname "$(readlink -f "$0")") != "$DOTFILES_DIR" ]]; then
    say "Copying local repo to $DOTFILES_DIR"
    cp -a "$(dirname "$(readlink -f "$0")")" "$DOTFILES_DIR"
    # A copy from another machine carries that machine's run state and profile.
    rm -rf "$DOTFILES_DIR/.state"
    if [[ -f $DOTFILES_DIR/config.env ]] && grep -qE "^PROFILE=['\"]?(desktop|workstation)" "$DOTFILES_DIR/config.env"; then
        sed -i "s/^PROFILE=.*/PROFILE=/" "$DOTFILES_DIR/config.env"
        echo "note: the copied config.env said PROFILE=desktop — cleared it (this is a server)" >&2
    fi
    chown -R "$TARGET_USER:$TARGET_USER" "$DOTFILES_DIR"
else
    say "Cloning $REPO_URL"
    runuser -u "$TARGET_USER" -- git clone --branch "$BRANCH" "$REPO_URL" "$DOTFILES_DIR"
fi

# Reuse the private, same-directory atomic writer under the config owner's uid.
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=lib/configure.sh
source "$DOTFILES_DIR/lib/configure.sh"

if [[ ! -f $DOTFILES_DIR/config.env ]]; then
    runuser -u "$TARGET_USER" -- install -m 600 "$DOTFILES_DIR/config.env.example" "$DOTFILES_DIR/config.env"
    config_set_owned "$DOTFILES_DIR/config.env" TARGET_USER "$TARGET_USER"
    for k in "${CONFIG_KEYS[@]}"; do
        [[ -n ${!k:-} ]] && config_set_owned "$DOTFILES_DIR/config.env" "$k" "${!k}"
    done
    say "Created $DOTFILES_DIR/config.env"
fi

# Unattended mode (FULL_CONTROL in config.env, on by default on servers):
# passwordless sudo from the start, so install.sh never asks. Validated with
# visudo; a broken file would lock sudo.
full_control_rule=/etc/sudoers.d/90-dotfiles-full-control
if grep -qE "^FULL_CONTROL=(['\"]?(true|yes|1|on)['\"]?|['\"]{0,2})[[:space:]]*(#|$)" "$DOTFILES_DIR/config.env" 2>/dev/null; then
    rule="$(mktemp)"
    printf '# Managed by ~/.dotfiles (FULL_CONTROL=true in config.env)\n%s ALL=(ALL:ALL) NOPASSWD: ALL\n' "$TARGET_USER" >"$rule"
    chmod 0440 "$rule"
    if visudo -cf "$rule" >/dev/null 2>&1; then
        install -m 0440 -o root -g root "$rule" "$full_control_rule"
        say "Passwordless sudo for $TARGET_USER (FULL_CONTROL=true)"
    else
        echo "warning: visudo rejected the passwordless-sudo rule — skipped" >&2
    fi
    rm -f "$rule"
else
    rm -f "$full_control_rule"
fi

# When FULL_CONTROL is off, sudo requires a password for TARGET_USER.
if [[ ! -f $full_control_rule ]] && ! passwd -S "$TARGET_USER" 2>/dev/null | awk '{exit ($2 ~ /^P/) ? 0 : 1}'; then
    if { : </dev/tty; } 2>/dev/null; then
        say "Set a sudo password for $TARGET_USER (FULL_CONTROL=false)"
        passwd "$TARGET_USER" </dev/tty
    else
        echo "warning: no TTY — set a password later with: passwd $TARGET_USER" >&2
    fi
fi

if ((RUN_INSTALL)); then
    # Without a way to sudo, hardening (root login off) would leave nobody
    # able to become root. And `curl | bash` has the pipe on stdin: hand
    # setup-server.sh the terminal so its wizard can run.
    if [[ ! -f $full_control_rule ]] && ! passwd -S "$TARGET_USER" 2>/dev/null | awk '{exit ($2 ~ /^P/) ? 0 : 1}'; then
        echo "not running setup-server.sh: $TARGET_USER has no password yet (sudo would be impossible after hardening)." >&2
        echo "Set one (passwd $TARGET_USER), then: ssh $TARGET_USER@<host> and run ~/.dotfiles/setup-server.sh" >&2
        exit 1
    fi
    if { : </dev/tty; } 2>/dev/null; then
        exec "$DOTFILES_DIR/setup-server.sh" </dev/tty
    fi
    exec "$DOTFILES_DIR/setup-server.sh"
fi

cat <<EOF

Bootstrap complete. Next, from your machine in a NEW terminal:
  ssh $TARGET_USER@<host>
  ~/.dotfiles/setup-server.sh      # asks for your settings, then installs
Keep this root session open until you have confirmed 'ssh $TARGET_USER@<host>' works.
EOF
