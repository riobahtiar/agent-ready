# shellcheck shell=bash
# Claude Code (Anthropic) — native installer, self-updating. https://code.claude.com/docs
agent_define claude \
    env="ANTHROPIC_API_KEY" \
    state="" \
    title="Claude Code (Anthropic)" \
    wrapper=b-claude \
    herdr=claude \
    guide="~/.claude/CLAUDE.md" \
    login="claude   then type /login (prints a URL; paste the code back)" \
    paths="~/.local/bin/claude ~/.local/share/claude" \
    config="~/.claude ~/.claude.json"

# claude_jail <dir> — `sandbox agent claude`: nothing in the real ~/.claude is
# writable (shell snapshots are sourced and project memory is loaded as
# instructions by later, unjailed sessions). Claude runs on a throwaway config
# dir instead, seeded with the sign-in and hook-free settings.
# <dir> comes from bin/sandbox's private_dir: brand new and empty, so nothing
# in it can be a planted link; -n / noclobber refuse to write through one anyway.
claude_jail() {
    local dir=$1
    [[ -d $dir && ! -L $dir && -z $(ls -A "$dir") ]] || die "claude_jail: $dir must be a new, empty directory"
    if [[ -f $HOME/.claude/.credentials.json ]]; then cp -n "$HOME/.claude/.credentials.json" "$dir/.credentials.json"; fi
    if [[ -f $HOME/.claude/settings.json ]] && have jq; then
        (set -o noclobber && jq 'del(.hooks, .statusLine, .apiKeyHelper)' "$HOME/.claude/settings.json" >"$dir/settings.json")
    fi
    chmod 600 "$dir"/* 2>/dev/null || true
    echo "CLAUDE_CONFIG_DIR=$dir"
}

claude_install() { _vendor_script https://claude.ai/install.sh; }
claude_update() { claude update; }
# Defaults merged into ~/.claude/settings.json; set only when absent, never
# overriding a value you set yourself (jq `//=` would clobber an explicit false).
#   cleanupPeriodDays  prune old transcripts (complements `cleanup agents`)
#   sandbox.enabled    run Bash inside bubblewrap/Seatbelt (AGENT_SANDBOX, stage 65)
#   permissions.deny   Read rules for credential files (added, never removed);
#                      Claude's sandbox doesn't read ~/.srt-settings.json.
claude_configure() {
    have jq || return 0
    local settings="$HOME/.claude/settings.json" tmp
    local filter='.cleanupPeriodDays //= 30 | .permissions.deny = (((.permissions.deny // []) + $deny) | unique)'
    if is_true "${FULL_CONTROL:-false}"; then
        # Permission bypass is separate from sandboxing and credential rules.
        filter+=' | .permissions.defaultMode //= "bypassPermissions"'
    fi
    is_true "${AGENT_SANDBOX:-true}" && filter+=' | (if .sandbox.enabled == null then .sandbox = ((.sandbox // {}) + {enabled: true}) else . end)'
    mkdir -p "$HOME/.claude"
    # Edit the real file if settings.json is a link (managed elsewhere).
    [[ -L $settings ]] && settings="$(readlink -f "$settings")"
    [[ -s $settings ]] || echo '{}' >"$settings"
    tmp="$(mktemp "$(dirname "$settings")/.settings.XXXXXX")"
    jq --argjson deny '["Read(~/.ssh/**)", "Read(~/.aws/**)", "Read(~/.gnupg/**)", "Read(~/.cloudflared/**)",
        "Read(~/.config/rclone/**)", "Read(~/.config/gh/**)", "Read(~/.config/secrets.env)", "Read(~/.hermes/.env)",
        "Read(~/.dotfiles/config.env)", "Read(~/.claude/.credentials.json)", "Read(~/.codex/auth.json)", "Read(~/.git-credentials)", "Read(~/.netrc)",
        "Read(~/.npmrc)", "Read(~/.docker/config.json)"]' "$filter" "$settings" >"$tmp" && mv "$tmp" "$settings"
}
