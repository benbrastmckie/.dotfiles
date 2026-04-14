# Deck Library

A pre-built library of Slidev deck components for agent-driven pitch deck construction. Provides themes, structural patterns, animations, styles, Vue components, and content templates that agents compose into complete presentations.

## Overview

The deck library enables agents to assemble Slidev pitch decks by selecting and combining pre-built building blocks rather than generating slide content from scratch. Each library item is indexed in `index.json`, which agents query to find appropriate items by category, deck mode, slide type, or tags.

The library follows a seed-and-runtime pattern: files here are the canonical seed copies. When the `/deck` command builds a presentation, it copies selected items into a runtime project directory. New content created during a session can be written back to the library for reuse.

## Directory Structure

```
deck/
├── README.md                              (this file)
├── index.json                             Library index (49 entries across 6 categories)
├── themes/                                Slidev headmatter + themeConfig presets (5 files)
│   ├── dark-blue.json                     AI startup default -- navy bg, blue accents
│   ├── growth-green.json                  Sustainability/biotech -- mint bg, green accents
│   ├── minimal-light.json                 Data-focused -- white bg, blue accent
│   ├── premium-dark.json                  Luxury/fintech -- near-black bg, gold accents
│   └── professional-blue.json             Corporate/enterprise -- white bg, navy accents
├── patterns/                              Deck structural patterns (5 files)
│   ├── investor-update.json               Quarterly investor update (8 slides)
│   ├── lightning-5-slide.json             Lightning talk (5 slides)
│   ├── partnership-proposal.json          Partnership pitch (8 slides)
│   ├── product-demo.json                  Product demo deck (10 slides)
│   └── yc-10-slide.json                   YC 10-slide investor pitch (10 slides)
├── animations/                            Reusable animation patterns (6 files)
│   ├── fade-in.md                         CSS fade via v-click (low complexity)
│   ├── metric-cascade.md                  Staggered v-motion KPI reveal (high complexity)
│   ├── rough-marks.md                     v-mark hand-drawn text highlights (medium)
│   ├── scale-in-pop.md                    v-motion spring scale for CTAs (medium)
│   ├── slide-in-below.md                  v-motion y-axis entrance (medium)
│   └── staggered-list.md                  v-clicks progressive list reveal (low)
├── styles/                                Composable CSS presets (9 files)
│   ├── colors/                            Color variable sets (4 files)
│   │   ├── dark-blue-navy.css             Navy bg with blue accents
│   │   ├── dark-gold-premium.css          Near-black bg with gold accents
│   │   ├── light-blue-corp.css            White bg with blue/navy accents
│   │   └── light-green-growth.css         Mint/white bg with green accents
│   ├── typography/                        Font pairing presets (3 files)
│   │   ├── inter-only.css                 All-sans clean look (Inter everywhere)
│   │   ├── montserrat-inter.css           Montserrat headings, Inter body
│   │   └── playfair-inter.css             Playfair Display serif headings, Inter body
│   └── textures/                          Background texture overlays (2 files)
│       ├── grid-overlay.css               Subtle grid for technical feel
│       └── noise-grain.css                Film grain SVG overlay for premium feel
├── components/                            Reusable Vue components (6 files)
│   ├── ComparisonCol.vue                  Side-by-side comparison column
│   ├── KaTex.vue                          KaTeX math wrapper with SVG injection (inactive)
│   ├── LogosOp.vue                        Custom compound operator SVG rendering
│   ├── MetricCard.vue                     Single KPI metric with animated entrance
│   ├── TeamMember.vue                     Team member card with photo and bio
│   └── TimelineItem.vue                   Milestone on a timeline with status
└── contents/                              Slide content templates (23 files, 11 topics)
    ├── appendix/                          Supplementary detail slides (3 files)
    │   ├── appendix-competition.md        Competitive landscape with differentiation
    │   ├── appendix-financials.md         Financial projections, burn rate, runway
    │   └── appendix-roadmap.md            Product roadmap timeline with milestones
    ├── ask/                               Fundraising ask slides (2 files)
    │   ├── ask-centered.md                Centered raise amount with allocation
    │   └── ask-milestone.md               Raise amount with milestone timeline
    ├── business-model/                    Revenue and unit economics (2 files)
    │   ├── biz-model-pricing.md           Revenue model with pricing and LTV/CAC
    │   └── biz-model-saas.md              SaaS metrics: ARR, MRR, churn, ARPU
    ├── closing/                           Closing and CTA slides (2 files)
    │   ├── closing-cta.md                 Call-to-action with next steps
    │   └── closing-standard.md            Company name and contact info
    ├── cover/                             Title slides (2 files)
    │   ├── cover-hero.md                  Full-bleed hero with bold typography
    │   └── cover-standard.md              Company name, tagline, funding round
    ├── market/                            Market sizing slides (2 files)
    │   ├── market-narrative.md            Text-based sizing with trend and timing
    │   └── market-tam-sam-som.md          Three-tier TAM/SAM/SOM with staggered reveal
    ├── problem/                           Problem framing slides (2 files)
    │   ├── problem-statement.md           Bold single-sentence with 3 evidence points
    │   └── problem-story.md               Narrative framing with impact statistic
    ├── solution/                          Solution presentation slides (2 files)
    │   ├── solution-demo.md               Solution with screenshot and differentiator
    │   └── solution-two-col.md            Benefits left, mechanism right
    ├── team/                              Team display slides (2 files)
    │   ├── team-grid.md                   Multi-member grid layout
    │   └── team-two-col.md                Two-column founder display with bios
    ├── traction/                          Traction and metrics slides (2 files)
    │   ├── traction-chart.md              Growth chart visualization
    │   └── traction-metrics.md            Three KPI metrics with cascade animation
    └── why-us-now/                        Competitive advantage slides (2 files)
        ├── why-us-moat.md                 Technical moat emphasis
        └── why-us-now-split.md            Two-column Why Us / Why Now
```

