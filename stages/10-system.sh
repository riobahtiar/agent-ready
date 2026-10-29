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

log "Login greeting (LOGIN_GREETING=$LOGIN_GREETING)"
# One greeting of our own (bin/motd, shown by the shell on SSH login) instead
# of Ubuntu's MOTD scripts, motd-news, ESM adverts and the provider banner.
if [[ $OS_FAMILY == debian ]]; then
    if is_true "$LOGIN_GREETING"; then
        # Ubuntu 26.04 dropped last/lastlog; wtmpdb records logins for "Last login".
        pkg_install wtmpdb libpam-wtmpdb
        # dpkg-statoverride: the mode survives package upgrades (a chmod wouldn't).
        # (A symlinked entry, e.g. 50-landscape-sysinfo, runs if its target is
        # executable: override the target.)
        for f in /etc/update-motd.d/*; do
            [[ -e $f ]] || continue
            [[ -L $f ]] && f="$(readlink -f "$f")"
            [[ -f $f ]] || continue
            dpkg-statoverride --list "$f" >/dev/null 2>&1 || as_root dpkg-statoverride --update --add root root 0644 "$f"
        done
        as_root sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news 2>/dev/null || true
        # motd-news.timer execs 50-motd-news directly: now 0644, so it fails (203/EXEC).
        if ((HAS_SYSTEMD)) && [[ -e /usr/lib/systemd/system/motd-news.timer ]]; then
            as_root systemctl mask --now motd-news.timer motd-news.service >/dev/null 2>&1 || true
            as_root systemctl reset-failed motd-news.timer motd-news.service >/dev/null 2>&1 || true
        fi
        # The provider's static banner (Contabo & co.), kept once as a backup.
        if as_root test -s /etc/motd && ! as_root grep -q 'Managed by ~/.dotfiles' /etc/motd; then
            as_root test -e /etc/motd.dotfiles-orig || as_root cp -p /etc/motd /etc/motd.dotfiles-orig
            : | as_root tee /etc/motd >/dev/null
        fi
        as_root rm -f /run/motd.dynamic
        ok "Ubuntu/provider MOTD off — greeting: bin/motd (provider banner kept in /etc/motd.dotfiles-orig)"
    else
        for f in $(dpkg-statoverride --list 2>/dev/null | awk '$4 ~ "^/etc/update-motd.d/" || $4 ~ "landscape-sysinfo" {print $4}'); do
            as_root dpkg-statoverride --remove "$f" >/dev/null && as_root chmod 0755 "$f"
        done
        if as_root test -e /etc/motd.dotfiles-orig; then as_root mv -f /etc/motd.dotfiles-orig /etc/motd; fi
        as_root sed -i 's/^ENABLED=0/ENABLED=1/' /etc/default/motd-news 2>/dev/null || true
        if ((HAS_SYSTEMD)) && [[ -e /usr/lib/systemd/system/motd-news.timer ]]; then
            as_root systemctl unmask motd-news.timer motd-news.service >/dev/null 2>&1 || true
            as_root systemctl enable --now motd-news.timer >/dev/null 2>&1 || true
        fi
        step "LOGIN_GREETING=false — Ubuntu's MOTD restored"
    fi
fi

# Providers' cloud-init user-data runs on every boot. Contabo's re-enables
# root SSH login in sshd_config each boot (and fails on 26.04, leaving a failed
# unit). After the first boot it has nothing left to do: lock it. Undo with
# CLOUD_INIT_LOCK=false (provider panel features — password reset, key
# injection — need cloud-init).
if have cloud-init && [[ -d /var/lib/cloud/instance ]]; then
    if is_true "$CLOUD_INIT_LOCK"; then
        if [[ ! -e /etc/cloud/cloud-init.disabled ]]; then
            echo '# Managed by ~/.dotfiles (CLOUD_INIT_LOCK=true): first-boot setup is done' | as_root tee /etc/cloud/cloud-init.disabled >/dev/null
            ok "cloud-init locked after first boot (provider boot commands no longer run)"
        fi
        as_root systemctl reset-failed 'cloud-init*' 2>/dev/null || true
    elif as_root grep -qs 'Managed by ~/.dotfiles' /etc/cloud/cloud-init.disabled; then
        as_root rm -f /etc/cloud/cloud-init.disabled
        step "cloud-init unlocked (CLOUD_INIT_LOCK=false)"
    fi
fi

log "Directories & user services"
as_root install -d -m 755 -o "$TARGET_USER" -g www-data "$WWW_DIR" 2>/dev/null ||
    as_root install -d -m 755 -o "$TARGET_USER" "$WWW_DIR"
# User services (cleanup timer, herdr, agents) keep running after logout.
as_root loginctl enable-linger "$TARGET_USER"
ok "system ready"
