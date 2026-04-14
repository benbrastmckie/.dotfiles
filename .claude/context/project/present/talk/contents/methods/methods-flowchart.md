# Methods Slide - Participant Flowchart

## Slidev Template

```md
---
layout: default
---

# Participant Flow

<FlowDiagram
  :stages="{{flow_stages}}"
  :counts="{{flow_counts}}"
  :excluded="{{flow_excluded}}"
/>

<div class="flow-notes">
{{flow_notes}}
</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `flow_stages` | Array of stage labels (e.g., Screened, Enrolled, Analyzed) | Yes |
| `flow_counts` | Array of counts at each stage | Yes |
| `flow_excluded` | Array of exclusion reasons with counts | Yes |
| `flow_notes` | Additional notes about the flow | No |

## Usage Notes

- Follow CONSORT guidelines for RCTs
- Follow STROBE guidelines for observational studies
- Show key exclusion reasons with counts
- Highlight final analytic sample prominently
- Use the FlowDiagram Vue component for consistent rendering
