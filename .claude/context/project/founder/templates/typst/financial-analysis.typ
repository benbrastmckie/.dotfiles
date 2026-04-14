// Financial Analysis Template
// Professional template for financial analysis documents
// Imports shared styles from strategy-template.typ
// Loads JSON metrics from financial-metrics.json for all numerical values

#import "strategy-template.typ": *

// ============================================================================
// Additional Color Definitions for Financial Analysis
// ============================================================================

#let health-green = rgb("#16a34a")
#let health-amber = rgb("#d97706")
#let health-red = rgb("#dc2626")
#let verify-match = rgb("#16a34a")
#let verify-discrepancy = rgb("#dc2626")
#let trend-up = rgb("#16a34a")
#let trend-down = rgb("#dc2626")
#let trend-flat = rgb("#6b7280")

// ============================================================================
// Financial Analysis Document
// ============================================================================

#let financial-doc(
  title: "Financial Analysis Report",
  project: "",
  date: "",
  mode: "REVIEW",
  data-file: "financial-metrics.json",
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
// Health Badge (Healthy/Adequate/Concerning/Critical)
// ============================================================================

#let health-badge(level) = {
  let (color, label) = if level == "healthy" or level == "Healthy" {
    (health-green, "Healthy")
  } else if level == "adequate" or level == "Adequate" {
    (health-amber, "Adequate")
  } else if level == "concerning" or level == "Concerning" {
    (health-red.lighten(20%), "Concerning")
  } else {
    (health-red, "Critical")
  }

  box(
    fill: color.lighten(80%),
    stroke: 0.5pt + color,
    radius: 3pt,
    inset: (x: 0.6em, y: 0.2em),
  )[
    #text(size: 9pt, fill: color, weight: "bold")[#label]
  ]
}

// ============================================================================
// Verification Badge (Verified/Supported/Unverified/Match/Discrepancy)
// ============================================================================

#let verification-badge(status) = {
  let (color, label) = if status == "verified" or status == "Verified" or status == "match" or status == "Match" {
    (verify-match, if status == "match" or status == "Match" { "Match" } else { "Verified" })
  } else if status == "supported" or status == "Supported" {
    (health-amber, "Supported")
  } else if status == "discrepancy" or status == "Discrepancy" {
    (verify-discrepancy, "Discrepancy")
  } else {
    (trend-flat, "Unverified")
  }

  box(
    fill: color.lighten(85%),
    stroke: 0.5pt + color,
    radius: 3pt,
    inset: (x: 0.5em, y: 0.2em),
  )[
    #text(size: 8pt, fill: color, weight: "bold")[#label]
  ]
}

// ============================================================================
// Financial Summary Cards (executive summary metrics)
// ============================================================================

