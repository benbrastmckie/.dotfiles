// Go-to-Market Strategy Template for Typst
// Generates professional GTM strategy documents
// Import: #import "strategy-template.typ": *

#import "strategy-template.typ": *

// GTM strategy document wrapper
#let gtm-strategy-doc(
  project: "",
  date: "",
  mode: "LAUNCH",
  // Executive summary
  summary: "",
  // Positioning
  positioning-statement: (
    target: "",
    problem: "",
    product: "",
    category: "",
    benefit: "",
    competitor: "",
    differentiator: "",
  ),
  positioning-breakdown: (),  // Array of (element, definition, rationale) tuples
  messaging: (),  // Array of (level, message, use-case) tuples
  // Target customer
  persona: (),  // Dictionary with persona attributes
  day-in-life: "",
  pain-points: (),  // Array of (pain, severity, current, why-better) tuples
  // Channel strategy
  channel-assessment: (),  // Array of (channel, cac, scalability, time, fit) tuples
  channel-priorities: (),  // Array of (priority, channel, rationale, investment) tuples
  channels-skip: (),  // Array of (channel, reason, revisit) tuples
  // Launch strategy
  launch-types: (),  // Array of (type, description, fit) tuples
  selected-launch: "",
  launch-rationale: "",
  launch-checklist: (),  // Array of (category, item, status, owner, due) tuples
  launch-timeline: (),  // Array of (week, milestone) tuples
  // 90-day plan
  phases: (),  // Array of phase objects with weeks
  // Metrics
  north-star: "",
  north-star-why: (),  // Array of strings
  dashboard: (),  // Array of (category, metric, current, target-30, target-90) tuples
  leading-indicators: (),  // Array of (leading, lagging, lead-time) tuples
  // Risks
  risks: (),  // Array of (risk, likelihood, impact, mitigation, owner) tuples
  // Observations
  observations: "",
  // Next steps
  immediate-steps: (),
  near-term-steps: (),
  dependencies: (),  // Array of (item, depends-on, owner, due) tuples
  doc,
) = {
  show: strategy-doc.with(
    title: "Go-to-Market Strategy",
    project: project,
    date: date,
    mode: mode,
  )

  // Executive Summary
  heading(level: 1)[Executive Summary]
  executive-summary[#summary]

  // Positioning
  heading(level: 1)[Positioning]

  heading(level: 2)[Positioning Statement]
  callout[
    #text(size: 12pt)[
      *For* #positioning-statement.target \
      *who* #positioning-statement.problem, \
      *#positioning-statement.product* is a #positioning-statement.category \
      *that* #positioning-statement.benefit. \
      *Unlike* #positioning-statement.competitor, \
      *we* #positioning-statement.differentiator.
    ]
  ]

  if positioning-breakdown.len() > 0 [
    #heading(level: 2)[Positioning Breakdown]
    #strategy-table(
      columns: (auto, 1fr, 1fr),
      header: ("Element", "Definition", "Rationale"),
      ..positioning-breakdown.map(p => ([*#p.element*], p.definition, p.rationale)),
    )
  ]

  if messaging.len() > 0 [
    #heading(level: 2)[Messaging Hierarchy]
    #strategy-table(
      columns: (auto, 1fr, 1fr),
      header: ("Level", "Message", "Use Case"),
      ..messaging.map(m => ([*#m.level*], m.message, m.use-case)),
    )
  ]

  // Target Customer
  heading(level: 1)[Target Customer]

  heading(level: 2)[Primary Persona]
  if persona.len() > 0 [
    #strategy-table(
      columns: (auto, 1fr),
      header: ("Attribute", "Definition"),
      ..persona.pairs().map(p => ([*#p.at(0)*], p.at(1))),
    )
  ]

  if day-in-life != "" [
    #heading(level: 2)[Day in the Life]
    #day-in-life
  ]

  if pain-points.len() > 0 [
    #heading(level: 2)[Pain Points]
    #strategy-table(
      columns: (1fr, auto, 1fr, 1fr),
      header: ("Pain Point", "Severity", "Current Solution", "Why Ours is Better"),
      ..pain-points.map(p => (p.pain, p.severity, p.current, p.why-better)),
    )
  ]

  // Channel Strategy
  heading(level: 1)[Channel Strategy]

  if channel-assessment.len() > 0 [
    #heading(level: 2)[Channel Assessment]
    #strategy-table(
      columns: (1fr, auto, auto, auto, auto),
      header: ("Channel", "CAC Est.", "Scalability", "Time to Results", "Fit Score"),
      ..channel-assessment.map(c => ([*#c.channel*], c.cac, c.scalability, c.time, c.fit)),
    )
  ]

  if channel-priorities.len() > 0 [
    #heading(level: 2)[Channel Prioritization]
    #strategy-table(
      columns: (auto, auto, 1fr, auto),
      header: ("Priority", "Channel", "Rationale", "Investment"),
      ..channel-priorities.map(c => ([*#c.priority*], c.channel, c.rationale, c.investment)),
    )
  ]

  if channels-skip.len() > 0 [
    #heading(level: 2)[Channels NOT Pursuing]
    #strategy-table(
      columns: (auto, 1fr, auto),
      header: ("Channel", "Reason to Skip", "Revisit When"),
      ..channels-skip.map(c => (c.channel, c.reason, c.revisit)),
    )
  ]

  // Launch Strategy
  heading(level: 1)[Launch Strategy]

  if launch-types.len() > 0 [
    #heading(level: 2)[Launch Type]
    #strategy-table(
      columns: (auto, 1fr, auto),
      header: ("Type", "Description", "Our Fit"),
      ..launch-types.map(l => ([*#l.type*], l.description, l.fit)),
    )

    #v(0.5em)
    #highlight-box(title: "Selected: " + selected-launch)[
      #launch-rationale
    ]
  ]

  if launch-checklist.len() > 0 [
    #heading(level: 2)[Launch Checklist]
    #strategy-table(
      columns: (auto, 1fr, auto, auto, auto),
      header: ("Category", "Item", "Status", "Owner", "Due"),
      ..launch-checklist.map(l => ([*#l.category*], l.item, l.status, l.owner, l.due)),
    )
  ]

  if launch-timeline.len() > 0 [
    #heading(level: 2)[Launch Timeline]
    #timeline(
      phases: launch-timeline.map(l => (
        name: l.week,
        description: l.milestone,
        complete: l.at("complete", default: false),
      )),
    )
  ]

  // 90-Day Plan
  heading(level: 1)[90-Day Plan]

  for phase in phases [
    #heading(level: 2)[Phase #phase.number: Days #phase.days - #phase.name]

    #highlight-box(title: "Goal")[#phase.goal]

    #if phase.at("weeks", default: ()).len() > 0 [
      #strategy-table(
        columns: (auto, 1fr, 1fr, auto),
        header: ("Week", "Focus", "Key Activities", "Success Metric"),
        ..phase.weeks.map(w => (w.week, w.focus, w.activities, w.metric)),
      )
    ]

    #v(0.5em)
    *Exit Criteria:* #phase.at("exit-criteria", default: "TBD")

    #section-divider()
  ]

  // Metrics & KPIs
  heading(level: 1)[Metrics & KPIs]

  heading(level: 2)[North Star Metric]
  metric-callout("North Star", north-star)

  if north-star-why.len() > 0 [
    #v(0.5em)
    *Why This Metric:*
    #for reason in north-star-why [
      - #reason
    ]
  ]

  if dashboard.len() > 0 [
    #heading(level: 2)[Dashboard]
    #strategy-table(
      columns: (auto, 1fr, auto, auto, auto),
      header: ("Category", "Metric", "Current", "30-Day Target", "90-Day Target"),
      ..dashboard.map(d => ([*#d.category*], d.metric, d.current, d.target-30, d.target-90)),
    )
  ]

  if leading-indicators.len() > 0 [
    #heading(level: 2)[Leading Indicators]
    #strategy-table(
      columns: (1fr, 1fr, auto),
      header: ("Leading Indicator", "Lagging Outcome", "Lead Time"),
      ..leading-indicators.map(l => (l.leading, l.lagging, l.lead-time)),
    )
  ]

  // Risks & Mitigations
  if risks.len() > 0 [
    #heading(level: 1)[Risks & Mitigations]
    #strategy-table(
      columns: (1fr, auto, auto, 1fr, auto),
      header: ("Risk", "Likelihood", "Impact", "Mitigation", "Owner"),
      ..risks.map(r => (r.risk, r.likelihood, r.impact, r.mitigation, r.owner)),
    )
  ]

  // What I Noticed
  if observations != "" [
    #heading(level: 1)[What I Noticed]
    #text(style: "italic")[#observations]
  ]

  // Next Steps
  heading(level: 1)[Next Steps]

  if immediate-steps.len() > 0 [
    #heading(level: 2)[Immediate (This Week)]
    #for (i, step) in immediate-steps.enumerate() [
      + #step
    ]
  ]

  if near-term-steps.len() > 0 [
    #heading(level: 2)[Near-Term (30 Days)]
    #for (i, step) in near-term-steps.enumerate() [
      + #step
    ]
  ]

  if dependencies.len() > 0 [
    #heading(level: 2)[Dependencies]
    #strategy-table(
      columns: (1fr, 1fr, auto, auto),
      header: ("Item", "Depends On", "Owner", "Due"),
      ..dependencies.map(d => (d.item, d.depends-on, d.owner, d.due)),
    )
  ]

  doc
}
