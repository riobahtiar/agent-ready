#!/usr/bin/env bash
# stage-user: root
# stage-os: any
# stage-profile: desktop
# stage-inputs: lib/desktop-apps.sh
# stage-desc: opt-in desktop apps from DESKTOP_APPS (empty or none installs nothing)
set -Eeuo pipefail
source "$AGENT_READY_DIR/lib/common.sh"
source "$AGENT_READY_DIR/lib/pkg.sh"
source "$AGENT_READY_DIR/lib/desktop-apps.sh"
load_config

# Retain the desktop boundary even when this script is invoked directly.
if [[ $PROFILE != desktop ]]; then
    step 'Desktop apps: skipped outside PROFILE=desktop'
    exit 0
fi

# read to EOF, not just the first newline; disable glob expansion by iterating
# an array so malformed IDs cannot expand into repository filenames.
selected=()
IFS=$' \t\n' read -r -d '' -a selected <<<"${DESKTOP_APPS:-}" || true
invalid=0
has_none=0
has_apps=0
for app in "${selected[@]}"; do
    if [[ $app == none ]]; then
        has_none=1
    elif desktop_app_label "$app" >/dev/null; then
        has_apps=1
    else
        invalid=1
    fi
done
if ((has_none && has_apps)); then
    warn "DESKTOP_APPS: 'none' cannot be combined with app IDs"
    invalid=1
fi
if ((invalid)); then
    stage_incomplete 'DESKTOP_APPS contains invalid selections — no desktop apps installed; correct config.env and retry desktop-apps'
    exit 0
fi
if ((! has_apps)); then
    step 'Desktop apps: none selected (existing apps are left installed)'
    exit 0
fi

log "Optional desktop apps: ${selected[*]}"
declare -A seen=()
for app in "${selected[@]}"; do
    [[ -z ${seen[$app]:-} ]] || continue
    seen[$app]=1
    desktop_app_install "$app" || stage_incomplete "$app: desktop app installation failed; other apps will continue"
done
