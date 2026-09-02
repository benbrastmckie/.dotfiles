# Configuration Files

This directory contains configuration files for various applications managed by Home Manager. All files are symlinked to their appropriate locations in `~/.config/` or `~/` when the NixOS configuration is activated.

## File Organization

Files are organized by application and deployment pattern:
- **Root level files**: Application-specific configs (e.g., `kitty.conf`, `himalaya-config.toml`)
- **Subdirectories**: Groups of related files (e.g., `sioyek/`)

## Deployment Mechanisms

All deployment logic lives in `modules/home/core/dotfiles.nix`. There are four distinct
mechanisms in that file; a given file in `config/` is deployed by exactly one (or two, for the
few files mirrored by both mechanism 1 and mechanism 2) of them. Mechanism 4 deploys a single key
inside `~/.claude.json` rather than a `config/`-sourced file — see its subsection below for why it
is grouped here anyway. Always check `dotfiles.nix` itself for the authoritative, current line
numbers — the ranges below are current as of this writing but will drift as the file is edited.

### Mechanism 1: `home.file.*.source` store symlinks (`dotfiles.nix:22-46`, plus `:63`)

The majority of `config/` files are deployed via `home.file.<target>.source = ../../../config/<file>;`
entries. Home Manager places an **immutable symlink** into the Nix store at the target path
(e.g. `~/.config/kitty/kitty.conf`) when `home-manager switch` runs. Because the target is a
read-only store symlink, applications cannot write to it; edits must be made in `config/` and
deployed via a rebuild. This is the default/most common mechanism and covers most rows in the
tables below (terminal emulators, fish, tmux, zathura, niri, sioyek, opencode, fastfetch,
himalaya, latexmkrc, and `.zuliprc` at line 59 — see the stale-row fix in the Chat section).

### Mechanism 2: `builtins.readFile` mirrors into `~/.config/config-files/` (`dotfiles.nix:49-55`)

A second, independent mechanism copies exactly **7** of the mechanism-1 files' contents into a
parallel `~/.config/config-files/` directory using `builtins.readFile`, producing plain
(non-symlink) text copies rather than store symlinks:

- `config.fish`
- `kitty.conf`
- `zathurarc`
- `alacritty.toml`
- `wezterm.lua`
- `.tmux.conf`
- `latexmkrc`

**Mirror asymmetry**: this is not a mirror of everything mechanism 1 deploys — only these 7 files
get a `~/.config/config-files/` copy. The other mechanism-1 files (`fastfetch.jsonc`,
`opencode.json`, the `sioyek/*` files, `config.kdl`, `himalaya-config.toml`, `.zuliprc`) have no
mechanism-2 mirror. The purpose of the mirror is to keep a version-control-friendly, easily
diffable plain-text copy alongside the store symlink; it is not itself the canonical deployed
config for any application.

### Mechanism 3: `home.activation.claudeSettings` merge + copy (`dotfiles.nix:65-127`)

`config/claude/settings.json` and `config/claude/keybindings.json` are deployed by an
**activation script**, not a symlink, so that they are plain writable files Claude Code can
write runtime changes to — which a read-only store symlink would not allow.

The two files are handled differently, because only one of them is written back by Claude Code.

**`keybindings.json` — plain copy.** `rm -f`, `cp`, `chmod u+w`, unconditionally. Claude Code
does not rewrite this file, so there is nothing to preserve; `config/claude/` is the source of
truth outright.

**`settings.json` — three-way merge.** Claude Code persists interactive settings here: every
change made through `/config` or `/model` (`editorMode`, `autoCompactEnabled`,
`agentPushNotifEnabled`, `remoteControlAtStartup`, and so on) is written straight into this file.
A `cp` over the top would therefore erase, on every rebuild, exactly the settings the "writable
regular file" choice exists to allow. The merge precedence is:

```
source defaults  <  live values  <  source ENFORCED keys
```

- **ENFORCED** (`_NOTE`, `env`, `hooks`, `model`, `permissions`, `statusLine`) are reset to the
  source value on every activation. These define system behaviour, or are referenced by the repo
  by path, so the repo owns them. `model` is enforced deliberately: Opus is the intended default.
  A per-session `/model` switch still works — only the *persisted default* is reset.
