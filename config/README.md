# Configuration Files

This directory contains configuration files for various applications managed by Home Manager. All files are symlinked to their appropriate locations in `~/.config/` or `~/` when the NixOS configuration is activated.

## File Organization

Files are organized by application and deployment pattern:
- **Root level files**: Application-specific configs (e.g., `kitty.conf`, `himalaya-config.toml`)
- **Subdirectories**: Groups of related files (e.g., `sioyek/`)

## Deployment Mechanisms

All deployment logic lives in `modules/home/core/dotfiles.nix`. There are three distinct
mechanisms in that file; a given file in `config/` is deployed by exactly one (or two, for the
few files mirrored by both mechanism 1 and mechanism 2) of them. Always check `dotfiles.nix`
itself for the authoritative, current line numbers — the ranges below are current as of this
writing but will drift as the file is edited.

### Mechanism 1: `home.file.*.source` store symlinks (`dotfiles.nix:19-40`, plus `:57`)

The majority of `config/` files are deployed via `home.file.<target>.source = ../../../config/<file>;`
entries. Home Manager places an **immutable symlink** into the Nix store at the target path
(e.g. `~/.config/kitty/kitty.conf`) when `home-manager switch` runs. Because the target is a
read-only store symlink, applications cannot write to it; edits must be made in `config/` and
deployed via a rebuild. This is the default/most common mechanism and covers most rows in the
tables below (terminal emulators, fish, tmux, zathura, niri, sioyek, opencode, fastfetch,
himalaya, latexmkrc, and `.zuliprc` at line 57 — see the stale-row fix in the Chat section).

### Mechanism 2: `builtins.readFile` mirrors into `~/.config/config-files/` (`dotfiles.nix:42-49`)

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

### Mechanism 3: `home.activation.claudeSettings` copy (`dotfiles.nix:59-68`)

`config/claude/settings.json` and `config/claude/keybindings.json` are deployed by an
**activation script**, not a symlink. On every `home-manager switch`, the
`home.activation.claudeSettings` block unconditionally:
1. `rm -f`s the existing `~/.claude/settings.json` and `~/.claude/keybindings.json`,
2. `cp`s the current `config/claude/{settings,keybindings}.json` over them, and
3. `chmod u+w`s the copies.

This produces plain, writable (non-symlink) files at `~/.claude/settings.json` and
`~/.claude/keybindings.json` so that Claude Code can write runtime changes to them, which a
read-only store symlink would not allow.

> **WARNING — intended force-overwrite behavior, not a bug**: because step 1 above is an
> unconditional `rm -f` + `cp` with no diff/merge, **any manual edit made directly to
> `~/.claude/settings.json` or `~/.claude/keybindings.json` that has not been copied back into
> `config/claude/` is silently destroyed on the next `home-manager switch`.** This is intended,
> documented behavior — the source of truth is `config/claude/`, not the deployed runtime files —
> and is not something this documentation update changes or "fixes". If you edit the runtime
> files directly, copy your changes into `config/claude/` before the next rebuild or they will be
> lost.

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

### The three-way "claude" collision

This repository contains three distinct, easily-confused "claude"-named entities. They must
never be conflated:

| Path | What it is | Scope |
|------|------------|-------|
| `.claude/` (repo root) | The Claude Code agent-orchestration system for this repo (commands, skills, agents, context) | Out of scope for this task and for task 81 generally |
| `config/claude/` | The dotfiles *source* for Claude Code CLI settings (`settings.json`, `keybindings.json`), tracked in this repo | In scope — this is what deployment mechanism 3 copies from |
| `~/.claude/` (user's `$HOME`) | The deployed *runtime* target directory that the actual Claude Code CLI reads/writes at `$HOME`, outside this repo | The destination mechanism 3 copies to; not itself version-controlled |

`.claude/` and `config/claude/` are both inside this git repository but serve completely
different purposes (agent orchestration vs. dotfiles source); `~/.claude/` is outside the repo
entirely and is where the CLI actually runs. When in doubt, name the full path.

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
| *(activation script)* | `~/.zuliprc` | Zulip API client configuration (seed file; created via activation script, not symlinked, so user can fill in API key) |

## System Information

| File | Deployed To | Description |
|------|-------------|-------------|
| `fastfetch.jsonc` | `~/.config/fastfetch/config.jsonc` | Fastfetch system info display configuration |

## Notes

- All configurations are declaratively managed through `home.nix`
- Changes to these files require running `home-manager switch` to take effect
- Most configs are deployed as symlinks; `claude/`, `rclone.conf`, and `.zuliprc` use activation scripts that copy/seed instead of symlink so the applications can write to them at runtime
- Some configs are also copied to `~/.config/config-files/` for version control backup
- See `home.nix` for complete deployment mappings

[← Back to main README](../README.md)