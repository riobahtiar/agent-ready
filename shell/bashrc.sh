# shellcheck shell=bash
# Managed by ~/.dotfiles (shell/bashrc.sh) — sourced from ~/.bashrc.
# bash is not the login shell (fish is) but agents and scripts use it, so it
# gets the same tools. Interactive extras only when interactive.

# shellcheck source=shell/profile.sh
. "$HOME/.dotfiles/shell/profile.sh"

if command -v mise >/dev/null 2>&1; then
    if [[ $- == *i* ]]; then
        eval "$(mise activate bash)"
    else
        eval "$(mise activate bash --shims)"
    fi
fi

[[ $- == *i* ]] || return 0

# SSH login into bash (fish shows the same greeting itself).
if shopt -q login_shell && [[ -n ${SSH_TTY:-} ]] && command -v motd >/dev/null 2>&1; then motd; fi

command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash)"
alias ll='eza --long --git --group-directories-first 2>/dev/null || ls -lah'
