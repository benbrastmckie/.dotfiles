# Scale In Pop Animation

v-motion spring scale entrance for CTAs and emphasis elements.

## Complexity
Medium

## Syntax

### Basic scale pop
```html
<div
  v-motion
  :initial="{ scale: 0, opacity: 0 }"
  :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 300, damping: 20 } }"
>
  <h1 class="text-6xl font-bold">$5M</h1>
  <p>Seed Round</p>
</div>
```

### With overshoot bounce
```html
<div
  v-motion
  :initial="{ scale: 0, opacity: 0 }"
  :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 400, damping: 15 } }"
>
  Call to action content
</div>
```

### Delayed pop for sequential reveal
```html
<div
  v-motion
  :initial="{ scale: 0, opacity: 0 }"
  :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 300, damping: 20, delay: 500 } }"
>
  Appears after half second
</div>
```

## Use Cases
- Ask slide funding amount
- Closing slide CTA
- Key metric callouts
- Logo or brand reveal

## Notes
- Higher stiffness = faster animation
- Lower damping = more bounce/overshoot
- Good defaults: stiffness 300, damping 20
- Scale from 0 for dramatic pop; from 0.5 for subtle grow
