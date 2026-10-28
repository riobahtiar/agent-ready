#!/usr/bin/env bash
# bootstrap.sh — first contact with a fresh Linux server (Ubuntu/Debian, Arch, Fedora). Run as root.
# Laptops, WSL and macOS don't need it: clone the repo to ~/.dotfiles and run
# ./install.sh (docs/08-multi-os.md).
#
#   curl -fsSL https://raw.githubusercontent.com/riobahtiar/dotfiles-cloud/main/bootstrap.sh | bash -s -- --user rio
#   # or, after copying the repo over:  sudo ./bootstrap.sh --user rio
#
# What it does (and nothing more):
#   1. installs git/curl/sudo, creates the user (sudo group), copies root's SSH keys
#   2. asks for a sudo password for that user (if none is set)
#   3. clones/updates this repo into ~USER/.dotfiles and creates config.env
#   4. with --install, runs install.sh straight away
#
# Options: --user NAME (default rio)  --repo URL  --branch NAME  --install
set -Eeuo pipefail

TARGET_USER=rio
REPO_URL="${DOTFILES_REPO:-https://github.com/riobahtiar/dotfiles-cloud.git}"
BRANCH=main
RUN_INSTALL=0

while (($#)); do
    case $1 in
    --user) TARGET_USER=$2 && shift ;;
    --repo) REPO_URL=$2 && shift ;;
    --branch) BRANCH=$2 && shift ;;
    --install) RUN_INSTALL=1 ;;
    -h | --help)
        sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
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
# shellcheck disable=SC1091
. /etc/os-release
[[ $ID == ubuntu ]] || echo "note: tuned for Ubuntu 26.04; on $PRETTY_NAME some server stages may skip (docs/08-multi-os.md)" >&2

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

# Hand root's authorized keys to the user so SSH hardening can disable root login.
if [[ -s /root/.ssh/authorized_keys ]]; then
    install -d -m 700 -o "$TARGET_USER" -g "$TARGET_USER" "$TARGET_HOME/.ssh"
    touch "$TARGET_HOME/.ssh/authorized_keys"
    # Cloud images put command="echo 'Please login as the user …';exit 142"
    # on root's key: copied as-is it would lock the user out after hardening,
    # so only that stub is stripped. Every other option (from=, restrict,
    # no-*, other forced commands) is a deliberate restriction and stays.
    while IFS= read -r key; do
        [[ -z $key ]] && continue
        grep -qxF "$key" "$TARGET_HOME/.ssh/authorized_keys" || echo "$key" >>"$TARGET_HOME/.ssh/authorized_keys"
    done < <(cat /root/.ssh/authorized_keys /root/.ssh/authorized_keys2 2>/dev/null | awk '
        /^[[:space:]]*(#|$)/ { next }
        /command="[^"]*Please login as/ {
            for (i = 1; i <= NF; i++)
                if ($i ~ /^(ssh-(ed25519|rsa|dss)|ecdsa-sha2-[a-z0-9-]+|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)$/) {
                    out = $i
                    for (j = i + 1; j <= NF; j++) out = out " " $j
                    print out
                    next
                }
        }
        { print }')
    chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh/authorized_keys"
    chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
    say "Copied root's SSH keys to $TARGET_USER"
fi

# Agents run with your user's privileges; keep sudo behind a password.
if passwd -S "$TARGET_USER" 2>/dev/null | awk '{exit ($2 == "P") ? 1 : 0}'; then
    if { : </dev/tty; } 2>/dev/null; then
        say "Set a sudo password for $TARGET_USER"
        passwd "$TARGET_USER" </dev/tty
    else
        echo "warning: no TTY — set a password later with: passwd $TARGET_USER" >&2
    fi
fi

DOTFILES_DIR="$TARGET_HOME/.dotfiles"
if [[ -d $DOTFILES_DIR/.git ]]; then
    say "Updating $DOTFILES_DIR"
    runuser -u "$TARGET_USER" -- git -C "$DOTFILES_DIR" pull --ff-only || echo "warning: git pull failed — continuing with local copy" >&2
elif [[ -f "$(dirname "$(readlink -f "$0")")/install.sh" && $(dirname "$(readlink -f "$0")") != "$DOTFILES_DIR" ]]; then
    say "Copying local repo to $DOTFILES_DIR"
    cp -a "$(dirname "$(readlink -f "$0")")" "$DOTFILES_DIR"
    # A copy from a laptop carries that machine's run state and profile.
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

if [[ ! -f $DOTFILES_DIR/config.env ]]; then
    runuser -u "$TARGET_USER" -- cp "$DOTFILES_DIR/config.env.example" "$DOTFILES_DIR/config.env"
    sed -i "s/^TARGET_USER=.*/TARGET_USER=$TARGET_USER/" "$DOTFILES_DIR/config.env"
    chmod 600 "$DOTFILES_DIR/config.env"
    say "Created $DOTFILES_DIR/config.env"
fi

if ((RUN_INSTALL)); then
    # Without a sudo password, hardening (root login off) would leave nobody
    # able to become root. And `curl | bash` has the pipe on stdin: hand
    # install.sh the terminal so its wizard can run.
    if ! passwd -S "$TARGET_USER" 2>/dev/null | awk '{exit ($2 == "P") ? 0 : 1}'; then
        echo "not running install.sh: $TARGET_USER has no password yet (sudo would be impossible after hardening)." >&2
        echo "Set one (passwd $TARGET_USER), then: ssh $TARGET_USER@<host> and run ~/.dotfiles/setup-server.sh" >&2
        exit 1
    fi
    if { : </dev/tty; } 2>/dev/null; then
        exec "$DOTFILES_DIR/setup-server.sh" </dev/tty
    fi
    exec "$DOTFILES_DIR/setup-server.sh"
fi

cat <<EOF

Bootstrap complete. Next, from your laptop in a NEW terminal:
  ssh $TARGET_USER@<host>
  ~/.dotfiles/install.sh      # asks for your settings, then installs
Keep this root session open until you have confirmed 'ssh $TARGET_USER@<host>' works.
EOF
