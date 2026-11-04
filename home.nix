{
  ...
}:

{
  # Import our custom modules (see modules/home/default.nix for the full list)
  imports = [
    ./modules/home
  ];

  # Note: Python packages overlay (including cvc5) is defined in flake.nix

  # Ollama (modules/home/services/ollama.nix). Still enabled, but its job has changed: Sapience
  # now names a ":cloud" model, so this daemon authenticates and forwards those calls to
  # ollama.com and runs no inference locally. It is the transport, which is why it cannot simply
  # be switched off -- the vendor client sends no Authorization header (extract_local.py:1511),
  # so something local must hold the credential. That credential is the ~/.ollama/id_ed25519
  # keypair `ollama signin` registers; OLLAMA_API_KEY is a client-side variable for configuring
  # other apps, and the daemon ignores it (absent from its own "server config" env dump).
  services.ollamaModels = {
    enable = true;

    # Empty: a ":cloud" model has no weights to fetch and the daemon resolves it remotely, so
    # the loader has nothing to pull. llama3.1 was dropped from this list rather than deleted --
    # the loader only ever pulls, so `ollama rm llama3.1:latest` is what reclaims its 4.9 GB.
    load = [ ];
  };

  # Sapience knowledge vault (modules/home/services/sapience.nix). "relay" would transit redacted
  # transcript chunks through app.spnc.ai BEFORE any review gate, and "anthropic"/"openai" have
  # their provider URL hardcoded in the vendor client (extract_local.py:1526 and :1537), so
  # neither can be aimed anywhere else. "ollama" is the only backend whose endpoint is
  # configurable (OLLAMA_HOST, extract_local.py:167), which is why it stays selected even though
  # extraction no longer runs on this machine -- see `model` below.
  #
  # Enabling the module installs the CLI, the hourly timer and the MCP registration, but reads
  # nothing: the sync unit is gated on ~/.sapience/config.json via ConditionPathExists, so no
  # transcript is touched until `sapience-bootstrap` is run by hand and projects are ticked.
  programs.sapience = {
    enable = true;

    # Stays "ollama": the local daemon is the transport, not necessarily the compute. A model
    # name ending in ":cloud" makes it forward the call to ollama.com and run nothing here, which
    # is how a remote model is reached at all given the missing Authorization header. Setting
    # this to "openai" would pin extraction to api.openai.com. docs/sapience.md has the detail.
    backend = "ollama";

    # Reflection's 501B/23B-active Apache-2.0 model, forwarded to ollama.com by the local daemon.
    # Chosen over gemma4:cloud and nemotron-3-super:cloud on all three axes that were compared:
    # strongest (GPQA Diamond 90.5 self-reported, against 84.3 and 79.2; Artificial Analysis puts
    # those two at 29 and 25 and has no entry for beam), cheapest (the cloud catalogue marks it
    # `free` with a dedicated badge and it has no row in the pricing table at all), and no worse
    # on privacy -- all three are open-weight models served on the same NVIDIA Cloud Provider
    # track under one contractual no-logging/no-training/zero-retention policy.
    #
    # Its emphasis on token-efficient reasoning also matters mechanically: llm() caps replies at
    # num_predict 8000 and never sends `think: false`, so a verbose reasoner can spend that
    # budget on thinking before emitting JSON and trip the re-split path in _extract_chunk.
    #
    # `free` reads as a launch promotion on a model two weeks old, and Ollama retires cloud
    # models with notice in its usage settings. If it starts billing or is withdrawn,
    # gemma4:cloud ($0.14/$0.40 per Mtok) is the drop-in fallback: this one word is the change.
    model = "beam:cloud";
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
