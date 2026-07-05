# Overlay providing the claude-squad package (terminal multi-agent manager)
# Source: https://github.com/smtg-ai/claude-squad
# deadnix: skip
final: prev: {
  claude-squad = final.buildGoModule rec {
    pname = "claude-squad";
    version = "1.0.8";

    src = final.fetchFromGitHub {
      owner = "smtg-ai";
      repo = "claude-squad";
      rev = "v${version}";
      sha256 = "sha256-mzW9Z+QN4EQ3JLFD3uTDT2/c+ZGLzMqngl3o5TVBZN0=";
    };

    vendorHash = "sha256-BduH6Vu+p5iFe1N5svZRsb9QuFlhf7usBjMsOtRn2nQ=";

    nativeBuildInputs = with final; [ go ];

    buildInputs = with final; [
      tmux
      gh
    ];

    postInstall = ''
      # Create 'cs' alias
      ln -s $out/bin/claude-squad $out/bin/cs
    '';

    meta = with final.lib; {
      description = "Terminal app that manages multiple AI terminal agents";
      homepage = "https://github.com/smtg-ai/claude-squad";
      license = licenses.agpl3Only;
      maintainers = [ ];
      platforms = platforms.linux ++ platforms.darwin;
    };
  };
}
