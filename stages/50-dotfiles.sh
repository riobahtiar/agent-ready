#!/usr/bin/env bash
# stage-user: user
# stage-os: any
# stage-profile: all
# stage-desc: symlink home/ into ~, git identity, bash hooks, secrets.env, ssh perms
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
load_config

log "Linking $DOTFILES_DIR/home → ~"
# Files are linked one by one (not whole dirs) so tools that write next to
# their config — fisher into ~/.config/fish, agents into ~/.claude — never
# write into this repo.
# "Soft" files are only linked where you have none: a desktop (Omarchy, your
# laptop setup) usually brings its own, and fish here doesn't use them.
soft=(.config/starship.toml)
while IFS= read -r -d '' src; do
    rel=${src#"$DOTFILES_DIR/home/"}
    dst="$HOME/$rel"
    if [[ " ${soft[*]} " == *" $rel "* && -e $dst && $(readlink "$dst" 2>/dev/null) != "$src" ]]; then
        step "kept your ~/$rel (delete it and re-run to use the repo's)"
        continue
    fi
    link_file "$src" "$dst"
done < <(find "$DOTFILES_DIR/home" -type f -print0 | sort -z)

# Links whose source was deleted from home/ (a retired tool's config) go too.
while IFS= read -r -d '' link; do
    if [[ $(readlink "$link") == "$DOTFILES_DIR/home/"* && ! -e $link ]]; then
        rm -f "$link" && step "removed stale link ${link/#$HOME/\~}"
    fi
done < <(find "$HOME" -maxdepth 4 -type l -print0 2>/dev/null)

log "git identity"
git_local="$HOME/.config/git/local"
if [[ -n ${GIT_NAME:-} && $GIT_NAME != "Your Name" ]]; then
    git config --file "$git_local" user.name "$GIT_NAME"
    git config --file "$git_local" user.email "$GIT_EMAIL"
    ok "$GIT_NAME <$GIT_EMAIL>"
else
    warn "GIT_NAME not set in config.env — set it, or: git config --file $git_local user.name '…'"
fi

log "bash hooks (agents and scripts run bash even though fish is the login shell)"
add_line() {
    local file=$1 line=$2
    touch "$file"
    grep -qxF "$line" "$file" || printf '\n# ~/.dotfiles\n%s\n' "$line" >>"$file"
}
profile_line='[ -r "$HOME/.dotfiles/shell/profile.sh" ] && . "$HOME/.dotfiles/shell/profile.sh"'
add_line "$HOME/.profile" "$profile_line"
# macOS login bash reads ~/.bash_profile (if present) instead of ~/.profile;
# zsh (macOS default, and what some agents spawn) reads ~/.zshenv everywhere.
[[ -f $HOME/.bash_profile ]] && add_line "$HOME/.bash_profile" "$profile_line"
have zsh && add_line "$HOME/.zshenv" "$profile_line"
# Ubuntu's ~/.bashrc returns early for non-interactive shells, so this goes
# at the top to cover `bash -c` too.
bashrc_line='[ -r "$HOME/.dotfiles/shell/bashrc.sh" ] && . "$HOME/.dotfiles/shell/bashrc.sh"'
if ! grep -qxF "$bashrc_line" "$HOME/.bashrc" 2>/dev/null; then
    {
        printf '# ~/.dotfiles (kept above the interactive guard)\n%s\n\n' "$bashrc_line"
        # A fresh account (macOS uses zsh) may have no ~/.bashrc yet.
        cat "$HOME/.bashrc" 2>/dev/null || true
    } >"$HOME/.bashrc.new"
    mv "$HOME/.bashrc.new" "$HOME/.bashrc"
fi
ok "~/.profile and ~/.bashrc source ~/.dotfiles/shell/"

log "Secrets file"
secrets="$HOME/.config/secrets.env"
if [[ ! -f $secrets ]]; then
    # (BSD install on macOS has no -D)
    mkdir -p "$(dirname "$secrets")"
    install -m 600 "$DOTFILES_DIR/secrets.env.example" "$secrets"
    ok "created $secrets (fill in API keys as needed)"
fi
chmod 600 "$secrets"
if [[ -n ${GITHUB_TOKEN:-} && -z $(env_get "$secrets" GITHUB_TOKEN) ]]; then
    env_set "$secrets" GITHUB_TOKEN "$GITHUB_TOKEN"
fi

log "SSH"
install -d -m 700 "$HOME/.ssh"
[[ -f $HOME/.ssh/authorized_keys ]] && chmod 600 "$HOME/.ssh/authorized_keys"
if [[ ! -f $HOME/.ssh/id_ed25519 ]]; then
    ssh-keygen -q -t ed25519 -N '' -C "$TARGET_USER@$(uname -n)" -f "$HOME/.ssh/id_ed25519"
    ok "generated ~/.ssh/id_ed25519 — add the .pub to GitHub as a deploy/auth key if you push over SSH"
fi

mkdir -p "$PROJECTS_DIR"
ok "dotfiles linked"
