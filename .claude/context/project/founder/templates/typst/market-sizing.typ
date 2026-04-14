// Market Sizing Template for Typst
// Generates professional TAM/SAM/SOM market analysis documents
// Import: #import "strategy-template.typ": *

#import "strategy-template.typ": *

// Market sizing document wrapper
#let market-sizing-doc(
  project: "",
  date: "",
  mode: "SIZE",
  // Key metrics for title page pills
  tam-value: "",
  sam-value: "",
  som-y1-value: "",
  funding-ask: "",
  value-proposition: "",
  // Executive summary content
  summary: "",
  // Market definition
  problem-statement: "",
  target-customer: "",
  customer-dimensions: (),  // Array of (dimension, definition) tuples
  // TAM section
  tam-methodology: "Bottom-Up",
  tam-calculation: "",
  tam-sources: (),  // Array of (source, data-point, confidence) tuples
  tam-breakdown: none,  // Optional breakdown text for nested diagram
  // SAM section
  sam-percent: "",
  narrowing-factors: (),  // Array of (factor, reduction, rationale) tuples
  sam-calculation: "",
  sam-description: "Serviceable market with geographic and segment filters",
  // SOM section
  som-values: (),  // Array of (timeframe, rate, value, rationale) tuples
  competitors: (),  // Array of (name, share, advantage) tuples
  // Revenue model (optional)
  revenue-stages: (),  // Array of (stage, target, pricing, rationale) tuples
  unit-economics: (),  // Array of (metric, b2c, b2b) tuples
  revenue-projections: (),  // Array of (stage, y1, y3, y5, notes) tuples
  // Assumptions
  assumptions: (),  // Array of (assumption, sensitivity, if-wrong) tuples
  // VC checks
  vc-checks: (),  // Array of (criterion, status, notes) tuples
  validation-steps: (),
  // Investor one-pager
  opportunity-summary: "",
  why-now: (),  // Array of strings
  // Appendix content
  appendix-calculations: none,
  appendix-sources: none,
  doc,
) = {
  show: strategy-doc.with(
    title: "Market Sizing Analysis",
    project: project,
    date: date,
    mode: mode,
  )

  // Key metrics pills row (on title page)
  v(1.5em)
  align(center)[
    #metric("TAM", tam-value) #h(0.8em)
    #metric("SAM", sam-value) #h(0.8em)
    #metric("SOM Y1", som-y1-value)
    #if funding-ask != "" [
      #h(0.8em)
      #metric("Funding Ask", funding-ask)
    ]
  ]

  // Value proposition callout
  if value-proposition != "" [
    #v(1.5em)
    #callout[
      *Value Proposition:* #value-proposition
    ]
  ]

  pagebreak()

  // Executive Summary
  heading(level: 1)[Executive Summary]
  executive-summary[#summary]

  // Key metrics row (large callouts)
  v(1em)
  metric-row(
    (label: "TAM", value: tam-value),
    (label: "SAM", value: sam-value, subtitle: sam-percent + " of TAM"),
    (label: "SOM Y1", value: som-y1-value),
  )

  // Market Definition
  heading(level: 1)[Market Definition]

  heading(level: 2)[Problem Statement]
  problem-statement

  heading(level: 2)[Target Customer]
  target-customer

  if customer-dimensions.len() > 0 [
    #strategy-table(
      columns: (auto, 1fr),
      header: ("Dimension", "Definition"),
      ..customer-dimensions.map(d => (d.dimension, d.definition)),
    )
  ]

  // TAM Section
  heading(level: 1)[TAM: Total Addressable Market]

  metric-callout("Total Addressable Market", tam-value)

  heading(level: 2)[Methodology: #tam-methodology]
  tam-calculation

  if tam-sources.len() > 0 [
    #heading(level: 2)[Data Sources]
    #strategy-table(
      columns: (1fr, 1fr, auto),
      header: ("Source", "Data Point", "Confidence"),
      ..tam-sources.map(s => (s.source, s.data-point, s.confidence)),
    )
  ]

  // SAM Section
  heading(level: 1)[SAM: Serviceable Available Market]

  metric-callout("Serviceable Available Market", sam-value, subtitle: sam-percent + " of TAM")

  if narrowing-factors.len() > 0 [
    #heading(level: 2)[Narrowing Factors]
    #strategy-table(
      columns: (auto, auto, 1fr),
      header: ("Factor", "TAM Reduction", "Rationale"),
      ..narrowing-factors.map(f => (f.factor, f.reduction, f.rationale)),
    )
  ]

  heading(level: 2)[Calculation]
  sam-calculation

  // SOM Section
  heading(level: 1)[SOM: Serviceable Obtainable Market]

  if som-values.len() > 0 [
    #heading(level: 2)[Capture Rate Assumptions]
    #strategy-table(
      columns: (auto, auto, auto, 1fr),
      header: ("Timeframe", "Capture Rate", "SOM Value", "Rationale"),
      ..som-values.map(s => (s.timeframe, s.rate, s.value, s.rationale)),
    )
  ]

  if competitors.len() > 0 [
    #heading(level: 2)[Competitive Context]
    #strategy-table(
      columns: (auto, auto, 1fr),
      header: ("Competitor", "Est. Market Share", "Your Advantage"),
      ..competitors.map(c => (c.name, c.share, c.advantage)),
    )
  ]

  // Market Visualization (professional nested boxes)
  heading(level: 1)[Market Visualization]

  // Build SOM years array if we have som-values
  let som-years-arr = if som-values.len() > 0 {
    som-values.map(s => ([#s.timeframe:], [#s.value]))
  } else { none }

  nested-market-diagram(
    tam: tam-value,
    sam: sam-value,
    som: if som-values.len() > 0 { som-values.at(0).value } else { som-y1-value },
    tam-breakdown: tam-breakdown,
    sam-description: sam-description,
    som-years: som-years-arr,
  )

  // Revenue Model (optional section)
  if revenue-stages.len() > 0 [
    #heading(level: 1)[Revenue Model]

    #heading(level: 2)[Business Model Stages]
    #strategy-table(
      columns: (auto, auto, auto, 1fr),
      header: ("Stage", "Target", "Pricing", "Rationale"),
      ..revenue-stages.map(s => (s.stage, s.target, s.pricing, s.rationale)),
    )

    #if unit-economics.len() > 0 [
      #heading(level: 2)[Unit Economics]
      #strategy-table(
        columns: (auto, auto, auto),
        header: ("Metric", "B2C", "B2B"),
        ..unit-economics.map(u => (u.metric, u.b2c, u.b2b)),
      )
    ]

    #if revenue-projections.len() > 0 [
      #heading(level: 2)[Revenue Projections]
      #strategy-table(
        columns: (auto, auto, auto, auto, 1fr),
        header: ("Stage", "Year 1", "Year 3", "Year 5", "Notes"),
        ..revenue-projections.map(r => (r.stage, r.y1, r.y3, r.y5, r.notes)),
      )
    ]
  ]

  // Key Assumptions
  if assumptions.len() > 0 [
    #heading(level: 1)[Key Assumptions]
    #strategy-table(
      columns: (auto, 1fr, auto, 1fr),
      header: ("#", "Assumption", "Sensitivity", "If Wrong"),
      ..assumptions.enumerate().map(((i, a)) => (str(i + 1), a.assumption, a.sensitivity, a.if-wrong)),
    )
  ]

  // Red Flags & Validation
  heading(level: 1)[Red Flags & Validation]

  if vc-checks.len() > 0 [
    #heading(level: 2)[VC Threshold Check]
    #strategy-table(
      columns: (1fr, auto, 1fr),
      header: ("Criterion", "Status", "Notes"),
      ..vc-checks.map(c => (c.criterion, c.status, c.notes)),
    )
  ]

  if validation-steps.len() > 0 [
    #heading(level: 2)[Validation Next Steps]
    #for (i, step) in validation-steps.enumerate() [
      + #step
    ]
  ]

  // Investor One-Pager
  heading(level: 1)[Investor One-Pager]

  highlight-box(title: "The Opportunity")[
    #opportunity-summary
  ]

  heading(level: 2)[Key Numbers]
  list(
    [*TAM:* #tam-value],
    [*SAM:* #sam-value (#sam-percent)],
    ..som-values.map(s => [*SOM #s.timeframe:* #s.value]),
  )

  if why-now.len() > 0 [
    #heading(level: 2)[Why This Market, Why Now]
    #for point in why-now [
      - #point
    ]
  ]

  // Appendices
  if appendix-calculations != none [
    #appendix(title: "Appendix: Detailed Calculations")[
      #appendix-calculations
    ]
  ]

  if appendix-sources != none [
    #appendix(title: "Appendix: Source Links")[
      #appendix-sources
    ]
  ]

  doc
}
