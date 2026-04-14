# Results Slide - Data Table

## Slidev Template

```md
---
layout: default
---

# {{results_title}}

<DataTable
  :headers="{{table_headers}}"
  :rows="{{table_rows}}"
  :highlight_row="{{highlight_row_index}}"
  caption="{{table_caption}}"
/>

<div v-click class="interpretation">

**Key Finding:** {{interpretation}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `results_title` | Slide heading (e.g., "Primary Outcomes") | Yes |
| `table_headers` | Array of column headers | Yes |
| `table_rows` | Array of row data arrays | Yes |
| `highlight_row_index` | Index of row to highlight (0-based) | No |
| `table_caption` | Table caption/footnotes | No |
| `interpretation` | One-sentence interpretation of key finding | Yes |

## Usage Notes

- Keep tables small (5-7 rows, 4-6 columns maximum)
- Highlight the primary result row
- Include confidence intervals, not just p-values
- Use the DataTable component for consistent formatting
- State the key finding in plain language below the table
