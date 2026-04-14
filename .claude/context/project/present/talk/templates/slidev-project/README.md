# Slidev Project Template

Scaffold files for new Slidev presentation decks. Copy all files in this directory
to the project root when creating a new deck.

## Contents

| File | Purpose |
|------|---------|
| `package.json` | Pins `@slidev/cli`, `lz-string`, `vue`, and `playwright-chromium`. Replace `DECK_NAME` and `DECK_DESCRIPTION` with project-specific values. |
| `.npmrc` | Enables `shamefully-hoist=true` for pnpm strict layout compatibility. |
| `vite.config.ts` | Aliases `lz-string` to the local ESM shim, resolving CJS/ESM incompatibility. |
| `lz-string-esm.js` | Self-contained ESM build of lz-string (vendored, WTFPL license). |

## Version Tracking

The `_slidev_template_version` field in `package.json` records which Slidev version
this template was validated against. Before using, check if a newer Slidev version
is available and update `@slidev/cli` if needed.

Current template version: **52.14** (validated April 2026).

## Usage

```bash
# Copy template files to new project
cp -r .claude/context/project/present/talk/templates/slidev-project/* /path/to/new-deck/
cp .claude/context/project/present/talk/templates/slidev-project/.npmrc /path/to/new-deck/

# Customize
cd /path/to/new-deck
# Edit package.json: replace DECK_NAME and DECK_DESCRIPTION
# Create slides.md
pnpm install
pnpm dev
```
