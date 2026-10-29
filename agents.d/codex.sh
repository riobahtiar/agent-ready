# shellcheck shell=bash
# OpenAI Codex CLI — an npm package, so mise manages it
# (home/.config/mise/conf.d/30-agents.toml).
agent_define codex \
    env="OPENAI_API_KEY" \
    state="~/.codex/sessions ~/.codex/log ~/.codex/history.jsonl" \
    title="Codex (OpenAI)" \
    wrapper=b-codex \
    herdr=codex \
    guide="~/.codex/AGENTS.md" \
    login="codex login --device-auth" \
    config="~/.codex"

codex_install() { mise install npm:@openai/codex; }
# Full control: no approval prompts, no sandbox (the b-codex flags, as default).
# Top-level TOML keys must come before any [table], so they're prepended, and
# only when you haven't set them yourself.
codex_configure() {
    is_true "${FULL_CONTROL:-false}" || return 0
    local cfg="$HOME/.codex/config.toml" add='' tmp
    mkdir -p "$HOME/.codex"
    [[ -f $cfg ]] || : >"$cfg"
    grep -qE '^[[:space:]]*approval_policy[[:space:]]*=' "$cfg" || add+='approval_policy = "never"'$'\n'
    grep -qE '^[[:space:]]*sandbox_mode[[:space:]]*=' "$cfg" || add+='sandbox_mode = "danger-full-access"'$'\n'
    [[ -n $add ]] || return 0
    tmp="$(mktemp "$HOME/.codex/.config.XXXXXX")"
    {
        printf '# Full control (FULL_CONTROL=true in ~/.dotfiles/config.env)\n%s\n' "$add"
        cat "$cfg"
    } >"$tmp" && mv -f "$tmp" "$cfg"
}
codex_update() { mise upgrade --yes npm:@openai/codex; }
codex_uninstall() {
    mise uninstall --all npm:@openai/codex 2>/dev/null || true
    warn "also delete the npm:@openai/codex line in home/.config/mise/conf.d/30-agents.toml"
}
