# Slidev Implementation Notes

Practical guidance for building Slidev decks, based on prior implementations.

## Project Setup (Critical)

### Project Scaffolding

When creating a new Slidev deck, copy the four template files from
`.claude/context/project/present/talk/templates/slidev-project/` into the new
project directory rather than starting from scratch:

- `package.json` -- pre-configured with correct `@slidev/cli` version and pnpm scripts
- `.npmrc` -- sets `shamefully-hoist=true` (required for lz-string; see below)
- `vite.config.ts` -- aliases `lz-string` to the ESM shim
- `lz-string-esm.js` -- the CJS-to-ESM shim for lz-string

**Template version check**: Before using the template, compare the `_slidev_template_version`
field in the template `package.json` against the current Slidev release. If the template is
out of date, pin the version in `package.json` to a known-working release rather than assuming
the template's version is still current.

### Package Manager

Use pnpm with `shamefully-hoist=true` in `.npmrc`. Slidev's internal dependencies
(especially `lz-string`, used by the mermaid module) are CJS-only and Vite's dep
optimizer cannot pre-bundle them under pnpm's strict layout. Without hoisting,
every mermaid slide crashes with:

```
SyntaxError: The requested module 'lz-string' does not provide an export named 'default'
```

### lz-string ESM Shim

Even with hoisting, Vite may not pre-bundle `lz-string` (CJS, no ESM exports).
Create a self-contained ESM build (`lz-string-esm.js`) by copying the source
and replacing the UMD footer with `export default LZString`. Then alias it in
`vite.config.ts`:

```ts
import { defineConfig } from 'vite'

export default defineConfig({
  resolve: {
    alias: {
      'lz-string': new URL('./lz-string-esm.js', import.meta.url).pathname,
    },
  },
})
```

**Note**: Slidev resolves `vite.config.ts` from the slide file's parent directory
(the `userRoot`), not from CWD. The config must be next to the entry markdown file.

### Version Alignment

The `slidev` binary used to preview/export MUST match the version in `package.json`.
If a global `slidev` is installed (e.g., via nix), it may differ from the project's
`@slidev/cli`. Use `npx @slidev/cli` in Zed tasks and scripts to resolve the local version.

### Inline Code Black Boxes (Shiki CSS Override)

Shiki, the syntax highlighter bundled with Slidev, injects its own `<code>` styles that override
custom theme CSS. On dark-background slides, this manifests as solid black rectangles over inline
code spans.

**Root cause**: Shiki sets `background-color` on `.shiki code` (and related selectors) without
`!important`, but the cascade order places it after theme styles, causing theme `<code>` resets to
be ignored.

**Fix**: Add `!important` overrides in the theme's CSS for inline code specifically:

```css
/* In theme/styles/index.css */
:not(pre) > code {
  background-color: transparent !important;
  color: inherit !important;
  padding: 0.1em 0.3em !important;
  border-radius: 3px !important;
}
```

Apply this in the theme stylesheet, not in individual slide frontmatter, so it applies globally.

### Vue Components in Markdown Tables

The Vue/MDC parser fails silently when Vue components appear inside markdown pipe tables. The
component renders as raw text or breaks the table layout with no error message.

**Root cause**: Slidev's markdown parser processes pipe table cells as inline markdown, not as
Vue template contexts. Vue component tags inside `| cell |` syntax are treated as literal text.

**Fix**: Use HTML `<table>` elements instead of markdown pipe syntax whenever a table cell
contains a Vue component:

```html
<table>
  <thead><tr><th>Label</th><th>Value</th></tr></thead>
  <tbody>
    <tr>
      <td>Result</td>
      <td><StatResult :value="0.032" /></td>
    </tr>
  </tbody>
</table>
```

Plain-text tables (no components) can continue to use pipe syntax.

### Footer and Absolute Positioning Overlap

Using `position: absolute` in slide content (e.g., to pin a figure to a corner) causes overlap
with Slidev's footer elements, which are also absolutely positioned within the slide container.

**Root cause**: Slidev renders footer content in a layer that shares the same positioning context
as slide body content. Absolutely positioned elements in the slide body can render on top of or
behind footer content unpredictably.

**Fix**: Prefer flow-based positioning for slide content. For intentional bottom-of-slide
placement, use Slidev's `::bottom::` slot:

```markdown
---
layout: default
---

Main slide content here.

::bottom::

<div class="text-sm text-gray-500">Caption or footnote that won't overlap the footer</div>
```

Reserve `position: absolute` only for decorative elements that have no risk of overlapping
interactive or required footer content.

