#!/usr/bin/env bash
# stage-user: user
# stage-os: any
# stage-profile: all
# stage-inputs: agents.d
# stage-desc: agent CLIs from agents.d/ (AGENTS in config.env), herdr hooks, shared machine AGENTS.md
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/agents.sh"
load_config

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.grok/bin:$HOME/.local/share/mise/shims:$PATH"

log "Agent CLIs: $AGENTS"
for agent in $AGENTS; do
    if [[ $(agent_get "$agent" managed) == stage:* ]]; then
        step "$agent is installed by the $(agent_get "$agent" managed | cut -d: -f2) stage"
        continue
    fi
    agent_install "$agent" || warn "$agent: install failed — retry with: agents install $agent"
    if agent_installed "$agent"; then _agent_hook "$agent" configure || true; fi
done

log "Shared machine guide → every agent's global instructions"
# One file describes this box (RAM budget, ports, docker, hosting, cleanup) to
# every agent. Project AGENTS.md / CLAUDE.md still take precedence. Done
# before the herdr hooks: it creates ~/.codex etc., which herdr looks for.
guide="$DOTFILES_DIR/agents/AGENTS.global.md"
for agent in "${AGENT_NAMES[@]}"; do
    target="$(agent_get "$agent" guide)"
    [[ $target != - ]] || continue
    target="$(_expand_home "$target")"
    # Your own global instructions win; reference the guide from them instead.
    if [[ -e $target && $(readlink "$target" 2>/dev/null) != "$guide" ]]; then
        step "kept your ${target/#$HOME/\~} — to include the machine guide, reference $guide from it"
        continue
    fi
    link_file "$guide" "$target"
done

if have herdr; then
    log "herdr integrations (agent state in the sidebar)"
    for agent in "${AGENT_NAMES[@]}"; do
        target="$(agent_get "$agent" herdr)"
        [[ $target != - ]] && agent_installed "$agent" || continue
        # Some agents create their config dir on first launch (omp): re-run
        # `agents herdr` after signing in.
        if out="$(herdr integration install "$target" 2>&1)"; then
            step "herdr ↔ $agent"
        else
            warn "herdr ↔ $agent skipped: $(tail -1 <<<"$out")"
        fi
    done
fi

echo >&2
agents_table
echo >&2
log "Sign in (one at a time, inside herdr so sessions survive disconnects) — or: agents login"
for agent in $AGENTS; do
    login="$(agent_get "$agent" login)"
    if [[ -n $login && $login != - ]] && agent_installed "$agent"; then printf '    %-9s %s\n' "$agent" "$login" >&2; fi
done
exit 0
