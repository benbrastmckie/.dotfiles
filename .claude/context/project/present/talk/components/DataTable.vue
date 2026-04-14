<script setup>
/**
 * DataTable - Formatted data table with optional row highlighting
 *
 * Props:
 *   headers       (Array, required)  - Array of column header strings
 *   rows          (Array, required)  - Array of row arrays (each row is an array of cell values)
 *   highlight_row (Number, optional) - Index of row to highlight (0-based)
 *   caption       (String, optional) - Table caption/footnotes
 *
 * Usage:
 *   <DataTable
 *     :headers="['Group', 'N', 'HR (95% CI)', 'P-value']"
 *     :rows="[
 *       ['Treatment', '250', '0.72 (0.58-0.89)', '0.003'],
 *       ['Control', '250', 'ref', '-']
 *     ]"
 *     :highlight_row="0"
 *     caption="Table 1. Primary outcome by treatment group"
 *   />
 */
const props = defineProps({
  headers: { type: Array, required: true },
  rows: { type: Array, required: true },
  highlight_row: { type: Number, default: -1 },
  caption: { type: String, default: '' }
})
</script>

<template>
  <div class="data-table-container">
    <table class="data-table">
      <thead>
        <tr>
          <th v-for="(header, i) in headers" :key="i">{{ header }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="(row, i) in rows"
          :key="i"
          :class="{ highlighted: i === highlight_row }"
        >
          <td v-for="(cell, j) in row" :key="j">{{ cell }}</td>
        </tr>
      </tbody>
    </table>
    <div v-if="caption" class="table-caption">{{ caption }}</div>
  </div>
</template>

<style scoped>
.data-table-container {
  display: flex;
  flex-direction: column;
  align-items: center;
}
.data-table {
  border-collapse: collapse;
  font-size: 0.9em;
  min-width: 60%;
}
.data-table th {
  background: #f0f4f8;
  border-bottom: 2px solid #3b5998;
  padding: 0.5rem 1rem;
  text-align: left;
  font-weight: 600;
}
.data-table td {
  border-bottom: 1px solid #e2e8f0;
  padding: 0.4rem 1rem;
}
.data-table tr.highlighted {
  background: #ebf5ff;
  font-weight: 600;
}
.table-caption {
  font-size: 0.8em;
  color: #666;
  margin-top: 0.5rem;
  text-align: center;
}
</style>
