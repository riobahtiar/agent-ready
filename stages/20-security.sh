#!/usr/bin/env bash
# stage-user: root
# stage-os: debian+systemd+nowsl,arch+systemd+nowsl
# stage-profile: server
# stage-desc: SSH hardening (key-only), ufw firewall (22/80/443), fail2ban
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/pkg.sh"
load_config

log "SSH"
if is_true "$SSH_HARDEN"; then
    if [[ -s $TARGET_HOME/.ssh/authorized_keys ]]; then
        conf=/etc/ssh/sshd_config.d/10-cloud.conf
        root_login=prohibit-password
        is_true "$SSH_DISABLE_ROOT" && root_login=no
        render "$DOTFILES_DIR/system/sshd.conf" ROOT_LOGIN="$root_login" | as_root tee "$conf.new" >/dev/null
        if as_root test -f "$conf"; then as_root cp "$conf" "$conf.prev"; fi
        as_root mv "$conf.new" "$conf"
        if as_root sshd -t; then
            # Ubuntu 26.04 calls it ssh.service (socket-activated), Arch sshd.service.
            unit=''
            for u in ssh.service sshd.service; do
                if systemctl cat "$u" >/dev/null 2>&1; then
                    unit=$u
                    break
                fi
            done
            if [[ -n $unit ]] && ! as_root systemctl try-reload-or-restart "$unit"; then
                warn "$unit didn't reload — running sshd keeps its old settings until it restarts"
            fi
            # Report what sshd will actually enforce, not what we wrote.
            if as_root sshd -T 2>/dev/null | grep -qx 'passwordauthentication no'; then
                ok "key-only auth, PermitRootLogin $root_login"
            else
                warn "sshd still allows passwords — another file in /etc/ssh/sshd_config.d wins over 10-cloud.conf"
            fi
            as_root rm -f "$conf.prev"
        elif as_root test -f "$conf.prev"; then
            as_root mv "$conf.prev" "$conf"
            warn "sshd -t rejected the new hardening config — restored the previous one"
        else
            as_root rm -f "$conf"
            warn "sshd -t rejected the hardening config — removed it, SSH left unchanged"
        fi
    else
        warn "$TARGET_USER has no ~/.ssh/authorized_keys — NOT disabling password auth (would lock you out)"
    fi
fi

log "Firewall (ufw)"
pkg_install ufw >/dev/null
as_root ufw default deny incoming >/dev/null
as_root ufw default allow outgoing >/dev/null
as_root ufw allow 22/tcp comment 'ssh' >/dev/null
as_root ufw allow 80/tcp comment 'http' >/dev/null
as_root ufw allow 443/tcp comment 'https' >/dev/null
if is_true "$OPEN_MOSH"; then
    as_root ufw allow 60000:61000/udp comment 'mosh' >/dev/null
fi
as_root ufw --force enable >/dev/null
as_root systemctl enable ufw >/dev/null 2>&1 || true
ok "$(as_root ufw status | head -1) — 22, 80, 443$(is_true "$OPEN_MOSH" && echo ', mosh')"
step "Docker binds published ports to 127.0.0.1 by default (see system/docker-daemon.json) because Docker bypasses ufw"

log "fail2ban"
pkg_install fail2ban >/dev/null
install_file "$DOTFILES_DIR/system/fail2ban.local" /etc/fail2ban/jail.d/90-cloud.local
as_root systemctl enable --now fail2ban >/dev/null 2>&1
as_root systemctl restart fail2ban
ok "jails: $(as_root fail2ban-client status 2>/dev/null | sed -n 's/.*Jail list:\s*//p')"
# Tailscale moved to stages/75-network.sh.