#let financial-summary-cards(arr: 0, mrr: 0, cash-balance: 0, runway-months: 0) = {
  grid(
    columns: (1fr, 1fr),
    column-gutter: 16pt,
    row-gutter: 16pt,
    metric-callout(
      "Annual Recurring Revenue",
      [\$$#{calc.round(arr, digits: 0)}],
      subtitle: "ARR"
    ),
    metric-callout(
      "Monthly Recurring Revenue",
      [\$$#{calc.round(mrr, digits: 0)}],
      subtitle: "MRR"
    ),
    metric-callout(
      "Cash Balance",
      [\$$#{calc.round(cash-balance, digits: 0)}],
      subtitle: "Current position"
    ),
    metric-callout(
      "Runway",
      [#runway-months months],
      subtitle: if runway-months >= 18 { "Comfortable" } else if runway-months >= 12 { "Adequate" } else { "Concerning" }
    ),
  )
}

// ============================================================================
// Document Inventory Table
// ============================================================================

#let document-inventory-table(documents) = {
  table(
    columns: (1fr, auto, auto, auto, auto),
    align: (left, center, center, center, center),
    table.header(
      [*Document*],
      [*Type*],
      [*Period*],
      [*Source*],
      [*Quality*],
    ),
    ..documents.map(doc => (
      [#doc.name],
      [#doc.type],
      [#doc.period],
      [#doc.source],
      verification-badge(doc.quality),
    )).flatten(),
  )
}

// ============================================================================
// Completeness Table
// ============================================================================

#let completeness-table(items) = {
  table(
    columns: (1fr, auto, 1fr),
    align: (left, center, left),
    table.header(
      [*Required Document*],
      [*Status*],
      [*Notes*],
    ),
    ..items.map(item => (
      [#item.document],
      [#if item.status == "Available" {
        text(fill: health-green, weight: "bold")[Available]
      } else if item.status == "Partial" {
        text(fill: health-amber, weight: "bold")[Partial]
      } else {
        text(fill: health-red, weight: "bold")[Missing]
      }],
      [#item.notes],
    )).flatten(),
  )
}

// ============================================================================
// Revenue Table
// ============================================================================

#let revenue-table(metrics) = {
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, center, center),
    table.header(
      [*Metric*],
      [*Value*],
      [*Trend*],
      [*Verification*],
    ),
    ..metrics.map(m => (
      [#m.metric],
      [#m.value],
      [#if m.at("trend", default: none) != none {
        let t = m.trend
        if t == "up" { text(fill: trend-up)[Growing] }
        else if t == "down" { text(fill: trend-down)[Declining] }
        else { text(fill: trend-flat)[Stable] }
      } else [-]],
      [#if m.at("verification", default: none) != none {
        verification-badge(m.verification)
      } else [-]],
    )).flatten(),
  )
}

// ============================================================================
// Expense Table
// ============================================================================

#let expense-table(categories) = {
  table(
    columns: (1fr, auto, auto, auto, auto),
    align: (left, right, right, right, center),
    table.header(
      [*Category*],
      [*Monthly*],
      [*Annual*],
      [*% of Total*],
      [*Trend*],
    ),
    ..categories.map(cat => (
      [#cat.name],
      [\$$#{calc.round(cat.monthly, digits: 0)}],
      [\$$#{calc.round(cat.annual, digits: 0)}],
      [#calc.round(cat.pct_of_total * 100, digits: 1)%],
      [#if cat.at("trend", default: none) != none {
        let t = cat.trend
        if t == "up" { text(fill: trend-down)[Increasing] }
        else if t == "down" { text(fill: trend-up)[Decreasing] }
        else { text(fill: trend-flat)[Stable] }
      } else [-]],
    )).flatten(),
  )
}

// ============================================================================
// Cash Position Block
// ============================================================================

#let cash-position-block(data) = {
  let months = data.runway_months
  let burn = data.monthly_net_burn

  rect(
    width: 100%,
    fill: if months >= 18 { rgb("#f0fdf4") } else if months >= 12 { fill-warning } else { rgb("#fef2f2") },
    stroke: (left: 3pt + if months >= 18 { health-green } else if months >= 12 { border-warning } else { health-red }),
    inset: 12pt,
    radius: (right: 4pt),
  )[
    #grid(
      columns: (1fr, auto),
      [
        #text(weight: "bold")[Cash Position Analysis]
        #v(0.3em)
        #text(size: 10pt)[
          Balance: \$$#calc.round(data.balance, digits: 0) |
          Net Burn: \$$#calc.round(burn, digits: 0)/mo |
          Gross Burn: \$$#calc.round(data.gross_burn, digits: 0)/mo
        ]
      ],
      [
        #align(right)[
          #text(weight: "bold", size: 16pt)[
            #let years = calc.floor(months / 12)
            #let remaining = calc.rem(months, 12)
            #if years > 0 [#years yr #remaining mo] else [#months months]
          ]
          #v(0.2em)
          #text(size: 10pt, fill: text-muted)[Runway]
        ]
      ],
    )
  ]
}

// ============================================================================
// Ratio Table (with benchmark comparison and conditional coloring)
// ============================================================================

