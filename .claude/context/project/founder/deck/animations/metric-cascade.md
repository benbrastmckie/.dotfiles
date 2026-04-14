# Metric Cascade Animation

Staggered v-motion entrance for KPI/metric slides with scale and opacity.

## Complexity
High

## Syntax

### Three-metric cascade
```html
<div class="grid grid-cols-3 gap-8">
  <div
    v-motion
    :initial="{ scale: 0.8, opacity: 0, y: 40 }"
    :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 0 } }"
  >
    <AutoFitText :max="48" :min="24" class="text-[var(--slidev-accent)]">
      $2.5M
    </AutoFitText>
    <p class="text-sm opacity-70">ARR</p>
  </div>

  <div
    v-motion
    :initial="{ scale: 0.8, opacity: 0, y: 40 }"
    :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 300 } }"
  >
    <AutoFitText :max="48" :min="24" class="text-[var(--slidev-accent)]">
      150%
    </AutoFitText>
    <p class="text-sm opacity-70">MoM Growth</p>
  </div>

  <div
    v-motion
    :initial="{ scale: 0.8, opacity: 0, y: 40 }"
    :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 600 } }"
  >
    <AutoFitText :max="48" :min="24" class="text-[var(--slidev-accent)]">
      10K
    </AutoFitText>
    <p class="text-sm opacity-70">Active Users</p>
  </div>
</div>
```

## Use Cases
- Traction slides with key metrics
- Financial summary numbers
- Any 2-4 metric display

## Notes
- Use 300ms delay increments between metrics
- Scale from 0.8 (not 0) for subtle effect
- Combine with AutoFitText for responsive sizing
- Works best on `layout: fact` or `layout: center` slides
