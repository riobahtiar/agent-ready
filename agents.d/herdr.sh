# shellcheck shell=bash
# Herdr — agent-aware terminal multiplexer (sessions survive SSH drops, agent
# state in the sidebar). https://herdr.dev/docs/
agent_define herdr \
    title="Herdr (multiplexer)" \
    login="-" \
    paths="~/.local/bin/herdr" \
    config="~/.config/herdr"

herdr_install() { _vendor_script https://herdr.dev/install.sh sh; }
herdr_update() { herdr update; }
