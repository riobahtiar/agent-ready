# Changelog

## Unreleased

### Added

- MIT license, contribution and security policies, a code of conduct, GitHub issue/PR templates, and static-check CI.
- Setup and installation FAQ, dummy configuration examples, and source-linked desktop compatibility documentation.
- Optional desktop-only application selection (`DESKTOP_APPS`) for OrbStack, TablePro, Zed, Ghostty, Tailscale, ChatGPT desktop, Claude desktop, Helium Browser, Cloudflare WARP, Obsidian, and the macOS Mole CLI. Empty/`none` installs nothing; unsupported platforms are skipped, and unavailable configured packages are reported incomplete.
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
