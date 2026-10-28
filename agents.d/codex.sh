# shellcheck shell=bash
# OpenAI Codex CLI — an npm package, so mise manages it
# (home/.config/mise/conf.d/30-agents.toml).
agent_define codex \
    title="Codex (OpenAI)" \
    wrapper=b-codex \
    herdr=codex \
    guide="~/.codex/AGENTS.md" \
    login="codex login --device-auth" \
    config="~/.codex"

codex_install() { mise install npm:@openai/codex; }
codex_update() { mise upgrade --yes npm:@openai/codex; }
codex_uninstall() {
    mise uninstall --all npm:@openai/codex 2>/dev/null || true
    warn "also delete the npm:@openai/codex line in home/.config/mise/conf.d/30-agents.toml"
}
