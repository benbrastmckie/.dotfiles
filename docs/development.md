# Development and Setup Notes

This document contains development notes, workflows, and initial setup procedures.

## API Configuration

LLM API keys are kept in private shell configuration files (e.g., `private.fish`) and are not tracked in git for security.

## USB Installer

For creating bootable USB installers with your complete configuration, see the dedicated guide:

**[USB Installer Guide](usb-installer.md)** - Complete instructions for building and using USB installers

Quick reference:
```bash
# Build USB installer ISO
nix build .#nixosConfigurations.usb-installer.config.system.build.isoImage

# Decompress and write to USB
zstd -d result/iso/nixos-*.iso.zst -o /tmp/nixos-installer.iso
sudo dd if=/tmp/nixos-installer.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

## Development Workflow

### Clean up build results

1. **Remove build symlinks:**
   ```bash
   rm -f ./result
   ```

2. **Clean up old generations:**
   ```bash
   # Full garbage collection
   nix-store --gc
   
   # Or targeted cleanup
   nix-collect-garbage -d
   ```

### ISO Contents

The custom ISO includes:
- GNOME desktop environment
- System configuration from `configuration.nix`
- Home-manager configuration
- Niri window manager
- All specified packages from the configuration

## Initial System Setup

### First Build Process

1. **Copy hardware configuration:**
   ```bash
   cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/hosts/HOST_NAME/hardware-configuration.nix
   ```

2. **First system build (specify hostname explicitly):**

   > **IMPORTANT**: On first build, explicitly specify your hostname rather than using `$(hostname)`. The hostname is set by NixOS, so `$(hostname)` will be wrong until the correct config is applied.

   ```bash
   sudo nixos-rebuild switch --flake ~/.dotfiles#your-hostname
   ```

3. **Subsequent rebuilds can use the update script:**
   ```bash
   ~/.dotfiles/scripts/update.sh
   ```
   See the README's [Full Update](../README.md#full-update-recommended) section for the
   `--checkpoint` and `--update` flags. (`--no-check` is still accepted but is a no-op — see
   the note in [testing.md](testing.md#testing-methods).)

4. **Apply home-manager configuration:**
   ```bash
   home-manager switch --flake ~/.dotfiles/
   ```

5. **Configure fish shell keybindings:**
   ```bash
   fish_vi_key_bindings
   ```

## Window Manager (Niri)

### Checking Niri Logs

To debug Niri window manager issues:

```bash
journalctl -b -u niri
```

This shows boot logs specific to the Niri service.

## OAuth2 Example URL

For reference, here's an example of what a Google OAuth2 authorization URL looks like:

```
https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=810486121108-i3d8dloc9hc0rg7g6ee9cj1tl8l1m0i8.apps.googleusercontent.com&state=JG-dxurfv1CAtSGA9Q7afg&code_challenge=vDgC6ctcdQi0ucIfdY3kehoLEA5yzvZn98IATf2TXcY&code_challenge_method=S256&redirect_uri=http%3A%2F%2Flocalhost%3A49152&scope=https%3A%2F%2Fmail.google.com%2F+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcontacts+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcalendar+https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcarddav
```

This can be helpful for understanding the OAuth2 flow in general. Note: Gmail email is
configured with a Gmail app password, not OAuth2 (see `docs/himalaya.md`, whose "XOAUTH2
troubleshooting" section carries the full revert recipe); this example illustrates the flow
itself.

## Host-Specific Configuration

For adding new hosts:

1. Generate hardware configuration on the new machine
2. Copy to `hosts/[hostname]/hardware-configuration.nix`
3. Update `flake.nix` to include the new host
4. Reference always-on settings in `modules/system/*.nix`; for host-specific overrides, add
   `hosts/<name>/default.nix` (see `hosts/nandi/default.nix` for the pattern)

## Lean 4 Development

### Loogle CLI

Loogle is a search tool for Lean 4's Mathlib library, allowing you to search for theorems and definitions by name or type signature.

#### Installation

Loogle is available via the custom package wrapper in `packages/loogle.nix`. It's installed in your home environment.

#### First Run

The first time you run `loogle`, it will:
1. Clone the loogle repository to `~/.cache/loogle` (~331 KB)
2. Download the Lean 4 toolchain (~484 MB)
3. Download and cache Mathlib (~7729 files)
4. Build loogle (~1-2 minutes)

Subsequent runs will be instant since everything is cached.

#### Usage Examples

```bash
# Search by function name
loogle List.map

# Search by type signature
loogle '(List.replicate (_ + _) _ = _)'

# Interactive mode
loogle --interactive

# Get help
loogle --help

# Output JSON format
loogle --json 'Nat.add'
```

#### Search Syntax

- `?a` - Match any single term
- `_ + _` - Match any addition operation
- `List ?a -> ?a` - Match functions from List to element type
- `name:substring` - Search by name containing substring
- Use quotes for complex queries: `'(List.replicate (_ + _) _ = _)'`

#### Cache Location

All Lean/Loogle data is stored in:
- `~/.cache/loogle/` - Repository and builds
- `~/.elan/` - Lean toolchain

To reset/update:
```bash
rm -rf ~/.cache/loogle
loogle  # Will rebuild on next run
```

#### Advanced Options

```bash
# Use custom module instead of Mathlib
loogle --module MyModule 'theorem_name'

# Save search index for faster subsequent searches
loogle --write-index /tmp/loogle.idx
loogle --read-index /tmp/loogle.idx 'query'

# Search specific path
loogle --path /path/to/lean/files 'query'
```

### Aeneas (Rust-to-Lean verification)

[Aeneas](https://github.com/AeneasVerif/aeneas) (with its front end, [Charon](https://github.com/AeneasVerif/charon)) translates verified Rust code into Lean (also Coq, F*, and HOL4) so Rust
programs can be formally verified.

#### What this config provides

`charon` and `aeneas` are installed on `PATH` via home-manager (see
`modules/home/packages/misc.nix`, "Lean 4 and formal mathematics tools" group), sourced from the
`aeneas` flake input in `flake.nix` (`aeneas.url = "github:AeneasVerif/aeneas"`, deliberately
without `inputs.nixpkgs.follows` — see the input's comment in `flake.nix` for why). The exact
revision is pinned in `flake.lock`; update it with:

```bash
nix flake lock --update-input aeneas
```

There is no documented public binary cache for these packages, so the first build compiles both
`charon` (Rust) and `aeneas` (OCaml) from source, which is slow but one-time.

#### Why system-wide rather than a project-local dev shell

The Verification project has no `flake.nix` of its own, this repo already threads a similar
externally-pinned tool (`lectic`) to home-manager the same way, and the Aeneas/Charon closures
are hermetic (their own pinned nixpkgs, Rust nightly, and OCaml 5.2), so they do not collide with
this config's own Rust toolchain (`modules/home/packages/rust.nix`).

#### Pipeline usage

From the Rust crate directory:

```bash
# 1. Extract Rust MIR to LLBC
charon cargo --preset=aeneas

# 2. Translate LLBC to Lean
aeneas -backend lean <file>.llbc
```

#### Verification-repo-local configuration (not managed by this config)

The Lean side of Aeneas is a Lake dependency the Verification project's own Lean project must
declare — it is fetched per-project by Lake, not installed by this config. Add to that project's
`lakefile.toml`:

```toml
[[require]]
name = "aeneas"
git = { url = "https://github.com/AeneasVerif/aeneas", subDir = "backends/lean" }
rev = "<commit>"
```

Pin `rev` to the same Aeneas commit this repo's `flake.lock` uses, so the Lean code Aeneas
generates and the Aeneas Lean library agree. Find the locked revision with:

```bash
jq -r '.nodes.aeneas.locked.rev' flake.lock
```

Before adding the `require`, check `backends/lean/lean-toolchain` at that commit against the
Verification project's own `lean-toolchain` file — a mismatch must be reconciled in that project,
not here. Adding this `require` makes a currently dependency-free Lake build fetch from the
network on first use; call that out in the Verification project's own README. After adding it,
run:

```bash
lake update aeneas
lake build
```

#### Explicit non-actions

Lean itself stays managed by `elan` (unaffected by this change), and this config does not add
`lean4` or `rustup` — the existing Rust toolchain
(`cargo`/`rustc`/`rustfmt`/`clippy` in `modules/home/packages/rust.nix`) is untouched.

## Related Documentation

- [Installation Guide](installation.md) - Detailed setup instructions
- [Testing](testing.md) - Configuration testing procedures
- [Applications](applications.md) - Application-specific configurations