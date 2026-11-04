# Local Ollama server plus a declarative model loader. Sole consumer at present is
# programs.sapience with backend = "ollama"; nothing here is coupled to Sapience. See
# docs/sapience.md.
#
# Whether transcript text stays on this machine is decided by the CONSUMER's model name, not by
# this module. A plain name (llama3.1) is served from local weights; a name ending in ":cloud"
# makes this daemon authenticate against ollama.com, forward the call and run nothing locally.
# In that mode the daemon is a credential-holding transport, which is the only way a consumer
# that sends no Authorization header can reach a remote model at all. Sapience currently names
# gemma4:cloud, so no inference happens here today.
#
# Note: home-manager rather than NixOS, so the whole feature stays on one rebuild path -- the
# cost is that the NixOS module's loadModels is unavailable and the pull below is hand-rolled.
#
# Note: CPU-only whenever a model does run here. ROCm on this gfx1150 iGPU is experimental and
# the workload was an hourly background job on 24 cores. Moot while the consumer names a
# ":cloud" model, which is also why the ROCm question stopped being urgent. See
# docs/sapience.md.
#
# Module shape follows services/cache-cleanup.nix: oneshot with guarded external calls, and the
# loader always exits 0 so a failed pull cannot degrade the user systemd session (the
# scripts/gmail-oauth2.nix precedent).
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

        Cloud models do NOT belong here. A ":cloud" name carries no weights, the server
        resolves it remotely on first use, and listing it only makes the loader log a
        pointless pull. An empty list is correct when every consumer names a cloud model.

        Note this list only ever adds: removing an entry stops it being re-pulled but
        never deletes it. Use `ollama rm <name>` to reclaim the disk.
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
                # Critical: exact match on the NAME column, never a regex -- a model name
                # contains dots, and escapeShellArg does not escape regex metacharacters.
                # awk NR>1 drops the header; bare and :latest forms both count as present.
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