- **Everything else in the source acts as a seed.** It populates a fresh machine, but a live
  value wins thereafter, so preferences set from inside Claude Code survive rebuilds.
- **Keys the source does not mention are always preserved.**

Adding a key to ENFORCED makes it repo-owned and un-changeable from inside Claude Code — the next
rebuild reverts it — so add deliberately.

Failure is fail-safe: if the live file is missing (fresh machine), unparseable, or the `jq` merge
errors, the source is copied verbatim rather than leaving a broken or absent settings file. The
merge writes to a temp file in the same directory and `mv`s it over the original, so a partially
written `settings.json` is never observable.

> **Note — this replaced an unconditional `rm -f` + `cp`.** Previously any setting changed inside
> Claude Code was silently destroyed on the next `home-manager switch`, and the only remedy was to
> notice the loss and hand-fold each key back into `config/claude/settings.json`. That is no
> longer the case for `settings.json`. It remains true for `keybindings.json`: edit the source,
> not the deployed file.

### Mechanism 4: `home.activation.claudeMcpServers` jq merge (`dotfiles.nix:136-164`)

`~/.claude.json` (see the four-way collision table below) is Claude Code's master user-scope
config file: `mcpServers`, the project list, OAuth state, and session history all live there. The
`home.activation.claudeMcpServers` block writes exactly one key into it —
`mcpServers.playwright` — on every `home-manager switch`, using the same `jq` read-modify-write
technique already proven by `.claude/scripts/setup-lean-mcp.sh` (create the file with `{}` if it
does not exist, `jq` the new key into a temp file in the same directory, then `mv` the temp file
over the original).

Both this and Mechanism 3 now merge rather than overwrite, but they differ in ownership: because
`~/.claude.json` carries OAuth/session/project-list state that must survive every rebuild, this
block claims **no** keys as repo-owned — it writes a single key and leaves every other key
(including the pre-existing `mcpServers.lean-lsp` entry) untouched, where Mechanism 3 resets its
ENFORCED set on every activation. If the `jq` merge fails for any reason (a
missing or malformed source file), the temp file is discarded and `~/.claude.json` is left
completely unmodified rather than partially written.

## Naming Hazards

Two naming collisions in this repo are easy to conflate. Always use the full path when referring
to any of the entities below — never a bare, ambiguous name like "the config directory" or "the
claude directory".

### `config/` directory vs. the Nix `config` module-argument

`modules/home/core/dotfiles.nix` (like other Home Manager modules) opens with
`{ config, pkgs, ... }:`. Inside that function body, the bare name `config` refers to the
**Home Manager module-system attribute set** — e.g. `config.home.homeDirectory` or
`config.lib.dag.entryAfter` — and has nothing to do with the repository's top-level `config/`
directory that holds the actual dotfiles content. The repo-root directory is never referred to
by the bare name `config` inside module code; it is always reached via a relative path such as
`../../../config/kitty.conf`. When reading `dotfiles.nix`, resolve `config.<x>` as "the Home
Manager module system" and `../../../config/<file>` as "the dotfiles source directory" — they are
unrelated despite sharing the word "config".

### The four-way "claude" collision

This repository contains four distinct, easily-confused "claude"-named entities. They must
never be conflated:

