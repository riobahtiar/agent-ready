# shellcheck shell=bash
# Agent registry. Each agent is one module, agents.d/<name>.sh, that calls
# agent_define and may define <name>_install / _update / _uninstall /
# _version. Everything else (stage 70, update-all, agents, doctor, vps, herdr
# hooks, the shared AGENTS.md links) reads the registry, so adding an agent
# means adding one file, and retiring one means `agents retire <name>`.
# See agents.d/_template.sh and docs/06-tools-and-agents.md.

[[ -n ${__CLOUD_AGENTS_LOADED:-} ]] && return 0
__CLOUD_AGENTS_LOADED=1

AGENTS_DIR="$DOTFILES_DIR/agents.d"
AGENT_NAMES=()
declare -gA AGENT_META=()

# agent_define <name> key=value… — keys:
#   title    shown in tables and menus
#   bin      command name (default: <name>)
#   wrapper  fish bypass wrapper in home/.config/fish/cloud/ai_bypass.fish, or -
#   herdr    herdr integration target (`herdr integration install <x>`), or -
#   login    how to sign in, shown in hints and run by `agents login`
#   guide    where the agent reads global instructions (gets agents/AGENTS.global.md linked), or -
#   paths    what uninstall removes (space-separated, ~ allowed)
#   config   settings/history, removed only by `agents remove <name> --purge`
#            (also what `sandbox agent <name>` may read and write)
#   env      API-key variables the agent needs inside `sandbox agent` (others stay unset)
#   state    the ONLY paths `sandbox agent` may write: session/log dirs (files if
#            the name has a dot). Never config, hooks, plugins, skills, MCP
#            settings or the agent's code: those run outside the sandbox later.
#   os       where it runs: linux macos (default both)
#   managed  "stage:<name>" when a stage owns install (hermes)
agent_define() {
    local name=$1 kv
    shift
    AGENT_NAMES+=("$name")
    AGENT_META["$name.bin"]=$name AGENT_META["$name.wrapper"]=- AGENT_META["$name.herdr"]=-
    AGENT_META["$name.guide"]=- AGENT_META["$name.os"]="linux macos"
    for kv; do AGENT_META["$name.${kv%%=*}"]=${kv#*=}; done
}

agent_get() { printf '%s' "${AGENT_META["$1.$2"]:-}"; }
agent_known() { [[ -n ${AGENT_META["$1.bin"]:-} ]]; }
agent_bin() { agent_get "$1" bin; }
agent_installed() { have "$(agent_bin "$1")"; }
agent_supported() { [[ " $(agent_get "$1" os) " == *" $OS_KIND "* ]]; }
_expand_home() {
    local p=$1
    printf '%s' "${p/#\~/$HOME}"
}

for __f in "$AGENTS_DIR"/*.sh; do
    [[ $(basename "$__f") == _* ]] && continue
    # shellcheck disable=SC1090
    source "$__f"
done
unset __f

# _vendor_script <url> [sh|bash] — download to a temp file, then run it.
# (Downloading first means a dropped connection can't run half a script.)
# SHELL=bash so installers append PATH lines to ~/.bashrc, not the symlinked fish config.
# _vendor_script <url> [sh|bash] [installer args…]
_vendor_script() {
    local url=$1 shell=${2:-bash} tmp
    shift $(($# < 2 ? $# : 2))
    tmp="$(mktemp)"
    if ! curl -fsSL "$url" -o "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    local rc=0
    SHELL=/bin/bash "$shell" "$tmp" "$@" </dev/null || rc=$?
    rm -f "$tmp"
    return $rc
}

_agent_hook() {
    local name=$1 hook=$2
    shift 2
    if declare -F "${name}_$hook" >/dev/null; then "${name}_$hook" "$@"; else return 127; fi
}

agent_install() {
    local name=$1
    agent_known "$name" || {
        warn "unknown agent '$name' (known: ${AGENT_NAMES[*]})"
        return 1
    }
    agent_supported "$name" || {
        step "$name: not available on $OS_KIND — skipped"
        return 0
    }
    if agent_installed "$name"; then
        if [[ ${RENEW:-0} == 1 ]]; then
            agent_update "$name"
        else
            step "$name already installed ($(command -v "$(agent_bin "$name")"))"
        fi
        return 0
    fi
    step "installing $name"
    _agent_hook "$name" install
}

# agent_update <name> — the tool's own updater, else re-run its installer.
agent_update() {
    local name=$1
    agent_installed "$name" || return 0
    local rc=0
    _agent_hook "$name" update || rc=$?
    ((rc == 127)) && {
        _agent_hook "$name" install
        return
    }
    return $rc
}

# agent_uninstall <name> [--purge] — remove binaries/install dirs; --purge also settings.
# _removable <path> — a path an agent module may delete: inside $HOME, at
# least two levels below it, and not a shared location like ~/.config.
_removable() {
    local p=$1 protected
    [[ $p == "$HOME"/?*/?* || $p == "$HOME"/.?* ]] || return 1
    for protected in "$HOME" "$HOME/.config" "$HOME/.local" "$HOME/.local/share" "$HOME/.local/bin" \
        "$HOME/.local/state" "$HOME/.cache" "$HOME/.ssh" "$HOME/.gnupg" "$HOME/.docker" "$HOME/.aws" \
        "$HOME/.kube" "$HOME/.npm" "$HOME/.bun" "$HOME/go" "${PROJECTS_DIR:-$HOME/projects}" "$DOTFILES_DIR"; do
        [[ ${p%/} == "${protected%/}" ]] && return 1
    done
    return 0
}

