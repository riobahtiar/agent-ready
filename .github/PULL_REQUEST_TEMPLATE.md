## Summary

<!-- Describe what this changes for AgentReady users and why. -->

## Related Issue

<!-- e.g. Fixes #123, or N/A -->

## Scope of Change

- [ ] Provisioning stages (`stages/`, `bootstrap.sh`, `install.sh`, `setup-*.sh`)
- [ ] Shared libraries (`lib/`)
- [ ] CLI commands (`bin/`)
- [ ] Agent or tunnel modules (`agents.d/`, `tunnels.d/`)
- [ ] Shell / dotfiles / `mise` tools (`home/`, `shell/`)
- [ ] System / nginx / systemd templates (`system/`, `nginx/`, `systemd/`)
- [ ] Documentation (`README.md`, `docs/`)

## Verification Checklist

- [ ] `mise run fmt` produces no diff (`shfmt -i 4`)
- [ ] `mise run check` passes (`bash -n`, `shellcheck`, `fish -n`, stage headers, module contracts, templates)
- [ ] Changes are idempotent (safe to re-run without duplicating state or breaking services)
- [ ] Interactive changes work both in a terminal menu and non-interactively via CLI flags
- [ ] Relevant documentation in `docs/` has been updated to match behavior
- [ ] No secrets, tokens, personal usernames, real domains, or private IP addresses are included (RFC dummy values like `example.com` / `203.0.113.0/24` used instead)

## How Was This Tested?

<!-- Describe the OS/container/command used to verify this change (e.g., Ubuntu LTS container, Arch container, macOS, `mise run check`). -->
