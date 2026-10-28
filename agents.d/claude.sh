# shellcheck shell=bash
# Claude Code (Anthropic) — native installer, self-updating. https://code.claude.com/docs
agent_define claude \
    title="Claude Code (Anthropic)" \
    wrapper=b-claude \
    herdr=claude \
    guide="~/.claude/CLAUDE.md" \
    login="claude   then type /login (prints a URL; paste the code back)" \
    paths="~/.local/bin/claude ~/.local/share/claude" \
    config="~/.claude ~/.claude.json"

claude_install() { _vendor_script https://claude.ai/install.sh; }
claude_update() { claude update; }
# Defaults merged into ~/.claude/settings.json; `//=` never overrides a value
# you set yourself.
#   cleanupPeriodDays  prune old transcripts (complements `cleanup agents`)
#   sandbox.enabled    run Bash inside bubblewrap/Seatbelt (AGENT_SANDBOX, stage 65)
claude_configure() {
    have jq || return 0
    local settings="$HOME/.claude/settings.json" tmp filter='.cleanupPeriodDays //= 30'
    is_true "${AGENT_SANDBOX:-true}" && filter+=' | .sandbox.enabled //= true'
    mkdir -p "$HOME/.claude"
    [[ -s $settings ]] || echo '{}' >"$settings"
    tmp="$(mktemp)"
    jq "$filter" "$settings" >"$tmp" && mv "$tmp" "$settings"
}
