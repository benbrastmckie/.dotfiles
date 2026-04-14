# Fade In Animation

CSS-based fade entrance for slide elements.

## Complexity
Low

## Syntax

### Basic v-click fade
```html
<div v-click>
  Content fades in on click
</div>
```

### CSS transition fade
```html
<div v-click class="transition-opacity duration-500">
  Smooth opacity transition
</div>
```

### Multiple elements with staggered fade
```html
<v-clicks>

- First item fades in
- Second item fades in
- Third item fades in

</v-clicks>
```

## Use Cases
- Default animation for most slide content
- Bullet point progressive reveal
- Simple text and image entrance

## Notes
- Slidev applies fade by default on v-click elements
- Combine with `duration-*` Windi CSS classes for timing control
- Lowest visual weight -- use for content-heavy slides
