#!/usr/bin/env bash
# stage-user: root
# stage-os: linux+systemd
# stage-profile: all
# stage-desc: Docker Engine + compose/buildx (official repo, distro fallback), loopback defaults for new bridge networks
set -Eeuo pipefail
source "$DOTFILES_DIR/lib/common.sh"
source "$DOTFILES_DIR/lib/pkg.sh"
load_config
# (macOS: use OrbStack or Docker Desktop — docs/08-multi-os.md.)

if ! is_true "$DOCKER"; then
    step "DOCKER=false — skipping (using Podman, Docker Desktop or none)"
    exit 0
fi

if ((IS_WSL)) && [[ -d /mnt/wsl/docker-desktop ]]; then
    step "Docker Desktop's WSL integration provides docker here — skipping the engine"
    exit 0
fi

install_debian() {
    local codename docker_os=ubuntu
    [[ $OS_ID == debian ]] && docker_os=debian
    codename="$(ubuntu_codename)"
    as_root install -m 0755 -d /etc/apt/keyrings
    fetch "https://download.docker.com/linux/$docker_os/gpg" | as_root tee /etc/apt/keyrings/docker.asc >/dev/null
    as_root chmod a+r /etc/apt/keyrings/docker.asc
    as_root tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/$docker_os
Suites: $codename
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    as_root apt-get update -qq || true
    # A brand-new LTS can land before Docker publishes its suite; fall back to Ubuntu's build.
    if apt-cache policy docker-ce 2>/dev/null | grep -q 'Candidate: [0-9]'; then
        apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ok "docker-ce from download.docker.com ($codename)"
    else
        warn "download.docker.com has no '$codename' suite yet — using Ubuntu's docker.io"
        as_root rm -f /etc/apt/sources.list.d/docker.sources
        as_root apt-get update -qq
        apt_install_available docker.io docker-compose-v2 docker-buildx
    fi
}

log "Docker Engine"
if ! have docker; then
    case $OS_FAMILY in
    debian) install_debian ;;
    arch) pkg_install docker docker-compose docker-buildx ;;
    fedora) pkg_install moby-engine docker-compose ;;
    *)
        warn "no Docker recipe for $OS_PRETTY — install Docker yourself, then: ./install.sh docker"
        exit 0
        ;;
    esac
fi

# A `docker` command without the engine's systemd unit is Docker Desktop for
# Linux or podman-docker: their daemon isn't ours to configure.
if ! systemctl cat docker.service >/dev/null 2>&1; then
    step "docker here isn't the Docker Engine service (Docker Desktop / podman?) — leaving it alone"
    exit 0
fi

# Docker documents an L2 localhost-publishing exposure in Engine versions <28.
# https://docs.docker.com/engine/network/port-publishing/
engine_version="$(dockerd --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
engine_major=${engine_version%%.*}
if [[ $engine_major =~ ^[0-9]+$ ]] && ((engine_major < 28)); then
    warn "Docker $engine_version: upgrade to Engine 28+ before relying on localhost-published ports being private from other L2 hosts"
fi

if is_true "${GVISOR:-false}" && ! have runsc; then
    log "gVisor (runsc): a user-space kernel for untrusted containers (sandbox box)"
    if [[ $OS_FAMILY == debian ]]; then
        fetch https://gvisor.dev/archive.key | as_root gpg --dearmor --yes -o /usr/share/keyrings/gvisor-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/gvisor-archive-keyring.gpg] https://storage.googleapis.com/gvisor/releases release main" |
            as_root tee /etc/apt/sources.list.d/gvisor.list >/dev/null
        as_root apt-get update -qq && apt_install runsc || warn "runsc install failed — sandbox box uses runc"
    else
        warn "gVisor packages are Debian/Ubuntu only here — install runsc yourself (AUR: gvisor-bin)"
    fi
fi

log "daemon.json"
daemon_json=/etc/docker/daemon.json
# Merge, don't replace: keys another tool set (Omarchy, Docker Desktop, you)
# stay; ours (127.0.0.1 binds, log rotation, …) win where both set one. Plus
# the runsc runtime when gVisor is installed.
desired="$(mktemp)"
existing='{}'
as_root test -s "$daemon_json" && existing="$(as_root cat "$daemon_json")"
jq -n --argjson have "$existing" --slurpfile ours "$DOTFILES_DIR/system/docker-daemon.json" '$have * $ours[0]' >"$desired"
if have runsc; then
    jq --arg p "$(command -v runsc)" '.runtimes.runsc.path = $p' "$desired" >"$desired.new" && mv "$desired.new" "$desired"
fi
if ! as_root cmp -s "$desired" "$daemon_json" 2>/dev/null; then
    if dockerd --validate --config-file "$desired" >/dev/null 2>&1; then
        [[ -f $daemon_json ]] && as_root cp "$daemon_json" "$daemon_json.bak"
        install_file "$desired" "$daemon_json"
        # A restart can disrupt running containers. New bridge-network defaults
        # do not migrate existing networks or override explicit host bindings.
        running="$( (as_root docker ps -q 2>/dev/null || true) | wc -l | xargs)" # daemon may be down
        if ((running > 0)) && ! { has_tty && ASSUME_YES=0 confirm "  Restart Docker now? $running container(s) may stop; existing networks/bindings are not migrated [y/N] "; }; then
            stage_incomplete "daemon.json installed, but Docker NOT restarted ($running containers running) — restart it when convenient: sudo systemctl restart docker"
        elif as_root systemctl restart docker; then
            ok "installed (log rotation, 127.0.0.1 default bind, live-restore$(have runsc && echo ', runsc runtime'))"
        else
            warn "docker failed to restart with the new daemon.json — restoring the previous one"
            if [[ -f $daemon_json.bak ]]; then as_root cp "$daemon_json.bak" "$daemon_json"; else as_root rm -f "$daemon_json"; fi
            as_root systemctl restart docker || warn "docker still doesn't start: journalctl -u docker -n 50"
            stage_incomplete "daemon.json rejected at runtime"
        fi
    else
        warn "dockerd rejected the daemon config — keeping the current one"
        dockerd --validate --config-file "$desired" || true
        stage_incomplete "Docker configuration not applied; default-network-opts requires Engine 24+ — review the validation error"
    fi
fi
rm -f "$desired" "$desired.new"
as_root systemctl enable --now docker containerd >/dev/null 2>&1 || as_root systemctl enable --now docker >/dev/null

if is_true "$DOCKER_SUDOLESS" && ! id -nG "$TARGET_USER" | grep -qw docker; then
    # Agents run docker without a password prompt; the group is root-equivalent.
    as_root usermod -aG docker "$TARGET_USER"
    warn "$TARGET_USER added to the docker group — log out/in to use docker without sudo"
elif ! is_true "$DOCKER_SUDOLESS"; then
    step "DOCKER_SUDOLESS=false — use 'sudo docker …' (set it true to let agents run docker)"
fi
ok "$(docker --version) · $(docker compose version 2>/dev/null || echo 'compose missing')"
