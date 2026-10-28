#!/usr/bin/env bash
# stage-user: user
# stage-os: any
# stage-profile: all
# stage-inputs: home/.config/mise home/.config/fish/fish_plugins
# stage-desc: mise runtimes + CLI tools (node, bun, go, python/uv, flutter, rg, ast-grep…), fisher plugins
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
load_config

if ! have mise; then
    log "mise (user installer — apt repo was unavailable)"
    fetch https://mise.run "$HOME/.mise-install.sh" && sh "$HOME/.mise-install.sh"
    rm -f "$HOME/.mise-install.sh"
    export PATH="$HOME/.local/bin:$PATH"
fi

log "mise install (global tools: ~/.config/mise/conf.d/*.toml)"
[[ -n ${MISE_GITHUB_TOKEN:-} ]] || warn "no GITHUB_TOKEN in config.env — GitHub may rate-limit this (60 req/h)"
export MISE_YES=1
# Several passes: some backends need a runtime from the same file (go: needs
# go, npm: needs node), and a flaky download gets another chance after a pause.
if ! mise install; then
    warn "first pass incomplete — retrying"
    retry 2 mise install || stage_incomplete "some mise tools failed — see 'mise ls --missing' (set GITHUB_TOKEN if it's a rate limit)"
fi
if [[ ${RENEW:-0} == 1 ]]; then
    log "Renew: upgrading every mise tool to its newest allowed version"
    mise upgrade --yes || stage_incomplete "mise upgrade had failures — see above"
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
    # Plugins come from GitHub: retried, since a single flaky fetch would
    # otherwise leave the box without its prompt.
    if fish -c 'functions -q fisher' 2>/dev/null; then
        retry 3 fish -c 'fisher update' >/dev/null || stage_incomplete "fisher update failed (GitHub rate limit?)"
    else
        fisher_src="$(mktemp)"
        if fetch https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish "$fisher_src" &&
            retry 3 fish -c "source '$fisher_src'; and fisher update" >/dev/null; then
            :
        else
            stage_incomplete "fisher bootstrap failed (no prompt theme/plugins yet)"
        fi
        rm -f "$fisher_src"
    fi
    ok "$(fish -c 'fisher list' 2>/dev/null | wc -l) plugins"
fi

if have gh && ! gh auth status >/dev/null 2>&1; then
    step "GitHub CLI not signed in — run: gh auth login && gh auth setup-git"
fi