| Path | What it is | Scope |
|------|------------|-------|
| `.claude/` (repo root) | The Claude Code agent-orchestration system for this repo (commands, skills, agents, context) | Out of scope for this document and for the `config/` tree generally |
| `config/claude/` | The dotfiles *source* for Claude Code CLI settings (`settings.json`, `keybindings.json`), tracked in this repo | In scope — this is what deployment mechanism 3 merges/copies from |
| `~/.claude/` (user's `$HOME`, a directory) | The deployed *runtime* target directory that the actual Claude Code CLI reads/writes at `$HOME`, outside this repo | The destination mechanism 3 merges `settings.json` into and copies `keybindings.json` to; not itself version-controlled |
| `~/.claude.json` (user's `$HOME`, a single file, no trailing slash) | Claude Code's master user-scope config file: `mcpServers`, project list, OAuth state, session history — distinct from, and outside, the `~/.claude/` directory above | The destination mechanism 4 merges `mcpServers.playwright` into; not itself version-controlled, and never fully overwritten |

`.claude/` and `config/claude/` are both inside this git repository but serve completely
different purposes (agent orchestration vs. dotfiles source); `~/.claude/` and `~/.claude.json`
are both outside the repo entirely — one a directory, the other a single file one level up from
it — and are where the CLI actually runs and stores its master config, respectively. When in
doubt, name the full path.

## Terminal Emulators

| File | Deployed To | Description |
|------|-------------|-------------|
| `alacritty.toml` | `~/.config/alacritty/alacritty.toml` | Alacritty terminal emulator configuration |
| `kitty.conf` | `~/.config/kitty/kitty.conf` | Kitty terminal emulator configuration |
| `wezterm.lua` | `~/.config/wezterm/wezterm.lua` | WezTerm GPU-accelerated terminal configuration |

## Shell & Multiplexers

| File | Deployed To | Description |
|------|-------------|-------------|
| `config.fish` | `~/.config/fish/config.fish` | Fish shell configuration and aliases |
| `.tmux.conf` | `~/.tmux.conf` | tmux terminal multiplexer configuration |

## Window Manager

| File | Deployed To | Description |
|------|-------------|-------------|
| `config.kdl` | `~/.config/niri/config.kdl` | Niri Wayland compositor configuration |

## Document Viewers

| File | Deployed To | Description |
|------|-------------|-------------|
| `zathurarc` | `~/.config/zathura/zathurarc` | Zathura PDF viewer configuration |
| `sioyek/prefs_user.config` | `~/.config/sioyek/prefs_user.config` | Sioyek PDF viewer preferences (research papers) |
| `sioyek/keys_user.config` | `~/.config/sioyek/keys_user.config` | Sioyek keyboard shortcuts |

## Development Tools

| File | Deployed To | Description |
|------|-------------|-------------|
| `claude/settings.json` | `~/.claude/settings.json` | Claude Code CLI settings (copied, not symlinked) |
| `claude/keybindings.json` | `~/.claude/keybindings.json` | Claude Code keyboard shortcuts (copied, not symlinked) |
| `opencode.json` | `~/.config/opencode/opencode.json` | OpenCode configuration |
| `latexmkrc` | `~/.latexmkrc` | LaTeX build automation configuration |

## Email

| File | Deployed To | Description |
|------|-------------|-------------|
| `himalaya-config.toml` | `~/.config/himalaya/config.toml` | Himalaya email client configuration |

## Cloud Storage

| File | Deployed To | Description |
|------|-------------|-------------|
| `rclone.conf` | `~/.config/rclone/rclone.conf` | Rclone cloud storage sync configuration (seed file; copied via activation script, not symlinked, so rclone can write token refreshes) |

## Chat

| File | Deployed To | Description |
|------|-------------|-------------|
| `zuliprc` | `~/.zuliprc` | Zulip API client configuration (mechanism 1: plain `home.file.".zuliprc".source` store symlink, `dotfiles.nix:63` — not an activation script) |

## System Information

| File | Deployed To | Description |
|------|-------------|-------------|
| `fastfetch.jsonc` | `~/.config/fastfetch/config.jsonc` | Fastfetch system info display configuration |

## Notes

- All configurations are declaratively managed through `modules/home/core/dotfiles.nix` (see
  `## Deployment Mechanisms` above for the full mechanism reference)
- Changes to these files require running `home-manager switch` to take effect
- Most configs are deployed as mechanism-1 symlinks (including `.zuliprc`); only
  `config/claude/{settings,keybindings}.json` use an activation script (mechanism 3) that copies
  instead of symlinks, so Claude Code can write to them at runtime — `settings.json` is merged
  (enforced keys reset, the rest preserved) and `keybindings.json` is copied outright; see
  mechanism 3 above. `~/.claude.json` (mechanism 4) is a separate, unrelated
  activation script that merges a single key rather than deploying a `config/`-sourced file —
  see mechanism 4 above. `rclone.conf` is out of scope for this reference (see
  `## Cloud Storage` above)
- 7 of the mechanism-1 configs are also mirrored to `~/.config/config-files/` as plain-text
  copies for version-control visibility (mechanism 2 — see `## Deployment Mechanisms` above for
  the exact file list and the mirror asymmetry)
- See `home.nix` for complete deployment mappings

[← Back to main README](../README.md)