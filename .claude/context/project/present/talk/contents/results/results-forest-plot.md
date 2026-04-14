# Results Slide - Forest Plot

## Slidev Template

```md
---
layout: default
---

# {{results_title}}

<FigurePanel
  src="{{forest_plot_path}}"
  caption="{{plot_caption}}"
  source="{{data_source}}"
  :scale="{{plot_scale}}"
/>

<div class="forest-summary">

| Subgroup | HR/OR (95% CI) | P-value |
|----------|----------------|---------|
{{subgroup_rows}}

**Overall:** {{overall_estimate}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `results_title` | Slide heading (e.g., "Subgroup Analyses") | Yes |
| `forest_plot_path` | Path to forest plot image | Yes |
| `plot_caption` | Figure caption | Yes |
| `data_source` | Source attribution | No |
| `plot_scale` | Scale factor | No |
| `subgroup_rows` | Rows for subgroup summary table | No |
| `overall_estimate` | Overall pooled estimate with CI | Yes |

## Usage Notes

- Forest plots work well for meta-analyses and subgroup analyses
- Include the reference line (null effect) clearly
- Highlight the overall estimate
- If the plot is complex, use the summary table to reinforce key findings
- Consider animating subgroups with v-click for complex plots