agent_uninstall() {
    local name=$1 purge=${2:-} p
    local rc=0
    _agent_hook "$name" uninstall || rc=$?
    if ((rc == 127)); then
        for p in $(agent_get "$name" paths); do
            p="$(_expand_home "$p")"
            [[ -e $p || -L $p ]] || continue
            if ! _removable "$p"; then
                warn "not removing ${p/#$HOME/\~}: shared location (fix 'paths' in agents.d/$name.sh)"
                continue
            fi
            rm -rf -- "$p" && step "removed ${p/#$HOME/\~}"
        done
    fi
    if [[ $purge == --purge ]]; then
        local repos
        for p in $(agent_get "$name" config); do
            p="$(_expand_home "$p")"
            [[ -e $p || -L $p ]] || continue
            if ! _removable "$p"; then
                warn "not purging ${p/#$HOME/\~}: shared location (fix 'config' in agents.d/$name.sh)"
                continue
            fi
            # Agents keep worktrees (= your code) under their config dirs.
            repos="$(find "$p" -maxdepth 5 -name .git -print 2>/dev/null | head -3 | sed "s|^$HOME|~|" | tr '\n' ' ')"
            if [[ -n $repos ]]; then
                warn "not purging ${p/#$HOME/\~}: it holds git checkouts/worktrees (${repos% }) — move them out first"
                continue
            fi
            rm -rf -- "$p" && step "purged ${p/#$HOME/\~}"
        done
    fi
    hash -r
}

agent_version() {
    local name=$1 out
    if out="$(_agent_hook "$name" version 2>/dev/null)"; then
        printf '%s\n' "$out"
        return
    fi
    with_timeout 5 "$(agent_bin "$name")" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?[^ ]*' | head -1
}

# agents_installed — names of installed agents, registry order.
agents_installed() {
    local name
    for name in "${AGENT_NAMES[@]}"; do
        if agent_installed "$name"; then echo "$name"; fi
    done
}

agents_table() {
    local name bin
    printf '%-10s %-24s %-12s %-11s %s\n' CLI Product Version Wrapper Path
    printf '%s\n' "$(printf '─%.0s' {1..82})"
    for name in "${AGENT_NAMES[@]}"; do
        bin="$(agent_bin "$name")"
        if have "$bin"; then
            printf '%-10s %-24s %-12s %-11s %s\n' "$name" "$(agent_get "$name" title)" "$(agent_version "$name")" \
                "$(agent_get "$name" wrapper)" "$(command -v "$bin")"
        else
            printf '%-10s %-24s %-12s %-11s %s\n' "$name" "$(agent_get "$name" title)" "-" "$(agent_get "$name" wrapper)" "(not installed)"
        fi
    done
}
