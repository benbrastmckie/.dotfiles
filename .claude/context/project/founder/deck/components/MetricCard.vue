<script setup>
/**
 * MetricCard -- Displays a single KPI metric with animated entrance.
 * Props: value (string), label (string), delay (number ms), color (CSS color)
 */
const props = defineProps({
  value: { type: String, required: true },
  label: { type: String, required: true },
  delay: { type: Number, default: 0 },
  color: { type: String, default: 'var(--slidev-accent)' },
})
</script>

<template>
  <div
    v-motion
    :initial="{ scale: 0.8, opacity: 0, y: 40 }"
    :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: props.delay } }"
    class="text-center p-4"
  >
    <div class="text-4xl font-bold" :style="{ color: props.color }">
      {{ props.value }}
    </div>
    <div class="text-sm opacity-70 mt-2">
      {{ props.label }}
    </div>
  </div>
</template>
