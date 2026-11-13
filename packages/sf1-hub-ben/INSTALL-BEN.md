# SF-1 hub runner on NixOS: install guide for Ben

Status (v0.2.1-1112, remote defaults: the live hub routes on https://app.spnc.ai): runs the shared hub runner core, the same bytes
Oliver runs (commit bb49e68c2). Tested on a NixOS 25.05 container
(30/30 rows, test/results-run7.json + rows-sh-run7.txt, incl. N14 remote route
rows against a stand-in of the live shapes).

## What it is

- A background runner for the shared Oliver + Ben room. It takes task
  cards from the room and runs each one in a fresh git worktree on your
  machine, with your own Claude Code login.
- The guard, per repo. It blocks edits and commits that break a rule you
  both accepted in the room, and stops writes if it can't reach the rules.
- It only runs in repos where you typed the consent line yourself.

## What it never touches

- Nothing under /usr, nothing as root.
- Nothing under ~/.claude except the memory sync below. Your settings,
  CLAUDE.md, commands and agents stay as they are, including links
  home-manager owns.
- Your working tree. Cards run in worktrees under
  ~/.local/state/sf1-hub-ben/hub/runner/work/.
- Your unpushed branches stay private unless you opt in, per repo.

## 1. Install (pick one)

### a. Flake + home-manager

    inputs.sf1-hub-ben.url = "path:/path/to/sf1-hub-ben-nixos";
    # in your home-manager modules:
    imports = [ inputs.sf1-hub-ben.homeManagerModules.default ];
    services.sf1-hub-ben.enable = true;
    # services.sf1-hub-ben.claudeBin = "/etc/profiles/per-user/ben/bin/claude";

Then `home-manager switch`. That puts `sf1-hub-ben` on your PATH and
declares `sf1-hub-ben.service` as a user unit. It does not auto-start
(`autoStart = false`).

### b. Plain script (no flake)

    sh install.sh            # dry run: prints what it would write
    sh install.sh --install

If python3 isn't on your PATH it runs `nix build nixpkgs#python3` with
a GC root in ~/.local/state/sf1-hub-ben/gcroots/. If home-manager owns
~/.config/systemd/user, it doesn't write the unit and tells you to use
route (a).

## 2. Your token, then attach the guard, one repo at a time

    sf1-hub-ben token                 # paste your private link; nothing is shown or printed
    sf1-hub-ben attach ~/code/<repo>

The private link is in the app: Settings > "Sign in on another device" >
"copy my private link". `token` keeps only the token part, in
~/.config/sf1-hub-ben/sapience-token and as SAPIENCE_TOKEN in
~/.config/sf1-hub-ben/env (both 600). Never paste it in a chat.

attach defaults to the live routes: rules
hub-route:https://app.spnc.ai/v1/projects/oliver-ben/rules, events
hosted-events:https://app.spnc.ai/v1/rooms/mEdYrFW_qClSGDfx/events, read
with your own token. Your handle on the server is "benjamin" (the first
word of your name in the app); if you rename yourself, put
SF1_HUB_PERSON=<new first word> in the env file.

This writes `.git/hooks/{pre-commit,post-commit,post-rewrite}` and adds
two hook entries to `<repo>/.claude/settings.local.json` (gitignored).
It keeps anything already in that file and backs everything up first.

Then restart Claude Code in that repo (inside nvim too), run `/hooks`,
and check the guard entry is listed.

If your hooks or that repo's .claude are Nix-managed, attach refuses and
prints the lines to add to your Nix config instead.

## 3. Consent, in your own terminal

    sf1-hub-ben enable ~/code/<repo>      # same as `consent`

Type the line it shows, exactly. A second question asks whether to share
unpushed branches. Press Enter to keep that off.

It refuses to run from Claude Code, from a script, or without a real
terminal. Once the guard is attached, no Claude Code session can write
the marker either. One marker per repo.

## 4. Start it

    systemctl --user start sf1-hub-ben.service
    sf1-hub-ben status

It runs preflight first and refuses (exit 78, no restart loop) if:
there's no consented repo, the kill switch is on, the guard isn't
attached, or the runner core can't run cards with the guard hook.

Cards run in ONE repo. With one consented repo that's the one; with
several, put `SF1_HUB_CARD_REPO=<slug>` in ~/.config/sf1-hub-ben/env.
The env file also holds `SAPIENCE_TOKEN=<your brain token>` (the runner
reads the room with it) and, optionally, `ANTHROPIC_API_KEY` /
`OPENROUTER_API_KEY` for the card-plan pair (off without them). The
runner never hands any *_TOKEN or *_KEY variable to a card.

## 5. Go live (after the room thread's go-live)

    sf1-hub-ben golive                     # base defaults to https://app.spnc.ai

Until this, the runner is pre-live: zero network calls, zero model
calls. golive makes one rules request and mints your hub key (600).
It first reads the room once. It goes on only if the room shows
Oliver's room thread went live: its labeled SF-1 test post, then its
digest message. If not, it stops there, with no other call. Then a card for you looks like:

    CARD for:benjamin repo:<slug> base:<sha> files:<glob> accept:<cmd> cites:none dirty:no
    <the task, on the next lines>

A card Oliver writes for you waits for your `TAKE C-<n>`. Either of
you can `HOLD C-<n>`.

## Stop it

- `sf1-hub-ben kill`: stops the runner and every card it started.
  Anyone can run it, an agent included. Nothing restarts until you run
  `sf1-hub-ben unkill` yourself in a terminal.
- `sf1-hub-ben detach ~/code/<repo>`: turns the guard off in one repo,
  tells the room, and restores that repo's hook files byte-for-byte.
  You run this yourself.
- `sf1-hub-ben uninstall`: kill, detach everywhere, and remove every file
  it installed. You run this yourself.

## Known gaps

- Memory sync is ON: room rulings go into one file, hub-rulings.md,
  plus one pointer line in MEMORY.md, in your Claude Code memory for the
  card repo (~/.claude/projects/<path>/memory). MEMORY.md is backed up
  first and restored byte-for-byte on uninstall. If home-manager owns
  any of that path (a read-only link), sync stays off and `status` says
  why.
- An nvim plugin that calls the API directly, without Claude Code, gets
  no edit-time check. Only the commit-time hook covers it.
- Claude Code hook behaviour has to be re-measured on your version (G1).
  On 2.1.322, a hook that exits 1 or times out lets the action through,
  which is why the command ends in `|| exit 2`.
- If home-manager makes ~/.claude/projects read-only, room rulings can't
  go into your Claude Code memory files. The guard and the room still
  carry them.
