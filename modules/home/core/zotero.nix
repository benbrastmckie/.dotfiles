# Declarative ~/.config/zot/config.toml, sourced from the same sops secret as the shell exports
# (modules/system/shell.nix) and the systemd --user environment (services/zotero-env.nix). This
# gives `zot` usable credentials with ZERO dependence on environment propagation, in every
# context — interactive shell, agent-spawned bash, systemd --user unit — because a plain file
# under $HOME needs no propagation at all.
#
# Design decision (report 02, approach (b)): write the TOML directly from this activation script,
# rather than shelling out to `zot config init --api-key ...` (approach (a)). `config init`'s
# idempotency under repeated `home-manager switch` runs is undocumented and unverified upstream;
# writing the file directly puts idempotency fully under Nix's control and does not require the
# `zot` wrapper (and therefore a `uvx` network fetch) to be functional inside the activation
# sandbox. `zot config init` is never invoked against the real config path by this repo.
{ config, ... }:
{
  home.activation.zotConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    zotDir="${config.home.homeDirectory}/.config/zot"
    if [[ -v DRY_RUN ]]; then
      echo "Would write $zotDir/config.toml from /run/secrets/zotero_api_key"
    elif [ -r /run/secrets/zotero_api_key ]; then
      mkdir -p "$zotDir"
      ( umask 077
        cat > "$zotDir/config.toml" <<TOML
    [zotero]
    data_dir = "${config.home.homeDirectory}/Documents/Zotero"
    library_id = "2622830"
    api_key = "$(cat /run/secrets/zotero_api_key)"
    TOML
      )
      chmod 0600 "$zotDir/config.toml"
    else
      echo "zotConfig: /run/secrets/zotero_api_key not readable; skipping" >&2
    fi
  '';
}
