# Local Ollama server for on-device LLM inference, plus a declarative model loader.
#
# Sole consumer at present: programs.sapience with backend = "ollama", which keeps AI-session
# transcript text on this machine instead of relaying it to a third party. Ollama is useful
# independently, so this module carries its own enable flag rather than being folded into
# services/sapience.nix -- but nothing here is coupled to Sapience, and the two can be enabled
# separately in either order.
#
# HOME-MANAGER, NOT NIXOS (deliberate): nixpkgs' NixOS `services.ollama` has `loadModels` /
# `syncModels` / `modelsDir`, which the home-manager module lacks, so the model pull below is
# hand-rolled. That cost is worth paying to keep this in the home profile: the server then runs
# as this user against ~/.ollama, needs no sudo, and -- the point that decided it -- the whole
# Sapience feature stays on ONE rebuild path (`home-manager switch`, <leader>nh) instead of
# splitting across a system rebuild for the model store and a home rebuild for its only client.
#
# CPU INFERENCE (deliberate): this machine is a Radeon 890M (gfx1150, RDNA 3.5) integrated GPU.
# ROCm support for gfx1150 is experimental and typically needs an HSA_OVERRIDE_GFX_VERSION fudge
# via rocmOverrideGfx, while pulling a multi-gigabyte ROCm closure. The only workload here is an
# hourly background extraction over transcript deltas, where latency is irrelevant and 24 Ryzen
# cores are ample. To revisit later, set `services.ollama.acceleration = "rocm"` -- the
# home-manager module exposes it -- and expect to tune the gfx override.
#
# Module shape follows services/cache-cleanup.nix and services/zotero-translation-server.nix:
# oneshot + guarded external calls + `starting`/`done` echo bracketing, with the
# scripts/gmail-oauth2.nix precedent in mind (a unit that fails every run degrades the whole
# user systemd session), so the loader always exits 0.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ollamaModels;
in
{
  options.services.ollamaModels = {
    enable = lib.mkEnableOption "the local Ollama server and its declarative model loader";

    load = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "llama3.1" ];
      example = [
        "llama3.1"
        "qwen2.5-coder"
      ];
      description = ''
        Models to `ollama pull` once the server is up, if not already present. Defaults to
        llama3.1, which is what Sapience's ollama backend asks for by default (its
        extract_local.py maps backend "ollama" to model "llama3.1"); changing this list without
        also setting a matching model on the consumer will leave that consumer pulling a model
        on first use. Roughly 4.7 GB on disk for llama3.1 at the default quantisation.
      '';
    };

    pullTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = ''
        Per-run ceiling for the model loader. A cold pull of several gigabytes over a slow link
        can take a long time, and the unit is oneshot, so systemd's default timeout would kill a
        legitimate first pull partway through.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      # Localhost only. Nothing outside this machine has any business reaching the inference
      # server, and the whole reason this module exists is to keep transcript text local.
      host = "127.0.0.1";
      port = 11434;
    };

    # Pulls declared models after the server is listening. Not a timer: this is convergence to a
    # declared state, so it runs once per activation and is a cheap no-op (`ollama list` grep)
    # whenever the models are already there.
    systemd.user.services.ollama-model-loader = {
      Unit = {
        Description = "Pull the Ollama models declared in services.ollamaModels.load";
        After = [ "ollama.service" ];
        Wants = [ "ollama.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = false;
        TimeoutStartSec = cfg.pullTimeoutSec;
        ExecStart =
          let
            script = pkgs.writeShellScript "ollama-model-loader" ''
              export PATH="${
                lib.makeBinPath [
                  pkgs.coreutils
                  pkgs.curl
                  pkgs.gawk
                  pkgs.gnugrep
                  pkgs.ollama
                ]
              }:$PATH"
              export OLLAMA_HOST="127.0.0.1:11434"
              # Deliberately no `set -e`: a model pull is a large network operation and a
              # transient failure must not leave this unit `failed`. Always reaches exit 0; the
              # next activation retries whatever is still missing.

              echo "ollama-model-loader: starting"

              # Wait for the server rather than racing it: After= only orders unit START, and
              # ollama needs a moment to bind the port before `ollama list` can succeed.
              ready=0
              for _ in $(seq 1 30); do
                if curl -fsS -m 2 "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
                  ready=1
                  break
                fi
                sleep 1
              done

              if [ "$ready" -ne 1 ]; then
                echo "ollama-model-loader: server not reachable, skipping (will retry next activation)"
                echo "ollama-model-loader: done"
                exit 0
              fi

              present="$(ollama list 2>/dev/null || true)"

              ${lib.concatMapStringsSep "\n" (m: ''
                # Exact match on the NAME column, not a regex: a model name contains dots
                # ("llama3.1"), which an -E pattern would treat as wildcards, and
                # lib.escapeShellArg quotes for the shell without escaping regex metacharacters.
                # awk NR>1 drops the header row; both the bare name and the resolved :latest
                # form count as present, since `ollama list` prints the tag while the declared
                # name here is usually untagged.
                names="$(echo "$present" | awk 'NR > 1 { print $1 }')"
                if echo "$names" | grep -qxF ${lib.escapeShellArg m} \
                  || echo "$names" | grep -qxF ${lib.escapeShellArg "${m}:latest"}; then
                  echo "ollama-model-loader: ${m} already present"
                else
                  echo "ollama-model-loader: pulling ${m} (this may take a while)"
                  ollama pull ${lib.escapeShellArg m} \
                    || echo "ollama-model-loader: pull of ${m} failed (will retry next activation)"
                fi
              '') cfg.load}

              echo "ollama-model-loader: done"
              exit 0
            '';
          in
          "${script}";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
