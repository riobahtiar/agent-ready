# shellcheck shell=bash
# Package manager layer: Debian package names are the canonical names, and
# PKG_TABLE maps them for the other families. Source after lib/common.sh.
#
#   pkg_refresh                 update the package index (and, on Arch, the system: no partial upgrades)
#   pkg_upgrade                 full upgrade
#   pkg_install <name...>       install what exists on this OS, warn about the rest
#
# Add a package: use its Debian name, and add a row here only when another
# family calls it something else ("-" = not needed / not available there).

PKG_TABLE='
# debian            arch            fedora                  brew
build-essential     base-devel      @development-tools      -
pkg-config          pkgconf         pkgconf-pkg-config      pkgconf
ca-certificates     ca-certificates ca-certificates         -
gnupg               gnupg           gnupg2                  gnupg
xz-utils            xz              xz                      xz
tar                 tar             tar                     -
file                file            file                    -
sqlite3             sqlite          sqlite                  sqlite
lsof                lsof            lsof                    -
acl                 acl             acl                     -
iproute2            iproute2        iproute                 -
iputils-ping        iputils         iputils                 -
mtr-tiny            mtr             mtr                     mtr
bind9-dnsutils      bind            bind-utils              bind
python3             python          python3                 python
python3-venv        -               -                       -
python3-pip         python-pip      python3-pip             -
libssl-dev          openssl         openssl-devel           openssl@3
zlib1g-dev          zlib            zlib-devel              -
libffi-dev          libffi          libffi-devel            -
libsqlite3-dev      sqlite          sqlite-devel            -
libreadline-dev     readline        readline-devel          readline
libbz2-dev          bzip2           bzip2-devel             -
liblzma-dev         xz              xz-devel                -
libyaml-dev         libyaml         libyaml-devel           libyaml
libglu1-mesa        glu             mesa-libGLU             -
locales             -               glibc-langpack-en       -
tzdata              tzdata          tzdata                  -
logrotate           logrotate       logrotate               -
unattended-upgrades -               dnf-automatic           -
ninja-build         ninja           ninja-build             ninja
libgtk-3-dev        gtk3            gtk3-devel              -
openssh-server      openssh         openssh-server          -
ufw                 ufw             ufw                     -
fail2ban            fail2ban        fail2ban                -
bash                bash            bash                    bash
hostname            inetutils       hostname                -
'

# pkg_name <debian-name> — this OS's name(s), or nothing when not applicable.
pkg_name() {
    local col
    case $OS_FAMILY in
    debian) printf '%s\n' "$1" && return 0 ;;
    arch) col=2 ;;
    fedora) col=3 ;;
    macos) col=4 ;;
    *) printf '%s\n' "$1" && return 0 ;;
    esac
    local mapped
    mapped="$(awk -v n="$1" -v c="$col" '$1 == n { print $c; found = 1; exit } END { if (!found) print n }' <<<"$PKG_TABLE")"
    [[ $mapped == - ]] || printf '%s\n' "$mapped"
}

_pkg_brew() {
    # Homebrew refuses to run as root; stages run as the user on macOS anyway.
    if is_root; then run_as_user brew "$@"; else brew "$@"; fi
}

# Arch removes the running kernel's modules on upgrade: until a reboot, loading
# new ones (ufw/iptables, zram, docker, tun) fails.
_arch_reboot_check() {
    [[ -d /usr/lib/modules/$(uname -r) ]] ||
        warn "the kernel was upgraded — reboot before relying on firewall, Docker, zram or Tailscale"
}

# Debian: never stop at a "modified config file" question; keep local edits.
APT_OPTS=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

pkg_refresh() {
    case $OS_FAMILY in
    debian) as_root apt-get update -qq ;;
    arch)
        as_root pacman -Syu --noconfirm --needed >/dev/null
        _arch_reboot_check
        ;;
    fedora) as_root dnf -q makecache ;;
    macos) _pkg_brew update --quiet ;;
    *) warn "unknown package manager on $OS_PRETTY — install packages yourself" ;;
    esac
}

pkg_upgrade() {
    case $OS_FAMILY in
    debian) as_root apt-get "${APT_OPTS[@]}" full-upgrade -y -qq ;;
    arch)
        as_root pacman -Syu --noconfirm
        _arch_reboot_check
        ;;
    fedora) as_root dnf -y -q upgrade ;;
    macos) _pkg_brew upgrade ;;
    esac
}

# pkg_available <native-name> — exists in this OS's repositories.
pkg_available() {
    case $OS_FAMILY in
    debian) apt-cache show "$1" >/dev/null 2>&1 ;;
    arch) pacman -Si "$1" >/dev/null 2>&1 || pacman -Sg "$1" >/dev/null 2>&1 ;;
    fedora) [[ $1 == @* ]] || dnf -q info "$1" >/dev/null 2>&1 ;;
    *) return 0 ;; # brew: just try
    esac
}

pkg_install() {
    local -a native=()
    local name n
    for name in "$@"; do
        while read -r n; do
            [[ -n $n ]] || continue
            if pkg_available "$n"; then
                native+=("$n")
            else
                warn "package '$n' not available on $OS_PRETTY — skipped"
            fi
        done < <(pkg_name "$name")
    done
    ((${#native[@]})) || return 0
    case $OS_FAMILY in
    debian) as_root apt-get "${APT_OPTS[@]}" install -y -qq --no-install-recommends "${native[@]}" ;;
    arch) as_root pacman -S --noconfirm --needed "${native[@]}" ;;
    fedora)
        # Groups (@development-tools) differ between Fedora and RHEL clones:
        # install them on their own so one missing group can't sink the rest.
        local -a groups=() pkgs=()
        for n in "${native[@]}"; do if [[ $n == @* ]]; then groups+=("${n#@}"); else pkgs+=("$n"); fi; done
        for n in "${groups[@]}"; do as_root dnf -y -q group install "$n" || warn "dnf group '$n' not available — skipped"; done
        ((${#pkgs[@]} == 0)) || as_root dnf -y -q install "${pkgs[@]}"
        ;;
    macos) _pkg_brew install --quiet "${native[@]}" || warn "brew could not install some of: ${native[*]}" ;;
    *) warn "install these yourself: ${native[*]}" ;;
    esac
}

# pkg_installed <native-name> — already installed.
pkg_installed() {
    case $OS_FAMILY in
    debian) dpkg -s "$1" >/dev/null 2>&1 ;;
    arch) pacman -Q "$1" >/dev/null 2>&1 ;;
    fedora) rpm -q "$1" >/dev/null 2>&1 ;;
    macos) brew list --formula "$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
    esac
}