## Categories

### Themes

Theme files define Slidev headmatter configuration (base theme, color schema, fonts, transitions) and CSS variable presets. Each theme references composable style presets from `styles/`.

| ID | Name | Color Schema | Mood | Base Theme |
|----|------|-------------|------|------------|
| `theme-dark-blue` | Dark Blue (AI Startup) | dark | professional, technical, modern | seriph |
| `theme-minimal-light` | Minimal Light | light | clean, minimal, data-focused | seriph |
| `theme-premium-dark` | Premium Dark (Gold) | dark | luxury, premium, fintech | seriph |
| `theme-growth-green` | Growth Green | light | fresh, sustainability, biotech | seriph |
| `theme-professional-blue` | Professional Blue | light | corporate, enterprise, trustworthy | seriph |

Theme JSON structure:
- `headmatter` -- Slidev frontmatter fields (theme, colorSchema, fonts, transition)
- `style_presets` -- Array of composable CSS file paths from `styles/`
- `css_variables` -- CSS custom properties for colors and accents
- `scoped_css_template` -- Default scoped CSS for headings and body text

### Patterns

Patterns define the structural skeleton of a deck: the ordered sequence of slide types, default content for each position, appendix suggestions, and slide constraints.

| ID | Name | Slide Count | Deck Modes |
|----|------|------------|------------|
| `pattern-yc-10-slide` | YC 10-Slide Investor Pitch | 10 | INVESTOR |
| `pattern-lightning-5` | Lightning Talk | 5 | LIGHTNING |
| `pattern-product-demo` | Product Demo | 10 | DEMO |
| `pattern-investor-update` | Investor Update | 8 | UPDATE |
| `pattern-partnership` | Partnership Proposal | 8 | PARTNERSHIP |

Pattern JSON structure:
- `slide_sequence` -- Ordered array of `{position, slide_type, required, default_content}`
- `appendix_suggestions` -- Recommended appendix content IDs
- `constraints` -- Limits for slide count, bullets, word count, font sizes
- `ordering_strategies` -- Named reorderings (e.g., `yc-standard`, `traction-led`)

### Animations

Animation files document Slidev animation patterns with syntax examples and usage guidance. Each file covers a specific technique using Slidev directives (`v-click`, `v-clicks`, `v-motion`, `v-mark`).

| ID | Name | Trigger | Complexity |
|----|------|---------|------------|
| `anim-fade-in` | Fade In | v-click | low |
| `anim-staggered-list` | Staggered List | v-clicks | low |
| `anim-slide-in-below` | Slide In Below | v-motion | medium |
| `anim-rough-marks` | Rough Marks | v-mark | medium |
| `anim-scale-in-pop` | Scale In Pop | v-motion | medium |
| `anim-metric-cascade` | Metric Cascade | v-motion | high |

### Styles

Styles are composable CSS presets organized into three subdirectories. Themes reference these via `style_presets` arrays, and they can also be imported independently.

**Colors** (4 files):

| ID | Name | Color Schema |
|----|------|-------------|
| `style-dark-blue-navy` | Dark Blue Navy Colors | dark |
| `style-dark-gold-premium` | Dark Gold Premium Colors | dark |
| `style-light-green-growth` | Light Green Growth Colors | light |
| `style-light-blue-corp` | Light Blue Corporate Colors | light |

**Typography** (3 files):

| ID | Name | Pairing |
|----|------|---------|
| `style-montserrat-inter` | Montserrat + Inter | Montserrat headings, Inter body |
| `style-playfair-inter` | Playfair + Inter | Playfair Display headings, Inter body |
| `style-inter-only` | Inter Only | Inter for all text |

