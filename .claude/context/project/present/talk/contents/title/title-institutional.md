# Title Slide - Institutional

## Slidev Template

```md
---
layout: cover
class: institutional
---

<div class="logo-bar">
  <img src="{{institution_logo}}" alt="{{institution_name}}" />
</div>

# {{title}}

**{{department}}**

{{author_list}}

<div class="event-info">
{{conference_or_event}} | {{date}}
</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `institution_logo` | Path to institution logo image | Yes |
| `institution_name` | Institution name (for alt text) | Yes |
| `title` | Full talk title | Yes |
| `department` | Department or division name | Yes |
| `author_list` | Comma-separated author names | Yes |
| `conference_or_event` | Conference name or event | No |
| `date` | Presentation date | No |

## Usage Notes

- Place institution logo in top-left or top-center
- Use official institutional branding colors if available
- Department name appears below the title in smaller font
- Suitable for institutional seminars and formal presentations
