# Slide In Below Animation

v-motion y-axis entrance for dynamic content reveal.

## Complexity
Medium

## Syntax

### Basic slide-up entrance
```html
<div
  v-motion
  :initial="{ y: 80, opacity: 0 }"
  :enter="{ y: 0, opacity: 1 }"
  :delay="200"
>
  Content slides up from below
</div>
```

### With spring physics
```html
<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { type: 'spring', stiffness: 250, damping: 25 } }"
>
  Bouncy entrance
</div>
```

### Staggered group
```html
<div v-motion :initial="{ y: 60, opacity: 0 }" :enter="{ y: 0, opacity: 1 }" :delay="0">Item 1</div>
<div v-motion :initial="{ y: 60, opacity: 0 }" :enter="{ y: 0, opacity: 1 }" :delay="200">Item 2</div>
<div v-motion :initial="{ y: 60, opacity: 0 }" :enter="{ y: 0, opacity: 1 }" :delay="400">Item 3</div>
```

## Use Cases
- Hero content on cover slides
- Key metric reveals
- Call-to-action elements

## Notes
- Requires `@vueuse/motion` (bundled with Slidev)
- Use `:delay` for staggering multiple elements
- Keep y offset between 60-100px for natural feel
