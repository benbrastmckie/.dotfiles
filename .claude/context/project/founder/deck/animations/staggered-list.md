# Staggered List Animation

v-clicks with depth and every parameters for progressive list reveal.

## Complexity
Low

## Syntax

### Basic staggered list
```html
<v-clicks>

- First point appears
- Second point appears
- Third point appears

</v-clicks>
```

### With depth control (nested lists)
```html
<v-clicks depth="2">

- Main point
  - Sub-point revealed with parent
- Another point
  - Another sub-point

</v-clicks>
```

### Every N items
```html
<v-clicks every="2">

- These two appear together
- (same click as above)
- These two appear together
- (same click as above)

</v-clicks>
```

### Manual click indexing
```html
<ul>
  <li v-click="1">First</li>
  <li v-click="1">Also first (same click)</li>
  <li v-click="2">Second</li>
  <li v-click="3">Third</li>
</ul>
```

## Use Cases
- Problem evidence points
- Solution benefit lists
- Team member introductions
- Any progressive bullet content

## Notes
- `<v-clicks>` wraps any list for automatic staggering
- `depth` controls how deep into nested structures clicks propagate
- `every` groups multiple items per click
- Prefer `<v-clicks>` over manual `v-click` for simple lists
