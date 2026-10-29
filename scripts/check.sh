#!/usr/bin/env bash
# check.sh — static checks for this repo (no network, no root, safe on macOS).
#   ./scripts/check.sh      or      mise run check
set -Eeuo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

fail=0
note() { printf '%s\n' "$*" >&2; }

# (no mapfile: macOS still ships bash 3.2)
sh_files=()
while IFS= read -r f; do sh_files+=("$f"); done < <({
    ls install.sh bootstrap.sh setup-*.sh lib/*.sh stages/*.sh scripts/*.sh shell/*.sh agents.d/*.sh tunnels.d/*.sh
    grep -l '^#!/usr/bin/env bash' bin/*
} | sort -u)

note "bash -n (${#sh_files[@]} files)"
for f in "${sh_files[@]}"; do bash -n "$f" || fail=1; done

note "sh -n (certbot reload hook)"
sh -n system/certbot-reload-nginx.sh || fail=1

if command -v shellcheck >/dev/null; then
    note "shellcheck"
    shellcheck -x -S warning "${sh_files[@]}" || fail=1
else
    note "shellcheck not installed — skipped (mise install)"
fi

if command -v fish >/dev/null; then
    note "fish -n"
    while IFS= read -r f; do fish -n "$f" || fail=1; done < <(find home -name '*.fish')
fi

note "stage headers"
for f in stages/[0-9]*.sh; do
    grep -qE '^# stage-user: (root|user)$' "$f" || {
        note "  $f: missing '# stage-user: root|user'"
        fail=1
    }
    grep -q '^# stage-desc: ' "$f" || {
        note "  $f: missing '# stage-desc:'"
        fail=1
    }
    stage_os=$(grep '^# stage-os: ' "$f" || true)
    if [[ ! $stage_os =~ ^'# stage-os: '[a-z]+([,+][a-z]+)*$ ]]; then
        note "  $f: missing or malformed '# stage-os:'"
        fail=1
    else
        IFS=',+' read -r -a os_tokens <<<"${stage_os#\# stage-os: }"
        for token in "${os_tokens[@]}"; do
            if [[ ! $token =~ ^(any|linux|macos|debian|arch|fedora|systemd|wsl|nowsl)$ ]]; then
                note "  $f: unknown stage-os token '$token'"
                fail=1
            fi
        done
    fi
    grep -qE '^# stage-profile: (all|server|desktop)$' "$f" || {
        note "  $f: missing '# stage-profile: all|server|desktop'"
        fail=1
    }
done

note "modules"
for f in agents.d/[!_]*.sh; do
    n="$(basename "$f" .sh)"
    grep -q "^agent_define $n " "$f" || {
        note "  $f: must call 'agent_define $n …'"
        fail=1
    }
    grep -q "^${n}_install()" "$f" || {
        note "  $f: must define ${n}_install"
        fail=1
    }
done
for f in tunnels.d/[!_]*.sh; do
    n="$(basename "$f" .sh)"
    grep -q "^tunnel_define $n " "$f" || {
        note "  $f: must call 'tunnel_define $n …'"
        fail=1
    }
    for fn in ready start; do grep -q "^${n}_$fn()" "$f" || {
        note "  $f: must define ${n}_$fn"
        fail=1
    }; done
done
for f in home/.config/mise/conf.d/[1-9]*.toml; do
    grep -q '^\[tools\]' "$f" || {
        note "  $f: no [tools] table"
        fail=1
    }
done
python3 -m json.tool home/.srt-settings.json >/dev/null || fail=1

note "templates"
for t in nginx/templates/*.conf; do
    head -1 "$t" | grep -q '^# site: __DOMAIN__ type=' || {
        note "  $t: first line must be '# site: __DOMAIN__ type=…' (site ls parses it)"
        fail=1
    }
done
python3 -m json.tool system/docker-daemon.json >/dev/null || fail=1

note "secrets"
if git ls-files --error-unmatch config.env >/dev/null 2>&1; then
    note "  config.env is tracked!"
    fail=1
fi
# (a mise shim without an installed version exists but can't run: test it)
if gitleaks version >/dev/null 2>&1; then gitleaks detect --no-banner --redact --log-level warn || fail=1; fi

((fail)) && {
    note "FAILED"
    exit 1
}
note "ok"
