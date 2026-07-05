# Package Management

## Package Sources

### Stable Packages

Main package set from nixpkgs stable channel:
- System utilities and core applications
- Well-tested packages with stability focus
- Default choice for most applications

### Unstable Packages

Packages from nixpkgs unstable channel defined in `overlays/unstable-packages.nix`:
- Latest versions of development tools
- Packages requiring newer features
- Applications needing frequent updates

### Custom Packages

Custom package definitions in `packages/`:

#### Neovim (packages/neovim.nix)

Comprehensive Neovim configuration:
- Language servers and tools
- Plugin dependencies
- Custom build with specific features
- Integration with system clipboard and external tools

#### Python Packages (packages/python-cvc5.nix)

Custom Python packages are integrated via overlays defined in `flake.nix`:

**CVC5 SMT Solver Bindings (v1.3.1)**:
- Custom package for CVC5 Python bindings (not available in nixpkgs)
- Built from PyPI wheel with autoPatchelfHook for native libraries
- Integrated via `pythonPackagesOverlay` in `flake.nix`
- Available in `python3.withPackages` alongside standard packages
- Requires `LD_LIBRARY_PATH` configuration for C++ dependencies

See [`packages/README.md`](../packages/README.md) for detailed documentation on custom packages.

**Related Documentation**:
- Implementation plan: [`specs/plans/009_cvc5_python_bindings_overlay.md`](../specs/plans/009_cvc5_python_bindings_overlay.md)
- Research report: [`specs/reports/011_cvc5_nixos_installation_strategy.md`](../specs/reports/011_cvc5_nixos_installation_strategy.md)

#### Claude Code (packages/claude-code.nix)

NPX wrapper for Claude Code that automatically uses the latest version:
- Zero-maintenance approach (no version pinning)
- Simple shell script wrapper around `npx @anthropic-ai/claude-code@latest`
- Offline support via NPX caching

#### Loogle (packages/loogle.nix)

Wrapper script for the Lean 4 Mathlib search tool:
- Lazy installation: clones and builds on first run
- Caches everything in `~/.cache/loogle/` for fast subsequent runs
- Uses Nix development shell for reproducible builds
- Automatically manages Lean toolchain via elan
- First run downloads ~484 MB and takes 1-2 minutes
- Subsequent runs are instant

Usage: `loogle 'List.map'` or `loogle --help`

See [Development Guide](development.md#lean-4-development) for detailed usage.

#### Package Structure

- Package derivations and build instructions
- Custom wrappers for applications
- Python package overlays for missing nixpkgs packages
- Build scripts and testing utilities

## Adding Packages

### System Packages

Add to `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  package-name
];
```

### User Packages

Add to `home.nix`:
```nix
home.packages = with pkgs; [
  package-name
];
```

### Unstable Packages

Add to `overlays/unstable-packages.nix` and reference in configurations.

## Web Development & Network Tools

The following tools are installed to support web development, DNS diagnostics, and website management:

### DNS & Network Diagnostics (configuration.nix)

**Essential for troubleshooting domain, DNS, and network issues:**
- `bind` - DNS tools (dig, nslookup, host) for DNS record queries
- `dnsutils` - Additional DNS diagnostic utilities
- `whois` - Domain registration lookup and nameserver information
- `traceroute` - Network path diagnosis
- `mtr` - Advanced network diagnostics (combines ping and traceroute)

**Example usage:**
```bash
# Check DNS records
dig logos-labs.ai MX +short
dig logos-labs.ai TXT +short

# Check domain registration
whois logos-labs.ai

# Diagnose network path
mtr logos-labs.ai
```

### SSL/TLS Tools (configuration.nix)

- `mkcert` - Create locally-trusted development certificates

**Note:** OpenSSL is available system-wide for SSL certificate inspection and testing.

### Cloudflare Development (configuration.nix)

- `wrangler` - CLI for building and deploying Cloudflare Workers, Pages, and D1 databases

**Example usage:**
```bash
# Initialize a new Workers project
wrangler init my-worker

# Deploy to Cloudflare Workers
wrangler deploy

# Tail logs from deployed worker
wrangler tail
```

### HTTP & API Testing (home.nix)

- `httpie` - User-friendly HTTP client with syntax highlighting and JSON formatting
- `curl` - Classic HTTP tool (already installed)
- `fx` - Interactive JSON viewer and processor

**Example usage:**
```bash
# Test API with httpie
http GET https://api.example.com/data

# View JSON interactively
curl -s https://api.example.com/data | fx
```

### Git Enhancement Tools (home.nix)

- `gh` - GitHub CLI (already installed)
- `glab` - GitLab CLI for managing GitLab repositories
- `lazygit` - Terminal UI for git (already installed)
- `delta` - Syntax-highlighting pager for git diffs

**Configure delta for better git diffs:**
```bash
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.side-by-side true
```

### System Monitoring (home.nix)

- `btop` - Modern, beautiful system monitor with mouse support
- `htop` - Interactive process viewer
- `bandwhich` - Real-time network bandwidth monitor by process

### Documentation & Writing Tools (home.nix)

- `vale` - Prose linter for enforcing writing style guides
- `marksman` - Markdown language server for LSP integration
- `mdl` - Markdown linter for checking formatting

**Example usage:**
```bash
# Lint documentation
vale docs/*.md

# Check markdown files
mdl README.md
```

### Image Optimization (home.nix)

**Tools for optimizing web assets:**
- `imagemagick` - Comprehensive image manipulation toolkit
- `optipng` - PNG optimizer
- `jpegoptim` - JPEG optimizer

**Example usage:**
```bash
# Optimize for web
optipng -o7 src/assets/logo.png
jpegoptim --strip-all --all-progressive src/assets/hero.jpg

# Resize image
convert input.jpg -resize 800x600 output.jpg
```

### Email Testing (home.nix)

- `swaks` - Swiss Army Knife for SMTP - comprehensive email testing tool
- `mailutils` - Collection of email utilities (mail, mailx, etc.)

**Example usage:**
```bash
# Test SMTP connection
swaks --to user@example.com \
      --from test@example.com \
      --server smtp.gmail.com \
      --tls
```

### Wayland/Niri Tools (configuration.nix, home.nix)

Tools for the Niri Wayland compositor session:

- `xwayland-satellite` - X11 compatibility layer for running X11 applications in Niri
- `fuzzel` - Lightweight application launcher for Wayland (Mod+p in niri)
- `wdisplays` - GUI tool for configuring monitors on wlr-output-management compositors
- `satty` - Screenshot annotation tool with drawing and text capabilities
- `grim` - Minimal Wayland screenshot utility (captures full screen or regions)
- `slurp` - Region selection tool for Wayland (used with grim for area screenshots)
- `power-profiles-daemon` - System service for power profile management (integrated with Waybar)