#!/usr/bin/env bash
# stage-user: root
# stage-os: debian+systemd+nowsl,arch+systemd+nowsl
# stage-profile: server
# stage-desc: SSH hardening (key-only), ufw firewall (22/80/443), fail2ban
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/pkg.sh"
load_config

# key_login_seen — the journal (or auth.log) shows this user logging in with a
# key. Until then, turning passwords off could lock them out.
key_login_seen() {
    local pattern="Accepted publickey for $TARGET_USER from"
    as_root journalctl -q --no-pager --since=-90d --grep "$pattern" 2>/dev/null | grep -q . && return 0
    as_root grep -qs "$pattern" /var/log/auth.log /var/log/auth.log.1 /var/log/secure 2>/dev/null
}
# ssh_ports — every port sshd (or ssh.socket on 26.04) listens on.
ssh_ports() {
    {
        as_root sshd -T 2>/dev/null | awk '$1 == "port" {print $2}'
        systemctl show ssh.socket -p Listen --value 2>/dev/null | grep -oE ':[0-9]+ ' | tr -d ': '
    } | sort -un
}
valid_cidr() { [[ $1 =~ ^[0-9A-Fa-f:.]+(/[0-9]{1,3})?$ ]]; }

log "SSH"
if is_true "$SSH_HARDEN" || [[ $SSH_HARDEN == force ]]; then
    if [[ -s $TARGET_HOME/.ssh/authorized_keys ]]; then
        conf=/etc/ssh/sshd_config.d/10-cloud.conf
        root_login=prohibit-password
        is_true "$SSH_DISABLE_ROOT" && root_login=no
        # Root SSH is the way back in when the user can't sudo: keep it (key only)
        # until the user has a password.
        if [[ $root_login == no ]] && ! passwd -S "$TARGET_USER" 2>/dev/null | awk '{exit ($2 == "P") ? 0 : 1}'; then
            root_login=prohibit-password
            warn "$TARGET_USER has no password (no sudo) — keeping root key login; set one with: sudo passwd $TARGET_USER"
        fi
        password_auth=no
        if [[ $SSH_HARDEN != force ]] && ! key_login_seen; then
            password_auth=yes
            warn "no key login by $TARGET_USER seen yet — keeping password login ON. Log in once with your key, then: ./install.sh security"
            stage_incomplete "SSH password login still on (no key login by $TARGET_USER seen)"
        fi
        render "$DOTFILES_DIR/system/sshd.conf" ROOT_LOGIN="$root_login" PASSWORD_AUTH="$password_auth" |
            as_root tee "$conf.new" >/dev/null
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
            # Report what sshd will enforce, not what we wrote. (Captured first:
            # `sshd -T | grep -q` can SIGPIPE sshd and fail under pipefail.)
            effective="$(as_root sshd -T 2>/dev/null || true)"
            if grep -qx "passwordauthentication $password_auth" <<<"$effective"; then
                ok "password login: $password_auth · PermitRootLogin $root_login"
            else
                warn "sshd doesn't enforce PasswordAuthentication $password_auth — another file in /etc/ssh/sshd_config.d wins over 10-cloud.conf"
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
# Every port SSH really listens on goes in BEFORE the firewall turns on.
mapfile -t sshp < <(ssh_ports)
((${#sshp[@]})) || sshp=(22)
for p in "${sshp[@]}"; do as_root ufw allow "$p/tcp" comment 'ssh' >/dev/null; done
as_root ufw allow 80/tcp comment 'http' >/dev/null
as_root ufw allow 443/tcp comment 'https' >/dev/null
if is_true "$OPEN_MOSH"; then
    as_root ufw allow 60000:61000/udp comment 'mosh' >/dev/null
fi
as_root ufw default deny incoming >/dev/null
as_root ufw default allow outgoing >/dev/null
as_root ufw --force enable >/dev/null
as_root systemctl enable ufw >/dev/null 2>&1 || true
ok "$(as_root ufw status | head -1) — ssh ${sshp[*]}, 80, 443$(is_true "$OPEN_MOSH" && echo ', mosh')"
step "Docker binds published ports to 127.0.0.1 by default (see system/docker-daemon.json) because Docker bypasses ufw"

log "fail2ban"
pkg_install fail2ban >/dev/null
ignore="127.0.0.1/8 ::1 100.64.0.0/10"
# The address this install is driven from (passed through sudo by install.sh).
client="${SSH_CONNECTION:-}"
client="${client%% *}"
valid_cidr "$client" && ignore+=" $client"
for ip in ${F2B_IGNORE_IPS:-}; do
    valid_cidr "$ip" || die "F2B_IGNORE_IPS: '$ip' is not an IP or CIDR"
    ignore+=" $ip"
done
desired="$(mktemp)"
render "$DOTFILES_DIR/system/fail2ban.local" IGNORE="$ignore" >"$desired"
if ! as_root cmp -s "$desired" /etc/fail2ban/jail.d/90-cloud.local; then
    install_file "$desired" /etc/fail2ban/jail.d/90-cloud.local
    as_root systemctl enable --now fail2ban >/dev/null 2>&1 || true
    as_root systemctl restart fail2ban
fi
rm -f "$desired"
as_root systemctl enable --now fail2ban >/dev/null 2>&1 || true
ok "jails: $(as_root fail2ban-client status 2>/dev/null | sed -n 's/.*Jail list:\s*//p') · never banned: $ignore"
# Tailscale moved to stages/75-network.sh.
