#!/usr/bin/env bash
# stage-user: root
# stage-os: linux+systemd+nowsl
# stage-profile: server
# stage-desc: locale/timezone, zram+swap, kernel limits, journald, unattended upgrades, lingering user services
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/pkg.sh"
load_config

log "Locale & timezone"
if ! locale -a 2>/dev/null | grep -qi "^${LOCALE/UTF-8/utf8}$"; then
    if [[ $OS_FAMILY == debian ]]; then
        as_root locale-gen "$LOCALE" >/dev/null
    elif [[ -f /etc/locale.gen ]]; then
        as_root sed -i "s/^#\s*\(${LOCALE} \)/\1/" /etc/locale.gen && as_root locale-gen >/dev/null
    fi
fi
as_root localectl set-locale LANG="$LOCALE" 2>/dev/null || { have update-locale && as_root update-locale LANG="$LOCALE"; } || true
as_root timedatectl set-timezone "$TIMEZONE"
if [[ -n ${HOSTNAME_FQDN:-} && $(hostname -f 2>/dev/null) != "$HOSTNAME_FQDN" ]]; then
    as_root hostnamectl set-hostname "$HOSTNAME_FQDN"
fi
ok "$(timedatectl show -p Timezone --value) · $LOCALE · $(hostname)"

log "Memory: zram + swapfile"
# 6 GB shared by several agents, LSPs, Docker and builds: zram absorbs bursts
# cheaply; a low-priority disk swapfile is the last resort before the OOM killer.
if is_true "$ZRAM"; then
    zram_pkg=systemd-zram-generator
    [[ $OS_FAMILY == arch ]] && zram_pkg=zram-generator
    [[ $OS_FAMILY == fedora ]] && zram_pkg=zram-generator
    pkg_install "$zram_pkg"
    if [[ -d /usr/lib/systemd/system-generators || -d /lib/systemd/system-generators ]] && as_root modprobe zram 2>/dev/null; then
        install_file "$DOTFILES_DIR/system/zram-generator.conf" /etc/systemd/zram-generator.conf
        install_file "$DOTFILES_DIR/system/sysctl-zram.conf" /etc/sysctl.d/91-cloud-zram.conf
        as_root sysctl --quiet --load /etc/sysctl.d/91-cloud-zram.conf
        as_root systemctl daemon-reload
        as_root systemctl start systemd-zram-setup@zram0.service 2>/dev/null || warn "zram will activate after reboot"
    else
        warn "zram module unavailable on this kernel — relying on the swapfile"
    fi
fi
if ((SWAP_SIZE_GB > 0)) && ! swapon --show=NAME --noheadings | grep -qx /swapfile; then
    if [[ ! -f /swapfile ]]; then
        as_root fallocate -l "${SWAP_SIZE_GB}G" /swapfile
        as_root chmod 600 /swapfile
        as_root mkswap /swapfile >/dev/null
    fi
    if as_root swapon --priority 10 /swapfile 2>/dev/null; then
        grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw,pri=10 0 0' | as_root tee -a /etc/fstab >/dev/null
    else
        # e.g. btrfs/overlay root, or a container — not worth failing the install over.
        as_root rm -f /swapfile
        warn "this filesystem can't host a swapfile — continuing without disk swap"
    fi
fi
swapon --show >&2 || true

log "Kernel & limits"
install_file "$DOTFILES_DIR/system/sysctl.conf" /etc/sysctl.d/90-cloud.conf
as_root sysctl --quiet --load /etc/sysctl.d/90-cloud.conf
install_file "$DOTFILES_DIR/system/limits.conf" /etc/security/limits.d/90-cloud.conf
install_file "$DOTFILES_DIR/system/systemd-limits.conf" /etc/systemd/system.conf.d/90-cloud.conf
install_file "$DOTFILES_DIR/system/systemd-limits.conf" /etc/systemd/user.conf.d/90-cloud.conf
# Restart journald only when its config changed (not on every re-run).
if install_changed "$DOTFILES_DIR/system/journald.conf" /etc/systemd/journald.conf.d/90-cloud.conf; then
    as_root systemctl restart systemd-journald
fi

if [[ $OS_FAMILY == debian ]]; then
    log "Unattended security upgrades (no auto-reboot)"
    pkg_install unattended-upgrades
    install_file "$DOTFILES_DIR/system/apt-unattended.conf" /etc/apt/apt.conf.d/52cloud-unattended
    as_root systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
else
    # Arch has no safe unattended upgrades (partial upgrades break it); Fedora: dnf-automatic.
    step "no unattended upgrades on $OS_FAMILY — run update-all regularly"
fi

log "Directories & user services"
as_root install -d -m 755 -o "$TARGET_USER" -g www-data "$WWW_DIR" 2>/dev/null ||
    as_root install -d -m 755 -o "$TARGET_USER" "$WWW_DIR"
# User services (cleanup timer, herdr, agents) keep running after logout.
as_root loginctl enable-linger "$TARGET_USER"
ok "system ready"
