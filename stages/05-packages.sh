#!/usr/bin/env bash
# stage-user: root
# stage-os: any
# stage-profile: all
# stage-desc: base packages (apt · pacman · dnf · brew), mise, fish as login shell, ~/projects
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/pkg.sh"
load_config

log "Packages on $OS_PRETTY$([[ $IS_WSL == 1 ]] && echo " (WSL)")"
if [[ $OS_KIND == macos ]] && ! have brew; then
    die "Homebrew is required on macOS — install it from https://brew.sh, then re-run"
fi
# Flaky mirrors: let apt retry failed fetches instead of failing the stage.
if [[ $OS_FAMILY == debian ]]; then
    echo 'Acquire::Retries "5";' | as_root tee /etc/apt/apt.conf.d/80-dotfiles-retries >/dev/null
fi
pkg_refresh
# A server gets a full upgrade on setup; on a desktop that's your call (update-all).
# (Not on --changed: a config tweak shouldn't trigger a full upgrade.)
if [[ $OS_FAMILY == debian && $PROFILE == server && ${INSTALL_MODE:-all} != changed ]]; then pkg_upgrade; fi

# Language runtimes come from mise (tools stage), not the OS. These are the
# build deps and ops tools every stack here needs, by their Debian names
# (lib/pkg.sh maps them for Arch, Fedora and Homebrew).
pkg_install \
    build-essential pkg-config git git-lfs curl wget ca-certificates gnupg \
    unzip zip xz-utils zstd tar rsync file tree pv \
    jq sqlite3 openssl lsof acl iproute2 iputils-ping mtr-tiny bind9-dnsutils \
    htop btop ncdu duf tmux mosh \
    python3 python3-venv python3-pip \
    libssl-dev zlib1g-dev libffi-dev libsqlite3-dev libreadline-dev libbz2-dev liblzma-dev libyaml-dev \
    libglu1-mesa locales tzdata logrotate \
    fish bash hostname

if is_true "$FLUTTER_LINUX_DESKTOP" && [[ $OS_KIND == linux ]]; then
    pkg_install clang cmake ninja-build libgtk-3-dev
fi

if [[ $OS_KIND == linux ]]; then
    log "Inside access (FULL_CONTROL=$FULL_CONTROL)"
    if is_true "$FULL_CONTROL"; then
        full_control_sudo "$TARGET_USER" on || stage_incomplete "passwordless sudo not set up (see above)"
    else
        full_control_sudo "$TARGET_USER" off
    fi
fi

log "mise"
if ! have mise; then
    case $OS_FAMILY in
    debian)
        as_root install -d -m 755 /etc/apt/keyrings
        fetch https://mise.jdx.dev/gpg-key.pub | as_root tee /etc/apt/keyrings/mise-archive-keyring.asc >/dev/null
        echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.jdx.dev/deb stable main" |
            as_root tee /etc/apt/sources.list.d/mise.list >/dev/null
        if ! { as_root apt-get update -qq && as_root apt-get install -y -qq mise; }; then
            warn "mise apt repo failed — the tools stage falls back to the user installer"
            as_root rm -f /etc/apt/sources.list.d/mise.list
        fi
        ;;
    arch | macos) pkg_install mise ;;
    *) step "no packaged mise here — the tools stage uses the user installer (mise.run)" ;;
    esac
fi
have mise && ok "mise $(mise --version 2>/dev/null | cut -d' ' -f1)"

log "Login shell & directories"
if [[ $LOGIN_SHELL == fish ]] && have fish; then
    fish_bin="$(command -v fish)"
    fish_major="$(fish --version | grep -oE '[0-9]+' | head -1)"
    ((fish_major >= 4)) || warn "fish $(fish --version) is older than 4.x — config targets fish 4"
    grep -qxF "$fish_bin" /etc/shells || echo "$fish_bin" | as_root tee -a /etc/shells >/dev/null ||
        warn "couldn't add $fish_bin to /etc/shells (sudo needs a terminal) — chsh will fail until it's there"
    if [[ $OS_KIND == macos ]]; then
        current="$(dscl . -read "/Users/$TARGET_USER" UserShell 2>/dev/null | awk '{print $2}')"
    else
        current="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
    fi
    if [[ $current != "$fish_bin" ]]; then
        as_root chsh -s "$fish_bin" "$TARGET_USER" && ok "login shell → $fish_bin" ||
            warn "couldn't change the login shell — run: chsh -s $fish_bin"
    fi
fi
if is_root; then
    install -d -m 755 -o "$TARGET_USER" -g "$(id -gn "$TARGET_USER")" "$PROJECTS_DIR"
else
    mkdir -p "$PROJECTS_DIR"
fi
ok "packages ready"
