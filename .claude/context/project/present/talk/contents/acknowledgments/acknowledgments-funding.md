# Acknowledgments Slide - Funding and Disclosures

## Slidev Template

```md
---
layout: default
---

# Acknowledgments

**Funding:**

{{funding_sources}}

**Collaborators:**

{{collaborator_list}}

<div class="disclosures">

**Disclosures:** {{disclosures}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `funding_sources` | Grant numbers, funding agencies, awards | Yes |
| `collaborator_list` | Key collaborators and their roles | No |
| `disclosures` | COI disclosures or "None to declare" | Yes |

## Usage Notes

- Include full grant numbers (e.g., NIH R01-CA123456)
- Include funder logos if permitted
- List key collaborators by name and institution
- Always include a disclosures statement (required by most conferences)
- Keep this slide brief; it is transitional to Q&A
