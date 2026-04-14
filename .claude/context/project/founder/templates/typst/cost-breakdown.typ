// Cost Breakdown Template
// Professional template for cost analysis documents
// Imports shared styles from strategy-template.typ
// Loads JSON metrics from cost-metrics.json for adaptive values

#import "strategy-template.typ": *

// ============================================================================
// Additional Color Definitions for Cost Analysis
// ============================================================================

#let input-blue = rgb("#0000FF")
#let formula-black = rgb("#000000")
#let highlight-green = rgb("#16a34a")
#let category-personnel = rgb("#2563eb")
#let category-infrastructure = rgb("#7c3aed")
#let category-marketing = rgb("#db2777")
#let category-operations = rgb("#ea580c")

// ============================================================================
// Cost Breakdown Document
// ============================================================================

#let cost-doc(
  title: "Cost Breakdown Analysis",
  project: "",
  date: "",
  mode: "BUDGET",
  data-file: "cost-metrics.json",
  doc,
) = {
  // Load JSON data at compile time
  let data = json(data-file)

  // Apply base strategy document styling
  show: strategy-doc.with(
    title: title,
    project: project,
    date: date,
    mode: mode,
  )

  // Make data available to content
  doc
}

// ============================================================================
// Cost Summary Cards (large metric display)
// ============================================================================

#let cost-summary-cards(monthly: 0, annual: 0, category-count: 0, line-item-count: 0) = {
  grid(
    columns: (1fr, 1fr),
    column-gutter: 16pt,
    row-gutter: 16pt,
    metric-callout(
      "Monthly Total",
      [\$$#{calc.round(monthly, digits: 0)}],
      subtitle: "All categories combined"
    ),
    metric-callout(
      "Annual Total",
      [\$$#{calc.round(annual, digits: 0)}],
      subtitle: "12-month projection"
    ),
    metric-callout(
      "Categories",
      str(category-count),
      subtitle: "Cost buckets"
    ),
    metric-callout(
      "Line Items",
      str(line-item-count),
      subtitle: "Individual costs"
    ),
  )
}

// ============================================================================
// Category Breakdown Table
// ============================================================================

#let category-table(categories) = {
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, right, right),
    table.header(
      [*Category*],
      [*Monthly*],
      [*Annual*],
      [*% of Total*],
    ),
    ..categories.map(cat => (
      [#cat.name],
      [\$$#calc.round(cat.monthly, digits: 0)],
      [\$$#calc.round(cat.annual, digits: 0)],
      [#calc.round(cat.percent_of_total * 100, digits: 1)%],
    )).flatten(),
  )
}

// ============================================================================
// Line Item Detail Table
// ============================================================================

#let line-item-table(items) = {
  table(
    columns: (auto, 1fr, auto, auto, auto, auto),
    align: (left, left, center, right, right, right),
    table.header(
      [*Category*],
      [*Line Item*],
      [*Unit*],
      [*Qty*],
      [*Unit Cost*],
      [*Monthly*],
    ),
    ..items.map(item => (
      [#item.category],
      [#item.name],
      [#item.unit],
      [#item.quantity],
      [\$$#calc.round(item.unit_cost, digits: 0)],
      [\$$#calc.round(item.monthly, digits: 0)],
    )).flatten(),
  )
}

// ============================================================================
// Category Percentage Bar (horizontal stacked bar)
// ============================================================================

#let category-bar(categories, total-width: 100%) = {
  let total = categories.map(c => c.monthly).sum()
  let colors = (
    category-personnel,
    category-infrastructure,
    category-marketing,
    category-operations,
    navy-light,
    text-muted,
  )

  rect(
    width: total-width,
    height: 24pt,
    stroke: 0.5pt + border-light,
    radius: 4pt,
  )[
    #stack(
      dir: ltr,
      ..categories.enumerate().map(((i, cat)) => {
        let width-pct = cat.monthly / total * 100
        rect(
          width: calc.round(width-pct, digits: 1) * 1%,
          height: 24pt,
          fill: colors.at(calc.rem(i, colors.len())),
        )[]
      }),
    )
  ]
  #v(0.5em)
  #grid(
    columns: categories.len(),
    column-gutter: 8pt,
    ..categories.enumerate().map(((i, cat)) => {
      [
        #box(
          width: 10pt,
          height: 10pt,
          fill: colors.at(calc.rem(i, colors.len())),
          radius: 2pt,
        )
        #text(size: 9pt)[#cat.name (#calc.round(cat.percent_of_total * 100, digits: 0)%)]
      ]
    }),
  )
}

// ============================================================================
// Cost Assumption Box
// ============================================================================

#let assumption-box(assumptions) = {
  callout(
    color: fill-callout,
    border: navy-medium,
  )[
    #text(weight: "bold", fill: navy-medium)[Key Assumptions]
    #v(0.3em)
    #for (i, assumption) in assumptions.enumerate() [
      #text(size: 10pt)[#str(i + 1). #assumption]
      #if i < assumptions.len() - 1 [ #v(0.2em) ]
    ]
  ]
}

// ============================================================================
// Data Quality Indicator
// ============================================================================

#let quality-indicator(quality) = {
  let (color, label) = if quality == "high" {
    (highlight-green, "High")
  } else if quality == "medium" {
    (border-warning, "Medium")
  } else {
    (rgb("#dc2626"), "Low")
  }

  box(
    fill: color.lighten(80%),
    stroke: 0.5pt + color,
    radius: 3pt,
    inset: (x: 0.5em, y: 0.2em),
  )[
    #text(size: 8pt, fill: color, weight: "bold")[#label]
  ]
}

