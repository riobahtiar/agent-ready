# Shell and prompt

fish is the login shell, structured cleanly in stages: PATH, then
mise, interactive extras, secrets, then everything in `~/.config/fish/cloud/*.fish`.
bash gets the same PATH, mise shims and secrets (`shell/profile.sh`,
`shell/bashrc.sh`) because agents and scripts run `bash -c`. bash keeps the
starship prompt.

## The prompt: easy-eel

The theme is [pgolebiowski/theme-easy-eel](https://github.com/pgolebiowski/theme-easy-eel),
installed by fisher from `fish_plugins`. Its settings and our additions are in
**`home/.config/fish/cloud/prompt.fish`**. Edit it, then `exec fish`.

```
dev at vps in shop/s/components on feat/cart [!☡+]       ✘ 1  4.2s  ⎇ worktree  bun 1.3  compose
↪
```

### Left: easy-eel sections

| Section | Shows | Our tuning |
|---|---|---|
| user | `dev` | cyan; **bold red when root** |
| host | short hostname | bold yellow over SSH (the theme's red reads like an alarm on a box you always SSH into) |
| directory | where you are | **project-relative inside `~/projects`**: `shop/s/components` instead of `~/p/s/s/components` |
| git | branch + state | `✓` clean · `!` dirty · `☡` untracked · `+` ahead (unpushed agent work) · `-` behind · `↩` stash |
| indicator | `↪` | red when the last command failed |

Colours take anything `set_color` accepts (`brblue`, `"--bold red"`, `ff8800`).
Hide a section with `set -g EASY_EEL_HIDE_USER true` (also `_HOST`,
`_CURRENT_DIRECTORY`, `_GIT_STATE`).

### Right: full-stack context (our `fish_right_prompt`)

Only what's true for the current directory, read from files and PATH: no
`node --version` subprocess on every prompt.

| Section | When it shows |
|---|---|
| `status` | `✘ 1`: the last command's exit code, when it failed |
| `duration` | how long the last command took, when ≥ `CLOUD_PROMPT_SLOW_MS` (3000) |
| `jobs` | `⚙ 2`: background jobs in this shell |
| `worktree` | `⎇ worktree`: inside `.worktrees/` or an agent's worktree |
| `node` | `package.json` without a bun lockfile → active Node version |
| `bun` | `bun.lock`/`bun.lockb`/`bunfig.toml` → Bun version |
| `go` | `go.mod` → Go version |
| `php` | `composer.json` → system PHP version |
| `python` | `pyproject.toml`/`requirements.txt`/`uv.lock`, or an active venv (`py 3.13 (.venv)`) |
| `flutter` | `pubspec.yaml` → Flutter version |
| `docker` | `compose` with a compose file, `docker` with only a Dockerfile |

Markers are searched from the current directory up to the repo root (or `~`).
Choose and order sections:

```fish
set -g CLOUD_PROMPT_RIGHT status duration git worktree bun go   # in prompt.fish
```

### Greeting and title

- On **SSH login** you get the greeting from `bin/motd` instead of Ubuntu's
  MOTD and the provider's banner (stage 10 turns those off, `LOGIN_GREETING`):
  previous login (time, IP), uptime and boot time, pending/security updates and
  the last apt run, load, memory and swap, disk, Docker containers, running
  agents, fail2ban bans and the firewall, plus warnings for a pending reboot,
  failed services or a nearly full disk. Run `motd` any time to see it again.
  herdr panes, subshells and local terminals stay quiet.
  `set -g CLOUD_GREETING eel` brings back the theme's ocean one-liners;
  `off` disables it.
- The terminal or herdr tab title is `command · host: dir`.

## Abbreviations

Abbreviations expand when you press space, so you always see the real command.

| Area | Abbreviations |
|---|---|
| git | `gst` `gco` `g-puo` `g-s` `g-s-list` `g-dev` `gpr` `ghw` `lg` (lazygit) |
| docker | `dco` `dcu` `dcud` `dcd` `dcl` `dce` `dcr` `dcb` `dps` `dpsa` `dprune` `lzd` |
| bun / npm | `br` `bx` `bi` `ba` `bd` `bt` `bld` · `nr` `nrd` `ni` |
| mise / python / go | `mu` `mug` `mi` `ml` · `uvr` `uva` `uvs` `rf` `rff` · `gci` |
| flutter | `fl` `flr` `flb` `flt` `flc` `flpg` `flpu` `fld` |
| laravel / php | `art`/`pa` `tinker` `migrate` `mfs` `serve` `pint` `pest` · `co` `ci` `cu` `cda` · `sail` |
| ops | `v` (vps) `sa` `sl` `ua` `uaa` `cln` `tn` (tunnel) `sbx` (sandbox) `lports` `jf` `sc` `scu` |
| cloud | `s3` (aws s3) `wr` `wrd` `wrp` (wrangler) `cfs` (cf cli search) |

Add your own in `home/.config/fish/cloud/aliases.fish`.

## Plugins (fisher)

`fish_plugins` lists fisher, fzf.fish (Ctrl-R history, Ctrl-Alt-F files),
autopair, sponge (drops failed commands from history), puffer-fish (`...` →
`../..`) and theme-easy-eel. Add a line, then `fisher update`.

## Secrets in the environment

`~/.config/secrets.env` (chmod 600) is parsed by both fish and bash. Empty
values are skipped, so an empty `ANTHROPIC_API_KEY=` never overrides an OAuth
sign-in. `DO_NOT_TRACK=1` is exported for every shell: cf, wrangler, Next.js
and Homebrew honour it.