#let ratio-table(ratios) = {
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, center, center),
    table.header(
      [*Ratio*],
      [*Value*],
      [*Benchmark*],
      [*Assessment*],
    ),
    ..ratios.map(r => (
      [#r.name],
      [#r.value],
      [#r.benchmark],
      health-badge(r.assessment),
    )).flatten(),
  )
}

// ============================================================================
// Startup Metrics Table
// ============================================================================

#let startup-metrics-table(metrics) = {
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, center, center),
    table.header(
      [*Metric*],
      [*Value*],
      [*Benchmark*],
      [*Assessment*],
    ),
    ..metrics.map(m => (
      [#m.name],
      [#m.value],
      [#m.benchmark],
      health-badge(m.assessment),
    )).flatten(),
  )
}

// ============================================================================
// Verification Matrix (cross-reference checks)
// ============================================================================

#let verification-matrix(items) = {
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, center),
    table.header(
      [*Item*],
      [*Source 1*],
      [*Source 2*],
      [*Source 3*],
      [*Status*],
    ),
    ..items.map(item => (
      [#item.item],
      [#item.source1],
      [#item.source2],
      [#item.at("source3", default: "-")],
      verification-badge(item.status),
    )).flatten(),
  )
}

// ============================================================================
// Discrepancy Table
// ============================================================================

#let discrepancy-table(items) = {
  table(
    columns: (auto, auto, 1fr, 1fr, auto),
    align: (center, left, left, left, center),
    table.header(
      [*\#*],
      [*Item*],
      [*Magnitude*],
      [*Explanation*],
      [*Status*],
    ),
    ..items.enumerate().map(((i, item)) => (
      [#str(i + 1)],
      [#item.item],
      [#item.magnitude],
      [#item.explanation],
      [#if item.status == "Explained" {
        text(fill: health-green, weight: "bold")[Explained]
      } else if item.status == "Investigating" {
        text(fill: health-amber, weight: "bold")[Investigating]
      } else {
        text(fill: health-red, weight: "bold")[Unresolved]
      }],
    )).flatten(),
  )
}

// ============================================================================
// Scenario Comparison
// ============================================================================

#let scenario-comparison(scenarios) = {
  table(
    columns: (auto, auto, auto, auto, 1fr),
    align: (left, right, right, center, left),
    table.header(
      [*Scenario*],
      [*Revenue*],
      [*Expenses*],
      [*Runway*],
      [*Key Driver*],
    ),
    ..scenarios.map(s => (
      [*#s.name*],
      [\$$#{calc.round(s.revenue, digits: 0)}],
      [\$$#{calc.round(s.expenses, digits: 0)}],
      [#s.runway_months months],
      [#s.key_driver],
    )).flatten(),
  )
}

// ============================================================================
// Assumption Table (with confidence and sensitivity)
// ============================================================================

#let assumption-table(assumptions) = {
  table(
    columns: (auto, 1fr, auto, auto, auto),
    align: (center, left, center, center, center),
    table.header(
      [*\#*],
      [*Assumption*],
      [*Value*],
      [*Confidence*],
      [*Sensitivity*],
    ),
    ..assumptions.enumerate().map(((i, a)) => (
      [#str(i + 1)],
      [#a.assumption],
      [#a.value],
      health-badge(a.confidence),
      [#if a.sensitivity == "high" or a.sensitivity == "High" {
        text(fill: health-red, weight: "bold")[High]
      } else if a.sensitivity == "medium" or a.sensitivity == "Medium" {
        text(fill: health-amber, weight: "bold")[Medium]
      } else {
        text(fill: health-green, weight: "bold")[Low]
      }],
    )).flatten(),
  )
}

// ============================================================================
// Monitoring Table
// ============================================================================

#let monitoring-table(metrics) = {
  table(
    columns: (1fr, auto, auto, 1fr),
    align: (left, center, center, left),
    table.header(
      [*Metric*],
      [*Frequency*],
      [*Threshold*],
      [*Action if Triggered*],
    ),
    ..metrics.map(m => (
      [#m.metric],
      [#m.frequency],
      [#m.threshold],
      [#m.action],
    )).flatten(),
  )
}

// ============================================================================
// Red Flag Item
// ============================================================================

#let red-flag-table(flags) = {
  table(
    columns: (auto, auto, 1fr, auto, 1fr),
    align: (center, center, left, center, left),
    table.header(
      [*\#*],
      [*Category*],
      [*Finding*],
      [*Severity*],
      [*Recommendation*],
    ),
    ..flags.enumerate().map(((i, f)) => (
      [#str(i + 1)],
      [#f.category],
      [#f.finding],
      [#if f.severity == "critical" or f.severity == "Critical" {
        text(fill: health-red, weight: "bold")[Critical]
      } else if f.severity == "high" or f.severity == "High" {
        text(fill: health-red.lighten(20%), weight: "bold")[High]
      } else if f.severity == "medium" or f.severity == "Medium" {
        text(fill: health-amber, weight: "bold")[Medium]
      } else {
        text(fill: health-green, weight: "bold")[Low]
      }],
      [#f.recommendation],
    )).flatten(),
  )
}

// ============================================================================
// Example Usage
// ============================================================================

// To use this template:
//
// ```typst
// #import "financial-analysis.typ": *
//
// // Load your JSON data
// #let data = json("financial-metrics.json")
//
// #show: financial-doc.with(
//   title: "Financial Analysis: Acme SaaS",
//   project: "Acme Inc.",
//   date: "Q1 2026",
//   mode: data.metadata.mode,
// )
//
// = Executive Summary
//
// #financial-summary-cards(
//   arr: data.revenue.arr,
//   mrr: data.revenue.mrr,
//   cash-balance: data.cash.balance,
//   runway-months: data.cash.runway_months,
// )
//
// = Revenue Analysis
//
// #revenue-table(data.revenue.metrics)
//
// = Expense Analysis
//
// #expense-table(data.expenses.categories)
//
// = Cash Position
//
// #cash-position-block(data.cash)
//
// = Key Ratios
//
// #ratio-table(data.ratios.items)
//
// = Startup Metrics
//
// #startup-metrics-table(data.startup_metrics.items)
//
// = Verification Results
//
// #verification-matrix(data.verification.items)
//
// = Scenario Analysis
//
// #scenario-comparison(data.scenarios.items)
//
// = Assumptions
//
// #assumption-table(data.assumptions.items)
//
// = Red Flags
//
// #red-flag-table(data.red_flags.items)
//
// = Monitoring Plan
//
// #monitoring-table(data.monitoring.items)
// ```

// ============================================================================
// JSON Data Schema Reference
// ============================================================================

// Expected JSON structure (financial-metrics.json):
// {
//   "metadata": {
//     "project": "Project Name",
//     "date": "2026-03-27",
//     "mode": "REVIEW",
//     "currency": "USD"
//   },
//   "revenue": {
//     "arr": 2400000,
//     "mrr": 200000,
//     "growth_yoy_pct": 85,
//     "top_customer_pct": 12,
//     "recurring_pct": 92,
//     "metrics": [
//       {"metric": "ARR", "value": "$2.4M", "trend": "up", "verification": "verified"}
//     ]
//   },
//   "expenses": {
//     "categories": [
//       {"name": "Personnel", "monthly": 120000, "annual": 1440000, "pct_of_total": 0.72, "trend": "up"}
//     ],
//     "total_monthly": 166000,
//     "total_annual": 1992000
//   },
//   "cash": {
//     "balance": 3200000,
//     "monthly_net_burn": 50000,
//     "gross_burn": 166000,
//     "runway_months": 64
//   },
//   "ratios": {
//     "items": [
//       {"name": "Gross Margin", "value": "72%", "benchmark": "> 70%", "assessment": "healthy"}
//     ]
//   },
//   "startup_metrics": {
//     "items": [
//       {"name": "Rule of 40", "value": "55%", "benchmark": "> 40%", "assessment": "healthy"}
//     ]
//   },
//   "verification": {
//     "items": [
//       {"item": "Revenue", "source1": "P&L: $2.4M", "source2": "Stripe: $2.38M", "source3": "Contracts: $2.4M", "status": "match"}
//     ]
//   },
//   "scenarios": {
//     "items": [
//       {"name": "Upside", "revenue": 3600000, "expenses": 2200000, "runway_months": 36, "key_driver": "Enterprise deal closes"}
//     ]
//   },
//   "assumptions": {
//     "items": [
//       {"assumption": "Revenue growth rate", "value": "85% YoY", "confidence": "healthy", "sensitivity": "high"}
//     ]
//   },
//   "red_flags": {
//     "items": [
//       {"category": "Revenue", "finding": "Top customer is 12% of ARR", "severity": "low", "recommendation": "Monitor concentration"}
//     ]
//   },
//   "monitoring": {
//     "items": [
//       {"metric": "Cash runway", "frequency": "Monthly", "threshold": "< 12 months", "action": "Begin fundraising process"}
//     ]
//   },
//   "documents": {
//     "inventory": [
//       {"name": "P&L", "type": "Statement", "period": "2025", "source": "CFO", "quality": "verified"}
//     ],
//     "completeness": [
//       {"document": "Income statement", "status": "Available", "notes": "Audited"}
//     ]
//   }
// }
