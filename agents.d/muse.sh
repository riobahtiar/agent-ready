# shellcheck shell=bash
# Muse Code (Meta) — vendor installer into ~/.local/bin. No herdr hook and no
# documented bypass flag yet (add a b-muse wrapper once there is one).
agent_define muse \
    env="META_API_KEY" \
    title="Muse Code (Meta)" \
    login="muse login" \
    paths="~/.local/bin/muse"

muse_install() { _vendor_script https://dev.meta.ai/install.sh; }
