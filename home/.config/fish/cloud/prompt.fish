# Prompt — easy-eel (pgolebiowski/theme-easy-eel, installed by fisher from
# fish_plugins) tuned for a remote full-stack box, plus a right prompt that
# shows the current project's toolchain. Edit the settings, then `exec fish`.
#
#   dev at vps in shop/s/components on feat/cart [!☡+]          node 24.11  bun 1.3  compose  4.2s
#   ↪
#
# Theme reference: https://github.com/pgolebiowski/theme-easy-eel#-documentation
# (bash keeps starship — shell/bashrc.sh.)

status is-interactive; or return

# ─── Left prompt: easy-eel sections ───
# Colors take anything `set_color` does ("--bold red", "brblue", "ff8800").
set -g EASY_EEL_COLOR_USER cyan
fish_is_root_user; and set -g EASY_EEL_COLOR_USER --bold red
# Every session here is SSH; the theme's bold red for SSH reads like an alarm.
set -g EASY_EEL_COLOR_HOST_SSH --bold yellow
set -g EASY_EEL_COLOR_HOST_DEFAULT yellow
set -g EASY_EEL_COLOR_CURRENT_DIRECTORY green
set -g EASY_EEL_COLOR_GIT_BRANCH magenta
set -g EASY_EEL_COLOR_GIT_STATE blue
set -g EASY_EEL_SYMBOL_GIT_CLEAN '✓'
set -g EASY_EEL_SYMBOL_GIT_DIRTY '!'
set -g EASY_EEL_SYMBOL_GIT_UNTRACKED '☡'
set -g EASY_EEL_SYMBOL_GIT_AHEAD '+'  # commits to push — agents' work isn't safe until pushed
set -g EASY_EEL_SYMBOL_GIT_BEHIND '-'
set -g EASY_EEL_SYMBOL_GIT_STASH '↩'
set -g EASY_EEL_SYMBOL_PROMPT_INDICATOR '↪ '
set -g EASY_EEL_COLOR_PROMPT_NORMAL normal
set -g EASY_EEL_COLOR_ERROR red
# Hide a section: set -g EASY_EEL_HIDE_USER true  (also _HOST, _CURRENT_DIRECTORY, _GIT_STATE)

# ─── Right prompt sections, in display order (delete the ones you don't want) ───
#   status    exit code of the last command, when it failed
#   duration  how long the last command took, when ≥ CLOUD_PROMPT_SLOW_MS
#   jobs      background jobs of this shell
#   worktree  you're inside an agent/git worktree (.worktrees/, ~/.codex/worktrees, …)
#   node bun go php python flutter   version, only when the project uses it
#   docker    the project has a compose file or Dockerfile
set -q CLOUD_PROMPT_RIGHT; or set -g CLOUD_PROMPT_RIGHT status duration jobs worktree node bun go php python flutter docker
set -q CLOUD_PROMPT_SLOW_MS; or set -g CLOUD_PROMPT_SLOW_MS 3000
# Greeting on SSH login: status (box summary) · eel (the theme's ocean line) · off
set -q CLOUD_GREETING; or set -g CLOUD_GREETING status

# ─── easy-eel overrides ───
function easy_eel_override_current_directory --description "Prompt dir: project-relative inside PROJECTS_DIR"
    set -l root (string trim -r -c / -- "$PROJECTS_DIR")
    if test -n "$root"; and string match -q -- "$root/*" $PWD
        set -l parts (string split -m 1 / -- (string replace -- "$root/" '' $PWD))
        if test (count $parts) -eq 1
            echo $parts[1]
        else
            echo $parts[1]/(prompt_pwd -d 1 -D 2 $parts[2])
        end
        return
    end
    prompt_pwd -D 2
end

function easy_eel_override_title --description "Terminal/herdr tab title: command · host: dir"
    set -l title (prompt_hostname)": "(prompt_pwd -d 1)
    set -l cmd (status current-command)
    test "$cmd" != fish; and set title "$cmd · $title"
    echo $title
end

function easy_eel_override_greeting --description "SSH login: box summary; herdr panes and subshells stay quiet"
    switch "$CLOUD_GREETING"
        case off
            return
        case eel
            _easy_eel_sea_greeting
            return
    end
    # Only over SSH: on a laptop every new terminal tab is a login shell.
    status is-login; and set -q SSH_TTY; or return
    if command -q motd
        command motd
    else
        __cloud_status_line
    end
end

