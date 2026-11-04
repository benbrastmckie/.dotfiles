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

    # Google's Gemma 4, forwarded to ollama.com by the local daemon. Chosen on measured
    # behaviour rather than benchmark scores, because what this workload needs is compact JSON
    # inside a fixed reply budget, not reasoning depth.
    #
    # llm() caps replies at num_predict 8000 and never sends `think: false`, so thinking tokens
    # compete with the JSON for that budget. gemma4 is the only model on Ollama's free list that
    # emits NO thinking at all: on one extraction prompt it answered in 1.7s with 552 output
    # tokens, against beam:cloud's 20.5s and 2152 tokens (6156 characters of which were
    # thinking). beam, both gpt-oss sizes and all three nemotrons think by default, and on a
    # 32-token probe four of them spent the whole budget thinking and returned empty content.
    #
    # That is not academic. Under beam a dense chunk overran the 8000 cap repeatedly, logging
    # "the cut-off reply had 0" -- the entire budget spent before any JSON -- and each overrun
    # costs two more calls through the re-split path in _extract_chunk, recursively to depth 2.
    # Extraction calls were running 37-86s each. gemma4's 552 tokens leave ~15x headroom.
    #
    # The cost is recall: on the same chunk beam returned 20 facts to gemma4's 9. Revisit if
    # review shows findings are too thin -- but beam's extra facts were not reliably realised,
    # since a truncated reply yields none at all.
    #
    # Free on Ollama's usage page, same as beam. `gemma4:cloud` tracks whatever size Ollama
    # points the tag at (31b today); pin `gemma4:31b-cloud` if that ever matters.
    model = "gemma4:cloud";

    # The agent system's source store, ingested explicitly rather than by the implicit
    # memory-file walk that `memoryFiles = false` shuts off. One authored tree gets in; the 20+
    # generated .claude/ deploys it produces stay out. Run `sapience-adddir-sources` by hand --
    # nothing about this is scheduled.
    sourceDirs = [ "/home/benjamin/.config/nvim/agent-system" ];
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
