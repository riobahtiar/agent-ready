#!/usr/bin/env bash
# stage-user: root
# stage-os: linux+systemd
# stage-profile: all
# stage-desc: weekly `cleanup --auto` timer, final health check
set -Eeuo pipefail
source "$AGENT_READY_DIR/lib/common.sh"
load_config

if is_true "$CLEANUP_TIMER"; then
    log "cloud-cleanup.timer"
    for unit in cloud-cleanup.service cloud-cleanup.timer; do
        render "$AGENT_READY_DIR/systemd/$unit" USER="$TARGET_USER" HOME="$TARGET_HOME" |
            as_root tee "/etc/systemd/system/$unit" >/dev/null
    done
    as_root systemctl daemon-reload
    as_root systemctl enable --now cloud-cleanup.timer >/dev/null 2>&1
    ok "next run: $(systemctl show cloud-cleanup.timer -p NextElapseUSecRealtime --value 2>/dev/null || echo '?')"
else
    as_root systemctl disable --now cloud-cleanup.timer >/dev/null 2>&1 || true
fi

log "Health check"
run_as_user "$AGENT_READY_DIR/bin/doctor" --brief || true
