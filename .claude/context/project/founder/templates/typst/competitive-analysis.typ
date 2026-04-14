// Competitive Analysis Template for Typst
// Generates professional competitive landscape and positioning documents
// Import: #import "strategy-template.typ": *

#import "strategy-template.typ": *

// Competitive analysis document wrapper
#let competitive-analysis-doc(
  project: "",
  date: "",
  mode: "LANDSCAPE",
  // Executive summary
  summary: "",
  // Landscape
  categories: (),  // Array of (category, description, players) tuples
  status-quo: "",
  // Competitor profiles (array of competitor objects)
  competitors: (),
  // Feature comparison
  features: (),  // Array of feature names
  feature-matrix: (),  // Array of (feature, us, comp1, comp2, comp3) tuples
  // Positioning
  x-axis: "",
  x-axis-rationale: "",
  y-axis: "",
  y-axis-rationale: "",
  positioning-quadrants: (
    top-left: [],
    top-right: [],
    bottom-left: [],
    bottom-right: [],
  ),
  white-spaces: (),  // Array of strings
  white-space-recommendation: "",
  // Battle cards
  battle-cards: (),  // Array of battle card objects
  // Strategic implications
  attack-opportunities: (),  // Array of (opportunity, approach, impact) tuples
  defend-priorities: (),  // Array of (threat, response, priority) tuples
  ignore-battles: (),  // Array of (battle, reason) tuples
  differentiation: "",
  // Observations
  observations: "",
  // Next steps
  next-steps: (),
  doc,
) = {
  show: strategy-doc.with(
    title: "Competitive Analysis",
    project: project,
    date: date,
    mode: mode,
  )

  // Executive Summary
  heading(level: 1)[Executive Summary]
  executive-summary[#summary]

  // Competitive Landscape
  heading(level: 1)[Competitive Landscape]

  if categories.len() > 0 [
    #heading(level: 2)[Categories]
    #strategy-table(
      columns: (auto, 1fr, 1fr),
      header: ("Category", "Description", "Key Players"),
      ..categories.map(c => ([*#c.category*], c.description, c.players)),
    )
  ]

  heading(level: 2)[Status Quo]
  highlight-box(title: "Current Solution")[
    #status-quo

    #v(0.5em)
    #text(style: "italic", size: 10pt, fill: text-muted)[
      This is your real competitor. Every other competitor is fighting for share of customers who have already decided to switch from status quo.
    ]
  ]

  // Competitor Profiles
  if competitors.len() > 0 [
    #heading(level: 1)[Competitor Profiles]

    #for comp in competitors [
      #heading(level: 2)[#comp.name]

      #strategy-table(
        columns: (auto, 1fr),
        header: ("Dimension", "Assessment"),
        ([*Category*], comp.at("category", default: "Direct")),
        ([*Positioning*], [_"#comp.at("positioning", default: "")"_]),
        ([*Target Customer*], comp.at("target", default: "")),
        ([*Pricing*], comp.at("pricing", default: "")),
        ([*Founded*], comp.at("founded", default: "")),
        ([*Funding*], comp.at("funding", default: "")),
        ([*Team Size*], comp.at("team-size", default: "")),
        ([*Key Customers*], comp.at("customers", default: "")),
      )

      #v(0.5em)
      #competitor-card(
        name: comp.name,
        category: comp.at("category", default: "Direct"),
        positioning: comp.at("positioning", default: ""),
        strengths: comp.at("strengths", default: ()),
        weaknesses: comp.at("weaknesses", default: ()),
        pricing: comp.at("pricing", default: ""),
      )

      #if comp.at("recent-moves", default: ()).len() > 0 [
        #v(0.5em)
        *Recent Moves* (last 6 months):
        #for move in comp.recent-moves [
          - #move
        ]
      ]

      #section-divider()
    ]
  ]

  // Feature Comparison
  if feature-matrix.len() > 0 [
    #heading(level: 1)[Feature Comparison]

    #let comp-count = calc.min(competitors.len(), 3)
    #let header-row = ("Feature", "Us", ..competitors.slice(0, comp-count).map(c => c.name))
    #comparison-table(
      columns: header-row.len(),
      header: header-row,
      ..feature-matrix.map(row => row),
    )

    #v(0.5em)
    #text(size: 10pt, fill: text-muted)[
      *Legend:* [check] = Yes, [x] = No, ~ = Partial, ? = Unknown
    ]
  ]

  // Positioning Map
  heading(level: 1)[Positioning Map]

  heading(level: 2)[Axis Selection]
  strategy-table(
    columns: (auto, 1fr),
    header: ("Axis", "Rationale"),
    ([*X-Axis:* #x-axis], x-axis-rationale),
    ([*Y-Axis:* #y-axis], y-axis-rationale),
  )

  heading(level: 2)[2x2 Map]
  positioning-map(
    x-axis: x-axis,
    y-axis: y-axis,
    quadrants: positioning-quadrants,
  )

  if white-spaces.len() > 0 [
    #heading(level: 2)[White Space Analysis]

    *Identified White Spaces:*
    #for (i, ws) in white-spaces.enumerate() [
      + #ws
    ]

    #v(0.5em)
    #highlight-box(title: "Recommendation")[
      #white-space-recommendation
    ]
  ]

  // Battle Cards
  if battle-cards.len() > 0 [
    #heading(level: 1)[Battle Cards]

    #for card in battle-cards [
      #battle-card(
        competitor: card.competitor,
        their-pitch: card.at("their-pitch", default: ""),
        our-response: card.at("our-response", default: ""),
        objections: card.at("objections", default: ()),
        win-signals: card.at("win-signals", default: ()),
        lose-signals: card.at("lose-signals", default: ()),
      )
      #v(1em)
    ]
  ]

  // Strategic Implications
  heading(level: 1)[Strategic Implications]

  if attack-opportunities.len() > 0 [
    #heading(level: 2)[Attack]
    *Where can we win directly?*

    #strategy-table(
      columns: (1fr, 1fr, auto),
      header: ("Opportunity", "Approach", "Expected Impact"),
      ..attack-opportunities.map(a => (a.opportunity, a.approach, a.impact)),
    )
  ]

  if defend-priorities.len() > 0 [
    #heading(level: 2)[Defend]
    *Where must we match competitors?*

    #strategy-table(
      columns: (1fr, 1fr, auto),
      header: ("Threat", "Response", "Priority"),
      ..defend-priorities.map(d => (d.threat, d.response, d.priority)),
    )
  ]

  if ignore-battles.len() > 0 [
    #heading(level: 2)[Ignore]
    *What battles aren't worth fighting?*

    #strategy-table(
      columns: (auto, 1fr),
      header: ("Battle", "Why Ignore"),
      ..ignore-battles.map(i => (i.battle, i.reason)),
    )
  ]

  heading(level: 2)[Differentiate]
  highlight-box(title: "What Makes Us Categorically Different")[
    #differentiation
  ]

  // What I Noticed
  if observations != "" [
    #heading(level: 1)[What I Noticed]
    #text(style: "italic")[#observations]
  ]

  // Next Steps
  if next-steps.len() > 0 [
    #heading(level: 1)[Next Steps]
    #for (i, step) in next-steps.enumerate() [
      + #step
    ]
  ]

  doc
}
