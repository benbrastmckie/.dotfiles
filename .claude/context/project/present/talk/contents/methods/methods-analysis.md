# Methods Slide - Statistical Analysis

## Slidev Template

```md
---
layout: default
---

# Statistical Analysis

**Primary Analysis:**

{{primary_analysis_description}}

**Key Variables:**

| Variable | Type | Measurement |
|----------|------|-------------|
{{variable_table_rows}}

**Adjustments:**

{{adjustment_variables}}

<div v-click>

**Sensitivity Analyses:**

{{sensitivity_analyses}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `primary_analysis_description` | Main statistical approach (e.g., Cox PH, logistic regression) | Yes |
| `variable_table_rows` | Rows for key variables table | Yes |
| `adjustment_variables` | Confounders adjusted for | Yes |
| `sensitivity_analyses` | Planned sensitivity/subgroup analyses | No |

## Usage Notes

- State the primary analysis method clearly
- List key covariates and their measurement
- Mention software and version if relevant
- Use v-click for sensitivity analyses to manage slide density
- For complex models, consider a diagram of the analytic framework
