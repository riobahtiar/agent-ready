# Changelog

## Unreleased

### Added

- MIT license, contribution and security policies, a code of conduct, GitHub issue/PR templates, and static-check CI.
- Setup and installation FAQ, dummy configuration examples, and source-linked desktop compatibility documentation.
- Optional desktop-only application selection (`DESKTOP_APPS`) for OrbStack, TablePro, Zed, Ghostty, Tailscale, ChatGPT desktop, Claude desktop, Helium Browser, Cloudflare WARP, Obsidian, and the macOS Mole CLI. Empty/`none` installs nothing; apps without a native package on the current platform warn and are skipped.
- Environment-variable configuration with private persistence during installation; read-only installer commands leave configuration unchanged.

### Changed

- Replaced machine-specific names, private links, and personal system assumptions with configurable settings and documentation-safe examples.
- Documented the recorded Ubuntu LTS container verification and unverified desktop-platform limitations separately.
- Added source-verified Docker loopback defaults for newly created user-defined bridge networks, explicit localhost Compose examples, and existing-network/older-engine caveats.
- Clarified unattended agent permissions, secret handling, optional services, and third-party licensing responsibilities.

### Fixed

- Bootstrap username/argument handling, cloud-user SSH-key fallback, private owner-side configuration writes, and cross-distribution password-status handling.
- CLI help paths that could otherwise perform setup actions, desktop-specific menus, optional feature prompts, and operating-system portability issues.
- Git-identity placeholders, symlinked shell startup-file preservation, Intel macOS Flutter SDK selection, sandbox resource defaults, and static-check compatibility with current Gitleaks.
- Matched CI and local ShellCheck/shfmt versions through the pinned mise toolchain, avoiding formatter-version-only failures.
- Environment overrides ignore values inherited from a parent dotfiles process or exported by the login shell (`secrets.env`, `projects_dir`), and are saved to `config.env` only after validation.
- Bootstrap copies cloud-init root SSH keys without their forced-command/option prefix; `FULL_CONTROL` truthy parsing matches `is_true`.
- Desktop apps without a native package on the current OS warn and skip; macOS casks install with `--adopt` so existing `/Applications` copies are adopted.
- `notify` prefers a dedicated bot in `~/.config/secrets.env` over the Hermes bot; `update-all --quick` never uses sudo.
- `doctor` SSH unit and nginx detection; `motd` on console logins; Docker restart prompt; `add_line` warns on symlinked files.
- Claude `sandbox.enabled` set explicitly to `false` is preserved; `scripts/check.sh` shows Gitleaks output.
