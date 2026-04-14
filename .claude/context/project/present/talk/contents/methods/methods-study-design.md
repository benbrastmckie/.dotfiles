# Methods Slide - Study Design

## Slidev Template

```md
---
layout: default
---

# Study Design

**Design:** {{study_design}}

**Setting:** {{study_setting}}

**Population:** {{population_description}}

**Sample Size:** {{sample_size}}

<div class="design-details">

| Element | Description |
|---------|-------------|
| Exposure/Intervention | {{exposure}} |
| Primary Outcome | {{primary_outcome}} |
| Follow-up | {{followup_period}} |
| Analysis | {{analysis_approach}} |

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `study_design` | Design type (RCT, cohort, cross-sectional, etc.) | Yes |
| `study_setting` | Where the study was conducted | Yes |
| `population_description` | Inclusion/exclusion criteria summary | Yes |
| `sample_size` | N with justification note | Yes |
| `exposure` | Main exposure or intervention | Yes |
| `primary_outcome` | Primary outcome measure | Yes |
| `followup_period` | Duration of follow-up | No |
| `analysis_approach` | Statistical analysis method | Yes |

## Usage Notes

- Use a clear, structured layout for quick comprehension
- Consider a visual diagram for complex multi-arm designs
- Include key inclusion/exclusion criteria only
- State the primary analysis approach (ITT, per-protocol, etc.)
