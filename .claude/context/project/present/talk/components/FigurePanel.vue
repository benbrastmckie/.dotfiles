<script setup>
/**
 * FigurePanel - Display a research figure with caption and source attribution
 *
 * Props:
 *   src      (String, required) - Path to the figure image
 *   caption  (String, required) - Figure caption text
 *   source   (String, optional) - Data source attribution
 *   scale    (Number, optional) - Scale factor for the image (default: 1.0)
 *
 * Usage:
 *   <FigurePanel
 *     src="/assets/figure1.png"
 *     caption="Figure 1. Overall survival by treatment group"
 *     source="Study cohort (N=500)"
 *     :scale="0.8"
 *   />
 */
const props = defineProps({
  src: { type: String, required: true },
  caption: { type: String, required: true },
  source: { type: String, default: '' },
  scale: { type: Number, default: 1.0 }
})
</script>

<template>
  <div class="figure-panel">
    <div class="figure-image" :style="{ transform: `scale(${scale})` }">
      <img :src="src" :alt="caption" />
    </div>
    <div class="figure-caption">
      {{ caption }}
    </div>
    <div v-if="source" class="figure-source">
      Source: {{ source }}
    </div>
  </div>
</template>

<style scoped>
.figure-panel {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
}
.figure-image {
  transform-origin: center;
}
.figure-image img {
  max-width: 100%;
  max-height: 60vh;
  object-fit: contain;
}
.figure-caption {
  font-size: 0.85em;
  color: #444;
  text-align: center;
  max-width: 80%;
}
.figure-source {
  font-size: 0.75em;
  color: #888;
  font-style: italic;
}
</style>
