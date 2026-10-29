#!/usr/bin/env bash
# stage-user: user
# stage-os: any
# stage-profile: all
# stage-desc: symlink home/ into ~, git identity, bash hooks, secrets.env, ssh perms
set -Eeuo pipefail
source "$AGENT_READY_DIR/lib/common.sh"
load_config

log "Linking $AGENT_READY_DIR/home → ~"
# Files are linked one by one (not whole dirs) so tools that write next to
# their config — fisher into ~/.config/fish, agents into ~/.claude — never
# write into this repo.
# "Soft" files are only linked where you have none: a desktop (Omarchy, your
# laptop setup) usually brings its own, and fish here doesn't use them.
soft=(.config/starship.toml)
while IFS= read -r -d '' src; do
    rel=${src#"$AGENT_READY_DIR/home/"}
    dst="$HOME/$rel"
    if [[ " ${soft[*]} " == *" $rel "* && -e $dst && $(readlink "$dst" 2>/dev/null) != "$src" ]]; then
        step "kept your ~/$rel (delete it and re-run to use the repo's)"
        continue
    fi
    link_file "$src" "$dst"
done < <(find "$AGENT_READY_DIR/home" -type f -print0 | sort -z)

# Links whose source was deleted from home/ (a retired tool's config) go too.
# Only the directories home/ links into are scanned: walking all of $HOME
# trips macOS privacy prompts (Desktop, Documents, iCloud).
while IFS= read -r -d '' link; do
    if [[ $(readlink "$link") == "$AGENT_READY_DIR/home/"* && ! -e $link ]]; then
        rm -f "$link" && step "removed stale link ${link/#$HOME/\~}"
    fi
done < <(
    {
        echo "$HOME"
        find "$AGENT_READY_DIR/home" -mindepth 1 -type d | sed "s|^$AGENT_READY_DIR/home|$HOME|"
    } |
        while IFS= read -r d; do [[ -d $d ]] && find "$d" -maxdepth 1 -type l -print0 2>/dev/null; done
)

# PROJECTS_DIR, resolved once by bash (as install.sh reads config.env), for the
# shells: they read this one line instead of executing config.env at every login.
mkdir -p "$HOME/.config/dotfiles"
printf '%s\n' "$PROJECTS_DIR" >"$HOME/.config/dotfiles/projects_dir"
# b-claude / b-codex skip their [y/N] in full-control mode.
if is_true "$FULL_CONTROL"; then echo true; else echo false; fi >"$HOME/.config/dotfiles/full_control"

log "git identity"
git_local="$HOME/.config/git/local"
if [[ -n ${GIT_NAME:-} && $GIT_NAME != "Your Name" ]]; then
    git config --file "$git_local" user.name "$GIT_NAME"
elif [[ -z $(git config user.name 2>/dev/null) ]]; then
    warn "GIT_NAME not set in config.env — set it, or: git config --file $git_local user.name 'Your Name'"
fi
if [[ -n ${GIT_EMAIL:-} && $GIT_EMAIL != "you@example.com" ]]; then
    git config --file "$git_local" user.email "$GIT_EMAIL"
elif [[ -z $(git config user.email 2>/dev/null) ]]; then
    warn "GIT_EMAIL not set in config.env — set it, or: git config --file $git_local user.email 'you@example.com'"
fi

log "bash hooks (agents and scripts run bash even though fish is the login shell)"
add_line() {
    local file=$1 line=$2
    if [[ -L $file ]]; then
        # Managed elsewhere (another dotfiles repo): don't turn the link into a file.
        grep -qxF "$line" "$file" 2>/dev/null ||
            warn "$file is a symlink — add this line to it yourself: $line"
        return 0
    fi
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
if [[ -L $HOME/.bashrc ]]; then
    # Managed elsewhere (another dotfiles repo): don't turn the link into a file.
    grep -qxF "$bashrc_line" "$HOME/.bashrc" 2>/dev/null ||
        warn "~/.bashrc is a symlink — add this line at its top yourself: $bashrc_line"
elif [[ -e $HOME/.bashrc && ! -r $HOME/.bashrc ]]; then
    die "~/.bashrc exists but can't be read — fix its permissions, then re-run (not rewriting it)"
elif ! grep -qxF "$bashrc_line" "$HOME/.bashrc" 2>/dev/null; then
    {
        printf '# ~/.dotfiles (kept above the interactive guard)\n%s\n\n' "$bashrc_line"
        # A fresh account (macOS uses zsh) may have no ~/.bashrc yet.
        if [[ -e $HOME/.bashrc ]]; then cat "$HOME/.bashrc"; fi
    } >"$HOME/.bashrc.new" || die "couldn't write ~/.bashrc.new (disk full?) — ~/.bashrc left as it was"
    # Never replace it with something shorter than what was there plus our lines.
    if [[ -e $HOME/.bashrc ]] && (($(wc -c <"$HOME/.bashrc.new") <= $(wc -c <"$HOME/.bashrc"))); then
        rm -f "$HOME/.bashrc.new"
        die "the new ~/.bashrc came out shorter than the old one — not replacing it"
    fi
    mv "$HOME/.bashrc.new" "$HOME/.bashrc"
fi
ok "~/.profile and ~/.bashrc source ~/.dotfiles/shell/"

log "Secrets file"
secrets="$HOME/.config/secrets.env"
if [[ ! -f $secrets ]]; then
    # (BSD install on macOS has no -D)
    mkdir -p "$(dirname "$secrets")"
    install -m 600 "$AGENT_READY_DIR/secrets.env.example" "$secrets"
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
