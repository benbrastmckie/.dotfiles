# Custom sioyek wrapper: disable Qt client-side decorations on Wayland (GNOME 49 ignores
# _MOTIF_WM_HINTS for XWayland, so use native Wayland + QT_WAYLAND_DISABLE_WINDOWDECORATION).
# Self-referential: wraps nixpkgs `sioyek` under the same name, so it is wired via
# `prev.sioyek` (NOT callPackage) to avoid recursion.
#
# The wrapper also seeds the theme-toggle state file. Sioyek reapplies the `custom_*`
# colors from prefs_user.config (Nord dark) on every launch, while the state file that
# `sioyek-theme-toggle` reads persists across launches; seeding it keeps the two in step
# so `w` toggles to Gruvbox light on the first press of every session. Commands sent to
# an already-running instance (`--execute-command`) must not reseed it, since that would
# desync the live window's palette.
sioyek: writeShellScriptBin:

writeShellScriptBin "sioyek" ''
  #!/bin/sh
  export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

  case " $* " in
    *" --execute-command "*) ;;
    *)
      state_file="''${XDG_CACHE_HOME:-$HOME/.cache}/sioyek-theme-state"
      mkdir -p "$(dirname "$state_file")" 2>/dev/null || true
      echo nord > "$state_file" 2>/dev/null || true
      ;;
  esac

  exec ${sioyek}/bin/sioyek "$@"
''
