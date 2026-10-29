#!/usr/bin/env bash
# setup-desktop.sh — set up a machine you sit at: macOS (Homebrew + mise),
# Arch/Omarchy, Ubuntu/Fedora desktop or WSL. You get packages, fish + the
# easy-eel prompt, mise runtimes and CLIs, agent CLIs, sandboxing, Docker
# (Linux), Tailscale and dev tunnels. Skipped on purpose: nginx, ufw/fail2ban,
# SSH hardening, swap/kernel tuning, Hermes dashboard, the 04:00 cleanup timer.
# Takes the same flags as install.sh (--changed, --renew, -y, <stage>…).
#
#   git clone https://github.com/riobahtiar/dotfiles-cloud ~/.dotfiles
#   ~/.dotfiles/setup-desktop.sh
#
# Already have other dotfiles in ~/.config/fish? They're backed up to
# ~/.dotfiles-backup/<time>/ before linking. docs/08-multi-os.md
set -eu
cd "$(dirname "$0")"
PROFILE_OVERRIDE=desktop exec ./install.sh "$@"
