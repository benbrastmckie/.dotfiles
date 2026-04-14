# Discussion Slide - Literature Comparison

## Slidev Template

```md
---
layout: default
---

# Discussion

**Our finding:** {{our_finding}}

<div v-click>

**Comparison to prior work:**

| Study | Population | Finding | Consistent? |
|-------|-----------|---------|-------------|
{{comparison_rows}}

</div>

<div v-click>

**Interpretation:**

{{interpretation}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `our_finding` | One-sentence summary of primary finding | Yes |
| `comparison_rows` | Rows comparing to 2-3 prior studies | Yes |
| `interpretation` | What the comparison means, why differences exist | Yes |

## Usage Notes

- Lead with your finding, then compare to literature
- Limit comparison to 2-3 most relevant studies
- Note key differences in population, methods, or setting
- Use v-click to build the comparison progressively
- End with clinical or scientific implications
