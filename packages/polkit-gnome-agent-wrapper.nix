# Polkit authentication agent for the niri session: polkit_gnome ships the agent under
# libexec/ (not linked onto PATH), so expose it on PATH under its conventional bin name.
{ lib, writeShellScriptBin, polkit_gnome }:

writeShellScriptBin "polkit-gnome-authentication-agent-1" ''
  #!/bin/sh
  exec ${polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 "$@"
''
