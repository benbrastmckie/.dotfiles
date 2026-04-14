# Limitations Slide - Standard

## Slidev Template

```md
---
layout: default
---

# Limitations

<div v-click="1">

- {{limitation_1}}

</div>

<div v-click="2">

- {{limitation_2}}

</div>

<div v-click="3">

- {{limitation_3}}

</div>

<div v-click="4">

- {{limitation_4}}

</div>

<div v-click="5" class="mitigation">

**Mitigations:** {{mitigation_note}}

</div>
```

## Content Slots

| Slot | Description | Required |
|------|-------------|----------|
| `limitation_1` | First limitation (e.g., study design) | Yes |
| `limitation_2` | Second limitation (e.g., generalizability) | Yes |
| `limitation_3` | Third limitation (e.g., measurement) | No |
| `limitation_4` | Fourth limitation (e.g., unmeasured confounding) | No |
| `mitigation_note` | How limitations were addressed or acknowledged | No |

## Usage Notes

- Be honest but strategic; do not undermine your findings
- Present 3-4 limitations, starting with the most obvious
- Include what you did to mitigate each limitation
- Show awareness of the limitation rather than dwelling on it
- This slide builds credibility with reviewers and experts
