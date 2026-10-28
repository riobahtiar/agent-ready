# shellcheck shell=bash
# agents.d/<name>.sh — one module per agent CLI. Copy with `agents new <name>`.
# Files starting with "_" are skipped; agents.d/retired/ is never loaded.
#
# Required: agent_define + <name>_install. Everything else is optional:
#   <name>_update     default: re-run <name>_install
#   <name>_uninstall  default: rm -rf the `paths` below
#   <name>_version    default: `<bin> --version`, first x.y.z found
#   <name>_configure  runs after install in stage 70 (settings, plugins)
# Helpers: _vendor_script <url> [sh|bash], have, step/ok/warn, mise.

agent_define NAME \
    title="Product Name (Vendor)" \
    bin=NAME \
    wrapper=- \
    herdr=- \
    guide=- \
    login="NAME login" \
    paths="~/.local/bin/NAME" \
    config="~/.NAME" \
    os="linux macos"

NAME_install() { _vendor_script https://example.com/install.sh; }
NAME_update() { NAME update; }
