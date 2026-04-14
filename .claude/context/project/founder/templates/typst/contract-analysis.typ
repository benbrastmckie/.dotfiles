// Contract Analysis Report Template
// Professional template for legal contract review and negotiation analysis
// Uses: strategy-template.typ base styles
// Output: PDF contract analysis reports

#import "strategy-template.typ": *

// ============================================================================
// Document Entry Point
// ============================================================================

#let contract-analysis-doc(
  title: "Contract Analysis Report",
  project: "",
  date: "",
  mode: "REVIEW",
  contract-type: "",
  doc,
) = {
  strategy-doc(
    title: title,
    project: project,
    date: date,
    mode: mode,
    doc,
  )
}

// ============================================================================
// Risk Level Badge
// ============================================================================

#let risk-badge(level) = {
  let (bg, fg) = if level == "Critical" {
    (rgb("#dc2626"), white)
  } else if level == "High" {
    (rgb("#ea580c"), white)
  } else if level == "Medium" {
    (rgb("#ca8a04"), white)
  } else {
    (rgb("#16a34a"), white)
  }
  box(
    fill: bg,
    radius: 3pt,
    inset: (x: 0.5em, y: 0.2em),
  )[
    #text(fill: fg, size: 8pt, weight: "bold")[#level]
  ]
}

// ============================================================================
// Contract Parties Table
// ============================================================================

#let parties-table(parties) = {
  table(
    columns: (1fr, 1fr, 2fr),
    table.header([*Party*], [*Role*], [*Notes*]),
    ..parties.map(p => (p.name, p.role, p.notes)).flatten(),
  )
}

// ============================================================================
// Key Terms Summary
// ============================================================================

#let key-terms-summary(terms) = {
  table(
    columns: (1.2fr, 1fr, 1.5fr),
    table.header([*Term*], [*Value*], [*Assessment*]),
    ..terms.map(t => (t.term, t.value, t.assessment)).flatten(),
  )
}

// ============================================================================
// Clause Analysis Table
// ============================================================================

#let clause-analysis-table(clauses) = {
  table(
    columns: (1.2fr, auto, 2fr, 2fr),
    fill: (x, y) => {
      if y == 0 { fill-header }
      else {
        let risk = clauses.at(y - 1).at("risk", default: "Low")
        if risk == "Critical" { rgb("#fef2f2") }
        else if risk == "High" { rgb("#fff7ed") }
        else if risk == "Medium" { rgb("#fefce8") }
        else if calc.odd(y) { fill-alt-row }
        else { white }
      }
    },
    table.header([*Section*], [*Risk*], [*Issue*], [*Recommendation*]),
    ..clauses.map(c => (
      c.section,
      risk-badge(c.risk),
      c.issue,
      c.recommendation,
    )).flatten(),
  )
}

// ============================================================================
// Risk Matrix Visualization
// ============================================================================

#let risk-matrix(must-fix: (), negotiate: (), monitor: (), accept: ()) = {
  rect(
    width: 100%,
    inset: 16pt,
    stroke: 0.5pt + border-light,
    radius: 4pt,
  )[
    #align(center)[
      #text(weight: "bold", size: 11pt, fill: navy-dark)[Risk Assessment Matrix]
      #v(0.5em)
      #grid(
        columns: (auto, 1fr, 1fr),
        rows: (auto, auto, auto),
        gutter: 2pt,
        // Row labels
        [],
        align(center)[#text(size: 9pt, fill: text-muted)[Low Severity]],
        align(center)[#text(size: 9pt, fill: text-muted)[High Severity]],

        // High likelihood row
        rotate(-90deg, reflow: true)[#text(size: 9pt, fill: text-muted)[High Likelihood]],
        rect(fill: rgb("#fef9c3"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#854d0e"))[NEGOTIATE]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in negotiate [
            - #item
          ]
        ],
        rect(fill: rgb("#fef2f2"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#dc2626"))[MUST FIX]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in must-fix [
            - #item
          ]
        ],

        // Low likelihood row
        rotate(-90deg, reflow: true)[#text(size: 9pt, fill: text-muted)[Low Likelihood]],
        rect(fill: rgb("#f0fdf4"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#16a34a"))[ACCEPT]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in accept [
            - #item
          ]
        ],
        rect(fill: rgb("#eff6ff"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#1d4ed8"))[MONITOR]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in monitor [
            - #item
          ]
        ],
      )
    ]
  ]
}

// ============================================================================
// BATNA Analysis Block
// ============================================================================

#let batna-block(your-batna: (), their-batna: (), bottom-line: "") = {
  comparison-block(
    left-title: "Your BATNA",
    right-title: "Their Likely BATNA",
    [
      #for alt in your-batna [
        - #alt.description #if alt.at("value", default: none) != none [- Value: #alt.value]
      ]
      #v(0.5em)
      #text(weight: "bold")[Bottom Line:]
      #bottom-line
    ],
    [
      #for alt in their-batna [
        - #alt.description
        #if alt.at("implication", default: none) != none [
          #text(size: 9pt, style: "italic")[ (#alt.implication)]
        ]
      ]
    ],
  )
}

// ============================================================================
// ZOPA Table
// ============================================================================

