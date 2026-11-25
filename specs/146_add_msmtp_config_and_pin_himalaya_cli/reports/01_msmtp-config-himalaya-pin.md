# Research Report: Task #146

**Task**: 146 - Add msmtp config and pin Himalaya CLI
**Started**: 2026-11-25T19:46:37Z
**Completed**: 2026-11-25T19:58:00Z
**Effort**: Small (about 1-2 hours implementation; one new module, one overlay, three small edits, docs)
**Dependencies**: None (must land before the nvim repo's notmuch.nvim send path is exercised)
**Sources/Inputs**:
- Local config: `flake.nix`, `flake.lock`, `lib/mkHost.nix`, `overlays/unstable-packages.nix`,
  `modules/home/default.nix`, `modules/home/packages/email-tools.nix`,
  `modules/home/email/{aerc,mbsync,protonmail}.nix`, `modules/home/email/agent-tools/*.nix`,
  `hosts/hamsa/default.nix`, `config/himalaya-config.toml`, `.claude/hooks/mail-guard.sh`
- Locked sources read from the store: nixpkgs `pkgs/by-name/hi/himalaya/package.nix` (both
  locked nixpkgs inputs), home-manager `modules/programs/msmtp/{default,accounts}.nix`
- Live read-only probes on host `hamsa`: `nix eval`, `openssl s_client` and an unauthenticated
  `EHLO` against the Bridge SMTP listener, `himalaya --version`
- MCP-NixOS (`nix_versions himalaya`, home-manager `programs.msmtp` options)
- Upstream: himalaya `Cargo.toml` at tags v1.2.0 / v2.0.0 / v2.2.1, himalaya `CHANGELOG.md`,
  the msmtp manual (marlam.de)
**Artifacts**: - specs/146_add_msmtp_config_and_pin_himalaya_cli/reports/01_msmtp-config-himalaya-pin.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Himalaya pin**: use a dedicated flake input pinned to the nixpkgs revision that
  `nixpkgs-unstable` is locked to today (`567a49d1913ce81ac6e9582e3553dd90a955875f`). Verified by
  `nix eval`: the feature-overridden himalaya from that revision evaluates to
  `/nix/store/909gc7jx8rv42hrmqm5r0zc0i73kyl61-himalaya-1.2.0`, the exact path installed now, so
  the pin is a zero-rebuild, zero-behavior-change move that also freezes the Rust toolchain.
- **The breakage is real and imminent**: upstream `Cargo.toml` at v2.0.0 and v2.2.1 has no
  `oauth2` or `keyring` feature, and nixpkgs master already ships 2.2.1 (NixHub). The next
  `nix flake update nixpkgs-unstable` would fail the build on the existing
  `--features=oauth2,keyring` flag. Stable `nixos-26.05` also carries 1.2.0 today, but it is a
  channel, not a pin.
- **Proton Bridge TLS, measured rather than guessed**: `127.0.0.1:1025` is plaintext with
  STARTTLS (implicit TLS fails with "wrong version number"). Its certificate is self-signed
  (`CN=127.0.0.1`, SAN `IP:127.0.0.1`, valid to 2046) and verifies cleanly against the system
  trust store on `hamsa`, because `hosts/hamsa/default.nix` adds
  `hosts/hamsa/protonmail-bridge-ca.pem` to `security.pki.certificateFiles`. msmtp therefore
  needs `tls on`, `tls_starttls on`, `host 127.0.0.1` (not `localhost`), and the system bundle.
- **msmtp module**: `programs.msmtp` with a raw `configContent` block is the best fit. It
  writes `~/.config/msmtp/config`, installs the package (so the bare `msmtp` in
  `email-tools.nix` is removed), and avoids introducing the unused `accounts.email` tree.
- **Envelope-from selection**: `msmtp -t --read-envelope-from` picks the first account whose
  `from` matches the From header and falls back to `account default` otherwise. Each account
  needs an explicit `from`; `account default : gmail` matches himalaya's `default = true`.
- **Verification constraint**: the mail-guard hook denies every agent Bash call containing a
  bare `msmtp` or `secret-tool` token, including `msmtp --version`. The implementer cannot run
  `msmtp --pretend` / `--serverinfo`. Verify the rendered config statically and hand the two
  live commands to the user. Do not route around the hook.

## Context & Scope

Two changes in one Nix task: (1) a declarative msmtp configuration for the two mail accounts,
consumed by notmuch.nvim's hardcoded `msmtp -t --read-envelope-from`; (2) pinning the Himalaya
CLI at v1.2.0 so the five email wrapper binaries keep working across nixpkgs bumps.
Constraints: wrappers, mail-guard, mbsync/mail-sync, and aerc unchanged; no real mail sent
during verification; `config/himalaya-config.toml` stays in place.

Not done in this phase: no msmtp binary was executed (hook-denied, see Finding 6), no
authentication against either SMTP server was attempted, and no build of a modified
configuration was run. The v3.0.0 `Cargo.toml` could not be fetched (tag URL returned an
error); v3 statements below rest on the changelog only.

## Findings

### 1. Existing Configuration

- `modules/home/packages/email-tools.nix` installs `msmtp` bare in `home.packages` and builds
  `pkgs-unstable.himalaya.overrideAttrs` appending `--features=oauth2,keyring` to
  `cargoBuildFlags`. No msmtp config exists anywhere in the repo.
- `modules/home/default.nix` imports `./email/{mbsync,protonmail,notmuch,aerc,mail-sync}.nix`
  and `./email/agent-tools`; the new module goes on that list.
- aerc outgoing settings (`modules/home/email/aerc.nix`, `accounts.conf`):
  - gmail: `smtps://benbrastmckie@gmail.com@smtp.gmail.com:465` (implicit TLS)
  - logos: `smtp://benjamin@logos-labs.ai@127.0.0.1:1025` — in aerc, `smtp://` means STARTTLS
    with certificate verification (`smtp+insecure://` is the plaintext form)
  - credential commands are bare `secret-tool lookup ...` (libsecret is system-wide)
- The other two Bridge clients skip TLS on loopback: mbsync uses `TLSType None` on 1143 and
  `config/himalaya-config.toml` uses `encryption.type = "none"` on 1025.
- `hosts/hamsa/default.nix` trusts the Bridge CA system-wide, with a comment saying this
  exists so aerc can send through 1025. No other host (`nandi`, `garuda`) has this, and the
  certificate is per-Bridge-vault, so the hamsa PEM would not validate another machine's
  Bridge anyway.
- Himalaya v1 call sites, all through `PATH`:
  `agent-tools/lib.nix` (`envelope list -o json -s`, `message read -p -H Message-Id`),
  `census.nix` (`envelope list -o json`), `archive-confirmed.nix` (`message move`),
  `delete-confirmed.nix` (`message delete`, `folder expunge`).
- Flake inputs: `nixpkgs` = `nixos-26.05` (locked 2026-09-21), `nixpkgs-unstable` =
  `nixos-unstable` (locked 2026-06-16, rev `567a49d1...`). Home modules receive
  `pkgs-unstable` through `extraSpecialArgs`, which is declared twice: `hmExtraSpecialArgs` in
  `flake.nix` and inline in `lib/mkHost.nix`. Both home-manager paths share
  `nixpkgsConfig.overlays`.
- Pinning precedent: `packages/landrun.nix` deliberately shadows nixpkgs' version through
  `overlays/unstable-packages.nix`, documented in `packages/README.md`.
- `nix flake check` runs statix, deadnix (`--fail`), nixfmt, and shellcheck as flake checks.

### 2. Himalaya Versions and Upstream Breakage

| Source | Version | Evidence |
|--------|---------|----------|
| Installed binary | 1.2.0 `+oauth2 +keyring +maildir +imap +smtp +sendmail +wizard +pgp-commands` | `himalaya --version` |
| Locked `nixpkgs-unstable` | 1.2.0 | `nix eval` |
| Locked `nixpkgs` (26.05) | 1.2.0, `package.nix` byte-identical to unstable's | `diff` of the two store sources |
| nixpkgs master | 2.2.1 (2.0.0 landed first) | MCP-NixOS `nix_versions` |

Upstream `Cargo.toml` `[features]`, fetched per tag:

- v1.2.0: `imap maildir notmuch smtp sendmail keyring oauth2 wizard pgp-commands pgp-gpg pgp-native`
- v2.0.0: `rustls-ring imap smtp jmap gmail msgraph maildir m2dir native-tls rustls-aws vendored`
  — no `oauth2`, no `keyring`, and `maildir` is not in the default set
- v2.2.1: same family plus `mbox sieve pimdir` — still no `oauth2` / `keyring`

So `--features=oauth2,keyring` is a hard cargo error on any 2.x source. The changelog also
records for 2.0.0 a flattened command tree replacing the `mailbox`/`envelope`/`message`/`flag`
subgroups, and for 3.0.0 "Changed every `--json` key to camelCase". Both break the wrappers
independently of the build failure. (A summarizing fetch of the changelog reported no explicit
"removed oauth2/keyring" line; the `Cargo.toml` diff is the authoritative evidence.)

Side observation: `config/himalaya-config.toml` uses `auth.command` with `secret-tool`, so
neither the `oauth2` nor the `keyring` feature is exercised at runtime. They are kept anyway
because dropping them changes the derivation and gains nothing for this task.

### 3. Pin Mechanism Comparison

| Option | Result | Cost / risk |
|--------|--------|-------------|
| **A. Dedicated flake input at a fixed nixpkgs rev** | Same expression, same rustc, same output path as today; immune to both channel bumps | One more lock node; a frozen closure (old glibc/openssl kept alive for this one package); no security updates to its linked libraries |
| B. `overrideAttrs` of `src`/`cargoHash` on `pkgs-unstable.himalaya` | Stays on current toolchain | Layers v1.2.0 sources onto whatever the 2.x/3.x nixpkgs expression becomes (different features, inputs, postInstall); most fragile |
| C. Vendored `packages/himalaya.nix` (`buildRustPackage`, v1.2.0 `hash`/`cargoHash` copied from nixpkgs) | Independent of the nixpkgs expression; matches the `landrun` precedent | Rebuild now; a future rustc can stop compiling 2025-era crates, so the pin can still break on a toolchain bump |
| D. Switch to stable `pkgs.himalaya` | No new input | Not a pin; moves to 2.x at the next release-channel upgrade |

Option A is the only one that pins the toolchain along with the source, and it is the only
one verified to reproduce the installed store path exactly.

### 4. Proton Bridge SMTP: Live Probe Results (host `hamsa`)

- `protonmail-bridge` user service active; listening on `127.0.0.1:1025` and `127.0.0.1:1143`.
- Unauthenticated `EHLO` on 1025 advertises `STARTTLS` and `AUTH PLAIN LOGIN` (AUTH is offered
  before STARTTLS too, which is why himalaya's `encryption none` works).
- `openssl s_client -starttls smtp -CAfile /etc/ssl/certs/ca-certificates.crt -verify_ip 127.0.0.1`:
  TLSv1.3, `Verify return code: 0 (ok)`.
- Direct TLS connect to 1025 (no STARTTLS): `wrong version number` — not implicit TLS.
- Certificate: self-signed, subject and issuer `C=CH, O=Proton AG, OU=Proton Mail, CN=127.0.0.1`,
  `CA:TRUE`, SAN `IP Address:127.0.0.1`, RSA 2048, valid 2026-02-09 to 2046-02-04; identical to
  `hosts/hamsa/protonmail-bridge-ca.pem`.

Consequences for msmtp:
- `tls on` + `tls_starttls on` + `tls_trust_file /etc/ssl/certs/ca-certificates.crt` works on
  hamsa with full verification, and mirrors what aerc already does.
- `host` must be `127.0.0.1`: the certificate carries an IP SAN only, so `localhost` would fail
  host verification.
- On a host without the Bridge CA in its trust store the logos account fails closed with a
  certificate error. That is the same behavior aerc has there today.
- The plaintext alternative (`tls off` + explicit `auth plain`) would be host-independent, but
  msmtp's `auth on` only considers SCRAM methods without TLS and the Bridge offers only
  PLAIN/LOGIN, so it needs a forced mechanism and sends the Bridge password unencrypted over
  loopback. Not recommended given verified TLS is available.

### 5. msmtp via Home Manager

- `programs.msmtp` options in the locked home-manager (release-26.05): `enable`, `package`,
  `configContent` (plus deprecated `extraConfig`/`extraAccounts`). Enabling it adds
  `cfg.package` to `home.packages`, writes `xdg.configFile."msmtp/config"`, and sets
  `MSMTPQ_Q` / `MSMTPQ_LOG` session variables.
- Per-account generation exists only through `accounts.email.accounts.<name>.msmtp`, which this
  repo does not use anywhere (aerc, mbsync, notmuch are all raw text). Introducing
  `accounts.email` for one consumer would add required fields (`realName`, `primary`, `smtp.*`)
  and a second source of account truth.
- With no `accounts.email` entries the module emits `# Generated by Home Manager.` followed by
  `configContent`, so raw `account` blocks in `configContent` are safe. The module's "account
  default was already defined" warning applies only when both mechanisms define accounts.
- msmtp manual, relevant semantics:
  - `--read-envelope-from`: envelope-from is taken from the From (or Resent-From) header; the
    first account with a matching `from` is chosen; with no match, account `default` is used.
  - `tls_starttls` defaults to `on`; `off` means tunnel the session through TLS (port 465).
  - `tls_trust_file` defaults to `system`.
  - `passwordeval` runs only when the password is needed; the store-symlinked config holds no
    secret, so its world-readable mode is not a problem.
- stable `pkgs.msmtp` is 1.8.32.

Recommended rendered config:

```
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account gmail
host smtp.gmail.com
port 465
tls_starttls off
from benbrastmckie@gmail.com
user benbrastmckie@gmail.com
passwordeval "secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com"

account logos
host 127.0.0.1
port 1025
tls_starttls on
from benjamin@logos-labs.ai
user benjamin@logos-labs.ai
passwordeval "secret-tool lookup service protonmail-bridge username benjamin@logos-labs.ai"

account default : gmail
```

### 6. Verification Is Constrained by mail-guard

`.claude/hooks/mail-guard.sh` denies any agent Bash command matching
`(^|[|;&[:space:]])msmtp([[:space:]]|$)` or the same pattern for `secret-tool`. This was hit
during research: a compound command containing `msmtp --version` was refused. `himalaya
--version` is allowed (only the mutating himalaya subcommands are denied).

The task's suggested `msmtp --pretend` / `--serverinfo` checks therefore cannot be run by the
implementation agent. Invoking the binary through its store path or a wrapper script would
evade the pattern, and that is exactly what the hook is there to stop; it must not be done.
What an agent can do:

- Build the generation and read the rendered file out of the build result
  (`result/home-files/.config/msmtp/config` for the standalone path) and assert its contents.
- Rely on the handshake evidence in Finding 4 for the Bridge TLS parameters.
- List the live commands in the summary for the user to run after switching:
  `msmtp --pretend --account=gmail`, `msmtp --pretend --account=logos`,
  `msmtp --serverinfo --account=gmail`, `msmtp --serverinfo --account=logos`, and
  `msmtp --pretend --read-envelope-from -t < draft.eml` per From address.
  `--pretend` prints `*` for the password and takes no network action; `--serverinfo` connects
  and negotiates TLS but does not authenticate or send.

A sandboxed flake check that runs `msmtp --pretend -C <rendered file>` would be mechanically
possible, but it makes an agent-triggered build execute a binary the hook denies to agents, so
it is not recommended without the user asking for it.

## Decisions

- **Pin mechanism: Option A**, input `nixpkgs-himalaya` at
  `github:NixOS/nixpkgs/567a49d1913ce81ac6e9582e3553dd90a955875f`, exposed through an overlay as
  `pkgs.himalaya` so `lib/mkHost.nix` and `hmExtraSpecialArgs` need no new argument.
- **Keep `--features=oauth2,keyring`** on the pinned build, to preserve the installed
  derivation exactly.
- **msmtp via `programs.msmtp.configContent`**, not `accounts.email` and not a bare
  `home.file`; remove `msmtp` from `email-tools.nix`.
- **Logos account uses STARTTLS with verification against the system bundle**, mirroring aerc.
- **Default account: gmail.**
- **`passwordeval` uses bare `secret-tool`**, matching aerc, mbsync, and himalaya. A store path
  (`${pkgs.libsecret}/bin/secret-tool`) is a reasonable hardening if the planner prefers it.
- **No msmtp execution by agents**; live msmtp checks are a user-run step.
- No `user_decision` raised: every choice above is settled by evidence or repo convention.

## Recommendations

1. **`flake.nix`** — add the input and an overlay entry:
   - `nixpkgs-himalaya.url = "github:NixOS/nixpkgs/567a49d1913ce81ac6e9582e3553dd90a955875f";`
     with a comment stating why it is frozen and what must be true before it is moved (the
     wrappers ported to the newer CLI).
   - Add `nixpkgs-himalaya` to the `outputs` argument set and append an overlay to
     `nixpkgsConfig.overlays`, e.g. a new `overlays/himalaya-pin.nix` curried the same way as
     `unstable-packages.nix`:
     `pkgs-himalaya: _final: _prev: { himalaya = pkgs-himalaya.himalaya.overrideAttrs (old: { cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features=oauth2,keyring" ]; }); }`
     called with `nixpkgs-himalaya.legacyPackages.${system}`. Underscore-prefixed arguments keep
     deadnix quiet.
   - Run `nix flake lock` (not `nix flake update`) so only the new node is added.
2. **`modules/home/packages/email-tools.nix`** — replace the `pkgs-unstable.himalaya.overrideAttrs`
   expression with plain `himalaya`, and delete the `msmtp` line. `pkgs-unstable` is still
   needed there for `isync`.
3. **New `modules/home/email/msmtp.nix`** — `_: { programs.msmtp = { enable = true; configContent = ''...''; }; }`
   with the config from Finding 5 and a header comment recording the cross-file contract
   (mirrors aerc's outgoing settings; `from` lines drive `--read-envelope-from`; logos TLS
   depends on the host trusting the Bridge CA, see `hosts/hamsa/default.nix`). Import it in
   `modules/home/default.nix` next to the other email modules.
4. **Docs** — update `docs/himalaya.md` (package snippet near line 116 still shows the old
   expression and bare `msmtp`) and add msmtp to `docs/email-workflow.md`; note the pin in
   `packages/README.md` or `overlays/` documentation if the planner wants it discoverable.
5. **Verification, in order**:
   - `nix eval` the new `pkgs.himalaya` out path and confirm it is
     `/nix/store/909gc7jx8rv42hrmqm5r0zc0i73kyl61-himalaya-1.2.0`.
   - `nix flake check` (the authoritative gate).
   - `home-manager build --flake .#benjamin` and `nixos-rebuild build --flake .#hamsa`; read the
     rendered `msmtp/config` from the result and check both `from` lines, both ports, the
     `tls_starttls` values, and `account default : gmail`.
   - Confirm the five wrapper binaries are still in the built profile and `himalaya --version`
     after switch still reports v1.2.0 with `+oauth2 +keyring`.
   - Hand the user the msmtp commands from Finding 6.
6. **Activation** — `home-manager switch --flake .#benjamin` is enough for `~/.config/msmtp/config`
   and the profile; `sudo nixos-rebuild switch` is unavailable to agents and stays a user step.

## Risks & Mitigations

- **Logos send fails on non-hamsa hosts** (Bridge CA not trusted). Same as aerc today;
  documented in the module comment. Fix per host by exporting that host's Bridge cert and
  adding it to `security.pki.certificateFiles`.
- **Bridge vault reset regenerates the certificate**, breaking msmtp and aerc together until
  `protonmail-bridge-ca.pem` is re-exported. Already noted in `hosts/hamsa/default.nix`.
- **Unmatched From address silently sends through Gmail** via the default account. Gmail
  rewrites the From to the authenticated address. Acceptable for two known addresses; dropping
  `account default` would fail closed instead, at the cost of the task's "sensible default".
- **Frozen himalaya closure** receives no library security updates. Exposure is small: the
  wrappers use only the maildir backend, and sending goes through msmtp/aerc.
- **`nix flake update` cannot move the pin** (full-rev URL), which is the intent; the comment in
  `flake.nix` should say so to prevent a well-meaning "cleanup".
- **Sent copies**: msmtp does not file a copy. Gmail and the Bridge both save sent mail
  server-side, which mbsync then pulls; any local Fcc is the nvim consumer's concern.
- **Existing `~/.config/msmtp/config`**: none is expected (no config exists today); if
  home-manager reports a collision on activation, it is an unmanaged file to move aside, not to
  overwrite blindly.
- **Grep-based artifact checks**: keep the module's prose comments free of the exact literal
  strings a later "exactly N occurrences" check searches for in the rendered file.

## Appendix

- Probes: `nix eval` of `himalaya.version` / `cargoHash` / overridden `outPath` on both locked
  nixpkgs inputs; `openssl s_client` with and without `-starttls smtp`; `nc` EHLO;
  `openssl x509` on `hosts/hamsa/protonmail-bridge-ca.pem`; `ss -ltnp`.
- v1.2.0 fixed-output hashes in nixpkgs: src `sha256-BBzfDeNu7s010ARCYuydCyR7QWrbeI3/B4CxA6d4olw=`,
  cargoHash `sha256-IkvRiU9NuD6n7aCF8J235u2LjjmLftnF1n874IWVcN0=` (needed only for Option C).
- MCP-NixOS was available and used; `accounts.email` search returned nothing useful, so the
  home-manager module source was read directly from the locked input.
- References:
  - https://github.com/pimalaya/himalaya/blob/master/CHANGELOG.md
  - https://raw.githubusercontent.com/pimalaya/himalaya/v2.0.0/Cargo.toml
  - https://marlam.de/msmtp/msmtp.html
  - home-manager `modules/programs/msmtp/default.nix` (release-26.05)
