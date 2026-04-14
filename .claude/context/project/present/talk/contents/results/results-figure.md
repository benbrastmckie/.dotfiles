# Results Slide - Figure Display

## Slidev Template

```md
---
layout: default
---

# {{results_title}}

<FigurePanel
  src="{{figure_path}}"
  caption="{{figure_caption}}"
  source="{{figure_source}}"
  :scale="{{figure_scale}}"
/>

<div v-click class="interpretation">

<StatResult
  test="{{stat_test}}"
  value="{{stat_value}}"
  p_value="{{p_value}}"
  ci="{{confidence_interval}}"
  :significance="{{is_significant}}"
/>

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `results_title` | Slide heading | Yes |
| `figure_path` | Path to figure image | Yes |
| `figure_caption` | Figure caption text | Yes |
| `figure_source` | Data source attribution | No |
| `figure_scale` | Scale factor (default 1.0) | No |
| `stat_test` | Statistical test name | No |
| `stat_value` | Test statistic value | No |
| `p_value` | P-value | No |
| `confidence_interval` | 95% CI range | No |
| `is_significant` | Boolean for significance highlighting | No |

## Usage Notes

- One figure per slide for clarity
- Use high-resolution figures (300+ DPI)
- Include axis labels and legends in the figure itself
- Reveal statistical results with v-click after showing the figure
- Use the FigurePanel component for consistent captioning
