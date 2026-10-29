# shellcheck shell=bash
# Optional desktop packages. Source after lib/common.sh and lib/pkg.sh.
# Homebrew tokens: https://formulae.brew.sh/cask/<token> (Mole: /formula/mole).
# Linux names follow vendor documentation; only already-configured sources are used.

desktop_app_ids() {
    printf '%s\n' orbstack tablepro zed ghostty tailscale chatgpt claude helium cloudflare-warp obsidian mole
}

desktop_app_label() {
    case ${1:-} in
    orbstack) printf '%s\n' 'OrbStack (macOS only)' ;;
    tablepro) printf '%s\n' 'TablePro (macOS only)' ;;
    zed) printf '%s\n' 'Zed (macOS; Linux with an existing native package source)' ;;
    ghostty) printf '%s\n' 'Ghostty (macOS; Linux with an existing native package source)' ;;
    tailscale) printf '%s\n' 'Tailscale (macOS app; Linux native client, no login/connect)' ;;
    chatgpt) printf '%s\n' 'ChatGPT desktop (official macOS app; no Linux wrapper)' ;;
    claude) printf '%s\n' 'Claude desktop (official macOS app; no Linux wrapper)' ;;
    helium) printf '%s\n' 'Helium Browser (macOS; Linux with an existing vendor package source)' ;;
    cloudflare-warp) printf '%s\n' 'Cloudflare WARP (macOS app; Linux native client, no login/connect)' ;;
    obsidian) printf '%s\n' 'Obsidian (macOS; Linux native package or existing verified Flathub app)' ;;
    mole) printf '%s\n' 'Mole (macOS maintenance CLI only; install without running cleanup)' ;;
    *)
        warn "unknown desktop app ID '${1:-}' — valid IDs: $(desktop_app_ids | paste -sd ' ' -)"
        return 1
        ;;
    esac
}

_desktop_app_brew() {
    local id=$1 token=$1 kind=cask
    case $id in
    tailscale) token=tailscale-app ;;
    helium) token=helium-browser ;;
    mole) kind=formula ;;
    esac
    if ! have brew; then
        stage_incomplete "$id: Homebrew is unavailable — install Homebrew before retrying desktop-apps"
        return 0
    fi
    if _pkg_brew list "--$kind" "$token" >/dev/null 2>&1; then
        step "$id: already installed (Homebrew $kind $token)"
        return 0
    fi
    # Brew enforces the package's current macOS/CPU requirements. Do not launch
    # apps or invoke Mole: package installation is the only requested action.
    if HOMEBREW_NO_AUTO_UPDATE=1 _pkg_brew install "--$kind" "$token" &&
        _pkg_brew list "--$kind" "$token" >/dev/null 2>&1; then
        ok "$id: installed (Homebrew $kind $token)"
    else
        stage_incomplete "$id: Homebrew install failed (check its OS/architecture requirements above); other apps will continue"
    fi
}

# Package names verified against https://zed.dev/docs/linux,
# https://ghostty.org/docs/install/binary, https://pkgs.tailscale.com/stable/,
# https://github.com/imputnet/helium-linux, https://pkg.cloudflareclient.com/,
# and https://archlinux.org/packages/extra/x86_64/obsidian/.
_desktop_app_native_package() {
    case $1 in
    zed)
        # Upstream currently documents native packages for Arch and Fedora/Terra.
        case $OS_FAMILY in arch | fedora) printf '%s\n' zed ;; esac
        ;;
    ghostty | tailscale) printf '%s\n' "$1" ;;
    cloudflare-warp)
        case $OS_FAMILY in debian | fedora) printf '%s\n' cloudflare-warp ;; esac
        ;;
    obsidian)
        case $OS_FAMILY in arch) printf '%s\n' obsidian ;; esac
        ;;
    helium)
        case $OS_FAMILY in debian | fedora) printf '%s\n' helium-bin ;; esac
        ;;
    esac
}

# Obsidian is website-verified on Flathub (but not vendor-supported):
# https://flathub.org/api/v2/appstream/md.obsidian.Obsidian . Zed's Flathub
# listing is not verified; Helium upstream explicitly does not support Flatpak.
_desktop_app_flatpak() {
    local scope=$1
    shift
    if [[ $scope == user ]]; then
        run_as_user flatpak --user "$@"
    else
        flatpak --system "$@"
    fi
}

