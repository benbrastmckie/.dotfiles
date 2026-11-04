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
  # through app.spnc.ai BEFORE any review gate. "anthropic" needs a pay-as-you-go API key, which
  # a Claude subscription does not provide; "openai" needs one too, but a ChatGPT Pro
  # subscription can fund it from its monthly API credit (claimed in ChatGPT billing settings).
  #
  # Enabling the module installs the CLI, the hourly timer and the MCP registration, but reads
  # nothing: the sync unit is gated on ~/.sapience/config.json via ConditionPathExists, so no
  # transcript is touched until `sapience-bootstrap` is run by hand and projects are ticked.
  programs.sapience = {
    enable = true;

    # "ollama" runs extraction on this machine's CPU at roughly 40s per model call. To move it
    # to the OpenAI API instead -- redacted chunks only, and funded by the ChatGPT Pro monthly
    # API credit rather than the CPU -- create the key file below, then change this one word to
    # "openai". Walkthrough and the max_tokens caveat: docs/sapience.md.
    backend = "ollama";

    # Read at activation and stored as config.json's api_key/api_key_env pair, which is the only
    # route that reaches the timer (it has no shell environment). Unused while backend is
    # "ollama"; harmless if the file does not exist yet.
    apiKeyFile = "/home/benjamin/.config/sapience/openai-key";

    # Empty keeps the client's per-backend default, which for openai is gpt-4o-mini -- the one
    # model known to work, because the client sends the deprecated `max_tokens` that o-series
    # and GPT-5 models reject with HTTP 400.
    model = "";
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
