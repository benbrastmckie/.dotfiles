# Title Slide - Standard

## Slidev Template

```md
---
layout: cover
---

# {{title}}

{{author_list}}

<div class="affiliations">
{{affiliations}}
</div>

<div class="event-info">
{{conference_or_event}} | {{date}}
</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `title` | Full talk title | Yes |
| `author_list` | Comma-separated author names, presenter underlined | Yes |
| `affiliations` | Numbered institutional affiliations | Yes |
| `conference_or_event` | Conference name, seminar series, or event | No |
| `date` | Presentation date | No |

## Usage Notes

- Keep the title concise (2 lines maximum on screen)
- Underline or bold the presenting author
- Use superscript numbers for multiple affiliations
- Include department and institution for each affiliation
