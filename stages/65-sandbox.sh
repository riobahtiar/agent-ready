#!/usr/bin/env bash
# stage-user: root
# stage-os: any
# stage-profile: all
# stage-inputs: home/.srt-settings.json
# stage-desc: agent sandboxing: bubblewrap + socat (Claude Code /sandbox, srt), AppArmor userns profile, srt policy
set -Eeuo pipefail
source "$AGENT_READY_DIR/lib/common.sh"
source "$AGENT_READY_DIR/lib/pkg.sh"
load_config

bwrap_works() { run_as_user bwrap --ro-bind / / --dev /dev --proc /proc --unshare-all true >/dev/null 2>&1; }

if [[ $OS_KIND == macos ]]; then
    # Seatbelt (sandbox-exec) ships with macOS; Claude Code, Codex and srt use it directly.
    ok "macOS: Seatbelt is built in — nothing to install"
else
    log "bubblewrap + socat"
    pkg_install bubblewrap socat
    if ! bwrap_works && [[ -d /sys/kernel/security/apparmor ]] && have apparmor_parser; then
        distro=/etc/apparmor.d/bwrap-userns-restrict
        if as_root test -f "$distro"; then
            # Ubuntu ships its own, narrower bwrap profile (userns, but the
            # sandboxed child gets no capabilities). Use it; two profiles for
            # /usr/bin/bwrap would conflict.
            log "AppArmor: loading the distro's bwrap-userns-restrict profile"
            if as_root test -f /etc/apparmor.d/dotfiles-bwrap; then
                as_root apparmor_parser -R /etc/apparmor.d/dotfiles-bwrap 2>/dev/null || true
                as_root rm -f /etc/apparmor.d/dotfiles-bwrap
            fi
            as_root apparmor_parser -r "$distro" || warn "apparmor_parser rejected $distro"
        else
            log "AppArmor: allow user namespaces for bwrap only"
            install_file "$AGENT_READY_DIR/system/apparmor-bwrap" /etc/apparmor.d/dotfiles-bwrap
            as_root apparmor_parser -r /etc/apparmor.d/dotfiles-bwrap || warn "apparmor_parser rejected the profile"
        fi
    fi
    if bwrap_works; then
        ok "bubblewrap sandboxes work ($(bwrap --version))"
    else
        warn "bwrap can't create namespaces here (container? hardened kernel?) — sandboxes fall back to prompts"
        ((IS_WSL)) && step "WSL: needs WSL 2 with systemd; see docs/09-sandboxing.md"
    fi
fi

log "Policy for srt (~/.srt-settings.json, linked by the dotfiles stage)"
step "allowlist: package registries, GitHub, model APIs · hides ~/.ssh, ~/.aws, secrets.env, Hermes .env"
is_true "${AGENT_SANDBOX:-true}" && step "Claude Code: sandbox.enabled is switched on by the agents stage (AGENT_SANDBOX=true)"
is_true "${GVISOR:-false}" && step "gVisor (runsc) for 'sandbox box' is installed by the docker stage"
step "try it: sandbox check   ·   sandbox run npm test   ·   sandbox box"
