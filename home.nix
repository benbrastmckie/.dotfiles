{
  ...
}:

{
  # Import our custom modules (see modules/home/default.nix for the full list)
  imports = [
    ./modules/home
  ];

  # Note: Python packages overlay (including cvc5) is defined in flake.nix

  # Local LLM inference (modules/home/services/ollama.nix). CPU-only by design; see that file
  # for why gfx1150/ROCm was rejected. Sole consumer is Sapience's on-device extraction.
  services.ollamaModels.enable = true;

  # Sapience knowledge vault (modules/home/services/sapience.nix). The "ollama" backend keeps
  # AI-session transcript text on this machine: "relay" would transit redacted transcript chunks
  # through app.spnc.ai BEFORE any review gate, and "anthropic"/"openai" need a pay-as-you-go
  # API key, which a Claude subscription does not provide.
  #
  # Enabling the module installs the CLI, the hourly timer and the MCP registration, but reads
  # nothing: the sync unit is gated on ~/.sapience/config.json via ConditionPathExists, so no
  # transcript is touched until `sapience-bootstrap` is run by hand and projects are ticked.
  programs.sapience = {
    enable = true;
    backend = "ollama";
  };

  home = {
    username = "benjamin";
    homeDirectory = "/home/benjamin";

    # Fish shell configuration is managed through home.file below
    # OMF has been removed - fish greeting disabled in config.fish

    stateVersion = "24.11"; # Please read the comment before changing.
    # History, do not restore — active stateVersion is frozen (see modules/README.md Verified
    # Health Notes). Kept as a record of prior values, not a rollback option.
    # home.stateVersion = "24.05"; # Please read the comment before changing.
    # home.stateVersion = "23.11"; # Please read the comment before changing.
  };
}
