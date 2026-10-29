#!/usr/bin/env bash
# stage-user: root
# stage-os: any
# stage-profile: all
# stage-inputs: tunnels.d
# stage-desc: Tailscale (TAILSCALE=true) + dev-tunnel readiness (cloudflared, zrok, pinggy — see `tunnel providers`)
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
load_config

setup_tailscale_linux() {
    # Official script: picks the right repo for Ubuntu/Debian/Arch/Fedora.
    if ! have tailscale; then
        local ts
        ts="$(mktemp)"
        if fetch https://tailscale.com/install.sh "$ts" && retry 2 as_root sh "$ts"; then :; else stage_incomplete "Tailscale install failed"; fi
        rm -f "$ts"
    fi
    if ! have tailscale; then
        warn "tailscale not installed — skipping its setup"
        return 0
    fi
    if ((HAS_SYSTEMD)); then as_root systemctl enable --now tailscaled >/dev/null 2>&1 || true; fi

    if ! tailscale status >/dev/null 2>&1; then
        if [[ -n ${TAILSCALE_AUTHKEY:-} ]]; then
            # The key goes through a 0600 file, never argv (it would show in `ps`).
            keyfile="$(mktemp)"
            chmod 600 "$keyfile"
            printf '%s' "$TAILSCALE_AUTHKEY" >"$keyfile"
            up_args=(--auth-key="file:$keyfile" --hostname="$(hostname -s)")
            is_true "$TAILSCALE_SSH" && up_args+=(--ssh)
            as_root tailscale up "${up_args[@]}" || warn "tailscale up failed — run it by hand"
            rm -f "$keyfile"
        else
            warn "not on a tailnet yet — run: sudo tailscale up$(is_true "$TAILSCALE_SSH" && echo ' --ssh')   (prints a login URL)"
        fi
    fi
    # Lets `tunnel` run `tailscale serve/funnel` without sudo.
    as_root tailscale set --operator="$TARGET_USER" >/dev/null 2>&1 ||
        step "after 'tailscale up': sudo tailscale set --operator=$TARGET_USER"
    if have ufw && as_root ufw status 2>/dev/null | grep -q 'Status: active'; then
        # Tailnet peers are already authenticated by WireGuard keys.
        as_root ufw allow in on tailscale0 comment 'tailnet' >/dev/null
        step "ufw: allowing traffic from tailscale0"
    fi
    tailscale status --self 2>/dev/null | head -1 | sed 's/^/    /' >&2 || true
}

if is_true "$TAILSCALE"; then
    log "Tailscale"
    if ((IS_WSL)); then
        step "WSL: run Tailscale on Windows (it covers WSL too) — skipping"
    elif [[ $OS_KIND == macos ]]; then
        have tailscale || warn "install the Tailscale app: https://tailscale.com/download/mac"
    else
        setup_tailscale_linux
    fi
else
    step "TAILSCALE=false — skipping (private tunnels and SSH over your tailnet need it)"
fi

log "Dev tunnels"
run_as_user "$DOTFILES_DIR/bin/tunnel" providers >&2 || true
step "share a dev server: tunnel   (or: tunnel 3000 cloudflare)"
