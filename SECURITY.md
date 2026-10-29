# Security Policy

## Scope

`dotfiles-cloud` provisions servers and desktops for running AI coding agents. On the `server` profile, its scripts configure security-sensitive components including OpenSSH (`sshd`), firewall rules (`ufw`), `fail2ban`, `sudoers` (`FULL_CONTROL`), `nginx` + Let's Encrypt TLS, Docker daemon bindings, `bubblewrap` / AppArmor sandboxing, and optional agent dashboards.

Security reports are welcome for:
- Privilege escalation, symlink traversal, or command injection in `bootstrap.sh`, `install.sh`, `stages/`, `lib/`, or `bin/`
- Unintended network exposure (e.g., services or container ports bound to `0.0.0.0` without explicit opt-in)
- Secret leakage (tokens or passwords exposed on process command lines, world-readable files, logs, or child installer environments)
- SSH lockout or authentication bypass edge cases in `bootstrap.sh` or `stages/20-security.sh`
- Sandbox bypasses in `bin/sandbox` or `home/.srt-settings.json`

## Supported Versions

Security fixes target the latest `main` branch. Older snapshots and third-party forks have no separate maintenance commitment. Third-party agent installers and packages have their own security policies and release cycles.

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Please report vulnerabilities privately through [GitHub Private Vulnerability Reporting](https://github.com/riobahtiar/dotfiles-cloud/security/advisories/new) on this repository.

Repository maintainers must enable private vulnerability reporting in GitHub Settings before public release. While the repository is private, the reporting link may be unavailable; do not post sensitive findings in public issues or pull requests.

Include:
1. Affected file(s), stage(s), or command(s)
2. Target OS and profile (`server` or `desktop`)
3. Minimal reproduction steps or proof of concept
4. Impact assessment and any suggested mitigation

## Security Model & Built-in Safeguards

- **Perimeter defaults (`server` profile):** Key-only SSH after a verified public-key login, disabled root SSH, `ufw` on 22/80/443, and `fail2ban`. Docker's default bridge and newly created user-defined bridges default to loopback publishing; existing networks, explicit public binds, direct-routing overrides, and Swarm remain your responsibility. Use explicit loopback binds and Docker Engine 28+; [older engines have a documented localhost-port L2 exposure](https://docs.docker.com/engine/network/port-publishing/).
- **`FULL_CONTROL` trade-off:** On the `server` profile, `FULL_CONTROL` defaults to `true` for unattended agent workflows (passwordless `sudo` validated via `visudo`, `docker` group membership, and skipped agent permission prompts). If you want password-gated `sudo` and interactive agent approvals on a server, set `FULL_CONTROL=false` and `AGENT_SANDBOX=true` in `config.env` before installing.
- **Root-to-user boundary:** User-owned paths should be written through `run_as_user`, with sensitive values on stdin and atomic file replacement. Review any changes crossing this boundary; `config.env` is executable Bash and must be trusted before running the installer with sudo.
- **Secret handling:** Keep `config.env`, `~/.config/secrets.env`, and `~/.hermes/.env` private (`0600`) and untracked. Machine secret keys are not intentionally exported to child vendor installers. `GITHUB_TOKEN` is deliberately forwarded as `MISE_GITHUB_TOKEN` for release downloads; shell API keys are also available to commands you launch. Do not treat environment variables or agent deny rules as a security boundary against an agent with root access.

## Operational Responsibility & Disclaimer

This repository modifies system, network, authentication, and privilege settings and installs third-party AI coding agents capable of executing arbitrary commands.

**You are responsible for reviewing the scripts, understanding your configuration (`config.env`), maintaining backups, securing your credentials, and monitoring machines and AI agents you operate.** The [MIT License](LICENSE) provides the software **"AS IS"**, without warranty, and disclaims authors' and copyright holders' liability to the fullest extent permitted by applicable law. This includes risks such as lockouts, data loss, unauthorized access, third-party tool behavior, and cloud/API charges; no license guarantees protection from every legal claim.
