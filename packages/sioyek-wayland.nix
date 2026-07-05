# Custom sioyek wrapper: disable Qt client-side decorations on Wayland (GNOME 49 ignores
# _MOTIF_WM_HINTS for XWayland, so use native Wayland + QT_WAYLAND_DISABLE_WINDOWDECORATION).
# Self-referential: wraps nixpkgs `sioyek` under the same name, so it is wired via
# `prev.sioyek` (NOT callPackage) to avoid recursion.
sioyek: writeShellScriptBin:

writeShellScriptBin "sioyek" ''
  #!/bin/sh
  export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
  exec ${sioyek}/bin/sioyek "$@"
''
