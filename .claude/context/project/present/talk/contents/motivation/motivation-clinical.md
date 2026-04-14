# Motivation Slide - Clinical Vignette

## Slidev Template

```md
---
layout: default
---

# {{section_title}}

<div class="clinical-vignette">

> {{vignette_text}}

</div>

<div v-click>

**The Clinical Challenge:**

{{challenge_statement}}

</div>

<div v-click>

**Epidemiological Context:**

{{epidemiology_stats}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `section_title` | Heading (e.g., "The Clinical Problem") | Yes |
| `vignette_text` | Brief clinical scenario (2-3 sentences) | Yes |
| `challenge_statement` | What makes this difficult to manage | Yes |
| `epidemiology_stats` | Prevalence, incidence, or burden data | No |

## Usage Notes

- Use a relatable clinical scenario to ground the audience
- Keep the vignette brief and de-identified
- Build from individual case to population-level significance
- Effective for clinical or mixed audiences
- Transitions naturally to "Our approach" or "Research question"
