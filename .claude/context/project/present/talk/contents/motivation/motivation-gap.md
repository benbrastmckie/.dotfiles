# Motivation Slide - Knowledge Gap

## Slidev Template

```md
---
layout: two-cols
---

# {{section_title}}

{{gap_statement}}

::right::

<CitationBlock
  author="{{key_citation_author}}"
  year="{{key_citation_year}}"
  journal="{{key_citation_journal}}"
  finding="{{key_citation_finding}}"
/>

<div v-click>

**What remains unknown:**

{{unknown_points}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `section_title` | Heading (e.g., "Why This Matters") | Yes |
| `gap_statement` | 2-3 sentences framing the knowledge gap | Yes |
| `key_citation_author` | First author of key reference | No |
| `key_citation_year` | Publication year | No |
| `key_citation_journal` | Journal name | No |
| `key_citation_finding` | Key finding from the reference | No |
| `unknown_points` | Bulleted list of what is not yet known | Yes |

## Usage Notes

- Start with what is known, then reveal what is unknown
- Use v-click to build the "unknown" points progressively
- Limit to 1-2 key citations for the gap
- The gap should naturally lead to your research question
