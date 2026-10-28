# AI agent bypass shortcuts — ported verbatim from the laptop config
# (functions/custom/ai_bypass.fish), trimmed to the agents this box installs.
# Guarded wrappers around agent CLIs that expose an official permission-bypass
# or auto-approval mode. Prompts before enabling bypass; default is normal launch.
# On a VPS, bypass means the agent can do anything your user can (docker
# group included) — prefer it inside a herdr pane on a throwaway worktree.

# __ai_bypass_read_consent - Read y/N from the controlling terminal (never from
# piped stdin, so `cat prompt | b-codex exec -` still delivers the prompt to the
# agent). Returns the raw answer string via echo (may be empty).
#
# AI_BYPASS_ANSWER — optional test/automation injection of the consent reply.
# Not a silent FORCE_BYPASS: callers still go through the same y/N decision.
function __ai_bypass_read_consent --description "Read bypass consent from the TTY"
    set -l name $argv[1]

    if set -q AI_BYPASS_ANSWER
        printf '%s\n' $AI_BYPASS_ANSWER
        return 0
    end

    # Prefer the controlling terminal so agent stdin stays intact for pipes.
    if test -c /dev/tty -a -r /dev/tty
        set -l answer ""
        read -P "Run $name with permission bypass? [y/N] " answer </dev/tty
        or true
        printf '%s\n' $answer
        return 0
    end

    # No TTY (pure batch / non-interactive): never steal piped stdin; refuse bypass.
    echo "b-$name: no controlling terminal; defaulting to no bypass." >&2
    printf '\n'
    return 0
end

# __ai_bypass_run - Shared helper
# Usage: __ai_bypass_run <display_name> <executable> <bypass_argc> [bypass_arg ...] [user_arg ...]
function __ai_bypass_run --description "Prompt then launch an agent with optional bypass args"
    if test (count $argv) -lt 3
        echo "b-*: internal error: __ai_bypass_run needs name, exe, and bypass count" >&2
        return 2
    end

    set -l name $argv[1]
    set -l exe $argv[2]
    set -l n $argv[3]

    if not string match -qr '^[0-9]+$' -- $n
        echo "b-$name: internal error: bypass count must be a non-negative integer" >&2
        return 2
    end

    set -l fixed_end (math 3 + $n)
    if test (count $argv) -lt $fixed_end
        echo "b-$name: internal error: expected $n bypass arg(s) after count" >&2
        return 2
    end

    set -l bypass
    if test $n -gt 0
        set bypass $argv[4..$fixed_end]
    end

    set -l user
    set -l user_start (math 4 + $n)
    if test (count $argv) -ge $user_start
        set user $argv[$user_start..-1]
    end

    if not command -q -- $exe
        echo "b-$name: '$exe' not found on PATH" >&2
        return 127
    end

    set -l preview (string escape -- $exe $bypass $user)
    echo "Will run: $preview"

    set -l answer (__ai_bypass_read_consent $name)
    # Strip a single trailing newline from command substitution; keep content.
    set answer (string collect -- $answer)

    if test "$answer" = y -o "$answer" = Y
        command $exe $bypass $user
        return $status
    end

    echo "Running without permission bypass."
    command $exe $user
    return $status
end

function b-claude --description "Launch claude with optional permission bypass"
    __ai_bypass_run claude claude 1 --dangerously-skip-permissions $argv
end

function b-codex --description "Launch codex with optional permission bypass"
    __ai_bypass_run codex codex 1 --dangerously-bypass-approvals-and-sandbox $argv
end

function b-opencode --description "Launch opencode with optional permission bypass"
    __ai_bypass_run opencode opencode 1 --auto $argv
end

function b-omp --description "Launch omp with optional permission bypass"
    __ai_bypass_run omp omp 1 --approval-mode=yolo $argv
end

function b-grok --description "Launch grok with optional permission bypass"
    __ai_bypass_run grok grok 2 --permission-mode bypassPermissions $argv
end

function b-hermes --description "Launch hermes with optional permission bypass"
    __ai_bypass_run hermes hermes 1 --yolo $argv
end

# Forward tab-completion to each underlying agent CLI (fish --wraps).
# Registered here because config.fish sources functions/custom/*.fish at startup;
# completions/<cmd>.fish only auto-load when the command name matches the file.
complete -c b-claude -w claude -d "Claude Code (optional permission bypass)"
complete -c b-codex -w codex -d "Codex (optional sandbox bypass)"
complete -c b-opencode -w opencode -d "OpenCode (optional --auto)"
complete -c b-omp -w omp -d "oh-my-pi / omp (optional yolo)"
complete -c b-grok -w grok -d "Grok CLI (optional bypassPermissions)"
complete -c b-hermes -w hermes -d "Hermes (optional --yolo)"
