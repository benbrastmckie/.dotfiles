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

#### Playwright MCP (packages/playwright-mcp.nix)

NPX wrapper for the Playwright MCP server that automatically uses the latest version:
- Zero-maintenance approach (no version pinning), matching the `claude-code.nix` convention —
  nixpkgs' own `playwright-mcp` derivation lags upstream and hardcodes a separate
  `PLAYWRIGHT_BROWSERS_PATH` browser set
- Resolves the newest `chromium-*` build already installed under `~/.cache/ms-playwright` and
  passes it via `--executable-path`, so no browser is ever downloaded
- Registered as `mcpServers.playwright` in `~/.claude.json` by
  `home.activation.claudeMcpServers` in `modules/home/core/dotfiles.nix` (see
  `config/README.md`'s Mechanism 4 for the merge-not-overwrite activation detail)
- **Runs the browser headless**, via a generated `--config` file (`--config` is the only route
  the MCP server exposes for browser settings; it has no `--browser-arg` equivalent). The same
  config also passes `--disable-blink-features=ScreenWakeLock`. Navigation, snapshots, and
  screenshots all work headless; what changes is that no browser window appears on screen.

  The reason is screen blanking: a headed browser owns a Wayland surface and can pin the display
  awake through `zwp_idle_inhibitor_v1`, which mutter relays into a GNOME SessionManager idle
  inhibitor. A headless browser has no surface and cannot inhibit by any route. Measurement on
  this machine found Playwright browsers were *not* in fact holding inhibitors (see
  `no-sleep-agents.md`, mechanism 5), so this is a forward-looking guarantee rather than a fix
  for an observed problem — it keeps agent-driven browsing structurally incapable of affecting
  the display, no matter what a page does.

  To get a visible browser back, drop `headless` from `mcpConfig` in `packages/playwright-mcp.nix`
  and rebuild, or pass a different config at invocation: `playwright-mcp --config /path/to.json`
  (the wrapper's trailing `"$@"` means a later `--config` wins).

#### Zot / zotero-cli-cc (packages/zot.nix)

`writeShellScriptBin` wrapper for the Zotero CLI, matching the `aristotle.nix` shape exactly:
- PyPI/uvx-distributed tool (`zotero-cli-cc`), not packaged in nixpkgs
- Zero-maintenance `@latest` resolution via `uvx --from zotero-cli-cc@latest zot "$@"` on every
  invocation (first run may take a moment while `uvx` populates its cache)
- Consumed by the literature extension's Zotero write-back path (`~/.config/nvim`)
- Credentials are provisioned separately — see [`docs/zotero.md`](zotero.md) for the sops secret,
  the `ZOTERO_API_KEY`/`ZOT_API_KEY`/`ZOT_LIBRARY_ID` exports, and the declarative
  `~/.config/zot/config.toml`

Usage: `zot --version` or `zot --help`

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

### Digital Hardware Simulation (home.nix)

**Open-source Verilog/SystemVerilog RTL simulation and waveform viewing** (defined in
`modules/home/packages/dev-tools.nix`):

- `iverilog` - Icarus Verilog simulator; provides `iverilog` (compiler) and `vvp` (runtime).
  Writes VCD trace files from `$dumpfile`/`$dumpvars` in the testbench.
- `verilator` - Fast compiled Verilog/SystemVerilog simulator (C++ transpilation)
- `gtkwave` - GTKWave VCD/waveform viewer
- `surfer` - Modern VCD/waveform viewer (alternative to GTKWave)

**Example usage (smoke test):**
```bash
# Compile + run an Icarus simulation, then view the trace.
# The testbench must contain: initial begin $dumpfile("dump.vcd"); $dumpvars; end
iverilog -o sim example.v && vvp sim   # runs sim, writes dump.vcd
gtkwave dump.vcd                        # open the trace (or: surfer dump.vcd)

# Verify installed versions
iverilog -V
verilator --version
gtkwave --version
surfer --version
```

### Digital Hardware Synthesis, Formal Verification & Linting (home.nix)

**Open-source RTL synthesis, formal-verification backends, and SystemVerilog linting** (defined
in `modules/home/packages/dev-tools.nix`):

- `yosys` - RTL synthesis suite; also drives Yosys-based formal flows
- `sby` - SymbiYosys, the front-end that runs Yosys formal verification (BMC, induction, etc.)
- `boolector` - SMT solver (bit-vectors + arrays) usable as a formal backend
- `bitwuzla` - SMT solver (bit-vectors/arrays/FP); Boolector's successor
- `yices` - Yices 2 SMT solver
- `verible` - SystemVerilog linter/formatter (`verible-verilog-lint`, `verible-verilog-format`, ...)
- `nusmv` - NuSMV symbolic model checker
- `python3Packages.cocotb` - Python cosimulation testbench framework (drives iverilog/verilator)

**Verify installed versions:**
```bash
yosys --version
sby --help                    # usage output; may exit non-zero (expected)
boolector --version
bitwuzla --version
yices --version
verible-verilog-lint --version
NuSMV -help                   # usage output; may exit non-zero (expected)

# cocotb has no version CLI flag:
python3 -c "import cocotb; print(cocotb.__version__)"
```

### Rust Toolchain (home.nix)

**Standard Rust tooling from nixpkgs** (defined in `modules/home/packages/rust.nix`). This is the
same set rustup installs in its default profile, plus the language server, all built against one
pinned compiler version:

- `rustc` - Compiler (links through the system `cc`)
- `cargo` - Build tool and package manager
- `clippy` - Linter, run as `cargo clippy`
- `rustfmt` - Formatter, run as `cargo fmt`
- `rust-analyzer` - Language server (LSP)

`RUST_SRC_PATH` is set to `rustPlatform.rustLibSrc`: the nixpkgs `rustc` ships without standard
library sources, which rust-analyzer needs for std resolution and completion.

`rustup` is deliberately not installed; it would manage a second, unpatched set of toolchains
outside the Nix store. Projects needing nightly or extra cross-compilation targets should pin
their toolchain in their own flake `devShell`.

**Example usage:**
```bash
cargo clippy --all-targets -- -D warnings   # lint, failing on any warning
cargo fmt --check                           # verify formatting without rewriting

# Verify installed versions
rustc --version && cargo --version
cargo clippy --version && cargo fmt --version
rust-analyzer --version
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