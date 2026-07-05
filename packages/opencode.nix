# opencode - AI coding agent built for the terminal
# Fetches prebuilt binary from GitHub releases instead of building from source,
# allowing version updates independent of the nixpkgs packaging lag.
#
# To update: change version, then run:
#   nix store prefetch-file --hash-type sha256 "https://github.com/anomalyco/opencode/releases/download/v<VERSION>/opencode-linux-x64.tar.gz"
# (no --unpack flag — hash the tarball itself, not its contents) and update the hash below.

{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  ripgrep,
}:

let
  version = "1.14.33";
  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
    hash = "sha256-qz3j1ApnVzQZ7HSRYhDPkNz4wYDcnYBS23Gsn1XCiBA=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;
  inherit src;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

  # Tarball contains a single binary with no directory wrapper,
  # so the default unpackPhase fails trying to cd into a nonexistent dir.
  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 opencode $out/bin/opencode
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
    runHook postInstall
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [ "x86_64-linux" ];
  };
}
