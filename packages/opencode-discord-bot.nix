# buildPythonApplication for the OpenCode Discord bot relay (packages/opencode-discord-bot/).
# callPackage'd directly in modules/system/optional/discord-bot.nix -- NOT routed through
# overlays/python-packages.nix, which is scoped to LIBRARY overrides composed via
# python3.withPackages. This is a standalone application with its own console-script
# entry point, so it is wired directly at its single consumption site instead.
#
# Future work: own-repo extraction. packages/opencode-discord-bot/ currently lives in-tree
# (src = ./opencode-discord-bot) as the deliberate near-term choice -- mirroring how most
# packages/*.nix here vendor small sources directly. If the bot's source grows independent
# release cadence or needs to be reused outside this flake, it could be extracted to its own
# repository and consumed as a flake input, the same way the email extension documents its
# wrapper-binary/own-source precedent (see .claude/extensions/email/ and docs/). Not
# implemented here -- deferred until there is an actual need to version/release it separately.
{
  lib,
  buildPythonApplication,
  setuptools,
  nextcord,
  aiohttp,
}:

buildPythonApplication {
  pname = "opencode-discord-bot";
  version = "0.1.0";
  pyproject = true;

  src = ./opencode-discord-bot;

  build-system = [ setuptools ];
  dependencies = [
    nextcord
    aiohttp
  ];

  pythonImportsCheck = [ "opencode_discord_bot" ];

  meta = with lib; {
    description = "Nextcord Discord bot relay for OpenCode agent management";
    homepage = "https://github.com/benbrastmckie/.dotfiles";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