// ============================================================================
// Data Quality Table
// ============================================================================

#let quality-table(quality-data) = {
  table(
    columns: (1fr, auto, 1fr),
    align: (left, center, left),
    table.header(
      [*Category*],
      [*Quality*],
      [*Notes*],
    ),
    ..quality-data.map(q => (
      [#q.category],
      quality-indicator(q.quality),
      [#q.notes],
    )).flatten(),
  )
}

// ============================================================================
// Contingency Block
// ============================================================================

#let contingency-block(percent: 10, rationale: "", amount-monthly: 0, amount-annual: 0) = {
  rect(
    width: 100%,
    fill: fill-warning,
    stroke: (left: 3pt + border-warning),
    inset: 12pt,
    radius: (right: 4pt),
  )[
    #grid(
      columns: (1fr, auto),
      [
        #text(weight: "bold", fill: border-warning)[Contingency Buffer: #percent%]
        #v(0.3em)
        #text(size: 10pt)[#rationale]
      ],
      [
        #align(right)[
          #text(weight: "bold", size: 12pt)[\$$#calc.round(amount-monthly, digits: 0)/mo]
          #v(0.2em)
          #text(size: 10pt, fill: text-muted)[\$$#calc.round(amount-annual, digits: 0)/yr]
        ]
      ],
    )
  ]
}

// ============================================================================
// Scenario Comparison
// ============================================================================

#let scenario-table(scenarios) = {
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, right, right),
    table.header(
      [*Scenario*],
      [*Monthly*],
      [*Annual*],
      [*Delta*],
    ),
    ..scenarios.map(s => (
      [#s.name],
      [\$$#calc.round(s.monthly, digits: 0)],
      [\$$#calc.round(s.annual, digits: 0)],
      [#if s.at("delta", default: none) != none [#s.delta] else [-]],
    )).flatten(),
  )
}

// ============================================================================
// Runway Calculator
// ============================================================================

#let runway-block(cash: 0, monthly-burn: 0) = {
  let months = calc.floor(cash / monthly-burn)
  let years = calc.floor(months / 12)
  let remaining-months = calc.rem(months, 12)

  rect(
    width: 100%,
    fill: if months >= 18 { rgb("#f0fdf4") } else if months >= 12 { fill-warning } else { rgb("#fef2f2") },
    stroke: (left: 3pt + if months >= 18 { highlight-green } else if months >= 12 { border-warning } else { rgb("#dc2626") }),
    inset: 12pt,
    radius: (right: 4pt),
  )[
    #grid(
      columns: (1fr, auto),
      [
        #text(weight: "bold")[Runway Analysis]
        #v(0.3em)
        #text(size: 10pt)[Cash: \$$#calc.round(cash, digits: 0) | Burn: \$$#calc.round(monthly-burn, digits: 0)/mo]
      ],
      [
        #align(right)[
          #text(weight: "bold", size: 16pt)[
            #if years > 0 [#years yr #remaining-months mo] else [#months months]
          ]
        ]
      ],
    )
  ]
}

// ============================================================================
// Example Usage
// ============================================================================

// To use this template:
//
// ```typst
// #import "cost-breakdown.typ": *
//
// // Load your JSON data
// #let data = json("cost-metrics.json")
//
// #show: cost-doc.with(
//   title: "Q1 2026 Cost Breakdown",
//   project: "Product Launch",
//   date: "March 2026",
//   mode: data.metadata.mode,
// )
//
// = Executive Summary
//
// #cost-summary-cards(
//   monthly: data.summary.total_monthly,
//   annual: data.summary.total_annual,
//   category-count: data.summary.category_count,
//   line-item-count: data.line_items.len(),
// )
//
// = Cost Breakdown by Category
//
// #category-bar(data.categories)
//
// #category-table(data.categories)
//
// = Detailed Line Items
//
// #line-item-table(data.line_items)
//
// = Contingency
//
// #contingency-block(
//   percent: 10,
//   rationale: "Low uncertainty, established costs",
//   amount-monthly: data.summary.total_monthly * 0.1,
//   amount-annual: data.summary.total_annual * 0.1,
// )
// ```

// ============================================================================
// JSON Data Schema Reference
// ============================================================================

// Expected JSON structure (cost-metrics.json):
// {
//   "metadata": {
//     "project": "Project Name",
//     "date": "2026-03-27",
//     "mode": "BUDGET",
//     "currency": "USD"
//   },
//   "summary": {
//     "total_monthly": 81200,
//     "total_annual": 974400,
//     "largest_category": "Personnel",
//     "category_count": 4
//   },
//   "categories": [
//     {
//       "name": "Personnel",
//       "monthly": 70000,
//       "annual": 840000,
//       "percent_of_total": 0.862
//     }
//   ],
//   "line_items": [
//     {
//       "category": "Personnel",
//       "name": "Engineers",
//       "unit": "FTE",
//       "quantity": 5,
//       "unit_cost": 12000,
//       "monthly": 60000,
//       "annual": 720000
//     }
//   ]
// }
