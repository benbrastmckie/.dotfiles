# Aggregator for the per-binary agent-tool modules in this directory. See lib.nix for the
# shared helpers and the frozen wrapper contract.
{ ... }:
{
  imports = [
    ./census.nix
    ./classify.nix
    ./unsubscribe-extract.nix
    ./archive-confirmed.nix
    ./delete-confirmed.nix
  ];
}