#let zopa-table(dimensions) = {
  table(
    columns: (1.5fr, 1fr, 1fr, auto),
    fill: (x, y) => {
      if y == 0 { fill-header }
      else {
        let has-zopa = dimensions.at(y - 1).at("zopa", default: "Unclear")
        if has-zopa == "Yes" { rgb("#f0fdf4") }
        else if has-zopa == "No" { rgb("#fef2f2") }
        else if calc.odd(y) { fill-alt-row }
        else { white }
      }
    },
    table.header([*Dimension*], [*Your Minimum*], [*Their Minimum*], [*ZOPA?*]),
    ..dimensions.map(d => (
      d.dimension,
      d.your-min,
      d.their-min,
      if d.zopa == "Yes" { text(fill: rgb("#16a34a"), weight: "bold")[Yes] }
      else if d.zopa == "No" { text(fill: rgb("#dc2626"), weight: "bold")[No] }
      else { text(fill: text-muted)[Unclear] },
    )).flatten(),
  )
}

// ============================================================================
// Trade-Off Table
// ============================================================================

#let tradeoff-table(trades) = {
  table(
    columns: (1fr, 1fr),
    fill: (x, y) => {
      if y == 0 { fill-header }
      else if x == 0 { rgb("#fef2f2") }
      else { rgb("#f0fdf4") }
    },
    table.header([*Give (Lower Priority)*], [*Get (Higher Priority)*]),
    ..trades.map(t => (t.give, t.get)).flatten(),
  )
}

// ============================================================================
// Modification Table
// ============================================================================

#let modification-table(priority: "Must-Have", modifications: ()) = {
  let header-color = if priority == "Must-Have" { rgb("#dc2626") }
    else if priority == "Should-Have" { rgb("#ea580c") }
    else { rgb("#16a34a") }

  rect(
    width: 100%,
    stroke: (left: 3pt + header-color),
    fill: fill-alt-row,
    inset: 12pt,
    radius: (right: 4pt),
  )[
    #text(weight: "bold", fill: header-color, size: 11pt)[#priority Changes]
    #v(0.5em)
    #table(
      columns: (1.5fr, 1.5fr, 1fr),
      table.header([*Current*], [*Proposed*], [*Rationale*]),
      ..modifications.map(m => (
        text(style: "italic")[#m.current],
        text(weight: "medium")[#m.proposed],
        m.rationale,
      )).flatten(),
    )
  ]
}

// ============================================================================
// Walk-Away Conditions
// ============================================================================

#let walkaway-conditions(conditions) = {
  warning-box(
    title: "Walk-Away Conditions",
    [
      Do not proceed if any of the following exist:
      #v(0.3em)
      #for (i, cond) in conditions.enumerate() [
        #text(weight: "bold")[#(i + 1).] #cond
        #v(0.2em)
      ]
    ],
  )
}

// ============================================================================
// Action Items Table
// ============================================================================

#let action-items-table(items) = {
  table(
    columns: (auto, 2fr, 1fr, 1fr),
    fill: (x, y) => {
      if y == 0 { fill-header }
      else {
        let priority = items.at(y - 1).at("priority", default: 5)
        if priority <= 2 { rgb("#fef2f2") }
        else if priority <= 3 { rgb("#fefce8") }
        else if calc.odd(y) { fill-alt-row }
        else { white }
      }
    },
    table.header([*P*], [*Action*], [*Owner*], [*Deadline*]),
    ..items.map(i => (
      str(i.priority),
      i.action,
      i.owner,
      i.deadline,
    )).flatten(),
  )
}

// ============================================================================
// Escalation Recommendation Block
// ============================================================================

#let escalation-block(level: "Self-serve", rationale: "", focus-areas: none, budget: none, timeline: none) = {
  let (bg, border-color, icon) = if level == "Attorney required" {
    (rgb("#fef2f2"), rgb("#dc2626"), "!")
  } else if level == "Attorney review" {
    (rgb("#fff7ed"), rgb("#ea580c"), "?")
  } else {
    (rgb("#f0fdf4"), rgb("#16a34a"), "v")
  }

  rect(
    width: 100%,
    stroke: (left: 3pt + border-color),
    fill: bg,
    inset: 12pt,
    radius: (right: 4pt),
  )[
    #text(weight: "bold", fill: border-color, size: 12pt)[Escalation: #level]
    #v(0.5em)
    #text[#rationale]
    #if focus-areas != none [
      #v(0.5em)
      #text(weight: "bold")[Focus Areas:]
      #for area in focus-areas [
        - #area
      ]
    ]
    #if budget != none or timeline != none [
      #v(0.5em)
      #grid(
        columns: (auto, auto),
        column-gutter: 2em,
        if budget != none [#text(weight: "bold")[Budget:] #budget],
        if timeline != none [#text(weight: "bold")[Timeline:] #timeline],
      )
    ]
  ]
}

// ============================================================================
// Detailed Clause Analysis Block
// ============================================================================

#let clause-detail(section: "", current-language: "", risk: "Low", issue: "", recommendation: "") = {
  rect(
    width: 100%,
    stroke: 0.5pt + border-light,
    fill: fill-alt-row,
    inset: 12pt,
    radius: 4pt,
  )[
    #grid(
      columns: (1fr, auto),
      [#text(weight: "bold", size: 11pt, fill: navy-dark)[#section]],
      risk-badge(risk),
    )
    #v(0.5em)
    #rect(
      width: 100%,
      fill: white,
      inset: 8pt,
      radius: 2pt,
    )[
      #text(size: 9pt, style: "italic")[#current-language]
    ]
    #v(0.5em)
    #text(weight: "bold", fill: navy-medium)[Issue:]
    #text[#issue]
    #v(0.3em)
    #text(weight: "bold", fill: navy-medium)[Recommendation:]
    #text[#recommendation]
  ]
}
