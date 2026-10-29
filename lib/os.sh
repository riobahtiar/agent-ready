# shellcheck shell=bash
# Platform detection. Sourced by lib/common.sh, so every script has:
#
#   OS_KIND     linux | macos
#   OS_FAMILY   debian | arch | fedora | macos | other   (Ubuntu, WSL Ubuntu → debian; Omarchy, EndeavourOS → arch)
#   OS_ID       os-release ID (ubuntu, debian, arch, omarchy, fedora…) or "macos"
#   OS_PRETTY   human-readable name and version
#   IS_WSL      1 inside Windows Subsystem for Linux
#   HAS_SYSTEMD 1 when systemd is PID 1 (false in containers and WSL without systemd=true)
#   IS_OMARCHY  1 on Omarchy (OS_FAMILY is arch)
#
# Profiles (PROFILE in config.env, or setup-server.sh / setup-desktop.sh) pick
# which stages make sense:
#   server   a VPS / headless box: hardening, firewall, nginx/TLS, Hermes
#            dashboard, swap/zram tuning, weekly cleanup timer
#   desktop  a laptop/desktop/WSL you sit at: packages, shell, tools, agents,
#            sandboxing, tunnels — no nginx, no ufw/fail2ban, no system tuning
# Default: desktop on macOS, WSL or any Linux with a graphical session
# installed; server on headless Linux.

# shellcheck disable=SC2034  # globals for every script that sources this
os_detect() {
    IS_WSL=0 HAS_SYSTEMD=0 IS_OMARCHY=0
    if [[ $(uname -s) == Darwin ]]; then
        OS_KIND=macos OS_FAMILY=macos OS_ID=macos
        OS_PRETTY="macOS $(sw_vers -productVersion 2>/dev/null)"
        return 0
    fi
    OS_KIND=linux
    local id='' like='' pretty=''
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        id="$(. /etc/os-release && echo "${ID:-}")"
        like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
        pretty="$(. /etc/os-release && echo "${PRETTY_NAME:-}")"
    fi
    OS_ID=${id:-linux}
    OS_PRETTY=${pretty:-Linux}
    case " $id $like " in
    *" debian "* | *" ubuntu "*) OS_FAMILY=debian ;;
    *" arch "* | *" omarchy "*) OS_FAMILY=arch ;;
    *" fedora "* | *" rhel "*) OS_FAMILY=fedora ;;
    *) OS_FAMILY=other ;;
    esac
    if [[ -n ${WSL_DISTRO_NAME:-} ]] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
        IS_WSL=1
    fi
    [[ -d /run/systemd/system ]] && HAS_SYSTEMD=1
    # Omarchy (Arch + Hyprland) owns parts of ~/.config and its own mise preinstalls.
    IS_OMARCHY=0
    [[ $id == omarchy || -d /usr/share/omarchy || -d $HOME/.local/share/omarchy ]] && IS_OMARCHY=1
    ((IS_OMARCHY)) && OS_PRETTY="Omarchy ($OS_PRETTY)"
    return 0
}

# os_has_desktop — a graphical session is running or installed.
os_has_desktop() {
    [[ $OS_KIND == macos || $IS_WSL == 1 ]] && return 0
    [[ -n ${XDG_CURRENT_DESKTOP:-}${WAYLAND_DISPLAY:-}${DISPLAY:-} ]] && return 0
    compgen -G '/usr/share/wayland-sessions/*.desktop' >/dev/null || compgen -G '/usr/share/xsessions/*.desktop' >/dev/null
}

os_default_profile() {
    if os_has_desktop; then echo desktop; else echo server; fi
}

# os_matches <spec> — a stage's `# stage-os:` value. Terms: any linux macos
# debian arch fedora systemd wsl nowsl. "," = or, "+" = and:
# "debian+systemd,arch+systemd" → systemd-based Debian or Arch.
os_matches() {
    local -a alts=() terms=()
    local alt term ok
    IFS=, read -ra alts <<<"$1"
    for alt in "${alts[@]}"; do
        ok=1
        IFS=+ read -ra terms <<<"$alt"
        for term in "${terms[@]}"; do
            case $term in
            any) ;;
            linux | macos) [[ $OS_KIND == "$term" ]] || ok=0 ;;
            debian | arch | fedora) [[ $OS_FAMILY == "$term" ]] || ok=0 ;;
            systemd) [[ $HAS_SYSTEMD == 1 ]] || ok=0 ;;
            wsl) [[ $IS_WSL == 1 ]] || ok=0 ;;
            nowsl) [[ $IS_WSL == 0 ]] || ok=0 ;;
            *) ok=0 ;;
            esac
        done
        ((ok)) && return 0
    done
    return 1
}

# os_sha256 <file...> — one digest over the files' contents (portable: Linux + macOS).
os_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        cat "$@" 2>/dev/null | sha256sum | cut -c1-16
    else
        cat "$@" 2>/dev/null | shasum -a 256 | cut -c1-16
    fi
}

# os_owner <path> — "user:group" of a path (GNU/uutils stat vs BSD stat).
os_owner() {
    stat -c %U:%G "$1" 2>/dev/null || stat -f %Su:%Sg "$1"
}

os_detect
