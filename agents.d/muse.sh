# shellcheck shell=bash
# Muse Code (Meta) — vendor installer into ~/.local/bin; no Herdr hook here.
# Upstream documents --yolo, --disable-approval, and --disable-sandbox.
agent_define muse \
    env="META_API_KEY" \
    title="Muse Code (Meta)" \
    login="muse   then type /login" \
    paths="~/.local/bin/muse"

muse_install() { _vendor_script https://dev.meta.ai/install.sh; }
