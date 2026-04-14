<script setup>
/**
 * CitationBlock - Inline literature reference with key finding
 *
 * Props:
 *   author  (String, required) - First author name (e.g., "Smith et al.")
 *   year    (String, required) - Publication year
 *   journal (String, required) - Journal name
 *   finding (String, required) - Key finding from the reference
 *
 * Usage:
 *   <CitationBlock
 *     author="Smith et al."
 *     year="2024"
 *     journal="NEJM"
 *     finding="Treatment reduced mortality by 25% (HR 0.75, 95% CI 0.62-0.91)"
 *   />
 */
const props = defineProps({
  author: { type: String, required: true },
  year: { type: String, required: true },
  journal: { type: String, required: true },
  finding: { type: String, required: true }
})
</script>

<template>
  <div class="citation-block">
    <div class="citation-ref">
      <span class="citation-author">{{ author }}</span>
      <span class="citation-meta">({{ year }}, <em>{{ journal }}</em>)</span>
    </div>
    <div class="citation-finding">
      "{{ finding }}"
    </div>
  </div>
</template>

<style scoped>
.citation-block {
  border-left: 3px solid #3b5998;
  padding: 0.5rem 1rem;
  margin: 0.5rem 0;
  background: #f8fafc;
  border-radius: 0 4px 4px 0;
}
.citation-author {
  font-weight: 600;
}
.citation-meta {
  color: #666;
  font-size: 0.9em;
  margin-left: 0.25rem;
}
.citation-finding {
  font-size: 0.9em;
  color: #444;
  margin-top: 0.25rem;
  font-style: italic;
}
</style>