## Mermaid Diagrams

Keep diagrams simple -- `flowchart LR` and `flowchart TD` are reliable in both
SPA and PDF export. Advanced features (nested subgraphs, click events) may not
render in PDF.

Use `\n` for line breaks in mermaid node labels. Do NOT use `<br/>` -- the
Vue/MDC parser may consume self-closing HTML tags before they reach mermaid.

If `slidev export` shows "An error occurred on this slide" but `slidev build`
works fine, the issue is Playwright/chromium configuration (common on NixOS),
not diagram syntax.

## Pre-Playwright Validation

Run `npx @slidev/cli build` as a required first-pass check before launching the dev server or
running Playwright. A successful build confirms:

- No lz-string / CJS module crashes (these abort the build with a clear stack trace)
- No Vue compile errors in components or slide frontmatter
- No missing layout or component references
- CLI version matches `package.json` (wrong version causes immediate exit)

**When to run**:
1. After initial project setup (before authoring any slides)
2. After adding new Vue components
3. After changing `vite.config.ts` or `package.json`
4. Before starting the Playwright verification phase

```bash
cd /path/to/project && npx @slidev/cli build
```

A clean build does not guarantee rendering quality (blank slides, overflow, style issues require
Playwright screenshot review), but it eliminates the entire class of compile-time failures
without needing a browser.

### NixOS Playwright Workaround

On NixOS, the Playwright-bundled Chromium binary is not executable due to dynamic linker
constraints. Two options:

**Option A**: Use the system Chromium by setting `executablePath` in the verify script:

```js
// In scripts/verify-slides.mjs
const browser = await chromium.launch({
  executablePath: '/run/current-system/sw/bin/chromium',
});
```

**Option B**: If browser automation is unavailable entirely, use `slidev build` as a fallback.
Build output in `dist/` can be manually inspected or served locally. This does not catch
rendering errors but validates compilation.

The standard `playwright-verify.mjs` template documents the `executablePath` option as a
comment near the `chromium.launch()` call.

## Required Final Phase: Playwright Verification

Every Slidev implementation plan MUST include a final phase that uses Playwright to verify every slide renders without errors. This phase runs after all slide content is authored and before the task is marked complete.

### Phase Template

The planner should include this as the last phase (after all content authoring and build phases):

```
### Phase N: Playwright Slide Verification [NOT STARTED]

**Goal**: Verify every slide renders without errors using Playwright,
fix any broken slides, and export the final PDF.

**Tasks**:
- [ ] Copy `talk/templates/playwright-verify.mjs` to `scripts/verify-slides.mjs`
- [ ] Run `node scripts/verify-slides.mjs --screenshots` to test every
      slide against the dev server
- [ ] Fix any slides that report VISIBLE ERROR or console errors
- [ ] Re-run verification until all slides pass (exit code 0)
- [ ] Run `pnpm run export` to produce the final PDF
- [ ] Verify PDF page count matches expected slide count

**Timing**: 0.5-1 hour

**Depends on**: all content authoring phases

**Verification**:
- `verify-slides.mjs` exits 0 (all slides pass)
- `pnpm run export` exits 0
- PDF page count matches slide count
- No "An error occurred on this slide" on any page
```

The template script is at `.claude/context/project/present/talk/templates/playwright-verify.mjs`. Copy it into the project's `scripts/` directory during this phase.

### What the Script Checks

For each slide, the script:
1. Navigates to `localhost:{port}/{slideNumber}` via Playwright chromium
2. Waits for network idle + 2 seconds (for Mermaid rendering)
3. Checks for visible "An error occurred on this slide" text
4. Captures any `pageerror` console errors
5. Checks text content length (catches blank/empty slides)
6. Optionally takes a screenshot (`--screenshots` flag)

Exit code 0 means all slides passed. Exit code 1 means at least one slide failed.

### Fixing Common Errors

When slides fail verification:
- **Vue component error**: check that all referenced components exist in `components/` and have valid `<template>` blocks
- **Mermaid parse error**: simplify the diagram syntax, check for unescaped special characters; use `\n` not `<br/>`
- **Blank slide**: check the `---` separator placement and layout name spelling
- **Console error about undefined property**: check that component props match what the slide passes
- **lz-string / CJS module error**: ensure `.npmrc` has `shamefully-hoist=true`, `lz-string-esm.js` exists, and `vite.config.ts` aliases it
- **Black boxes on inline code**: see "Inline Code Black Boxes (Shiki CSS Override)" section above
- **Vue components in markdown tables**: see "Vue Components in Markdown Tables" section above
