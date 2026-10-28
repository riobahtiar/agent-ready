# shellcheck shell=bash
# Claude Code (Anthropic) — native installer, self-updating. https://code.claude.com/docs
agent_define claude \
    env="ANTHROPIC_API_KEY" \
    state="~/.claude/projects ~/.claude/todos ~/.claude/shell-snapshots ~/.claude/session-env ~/.claude/file-history ~/.claude/paste-cache ~/.claude/debug ~/.claude/statsig" \
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
#   permissions.deny   Read rules for credential files (added, never removed);
#                      Claude's sandbox doesn't read ~/.srt-settings.json.
claude_configure() {
    have jq || return 0
    local settings="$HOME/.claude/settings.json" tmp
    local filter='.cleanupPeriodDays //= 30
        | .permissions.deny = (((.permissions.deny // []) + $deny) | unique)'
    is_true "${AGENT_SANDBOX:-true}" && filter+=' | .sandbox.enabled //= true'
    mkdir -p "$HOME/.claude"
    # Edit the real file if settings.json is a link (managed elsewhere).
    [[ -L $settings ]] && settings="$(readlink -f "$settings")"
    [[ -s $settings ]] || echo '{}' >"$settings"
    tmp="$(mktemp "$(dirname "$settings")/.settings.XXXXXX")"
    jq --argjson deny '["Read(~/.ssh/**)", "Read(~/.aws/**)", "Read(~/.gnupg/**)", "Read(~/.cloudflared/**)",
        "Read(~/.config/rclone/**)", "Read(~/.config/gh/**)", "Read(~/.config/secrets.env)", "Read(~/.hermes/.env)",
        "Read(~/.dotfiles/config.env)", "Read(~/.codex/auth.json)", "Read(~/.git-credentials)", "Read(~/.netrc)",
        "Read(~/.npmrc)", "Read(~/.docker/config.json)"]' "$filter" "$settings" >"$tmp" && mv "$tmp" "$settings"
}
