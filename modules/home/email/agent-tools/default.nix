# Aggregator for the task-88 split of the former monolithic email/agent-tools.nix (761 lines)
# into per-binary modules. See lib.nix for the full contract provenance and shared helpers.
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
