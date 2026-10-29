# Utilities — interactive helpers. Ops commands (cleanup, site, doctor,
# update-all, agents) are bash scripts in ~/.dotfiles/bin so agents and
# non-fish shells can call them too.

# __confirm - y/N from the controlling TTY (never piped stdin), default no.
function __confirm --description "Read y/N confirmation from the controlling TTY"
    set -l prompt "Confirm? [y/N] "
    test (count $argv) -gt 0; and set prompt "$argv"

    set -l answer
    if test -c /dev/tty -a -r /dev/tty
        read -P "$prompt" answer </dev/tty
        or true
    else
        echo "No controlling terminal; cancelled." >&2
        return 1
    end

    test "$answer" = y -o "$answer" = Y
end

function mkcd --description "Create a directory and cd into it"
    mkdir -p -- $argv[1]; and cd -- $argv[1]
end

function fish-reload --description "Restart fish (reloads conf.d, config and functions)"
    exec fish
end

function path-list --description "Print PATH, one entry per line, flag missing dirs"
    for p in $PATH
        if test -d "$p"
            echo $p
        else
            set_color red; echo "$p (missing)"; set_color normal
        end
    end
end

function ports --description "Listening TCP ports (all, or one port)"
    if command -q ss
        if test (count $argv) -gt 0
            sudo ss -tlnpH "sport = :$argv[1]"
        else
            sudo ss -tlnp
        end
    else if test (count $argv) -gt 0
        sudo lsof -nP -iTCP:$argv[1] -sTCP:LISTEN
    else
        sudo lsof -nP -iTCP -sTCP:LISTEN
    end
end

function pj --description "Jump to a project in \$PROJECTS_DIR (fzf)"
    set -l root $PROJECTS_DIR
    test -d "$root"; or begin
        echo "pj: $root does not exist" >&2
        return 1
    end
    set -l pick (command fd --type d --max-depth 2 --hidden --glob .git "$root" --exec dirname {} \; 2>/dev/null \
        | string replace "$root/" '' | sort -u | fzf --query "$argv" --select-1 --exit-0)
    test -n "$pick"; and cd "$root/$pick"
end

function clone --description "git clone into \$PROJECTS_DIR and cd there (url or owner/repo)"
    test (count $argv) -ge 1; or begin
        echo "usage: clone <url|owner/repo> [dir]" >&2
        return 2
    end
    set -l src $argv[1]
    # owner/repo shorthand → GitHub over HTTPS (gh auth setup-git handles credentials)
    string match -qr '^[\w.-]+/[\w.-]+$' -- $src; and set src "https://github.com/$src.git"
    set -l name (string replace -r '\.git$' '' -- (basename $src))
    test (count $argv) -ge 2; and set name $argv[2]
    command git clone $src "$PROJECTS_DIR/$name"; and cd "$PROJECTS_DIR/$name"; or return
    # A repo's mise config can run code ([env] exec, _.source, hooks): show it, trust on request.
    for f in mise.toml .mise.toml mise.local.toml .config/mise.toml
        test -f $f; or continue
        echo "── $f ──"
        command head -40 $f
        __confirm "Trust this repo's mise config (lets it run the code above)? [y/N] "; and command mise trust --quiet
        break
    end
end

# wt - make an isolated git worktree for an agent task, next to the repo:
#   <repo>/.worktrees/<branch>   (git-ignored globally, swept by `cleanup worktrees`)
function wt --description "Create a git worktree for a task: wt <branch> [base]"
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    or begin
        echo "wt: not inside a git repository" >&2
        return 1
    end
    test (count $argv) -ge 1; or begin
        echo "usage: wt <branch> [base]   (lists worktrees with no args: git worktree list)" >&2
        git worktree list
        return 2
    end
    set -l branch $argv[1]
    set -l base HEAD
    test (count $argv) -ge 2; and set base $argv[2]
    set -l dir "$root/.worktrees/"(string replace -a / - -- $branch)

    if git show-ref --verify --quiet "refs/heads/$branch"
        git worktree add "$dir" "$branch"
    else
        git worktree add -b "$branch" "$dir" "$base"
    end
    and cd "$dir"
end
