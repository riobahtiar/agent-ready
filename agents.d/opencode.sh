# shellcheck shell=bash
# OpenCode (sst) — vendor installer into ~/.opencode/bin. https://opencode.ai/docs
agent_define opencode \
    title="OpenCode" \
    wrapper=b-opencode \
    herdr=opencode \
    guide="~/.config/opencode/AGENTS.md" \
    login="opencode auth login" \
    paths="~/.opencode" \
    config="~/.config/opencode ~/.local/share/opencode"

opencode_install() { _vendor_script https://opencode.ai/install; }
opencode_update() { opencode upgrade; }
