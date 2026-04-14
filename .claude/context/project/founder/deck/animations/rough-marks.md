# Rough Marks Animation

v-mark emphasis patterns for highlighting key text with hand-drawn style marks.

## Complexity
Medium

## Syntax

### Underline emphasis
```html
<span v-mark.underline.orange="{ at: 1 }">key phrase</span>
```

### Circle emphasis
```html
<span v-mark.circle.red="{ at: 2 }">important number</span>
```

### Highlight emphasis
```html
<span v-mark.highlight.yellow="{ at: 1 }">highlighted text</span>
```

### Box emphasis
```html
<span v-mark.box.blue="{ at: 3 }">boxed content</span>
```

### Multiple marks in sequence
```html
<p>
  We grew <span v-mark.underline.orange="{ at: 1 }">150% MoM</span>
  reaching <span v-mark.circle.red="{ at: 2 }">10K users</span>
  with <span v-mark.highlight.yellow="{ at: 3 }">$0 marketing spend</span>
</p>
```

## Use Cases
- Emphasizing key metrics on traction slides
- Drawing attention to important claims
- Progressive emphasis during narration

## Notes
- Uses rough-notation library (bundled with Slidev)
- Colors: orange, red, yellow, blue, green, purple
- Mark types: underline, circle, highlight, box, strike-through
- Use `at` parameter to sync with v-click steps
