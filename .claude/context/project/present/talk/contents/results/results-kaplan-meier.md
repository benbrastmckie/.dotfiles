# Results Slide - Kaplan-Meier Survival

## Slidev Template

```md
---
layout: default
---

# {{results_title}}

<FigurePanel
  src="{{km_plot_path}}"
  caption="{{km_caption}}"
  source="{{data_source}}"
  :scale="{{plot_scale}}"
/>

<div v-click class="survival-stats">

<StatResult
  test="Log-rank"
  value="{{logrank_chi2}}"
  p_value="{{logrank_p}}"
  ci=""
  :significance="{{is_significant}}"
/>

| Group | Median Survival | 1-yr Rate |
|-------|----------------|-----------|
{{survival_table_rows}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `results_title` | Slide heading (e.g., "Overall Survival") | Yes |
| `km_plot_path` | Path to Kaplan-Meier plot image | Yes |
| `km_caption` | Figure caption | Yes |
| `data_source` | Source attribution | No |
| `plot_scale` | Scale factor | No |
| `logrank_chi2` | Log-rank test chi-square | No |
| `logrank_p` | Log-rank p-value | No |
| `is_significant` | Boolean for significance | No |
| `survival_table_rows` | Rows with group, median survival, rates | No |

## Usage Notes

- Include number at risk table below the KM curve
- Use distinct colors/patterns for each group
- Show confidence bands if sample sizes permit
- Include median survival times in the summary table
- Reveal statistics with v-click after the audience processes the curves
