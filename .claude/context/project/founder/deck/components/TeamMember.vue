<script setup>
/**
 * TeamMember -- Displays a team member card with photo, name, role, and bio.
 * Props: name (string), role (string), bio (string), photo (string URL), delay (number ms)
 */
const props = defineProps({
  name: { type: String, required: true },
  role: { type: String, required: true },
  bio: { type: String, default: '' },
  photo: { type: String, default: '' },
  delay: { type: Number, default: 0 },
})
</script>

<template>
  <div
    v-motion
    :initial="{ y: 60, opacity: 0 }"
    :enter="{ y: 0, opacity: 1, transition: { delay: props.delay } }"
    class="flex flex-col items-center text-center p-4"
  >
    <div
      v-if="props.photo"
      class="w-20 h-20 rounded-full overflow-hidden mb-3 border-2"
      :style="{ borderColor: 'var(--slidev-accent)' }"
    >
      <img :src="props.photo" :alt="props.name" class="w-full h-full object-cover" />
    </div>
    <div
      v-else
      class="w-20 h-20 rounded-full mb-3 flex items-center justify-center text-2xl font-bold"
      :style="{ backgroundColor: 'var(--slidev-accent)', color: 'var(--slidev-bg)' }"
    >
      {{ props.name.charAt(0) }}
    </div>
    <h3 class="text-lg font-bold">{{ props.name }}</h3>
    <p class="text-sm opacity-80">{{ props.role }}</p>
    <p v-if="props.bio" class="text-xs opacity-60 mt-1">{{ props.bio }}</p>
  </div>
</template>
