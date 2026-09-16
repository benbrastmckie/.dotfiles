# Rust toolchain: the standard rustup "default profile" set (rustc, cargo, clippy, rustfmt)
# plus rust-analyzer, all from nixpkgs so they share one pinned compiler version. rustup is
# deliberately not used: it would download unpatched toolchains outside the Nix store and
# duplicate these packages. Projects needing a different toolchain (nightly, cross targets)
# should pin it in their own flake devShell instead.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustc # Compiler (links via the system `cc`)
    cargo # Build tool and package manager
    clippy # Linter (`cargo clippy`)
    rustfmt # Formatter (`cargo fmt`)
    rust-analyzer # Language server (LSP)
  ];

  # nixpkgs' rustc ships without std sources, which rust-analyzer needs to resolve and
  # complete the standard library.
  home.sessionVariables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
}
