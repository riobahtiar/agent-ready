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
# PROJECTS_DIR as resolved from config.env by the dotfiles stage (one line;
# never executes config.env here, so a bad edit there can't break logins).
PROJECTS_DIR=''
[ -r "$HOME/.config/dotfiles/projects_dir" ] && IFS= read -r PROJECTS_DIR <"$HOME/.config/dotfiles/projects_dir"
export PROJECTS_DIR="${PROJECTS_DIR:-$HOME/projects}"
# Flutter publishes no linux-arm64 SDK (see lib/common.sh).
case "$(uname -s)-$(uname -m)" in Linux-aarch64)
    case ",${MISE_DISABLE_TOOLS:-}," in *,flutter,*) ;; *) export MISE_DISABLE_TOOLS="${MISE_DISABLE_TOOLS:+$MISE_DISABLE_TOOLS,}flutter" ;; esac
    ;;
esac
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
