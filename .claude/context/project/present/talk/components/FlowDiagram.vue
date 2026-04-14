<script setup>
/**
 * FlowDiagram - CONSORT/STROBE-style participant flow diagram
 *
 * Props:
 *   stages   (Array, required) - Array of stage label strings (e.g., ["Screened", "Enrolled", "Analyzed"])
 *   counts   (Array, required) - Array of participant counts at each stage
 *   excluded (Array, required) - Array of objects with exclusion details: { reason: String, count: Number }
 *
 * Usage:
 *   <FlowDiagram
 *     :stages="['Screened', 'Eligible', 'Enrolled', 'Analyzed']"
 *     :counts="[1200, 800, 500, 480]"
 *     :excluded="[
 *       { reason: 'Did not meet criteria', count: 400 },
 *       { reason: 'Declined participation', count: 300 },
 *       { reason: 'Lost to follow-up', count: 20 }
 *     ]"
 *   />
 */
const props = defineProps({
  stages: { type: Array, required: true },
  counts: { type: Array, required: true },
  excluded: { type: Array, required: true }
})
</script>

<template>
  <div class="flow-diagram">
    <div v-for="(stage, i) in stages" :key="i" class="flow-stage">
      <div class="stage-box">
        <div class="stage-label">{{ stage }}</div>
        <div class="stage-count">N = {{ counts[i] }}</div>
      </div>
      <div v-if="i < stages.length - 1" class="flow-connector">
        <div class="flow-arrow">|</div>
        <div v-if="excluded[i]" class="exclusion-box">
          <span class="exclusion-reason">{{ excluded[i].reason }}</span>
          <span class="exclusion-count">(n = {{ excluded[i].count }})</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.flow-diagram {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0;
}
.flow-stage {
  display: flex;
  flex-direction: column;
  align-items: center;
}
.stage-box {
  border: 2px solid #3b5998;
  border-radius: 6px;
  padding: 0.5rem 1.5rem;
  text-align: center;
  background: white;
  min-width: 180px;
}
.stage-label {
  font-weight: 600;
  font-size: 0.9em;
}
.stage-count {
  font-size: 0.85em;
  color: #444;
}
.flow-connector {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.25rem 0;
}
.flow-arrow {
  font-size: 1.2em;
  color: #3b5998;
  font-weight: bold;
}
.exclusion-box {
  background: #fef3c7;
  border: 1px solid #f59e0b;
  border-radius: 4px;
  padding: 0.25rem 0.75rem;
  font-size: 0.8em;
}
.exclusion-reason {
  color: #92400e;
}
.exclusion-count {
  color: #b45309;
  margin-left: 0.25rem;
}
</style>
