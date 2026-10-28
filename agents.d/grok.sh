# shellcheck shell=bash
# Grok Build (xAI) — vendor installer into ~/.grok/bin.
agent_define grok \
    env="XAI_API_KEY" \
    title="Grok Build (xAI)" \
    wrapper=b-grok \
    herdr=grok \
    login="grok login --device-auth" \
    paths="~/.grok/bin" \
    config="~/.grok"

grok_install() { _vendor_script https://x.ai/cli/install.sh; }
