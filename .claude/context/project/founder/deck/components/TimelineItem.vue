<script setup>
/**
 * TimelineItem -- Displays a milestone on a timeline with date, label, and status.
 * Props: date (string), label (string), description (string), status (string: done|current|upcoming)
 */
const props = defineProps({
  date: { type: String, required: true },
  label: { type: String, required: true },
  description: { type: String, default: '' },
  status: { type: String, default: 'upcoming', validator: (v) => ['done', 'current', 'upcoming'].includes(v) },
})

const dotColor = {
  done: 'var(--slidev-accent)',
  current: 'var(--slidev-accent-light)',
  upcoming: 'var(--slidev-text-muted)',
}
</script>

<template>
  <div
    v-click
    class="flex items-start gap-4 mb-4"
  >
    <div class="flex flex-col items-center">
      <div
        class="w-3 h-3 rounded-full"
        :style="{ backgroundColor: dotColor[props.status] }"
      />
      <div class="w-0.5 h-8 bg-gray-500 opacity-30" />
    </div>
    <div>
      <div class="text-xs opacity-50">{{ props.date }}</div>
      <div class="font-bold text-sm">{{ props.label }}</div>
      <div v-if="props.description" class="text-xs opacity-70">{{ props.description }}</div>
    </div>
  </div>
</template>
