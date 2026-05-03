# opencode - AI coding agent built for the terminal
# Fetches prebuilt binary from GitHub releases instead of building from source,
# allowing version updates independent of the nixpkgs packaging lag.
#
# To update: change version, then run:
#   nix-prefetch-url --unpack "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz"
# and update the hash below.

{ lib, stdenvNoCC, fetchurl, makeWrapper, ripgrep }:

let
  version = "1.14.33";
  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
    hash = "sha256-is/XYkgKTKr6/p2Ft4CXWt169Wn4XUkdkNCUJca6kvM=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;
  inherit src;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

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
