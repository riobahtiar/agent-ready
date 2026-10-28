#!/usr/bin/env bash
# stage-user: user
# stage-os: any
# stage-profile: all
# stage-desc: mise runtimes + CLI tools (node, bun, go, python/uv, flutter, rg, ast-grep…), fisher plugins
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
load_config

if ! have mise; then
    log "mise (user installer — apt repo was unavailable)"
    curl -fsSL https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

log "mise install (global tools: ~/.config/mise/conf.d/*.toml)"
[[ -n ${MISE_GITHUB_TOKEN:-} ]] || warn "no GITHUB_TOKEN in config.env — GitHub may rate-limit this (60 req/h)"
export MISE_YES=1
# Two passes: some backends need a runtime from the same file (go: needs go,
# npm: needs node). The second pass picks up whatever the first one could not.
mise install || {
    warn "first pass incomplete — retrying"
    mise install || warn "some tools failed; see 'mise ls --missing' and re-run: ./install.sh tools"
}
if [[ ${RENEW:-0} == 1 ]]; then
    log "Renew: upgrading every mise tool to its newest allowed version"
    mise upgrade --yes || warn "mise upgrade had failures — see above"
fi
mise reshim
ok "$(mise ls --global --current 2>/dev/null | wc -l) global tools active"

if mise which flutter >/dev/null 2>&1; then
    log "Flutter (headless)"
    mise exec -- flutter config --no-analytics >/dev/null 2>&1 || true
    mise exec -- flutter config --no-enable-linux-desktop >/dev/null 2>&1 || true
    is_true "$FLUTTER_LINUX_DESKTOP" && mise exec -- flutter config --enable-linux-desktop >/dev/null 2>&1
    mise exec -- dart --disable-analytics >/dev/null 2>&1 || true
    ok "$(mise exec -- flutter --version 2>/dev/null | head -1)"
fi

if have fish; then
    log "Fisher plugins (~/.config/fish/fish_plugins)"
    if fish -c 'functions -q fisher' 2>/dev/null; then
        fish -c 'fisher update' >/dev/null || warn "fisher update failed (GitHub rate limit?) — retry later"
    else
        fish -c 'curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; and fisher update' >/dev/null ||
            warn "fisher bootstrap failed — retry: ./install.sh tools"
    fi
    ok "$(fish -c 'fisher list' 2>/dev/null | wc -l) plugins"
fi

if have gh && ! gh auth status >/dev/null 2>&1; then
    step "GitHub CLI not signed in — run: gh auth login && gh auth setup-git"
fi
