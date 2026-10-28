# shellcheck shell=sh
# Managed by ~/.dotfiles (shell/profile.sh) — sourced from ~/.profile.
# Login shells and everything they spawn (agents' `bash -lc`, systemd user
# units via `bash -l`, ssh one-liners) get the same PATH as fish. Linux, WSL and macOS.

# Homebrew first (macOS, or Linuxbrew), so the dirs below still win.
for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [ -x "$b" ]; then
        eval "$("$b" shellenv)"
        break
    fi
done
unset b

for d in "$HOME/.local/share/mise/shims" "$HOME/.config/composer/vendor/bin" "$HOME/.pub-cache/bin" \
    "$HOME/go/bin" "$HOME/.cargo/bin" "$HOME/.bun/bin" "$HOME/.grok/bin" "$HOME/.opencode/bin" \
    "$HOME/.dotfiles/bin" "$HOME/.local/bin"; do
    case ":$PATH:" in
    *":$d:"*) ;;
    *) [ -d "$d" ] && PATH="$d:$PATH" ;;
    esac
done
export PATH
# PROJECTS_DIR from config.env when set there (empty = ~/projects). Evaluated
# by a shell, like install.sh does, so quotes, spaces, ~ and $HOME all work.
PROJECTS_DIR="$(
    PROJECTS_DIR=''
    [ -r "$HOME/.dotfiles/config.env" ] && . "$HOME/.dotfiles/config.env" >/dev/null 2>&1
    printf '%s' "$PROJECTS_DIR"
)"
export PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
# Opt out of CLI telemetry (cf, wrangler, Next.js, Homebrew, … honour it).
export DO_NOT_TRACK=1

# Secrets shared with fish (KEY=VALUE). Parsed, not sourced: empty values stay
# unset (an empty ANTHROPIC_API_KEY would override OAuth sign-in).
if [ -r "$HOME/.config/secrets.env" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line=${line#export }
        case $line in *=*) ;; *) continue ;; esac
        key=${line%%=*}
        case $key in '' | [!A-Za-z_]* | *[!A-Za-z0-9_]*) continue ;; esac
        val=${line#*=}
        val=${val#\"}
        val=${val%\"}
        val=${val#\'}
        val=${val%\'}
        if [ -n "$val" ]; then export "$key=$val"; fi
    done <"$HOME/.config/secrets.env"
    unset line key val
fi
