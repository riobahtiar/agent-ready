# Contributing

Contributions that improve portability, reliability, security, or documentation are welcome. Before opening a pull request, read how the repository is structured and what invariants every change must keep.

## Core Principles

1. **Idempotent or it doesn't ship.** Every stage (`stages/*.sh`) and CLI command (`bin/*`) must be safe to run repeatedly. Check state before mutating (`have`, `grep -q`, `cmp -s`).
2. **Never leave a service broken.** Always validate configs before reloading or restarting (`nginx -t`, `sshd -t`, `visudo -cf`, `dockerd --validate`) and roll back automatically on failure.
3. **Merge, don't clobber, on desktops.** Desktop environments (macOS, Omarchy/Arch, Ubuntu/Fedora desktop, WSL) already manage their own settings. Merge JSON configs with `jq`, preserve existing user files in `~/.dotfiles-backup/<timestamp>/`, and never touch `~/.config/mise/config.toml`.
4. **Menus for humans, flags for machines.** Interactive prompts (`lib/ui.sh`) may run **only** when `ui_interactive` is true and no CLI arguments were passed. Every menu action must have an equivalent non-interactive flag form so scripts and AI agents never hang on TTY input.
5. **No secrets or personal data.** Never include real domains, usernames, email addresses, IP addresses, or tokens in scripts, configs, comments, or commit messages. Use environment variables / `config.env` and RFC-reserved dummy values (`example.com`, `203.0.113.0/24`, `deploy`, `you@example.com`).
6. **Docs move with behavior.** Updating a stage, command, config key, or module requires updating the corresponding guide(s) in `docs/` (including `docs/08-multi-os.md`, `docs/10-reference.md`, `docs/15-what-gets-installed.md`, or `docs/16-faq.md` when applicable).

For deep implementation details, platform quirks (macOS Bash 3.2 bootstrap, Ubuntu `sudo-rs` / AppArmor `bwrap`, Arch `pacman -Syu`), and root/user security boundaries, read **[AGENTS.md](AGENTS.md)** and **[docs/10-reference.md](docs/10-reference.md)**.

## Common Additions

- **New coding agent CLI:** Run `bin/agents new <name>`, implement the hooks in `agents.d/<name>.sh` (see `agents.d/_template.sh`), and update `docs/06-tools-and-agents.md`.
- **New CLI tool / runtime:** Verify the package exists in `mise registry`, then add it to the appropriate `home/.config/mise/conf.d/*.toml` file (one invalid tool name breaks `mise install`).
- **New dev tunnel provider:** Copy `tunnels.d/_template.sh` to `tunnels.d/<id>.sh` and update `docs/07-networking.md`.
- **New OS package:** Use its Debian package name in the stage via `pkg_install` and add a mapping row in `PKG_TABLE` (`lib/pkg.sh`) if Arch, Fedora, or Homebrew uses a different package name.
- **New provisioning stage:** Create `stages/NN-name.sh` with all required `# stage-*:` metadata headers (`stage-user`, `stage-os`, `stage-profile`, `stage-desc`).

## Style & Static Checks

- **Bash:** `set -Eeuo pipefail`, 4-space indentation, unindented `case` labels (`shfmt -i 4`), `[[ ]]`, quote expansions, no secrets on command lines. `scripts/check.sh` itself must stay Bash 3.2-compatible so it runs unmodified on stock macOS.
- **Fish:** Every function needs `--description`, use `set -l` for locals, `command <bin>` when wrapping binaries, `abbr` over `alias`, `fish_add_path --path --move`, and never use `eval`.

Run formatting and static checks locally before committing:

```bash
mise install          # installs shellcheck and shfmt from mise.toml
mise run fmt          # formats shell scripts (shfmt -w -i 4)
mise run check        # bash -n, sh -n, shellcheck, fish -n, stage headers, module contracts, JSON/nginx templates, gitleaks
```

`mise.toml` pins ShellCheck and shfmt, and CI uses those same versions through
the [official mise action](https://github.com/jdx/mise-action). Do not substitute
an older distro formatter: formatting rules can differ across versions.
Fish and Gitleaks checks run when those executables are available.

## Testing Provisioning Changes

Changes to `stages/`, `bootstrap.sh`, `nginx/templates/`, or `bin/cleanup` should be smoke-tested in a disposable container before submitting:

- **Ubuntu LTS (systemd):** Launch an Ubuntu LTS container with `--privileged` and `/sbin/init`, copy the checkout into `/root/dotfiles-cloud` (avoid `/tmp`, which `systemd` mounts over), bootstrap a test user, and run `./setup-server.sh --all -y` followed by `./setup-server.sh --changed -y` to verify idempotency.
- **Arch Linux:** Test `pacman` package mapping and user stages in an `archlinux` container.
- **Interactive menus:** Verify both TTY menu mode and flag-driven non-TTY mode (`--help`, missing-arg errors, `-y`).

## Pull Request Process

1. Fork the repository and create a topic branch from `main`.
2. Keep each pull request focused on a single concern.
3. Ensure `mise run fmt` produces no diffs and `mise run check` passes cleanly.
4. Fill out the pull request template with what changed, why, and how you verified it.

By submitting a contribution, you agree that your contribution is licensed under the repository's [MIT License](LICENSE).