_desktop_app_flatpak_installed() {
    local id=$1 scope
    have flatpak || return 1
    for scope in user system; do
        if _desktop_app_flatpak "$scope" info "$id" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Return 1 only when there is no compatible configured Flathub source. Once an
# install is attempted, record failures as incomplete rather than silently skip.
_desktop_app_obsidian_flatpak() {
    have flatpak || return 1
    local scope remote url
    for scope in user system; do
        while IFS=$'\t' read -r remote url _; do
            # Do not trust a remote merely because it is named "flathub".
            case $url in
            https://dl.flathub.org/repo | https://dl.flathub.org/repo/ | https://flathub.org/repo | https://flathub.org/repo/) ;;
            *) continue ;;
            esac
            [[ -n $remote ]] || continue
            if ! _desktop_app_flatpak "$scope" remote-info "$remote" md.obsidian.Obsidian >/dev/null 2>&1; then
                continue
            fi
            if _desktop_app_flatpak "$scope" install --noninteractive --assumeyes "$remote" md.obsidian.Obsidian &&
                _desktop_app_flatpak "$scope" info md.obsidian.Obsidian >/dev/null 2>&1; then
                ok "obsidian: installed (Flatpak $scope md.obsidian.Obsidian)"
            else
                stage_incomplete "obsidian: Flatpak install failed; other apps will continue"
            fi
            return 0
        done < <(_desktop_app_flatpak "$scope" remotes --columns=name,url 2>/dev/null)
    done
    return 1
}

_desktop_app_linux() {
    local id=$1 package arch
    case $id in
    orbstack | tablepro | chatgpt | claude | mole)
        warn "$id: unsupported on Linux — skipped (no unofficial wrappers or installers)"
        return 0
        ;;
    esac
    case $id in
    tailscale | cloudflare-warp) ;;
    *)
        if [[ ${IS_WSL:-0} == 1 && -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} && ! -S /mnt/wslg/.X11-unix/X0 && ! -S /mnt/wslg/runtime-dir/wayland-0 ]]; then
            warn "$id: WSL has no detected GUI support — skipped; configure WSLg or a display yourself"
            return 0
        fi
        ;;
    esac
    arch=$(uname -m)
    case $id:$arch in
    tailscale:* | *:x86_64 | *:aarch64 | *:arm64) ;;
    *)
        warn "$id: unsupported Linux architecture $arch — skipped"
        return 0
        ;;
    esac
    case $OS_FAMILY in
    debian | arch | fedora) ;;
    *)
        if [[ $id == obsidian ]] && { _desktop_app_flatpak_installed md.obsidian.Obsidian || _desktop_app_obsidian_flatpak; }; then
            return 0
        fi
        warn "$id: no supported native package manager on $OS_PRETTY — skipped"
        return 0
        ;;
    esac
    package=$(_desktop_app_native_package "$id")
    if [[ -n $package ]] && pkg_installed "$package"; then
        step "$id: already installed (native package $package)"
        return 0
    fi
    case $id in
    tailscale)
        if have tailscale; then
            step 'tailscale: native client already installed'
            return 0
        fi
        ;;
    cloudflare-warp)
        if have warp-cli; then
            step 'cloudflare-warp: native client already installed'
            return 0
        fi
        ;;
    obsidian)
        if _desktop_app_flatpak_installed md.obsidian.Obsidian; then
            step 'obsidian: already installed (Flatpak)'
            return 0
        fi
        ;;
    esac
    if [[ -n $package ]] && pkg_available "$package"; then
        # Stage 05 refreshed repositories already. In particular, never run
        # pacman -Sy or upgrade the system merely to install optional apps.
        # Vendor package hooks may start a background daemon; we never enable,
        # start, authenticate, connect, or configure the VPN ourselves.
        if pkg_install "$package" && pkg_installed "$package"; then
            ok "$id: installed (native package $package)"
        else
            stage_incomplete "$id: native package $package was not installed successfully; other apps will continue"
        fi
        return 0
    fi
    if [[ $id == obsidian ]] && _desktop_app_obsidian_flatpak; then
        return 0
    fi
    stage_incomplete "$id: no compatible package in existing sources on $OS_PRETTY — configure a documented source, then retry desktop-apps"
}

desktop_app_install() {
    local id=${1:-}
    desktop_app_label "$id" >/dev/null || return 1
    if [[ ${PROFILE:-} != desktop ]]; then
        warn "$id: desktop apps are only installed for PROFILE=desktop — skipped"
        return 0
    fi
    case $OS_KIND in
    macos) _desktop_app_brew "$id" ;;
    linux) _desktop_app_linux "$id" ;;
    *) warn "$id: unsupported OS $OS_KIND — skipped" ;;
    esac
}
