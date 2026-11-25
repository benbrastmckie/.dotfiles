{
  ...
}:

{
  # Import our custom modules (see modules/home/default.nix for the full list)
  imports = [
    ./modules/home
  ];

  # Note: Python packages overlay (including cvc5) is defined in flake.nix

  # Ollama (modules/home/services/ollama.nix). Enabled for its own sake and its other consumers;
  # Sapience does not reach a model through it. The `anthropic` backend posts to
  # api.anthropic.com from the vendor client directly, so nothing local needs to hold a
  # credential or proxy a call on its behalf -- see docs/sapience.md.
  #
  # Worth a look if nothing else here wants it: the daemon loads no weights and sits at roughly
  # 20 MB resident, so it is cheap, but it is not load-bearing for anything in this file.
  # Note: one `services` attribute rather than separate dotted paths. statix's repeated-keys
  # check rejects re-opening the same top-level key three times, and `services.sf1-hub-ben`
  # below is the third (same constraint services/video-call-keepalive.nix documents).
  services = {
    ollamaModels = {
      enable = true;

      # Empty: nothing in this configuration asks the daemon to serve a model, so the loader has
      # nothing to pull. The loader only ever pulls, so `ollama rm llama3.1:latest` is what
      # reclaims the 4.9 GB that model still occupies on disk.
      load = [ ];
    };

    # Unattended meeting capture (modules/home/services/meeting-recorder.nix). Records while
    # lib/video-call-active.nix says a call is live, then transcribes locally with whisper.cpp
    # into transcriptDir. Everything stays on this machine: the weights are a store path
    # (packages/whisper-ggml-models.nix) and no model is contacted over the network.
    #
    # Deliberately NOT routed through Meetily, which cannot be made to start recording from
    # outside its GUI -- the module header states what was checked. Meetily still earns its keep
    # on the other end, importing a retained .wav for its summaries and templates; see
    # docs/meetily.md.
    meetingRecorder = {
      enable = true;

      # transcriptDir is left at its default, ~/Meetings -- a plain directory, not a Nix-managed
      # tree, because these are documents to read, edit and move and home-manager has no
      # business owning their lifetime.

      # Three days rather than 0. The ask was to discard audio once transcribed, but discarding
      # it immediately also forecloses the Meetily import that makes the summaries reachable --
      # the two goals are in direct tension, so this keeps the window just wide enough to notice
      # a meeting mattered and act on it. Set to 0 to discard as soon as the transcript lands.
      audioRetentionDays = 3;
    };
  };

  # Sapience knowledge vault (modules/home/services/sapience.nix). "relay" is ruled out on
  # privacy grounds: it transits redacted transcript chunks through app.spnc.ai BEFORE any
  # review gate. Of the three remaining backends, "anthropic" and "openai" have their provider
  # URL hardcoded in the vendor client (extract_local.py:1526 and :1537) and so cannot be aimed
  # elsewhere, while "ollama" is the only one whose endpoint is configurable (OLLAMA_HOST,
  # extract_local.py:167) -- see `backend` below for which is selected and what it costs.
  #
  # Enabling the module installs the CLI and the sync unit (on its own schedule or on request),
  # but reads nothing: the sync unit is gated on ~/.sapience/config.json via ConditionPathExists,
  # so no transcript is touched until `sapience-bootstrap` is run by hand and projects are
  # ticked. Claude Code's own registration of the vault is a separate, per-repository surface
  # owned by the sapience extension rather than by this module -- see docs/sapience.md.
  programs.sapience = {
    enable = true;

    # Pins extraction to api.anthropic.com, authenticated with `apiKeyFile` below.
    #
    # This is a deliberate privacy trade, stated plainly: chunks of raw transcript leave this
    # machine for a third-party provider. What is sent is transcript text, not the vault -- the
    # review gate still stands between an extraction and anything written to app.spnc.ai -- but
    # the text itself is no longer confined here. The alternative that keeps it confined is
    # "ollama" against a locally-resident model. Measured on this machine (24-core Ryzen AI 9
    # HX 370, no discrete GPU), llama3.1 decodes at roughly 6-7.7 tokens/sec under the Ollama
    # default (all cores) depending on ambient load, but the scheduled sync path deliberately
    # throttles to one thread (so a background job stays in the background), which measures
    # roughly 2-3 tokens/sec. A typical chunk fits in either case well inside the client's 180s
    # call timeout, but the client's own documented dense-chunk case (needing thousands of
    # output tokens) exceeds that timeout at any thread setting measured -- a real, occasional
    # outright failure, not merely slowness. Aiming "ollama" at ollama.com's hosted models
    # instead leaves this machine anyway AND returns HTTP 402 across every model tried, so it
    # buys no privacy and does not work.
    #
    # Revisit if local inference on this hardware becomes practical; that is the only option
    # that makes this trade unnecessary rather than merely accepted.
    backend = "anthropic";

    # Anthropic's cheapest tier, which is the right default for this workload: extraction wants
    # compact JSON inside a fixed reply budget, not reasoning depth.
    #
    # The budget is the binding constraint. llm() caps replies at 8000 tokens and never asks the
    # provider to suppress thinking, so any model that thinks by default spends that budget
    # before it emits JSON -- and a truncated reply yields no findings at all, while each overrun
    # costs two further calls through the re-split path in _extract_chunk, recursively to depth
    # 2. Haiku does not emit extended thinking unless asked, so the whole budget goes to content.
    #
    # Named explicitly rather than left empty. The client's own per-backend default for
    # "anthropic" is this same model, but an empty value sends no --model flag at all and leaves
    # the choice to vendor code that can change under us.
    #
    # Note that this value is passed as --model for every backend (sapience.nix:509 and :1177),
    # so it must always name a model the selected `backend` actually serves. Changing one
    # without the other fails at the provider, not at evaluation.
    #
    # The cost is recall, and it is paid per call: raise to a larger Anthropic model if review
    # shows findings are too thin.
    model = "claude-haiku-4-5";

    # The agent system's source store, ingested explicitly rather than by the implicit
    # memory-file walk that `memoryFiles = false` shuts off. One authored tree gets in; the 20+
    # generated .claude/ deploys it produces stay out. Run `sapience-adddir-sources` by hand --
    # nothing about this is scheduled, deliberately: `adddir` needs a TTY confirmation (or an
    # unattended `--yes`) to read anything, so activation has no safe way to run it itself.
    sourceDirs = [ "/home/benjamin/.config/nvim/agent-system" ];

    # Anthropic provider key, decrypted by sops-nix (modules/system/secrets.nix) to a mode-0400
    # file owned by this user, so it is readable by home-manager activation and never reaches the
    # world-readable Nix store. Activation merges it into ~/.sapience/config.json as the
    # api_key/api_key_env pair the client reads, taking the vendor's .run.lock first so a
    # concurrent extraction cannot lose its own folder and capture choices.
    #
    # Required at this backend: the module asserts on an empty apiKeyFile whenever `backend` is
    # "openai" or "anthropic".
    apiKeyFile = "/run/secrets/anthropic_api_key";

    # Sapience vault token, decrypted by sops-nix (modules/system/secrets.nix) to the same
    # owner/mode-0400 shape as apiKeyFile above, so sapience-bootstrap picks the token up
    # non-interactively on a fresh machine instead of prompting for a paste.
    #
    # Quoted deliberately: tokenFile is `nullOr path`, and assigning it an unquoted Nix path
    # literal to this same location would make the evaluator copy the secret into the
    # world-readable Nix store, or fail evaluation outright on a fresh machine before the
    # secret exists. A quoted string is read at activation time instead.
    tokenFile = "/run/secrets/sapience_token";
  };

  # SF-1 hub runner (modules/home/services/sf1-hub-ben.nix). The worker half of SF-1
  # delegation: task cards from the shared room run here, in throwaway worktrees, behind a
  # per-repo rule guard.
  #
  # Enabling it installs the CLI and declares the unit, and does nothing else. The runner makes
  # zero network and zero model calls before `sf1-hub-ben golive`, and refuses to serve at all
  # without a consent marker typed by hand in a real terminal. See docs/sf1-hub.md for the
  # setup sequence, which is deliberately not automated.
  services.sf1-hub-ben = {
    enable = true;

    # Pinned rather than left to PATH: packages/claude-code.nix is an npx wrapper, so a bare
    # `claude` resolves into an ~/.npm/_npx/<hash>/ cache path that changes whenever the cache
    # is rebuilt. The profile path is stable across those rebuilds.
    claudeBin = "/etc/profiles/per-user/benjamin/bin/claude";
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
