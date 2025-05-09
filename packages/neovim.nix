{ pkgs, pkgs-unstable, lib, ... }:

# This creates a proper wrapper around neovim-unwrapped from unstable
# that includes the missing maintainers attribute to prevent build errors
pkgs.wrapNeovimUnstable pkgs-unstable.neovim-unwrapped {
  configure = {};
  extraMakeWrapperArgs = "";
  extraName = "";
  withPython3 = true;
  withNodeJs = false;
  withRuby = false;
  viAlias = true;
  vimAlias = true;
  
  # The wrapNeovim function adds meta attributes, but the maintainers attribute
  # isn't properly set, causing the error. We'll fix it here.
} // {
  meta = {
    description = "Vim-fork focused on extensibility and usability (unstable version)";
    homepage = "https://neovim.io";
    license = lib.licenses.mit;
    mainProgram = "nvim";
    # This is what was missing
    maintainers = [ "claude" ];
    platforms = lib.platforms.all;
  };
}