**Textures** (2 files):

| ID | Name | Effect |
|----|------|--------|
| `style-grid-overlay` | Grid Overlay | Subtle grid background for technical feel |
| `style-noise-grain` | Noise Grain | Film grain SVG overlay for premium feel |

### Components

Vue single-file components for use inside Slidev slides. Each accepts props and provides animated, styled output.

| Component | Props | Usage |
|-----------|-------|-------|
| `ComparisonCol.vue` | title, points, color, highlight | Side-by-side comparison column |
| `KaTex.vue` | expr, display | KaTeX math wrapper with SVG placeholder injection (inactive -- not used in current deck) |
| `LogosOp.vue` | op | Custom compound operator SVG rendering (boxright, diamondright, circleright, dotcircleright) |
| `MetricCard.vue` | value, label, delay, color | KPI display with v-motion entrance |
| `TeamMember.vue` | name, role, bio, photo, delay | Team member card with photo |
| `TimelineItem.vue` | date, label, description, status | Milestone on a timeline |

### Contents

Content files are Slidev slide markdown snippets with placeholder slots that agents fill with real data. Each file includes a structured comment header with metadata and a speaker note.

**23 files across 11 topic directories**:

| Topic | Files | Variants |
|-------|-------|----------|
| cover | 2 | standard, hero |
| problem | 2 | statement, story |
| solution | 2 | two-col, demo |
| traction | 2 | metrics (3-up), chart |
| why-us-now | 2 | split, moat |
| business-model | 2 | pricing, saas |
| market | 2 | tam-sam-som, narrative |
| team | 2 | two-col, grid |
| ask | 2 | centered, milestone |
| closing | 2 | standard, cta |
| appendix | 3 | financials, competition, roadmap |

## Content Slot System

Content files use a structured comment header for metadata and `[SLOT: name]` placeholders for variable content. Agents read the header to understand the slide and replace slots with real data during deck assembly.

### Comment Header Format

Every content file begins with an HTML comment block:

```html
<!-- CONTENT: cover-standard
     SLIDE_TYPE: cover
     LAYOUT: cover
     COMPATIBLE_MODES: INVESTOR, UPDATE, PARTNERSHIP
     CONTENT_SLOTS: company_name, tagline, funding_round, date
     ANIMATIONS: v-motion entrance (y + opacity)
     IMPORT: Use src frontmatter or copy directly into slides.md
     LAST_UPDATED: 2026-04-01
-->
```

### Slot Syntax

Slots appear as `[SLOT: slot_name]` in the markdown body. Agents replace each slot with actual content:

```markdown
# [SLOT: company_name]

<div class="text-xl opacity-80">
[SLOT: tagline]
</div>
```

Becomes, after agent processing:

```markdown
# Acme AI

<div class="text-xl opacity-80">
Enterprise intelligence, automated.
</div>
```

The `content_slots` array in `index.json` lists all slots for each content entry, enabling agents to validate completeness.

## Agent Navigation

Agents select library items by querying `index.json`:

1. **Select a pattern** matching the desired deck mode (INVESTOR, DEMO, LIGHTNING, UPDATE, PARTNERSHIP)
2. **Select a theme** matching the desired mood and color schema
3. **For each slide position** in the pattern, select a content template by `slide_type`
4. **Select animations** appropriate to slide content and complexity budget
5. **Compose styles** by combining color, typography, and texture presets

The `tags` field on each entry enables filtering. For example, finding all content compatible with INVESTOR mode:

```
entries where tags.deck_mode contains "INVESTOR"
```

## Import Methods

Content files can be integrated into a Slidev deck in two ways:

**Direct copy** -- Paste the markdown (minus the comment header) directly into `slides.md`. This is the default method for most content.

**src frontmatter** -- Reference a file from the Slidev `src` field for slide-level imports:

```markdown
---
src: ./contents/cover/cover-standard.md
---
```

Direct copy is preferred because it allows agents to replace slots inline and customize animations per slide.

## Extending the Library

New content created during a `/deck` session can be written back to the seed library:

1. Create the new file in the appropriate category directory
2. Include the structured comment header with all metadata fields
3. Add a corresponding entry to `index.json` with id, category, name, path, description, and tags
4. If adding a new content topic, create a new subdirectory under `contents/`

Themes and patterns follow the same write-back pattern. New entries become available to all future deck sessions.

## Related Context

- `../patterns/pitch-deck-structure.md` -- High-level deck structure guidance and slide design principles
- `../patterns/slidev-deck-template.md` -- Slidev project scaffolding template
- `../patterns/yc-compliance-checklist.md` -- YC format compliance validation rules

## Navigation

Back to [Founder Context](../README.md)
