# Fish Shell Configuration — cloud VPS (Ubuntu 26.04)
# Managed by ~/.dotfiles (home/.config/fish/config.fish). Mirrors the laptop
# config's structure: PATH → mise → interactive extras → secrets → functions.

# The easy-eel theme draws the greeting (cloud/prompt.fish); this only silences
# fish's stock one if the theme isn't installed yet.
set fish_greeting

# ─── Homebrew (macOS, Linuxbrew) — first, so everything below takes precedence ───
for brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
    if test -x $brew
        $brew shellenv fish | source
        break
    end
end

# ─── PATH (`--path` = this session only, not universal) ───
# Ad-hoc / vendored CLIs go to the tail first; mise activates last so managed
# runtimes always win. (`--move` puts a dir at the *new* position.)
fish_add_path --path --append --move \
    "$HOME/.opencode/bin" \
    "$HOME/.grok/bin" \
    "$HOME/.bun/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/go/bin" \
    "$HOME/.pub-cache/bin" \
    "$HOME/.config/composer/vendor/bin"

# Our commands (cleanup, site, doctor, …) and native agent installers (claude, muse, hermes)
fish_add_path --path --move "$HOME/.local/bin" "$HOME/.dotfiles/bin"

# ─── Runtime Version Manager (mise) ───
# Interactive shells get full activation (per-directory versions on cd).
# Everything else — `fish -c`, agents' subshells, cron — uses shims, which
# resolve the right version from the cwd at exec time.
if command -q mise
    if status is-interactive
        mise activate fish | source
    else
        mise activate fish --shims | source
    end
    # Shims as a fallback even when activated, so child processes that change
    # directory (agents, task runners) still resolve per-project versions.
    fish_add_path --path --append "$HOME/.local/share/mise/shims"
end

# ─── Environment ───
set -gx EDITOR (command -s nvim; or command -s vim; or echo nano)
set -gx VISUAL $EDITOR
set -gx PAGER less
set -gx LESS -R
# PROJECTS_DIR from config.env when set there (empty = ~/projects). config.env
# is bash syntax, so bash evaluates it (quotes, spaces, ~, $HOME), as install.sh does.
set -l projects
if test -r ~/.dotfiles/config.env
    set projects (command bash -c 'PROJECTS_DIR=; . "$HOME/.dotfiles/config.env" >/dev/null 2>&1; printf %s "$PROJECTS_DIR"' 2>/dev/null)
end
if test -n "$projects"
    set -gx PROJECTS_DIR $projects
else
    set -gx PROJECTS_DIR "$HOME/projects"
end
# Opt out of CLI telemetry (cf, wrangler, Next.js, Homebrew, … honour it).
set -gx DO_NOT_TRACK 1
# Headless Linux (the VPS): no browser for OAuth flows — agents print a URL or
# device code instead. Desktops, macOS and WSL keep their real browser.
if test (uname) = Linux; and not set -q DISPLAY; and not set -q WAYLAND_DISPLAY; and not set -q WSL_DISTRO_NAME
    set -q BROWSER; or set -gx BROWSER echo
end

# ─── Interactive-only: dir jump, fzf fallback (prompt: cloud/prompt.fish) ───
if status is-interactive
    if not functions -q _fzf_search_directory
        command -q fzf; and fzf --fish | source
    end

    command -q zoxide; and zoxide init fish | source
end

# ─── Secrets (POSIX KEY=VALUE, shared with bash; never commit) ───
# ~/.config/secrets.env is created from ~/.dotfiles/secrets.env.example.
if test -r ~/.config/secrets.env
    for line in (string match -rv '^\s*(#|$)' < ~/.config/secrets.env)
        set -l kv (string split -m 1 = -- (string replace -r '^\s*export\s+' '' -- $line))
        test (count $kv) -eq 2; or continue
        string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- (string trim -- $kv[1]); or continue
        set -l value (string replace -r '^([\'"])(.*)\1$' '$2' -- (string trim -- $kv[2]))
        test -n "$value"; and set -gx (string trim -- $kv[1]) $value
    end
end

# ─── Functions & abbreviations (multi-function files cannot autoload) ───
for file in ~/.config/fish/cloud/*.fish
    source $file
end

# ─── Vendor-Appended (installers write here; keep at EOF) ───
# NOTE: this file is a symlink into ~/.dotfiles. If an installer appends a
# block, move what's needed into the PATH section above and drop the rest.
