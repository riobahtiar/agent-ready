# shellcheck shell=bash
# Hermes Agent (Nous Research) — installed by stages/80-hermes.sh (server
# profile: dashboard + nginx + Telegram gateway). On a desktop, `agents
# install hermes` gives you just the CLI.
agent_define hermes \
    env="ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY" \
    state="~/.hermes/sessions ~/.hermes/logs" \
    title="Hermes Agent (Nous)" \
    wrapper=b-hermes \
    herdr=hermes \
    login="hermes setup   then hermes-up (Telegram gateway)" \
    paths="~/.hermes/hermes-agent ~/.local/bin/hermes" \
    config="~/.hermes" \
    managed="stage:hermes"

# --non-interactive: the installer otherwise opens /dev/tty itself and runs
# `hermes setup` + `gateway install` mid-provisioning (that's hermes-up's job).
# --skip-computer-use on a machine without a desktop: that driver controls a
# GUI (needs libXi & co.) and fails verification on a headless VPS.
hermes_install() {
    local -a args=(--non-interactive)
    os_has_desktop || args+=(--skip-computer-use)
    _vendor_script https://hermes-agent.nousresearch.com/install.sh bash "${args[@]}"
}
hermes_update() { hermes update; }
hermes_uninstall() {
    if [[ $OS_KIND == linux ]] && systemctl cat hermes-dashboard >/dev/null 2>&1; then
        warn "stopping Hermes services (sudo)"
        sudo systemctl disable --now hermes-dashboard hermes-gateway 2>/dev/null || true
        sudo rm -f /etc/systemd/system/hermes-dashboard.service
        sudo systemctl daemon-reload
        warn "set HERMES=false in config.env and remove the vhost: site rm \$HERMES_DOMAIN"
    fi
    local p
    for p in "$HOME/.hermes/hermes-agent" "$HOME/.local/bin/hermes"; do
        [[ -e $p || -L $p ]] && rm -rf -- "$p" && step "removed ${p/#$HOME/\~}"
    done
}
