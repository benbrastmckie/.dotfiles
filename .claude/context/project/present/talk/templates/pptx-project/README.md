# pptx-project Template

PowerPoint (.pptx) generation template for the talk library. Provides theme mappings and a skeleton generation script that the pptx-assembly-agent uses when assembling PPTX output instead of Slidev markdown.

## Files

| File | Purpose |
|------|---------|
| `theme_mappings.json` | Theme constants for all three themes (colors, fonts, sizes, spacing) translated from the CSS-based theme JSONs to python-pptx values |
| `generate_deck.py` | Skeleton Python script demonstrating theme-aware PPTX generation with all component helpers |
| `README.md` | This file |

## Themes

Three themes are available, each mapping to a set of python-pptx constants:

| Theme | Headings | Body | Accent |
|-------|----------|------|--------|
| `academic-clean` | Georgia, bold, navy (#16213e) | Helvetica Neue, #1a1a2e | Muted blue (#3b5998) |
| `clinical-teal` | Segoe UI, semibold, dark teal (#0d4f4f) | Segoe UI, #1a202c | Teal (#0d9488) |
| `ucsf-institutional` | Garamond, bold, UCSF navy (#052049) | Arial, #1a202c | Pacific Blue (#0093D0) |

## Usage

### For the pptx-assembly-agent

When generating PPTX output, the pptx-assembly-agent should:

1. Copy `theme_mappings.json` to the project output directory
2. Use the patterns from `pptx-generation.md` (in `talk/patterns/`) to construct slides
3. Load the selected theme from `theme_mappings.json`
4. Apply theme colors, fonts, and spacing to all slide elements
5. Save the assembled presentation as `.pptx`

### Manual usage

```bash
# Install dependency
pip install python-pptx

# Generate example deck with default theme
python generate_deck.py

# Generate with a specific theme
python generate_deck.py --theme clinical-teal --output talk.pptx
```

## Relationship to Slidev Templates

This directory parallels `slidev-project/` in the talk library:

| Slidev | PPTX |
|--------|------|
| `package.json` + npm | `generate_deck.py` + pip |
| CSS theme variables | `theme_mappings.json` |
| Vue components | python-pptx helper functions |
| Markdown slides | Python slide data dicts |
| `slidev build` | `prs.save("output.pptx")` |

## Component Equivalents

The five Vue components in the talk library have python-pptx equivalents documented in `talk/patterns/pptx-generation.md`:

| Vue Component | python-pptx Helper | Purpose |
|---------------|-------------------|---------|
| `DataTable.vue` | `add_pptx_table()` | Formatted data tables with header highlighting |
| `FigurePanel.vue` | `add_pptx_figure()` | Images with caption and source |
| `CitationBlock.vue` | `add_pptx_citation()` | Bordered reference boxes |
| `StatResult.vue` | `add_pptx_stat_result()` | Color-coded statistical results |
| `FlowDiagram.vue` | `add_pptx_flow_diagram()` | CONSORT-style participant flow |

## Slide Dimensions

All presentations use 16:9 widescreen format:
- Width: 13.333 inches (960pt)
- Height: 7.5 inches (540pt)
- Content area: 0.75" left margin, 11.8" usable width

## Dependencies

- Python 3.8+
- python-pptx >= 1.0.0
- Images must be PNG, JPEG, GIF, BMP, or TIFF (SVG not supported)