# ─── Right prompt ───
function fish_right_prompt --description "Last status, duration, jobs and the project's toolchain"
    set -l last_status $status
    set -l out
    set -l markers (__cloud_project_markers)

    for section in $CLOUD_PROMPT_RIGHT
        switch $section
            case status
                test $last_status -ne 0; and set -a out (set_color red)"✘ $last_status"
            case duration
                test "$CMD_DURATION" -ge "$CLOUD_PROMPT_SLOW_MS" 2>/dev/null
                and set -a out (set_color yellow)(__cloud_duration $CMD_DURATION)
            case jobs
                set -l n (count (jobs -p))
                test $n -gt 0; and set -a out (set_color cyan)"⚙ $n"
            case worktree
                string match -qr '/(\.worktrees|worktrees)/' -- $PWD
                and set -a out (set_color bryellow)"⎇ worktree"
            case node
                contains package.json $markers; and not contains bun.lock $markers; and not contains bun.lockb $markers
                and set -a out (set_color green)(__cloud_label node (__cloud_tool_version node))
            case bun
                contains bun.lock $markers; or contains bun.lockb $markers; or contains bunfig.toml $markers
                and set -a out (set_color brwhite)(__cloud_label bun (__cloud_tool_version bun))
            case go
                contains go.mod $markers; and set -a out (set_color brcyan)(__cloud_label go (__cloud_tool_version go))
            case php
                contains composer.json $markers; and set -a out (set_color magenta)(__cloud_label php (__cloud_php_version))
            case python
                if set -q VIRTUAL_ENV
                    set -a out (set_color yellow)(__cloud_label py (__cloud_tool_version python) "("(path basename $VIRTUAL_ENV)")")
                else if contains pyproject.toml $markers; or contains requirements.txt $markers; or contains uv.lock $markers
                    set -a out (set_color yellow)(__cloud_label py (__cloud_tool_version python))
                end
            case flutter
                contains pubspec.yaml $markers; and set -a out (set_color blue)(__cloud_label flutter (__cloud_tool_version flutter))
            case docker
                if contains compose.yaml $markers; or contains compose.yml $markers; or contains docker-compose.yml $markers; or contains docker-compose.yaml $markers
                    set -a out (set_color blue)compose
                else if contains Dockerfile $markers
                    set -a out (set_color blue)docker
                end
        end
    end
    test (count $out) -gt 0; and echo -n (string join '  ' -- $out)(set_color normal)
end

# A version that can't be read (shim, not activated) leaves just the name:
# `"go "(cmd)` would drop the whole word when cmd prints nothing.
function __cloud_label --description "Join a section name with whatever details exist"
    string join ' ' -- $argv
end

function __cloud_project_markers --description "Project files from PWD up to the repo root (or HOME)"
    set -l dir $PWD
    while true
        path filter -- $dir/{package.json,bun.lock,bun.lockb,bunfig.toml,go.mod,composer.json,pyproject.toml,requirements.txt,uv.lock,pubspec.yaml,compose.yaml,compose.yml,docker-compose.yml,docker-compose.yaml,Dockerfile} | path basename
        test -e $dir/.git; or test "$dir" = "$HOME"; or test "$dir" = /; and break
        set dir (path dirname -- $dir)
    end
end

function __cloud_tool_version --argument-names tool --description "major.minor of a mise tool, read from PATH (no subprocess)"
    set -l bin (command -s $tool); or return 0
    string match -rq '/installs/[^/]+/(?<v>[0-9][^/]*)/' -- $bin; or return 0
    string replace -r '^(\d+\.\d+).*' '$1' -- $v
end

function __cloud_php_version --description "PHP version from the /usr/bin/php alternative"
    set -l bin (command -s php); or return 0
    string match -rq 'php(?<v>\d+\.\d+)$' -- (path resolve $bin); and echo $v
end

function __cloud_duration --argument-names ms --description "Human duration: 4.2s, 3m12s, 1h04m"
    set -l s (math -s0 $ms / 1000)
    if test $s -lt 60
        echo (math -s1 $ms / 1000)s
    else if test $s -lt 3600
        printf '%dm%02ds' (math -s0 $s / 60) (math $s % 60)
    else
        printf '%dh%02dm' (math -s0 $s / 3600) (math -s0 $s % 3600 / 60)
    end
end

function __cloud_status_line --description "Load, memory, disk, containers and running agents"
    set -l disk (df -P / | string match -rg '\s(\d+%)\s+/$')
    set -l line (set_color --bold)(prompt_hostname)(set_color normal)
    if test -r /proc/loadavg
        set -l load (string split ' ' < /proc/loadavg)[1]
        set -l kb (string match -rg '^(?:MemTotal|MemAvailable):\s+(\d+)' < /proc/meminfo)
        set -l mem (math -s1 "($kb[1] - $kb[2]) / 1048576")/(math -s1 "$kb[1] / 1048576")G
        set line "$line · load $load/"(nproc)" · mem $mem"
    else
        set line "$line · load "(sysctl -n vm.loadavg | string split ' ')[2]/(sysctl -n hw.ncpu)
    end
    set line "$line · disk $disk"

    if command -q docker; and command -q timeout; and test -w /var/run/docker.sock
        set -l running (count (timeout 1 docker ps -q 2>/dev/null))
        set line "$line · containers $running"
    end

    set -l agents
    # macOS prints full paths in comm; keep the basename.
    set -l comms (ps -u $USER -o comm= 2>/dev/null | string replace -r '.*/' '')
    for name in claude codex opencode omp grok muse
        set -l n (count (string match -- $name $comms))
        test $n -eq 1; and set -a agents $name
        test $n -gt 1; and set -a agents "$name×$n"
    end
    test (count $agents) -gt 0; and set line "$line · agents "(string join ' ' -- $agents)

    echo $line
    test -f /var/run/reboot-required; and echo (set_color yellow)"  ! reboot required (kernel/libc update) — reboot when agents are idle"(set_color normal)
    echo (set_color brblack)"  menu: vps · attach: herdr · health: doctor · update: update-all"(set_color normal)
end
