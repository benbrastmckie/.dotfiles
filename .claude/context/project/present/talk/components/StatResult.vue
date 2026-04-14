<script setup>
/**
 * StatResult - Display a statistical result with significance highlighting
 *
 * Props:
 *   test         (String, required) - Statistical test name (e.g., "Log-rank", "Cox PH")
 *   value        (String, required) - Test statistic value
 *   p_value      (String, required) - P-value string
 *   ci           (String, optional) - Confidence interval (e.g., "0.58-0.89")
 *   significance (Boolean, optional) - Whether the result is statistically significant
 *
 * Usage:
 *   <StatResult
 *     test="Cox proportional hazards"
 *     value="HR = 0.72"
 *     p_value="0.003"
 *     ci="0.58-0.89"
 *     :significance="true"
 *   />
 */
const props = defineProps({
  test: { type: String, required: true },
  value: { type: String, required: true },
  p_value: { type: String, required: true },
  ci: { type: String, default: '' },
  significance: { type: Boolean, default: false }
})
</script>

<template>
  <div class="stat-result" :class="{ significant: significance }">
    <span class="stat-test">{{ test }}:</span>
    <span class="stat-value">{{ value }}</span>
    <span v-if="ci" class="stat-ci">(95% CI: {{ ci }})</span>
    <span class="stat-p" :class="{ 'p-significant': significance }">
      p = {{ p_value }}
    </span>
  </div>
</template>

<style scoped>
.stat-result {
  display: inline-flex;
  align-items: baseline;
  gap: 0.5rem;
  padding: 0.4rem 0.8rem;
  background: #f8fafc;
  border-radius: 4px;
  font-family: 'Courier New', monospace;
  font-size: 0.9em;
}
.stat-result.significant {
  border-left: 3px solid #2563eb;
}
.stat-test {
  font-weight: 600;
  color: #374151;
}
.stat-value {
  color: #1e40af;
  font-weight: 600;
}
.stat-ci {
  color: #6b7280;
}
.stat-p {
  color: #6b7280;
}
.stat-p.p-significant {
  color: #dc2626;
  font-weight: 700;
}
</style>
