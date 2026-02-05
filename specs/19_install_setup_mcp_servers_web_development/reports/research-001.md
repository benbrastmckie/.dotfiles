# Research Report: Task #19

**Task**: 19 - Install and set up MCP servers for web development
**Date**: 2026-02-05
**Focus**: MCP server identification, installation, and configuration for LogosWebsite and similar projects

## Summary

The guide at `/home/benjamin/Projects/Logos/LogosWebsite/.claude/docs/guides/mcp-server-setup.md` identifies three MCP servers for web development: **Astro Docs** (HTTP, remote), **Context7** (stdio, via npx), and **Playwright** (stdio, via npx, currently deferred on NixOS). Astro Docs and Context7 are already configured in the LogosWebsite project's `.mcp.json` and `.claude/settings.json`. Playwright is deferred due to NixOS browser binary compatibility issues, with a clear solution path documented. The implementation task involves adding `playwright-driver.browsers` to `home.nix` and configuring the Playwright MCP server entry.

## Findings

### 1. Astro Docs MCP

- **Status**: Already configured and active
- **Type**: HTTP (remote) -- no local installation needed
- **Repository**: [withastro/docs-mcp](https://github.com/withastro/docs-mcp)
- **URL**: `https://mcp.docs.astro.build/mcp`
- **Tools**: `search_astro_docs` (1 tool) -- semantic search over official Astro documentation via kapa.ai
- **Configuration**: Already present in `/home/benjamin/Projects/Logos/LogosWebsite/.mcp.json`
- **Permissions**: Already present in `/home/benjamin/Projects/Logos/LogosWebsite/.claude/settings.json` as `mcp__astro-docs__*`
- **NixOS notes**: No NixOS-specific considerations. No authentication or API key required.
- **Action needed**: None. Already fully operational.

### 2. Context7 MCP

- **Status**: Already configured and active
- **Type**: stdio (local, via npx)
- **Repository**: [upstash/context7](https://github.com/upstash/context7)
- **Package**: `@upstash/context7-mcp` (latest npm version: 2.1.1)
- **Tools**: `resolve-library-id`, `query-docs` (2 tools) -- two-step workflow to resolve a library name and then query its documentation
- **Configuration**: Already present in `/home/benjamin/Projects/Logos/LogosWebsite/.mcp.json`
- **Permissions**: Already present in `/home/benjamin/Projects/Logos/LogosWebsite/.claude/settings.json` as `mcp__context7__*`
- **Prerequisites**: Node.js v24.13.0 and npx 11.6.2 are already installed via Nix
- **Optional**: API key available at `https://context7.com/dashboard` for higher rate limits (not currently configured)
- **NixOS notes**: The package is pure JavaScript, so no FHS or dynamic linking issues. First invocation may be slow (5-10 seconds) for package download.
- **Action needed**: None. Already fully operational. Optionally, an API key could be configured for higher rate limits.

### 3. Playwright MCP

- **Status**: Deferred -- blocked by browser binary availability on NixOS
- **Type**: stdio (local, via npx)
- **Repository**: [microsoft/playwright-mcp](https://github.com/microsoft/playwright-mcp)
- **Package**: `@playwright/mcp` (latest npm version: 0.0.63; must be pinned to match nixpkgs)
- **Tools**: ~33 tools (browser automation, screenshots, form filling, navigation, console monitoring, etc.)
- **Configuration**: Not yet in `.mcp.json` (deferred pending browser setup)
- **Permissions**: Already pre-configured in `.claude/settings.json` as `mcp__playwright__*`

#### Why It Is Deferred

NixOS does not follow the Filesystem Hierarchy Standard (FHS). All libraries and binaries live in `/nix/store/`. This causes three problems for Playwright:

1. `npx playwright install` downloads pre-built browser binaries that are dynamically linked against standard FHS paths (`/lib/x86_64-linux-gnu/`, etc.), which do not exist on NixOS.
2. System browsers (Vivaldi, Brave, etc.) are incompatible with Playwright's required version-matched dependencies.
3. The solution is Nix-packaged browsers via `playwright-driver.browsers`.

#### Solution Path

The guide documents a clear solution in `home.nix`:

```nix
home.packages = with pkgs; [
  playwright-driver.browsers
];

home.sessionVariables = {
  PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
  PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
};
```

#### Version Matching Requirement

- **nixpkgs `playwright-driver` version**: 1.57.0 (confirmed via `nix eval`)
- **Latest npm `@playwright/mcp` version**: 0.0.63
- **Critical**: The `@playwright/mcp` package internally depends on Playwright, and the Playwright version it uses must be compatible with the `playwright-driver.browsers` version from nixpkgs. The guide recommends pinning: `@playwright/mcp@1.57` -- but this is likely the Playwright core version, not the MCP wrapper version. The `.mcp.json` should use `@playwright/mcp@latest` (0.0.63) and rely on the environment variable `PLAYWRIGHT_BROWSERS_PATH` to point to the Nix-provided browsers.
- **Risk**: If the npm `@playwright/mcp@latest` internally bundles a Playwright version newer than 1.57.0, it may look for browser revisions not present in the Nix browsers directory. This can be mitigated by checking version compatibility after installation.

#### Alternative: Nix Flake

A community Nix flake at [benjaminkitt/nix-playwright-mcp](https://github.com/benjaminkitt/nix-playwright-mcp) bundles browser binaries and environment variables into a single derivation, avoiding version matching issues entirely:

```json
{
  "playwright": {
    "command": "nix",
    "args": ["run", "github:benjaminkitt/nix-playwright-mcp"]
  }
}
```

This is the simpler approach but depends on an external community-maintained flake.

#### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `PLAYWRIGHT_BROWSERS_PATH` | Nix store path to `playwright-driver.browsers` | Tells Playwright where to find browser binaries |
| `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS` | `true` | Bypasses host validation checks that fail on NixOS |
| `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` | `1` | Prevents npm postinstall scripts from downloading incompatible binaries |

**Current state**: `PLAYWRIGHT_BROWSERS_PATH` is not set. `playwright-driver.browsers` is not in `home.packages`.

### 4. Configuration Architecture

#### Current Configuration Files

| File | Location | Status |
|------|----------|--------|
| `.mcp.json` | `/home/benjamin/Projects/Logos/LogosWebsite/.mcp.json` | Has astro-docs and context7; Playwright deferred with a note |
| `.claude/settings.json` | `/home/benjamin/Projects/Logos/LogosWebsite/.claude/settings.json` | Has permission wildcards for all three servers |
| `~/.claude/settings.json` | Symlinked from `~/.dotfiles/config/claude-settings.json` via home-manager | User-level; has `mcp__lean-lsp__*` only |
| `~/.claude.json` | `/home/benjamin/.claude.json` | User-level; has `lean-lsp` MCP server config |
| `~/.dotfiles/home.nix` | `/home/benjamin/.dotfiles/home.nix` | Has `nodejs` in packages; no Playwright browser packages yet |

#### Configuration Scope Strategy

The LogosWebsite project uses **project scope** for web-related MCP servers (`.mcp.json` in project root). This is the recommended approach because:
- Servers are version-controlled with the project
- Team members get the same configuration
- Different projects can have different server sets

#### Permission Auto-Approval

The LogosWebsite project's `.claude/settings.json` already includes all necessary permission wildcards:
- `mcp__astro-docs__*`
- `mcp__context7__*`
- `mcp__playwright__*`
- `Bash(npx *)`

#### Reusability for Other Projects

To use the same MCP servers in other web development projects, copy the `.mcp.json` to the new project root and add the permission wildcards to the project's `.claude/settings.json`. Alternatively, add the servers to `~/.claude.json` under the `mcpServers` key for user-level availability across all projects.

### 5. Dotfiles Repository Changes Required

The only change needed in the dotfiles repository (`~/.dotfiles/`) is adding Playwright browser support to `home.nix`. The two currently active servers (Astro Docs, Context7) are already fully configured in the LogosWebsite project itself and do not require dotfiles changes.

#### Changes to `home.nix`

1. Add `playwright-driver.browsers` to `home.packages`
2. Add three environment variables to `home.sessionVariables`:
   - `PLAYWRIGHT_BROWSERS_PATH`
   - `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS`
   - `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD`

#### Changes to LogosWebsite `.mcp.json`

1. Add the `playwright` entry to `mcpServers`
2. Remove the `_playwright_note` field

## Recommendations

1. **Astro Docs and Context7 require no changes** -- they are already fully configured and operational in the LogosWebsite project.

2. **For Playwright, use the home.nix approach** (not the Nix flake alternative) for better control over version matching and to avoid dependency on an external community flake. The home.nix approach is already documented in the guide and integrates with the existing declarative NixOS setup.

3. **Pin the @playwright/mcp version** to avoid version drift between the npm package and the Nix-provided browsers. Use `@playwright/mcp@1.57` as recommended in the guide, or verify that `@playwright/mcp@latest` (0.0.63) is compatible with playwright-driver 1.57.0 before using `@latest`.

4. **Run `home-manager switch`** after modifying `home.nix` to install the browser binaries and set environment variables.

5. **For reusing in other projects**, consider documenting a template `.mcp.json` that can be copied to new web development projects, or eventually adding the web servers to user-level config (`~/.claude.json`) if they become universally needed.

6. **Optionally configure a Context7 API key** if rate limiting becomes an issue. The key can be set via `home.sessionVariables` in `home.nix` and referenced in `.mcp.json` via `${CONTEXT7_API_KEY}`.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Playwright browser version mismatch | Medium | Browsers fail to launch | Pin npm package version to match nixpkgs playwright-driver version (1.57.0) |
| home-manager switch fails | Low | No browser binaries installed | Test build with `home-manager build` before switching |
| `PLAYWRIGHT_BROWSERS_PATH` not interpolated in .mcp.json | Low | Playwright can't find browsers | Verify `${PLAYWRIGHT_BROWSERS_PATH}` expansion in `.mcp.json` by checking the Claude Code `/mcp` output |
| Community flake (nix-playwright-mcp) becomes unmaintained | Medium | Alternative approach unavailable | Use the primary home.nix approach; keep flake as documented fallback only |

## References

- [MCP Server Setup Guide (project)](file:///home/benjamin/Projects/Logos/LogosWebsite/.claude/docs/guides/mcp-server-setup.md) -- primary reference document
- [Claude Code MCP Documentation](https://code.claude.com/docs/en/mcp) -- official MCP docs
- [Model Context Protocol Specification](https://modelcontextprotocol.io/) -- MCP protocol spec
- [Astro Docs MCP (GitHub)](https://github.com/withastro/docs-mcp) -- Astro Docs server
- [Context7 MCP (GitHub)](https://github.com/upstash/context7) -- Context7 server
- [Playwright MCP (GitHub)](https://github.com/microsoft/playwright-mcp) -- Playwright server
- [NixOS Wiki: Playwright](https://wiki.nixos.org/wiki/Playwright) -- NixOS Playwright setup
- [nix-playwright-mcp (GitHub)](https://github.com/benjaminkitt/nix-playwright-mcp) -- Community Nix flake
- [Claude Code Playwright MCP on NixOS](https://chili-it.de/posts/claude-code-playwright-nixos/) -- Community walkthrough

## Next Steps

1. Run `/plan 19` to create an implementation plan
2. The plan should cover:
   - Phase 1: Add `playwright-driver.browsers` and environment variables to `home.nix`
   - Phase 2: Run `home-manager switch` to install browsers
   - Phase 3: Add Playwright MCP entry to LogosWebsite `.mcp.json`
   - Phase 4: Verify all three servers are operational (Astro Docs, Context7, Playwright)
3. Consider whether to also update the user-level `~/.dotfiles/config/claude-settings.json` with the MCP server permission wildcards for cross-project availability
