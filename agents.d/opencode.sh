# shellcheck shell=bash
# OpenCode 1 — vendor installer into ~/.opencode/bin. https://opencode.ai/docs
agent_define opencode \
    env="ANTHROPIC_API_KEY OPENAI_API_KEY OPENROUTER_API_KEY GEMINI_API_KEY" \
    state="~/.local/share/opencode/storage ~/.local/share/opencode/log" \
    title="OpenCode" \
    wrapper=b-opencode \
    herdr=opencode \
    guide="~/.config/opencode/AGENTS.md" \
    login="opencode auth login" \
    paths="~/.opencode" \
    config="~/.config/opencode ~/.local/share/opencode"

opencode_install() { _vendor_script https://opencode.ai/install; }
opencode_update() { opencode upgrade; }
