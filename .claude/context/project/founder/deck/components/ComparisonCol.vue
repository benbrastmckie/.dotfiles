<script setup>
/**
 * ComparisonCol -- A column for side-by-side comparison (e.g., Before/After, Us/Them).
 * Props: title (string), points (string[]), color (CSS color), highlight (boolean)
 */
const props = defineProps({
  title: { type: String, required: true },
  points: { type: Array, required: true },
  color: { type: String, default: 'var(--slidev-accent)' },
  highlight: { type: Boolean, default: false },
})
</script>

<template>
  <div
    v-click
    class="p-6 rounded-lg"
    :class="{ 'ring-2': props.highlight }"
    :style="{
      borderColor: props.highlight ? props.color : 'transparent',
      ringColor: props.highlight ? props.color : 'transparent',
    }"
  >
    <h3 class="text-xl font-bold mb-4" :style="{ color: props.color }">
      {{ props.title }}
    </h3>
    <ul class="space-y-2">
      <li
        v-for="(point, i) in props.points"
        :key="i"
        class="text-sm opacity-80"
      >
        {{ point }}
      </li>
    </ul>
  </div>
</template>
