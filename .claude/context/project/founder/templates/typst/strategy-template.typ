// Founder Strategy Template
// Professional template for strategy documents
// Used by: market-sizing.typ, competitive-analysis.typ, gtm-strategy.typ
// Style: Navy gradient palette with Libertinus Serif typography

// ============================================================================
// Professional Color Palette
// ============================================================================

#let navy-dark = rgb("#0a2540")
#let navy-medium = rgb("#1a4a7a")
#let navy-light = rgb("#2a5a9a")
#let text-primary = rgb("#1a1a1a")
#let text-muted = rgb("#888888")
#let text-light = rgb("#aaaaaa")
#let fill-header = rgb("#e8eef5")
#let fill-alt-row = rgb("#f8f9fb")
#let fill-callout = rgb("#e8f0fb")
#let fill-warning = rgb("#fff8e8")
#let border-light = rgb("#cccccc")
#let border-warning = rgb("#c87800")

// ============================================================================
// Document Setup
// ============================================================================

#let strategy-doc(
  title: "",
  project: "",
  date: "",
  mode: "",
  doc,
) = {
  // Page setup with professional header/footer
  set page(
    paper: "us-letter",
    margin: (top: 1.1in, bottom: 1.0in, left: 1.1in, right: 1.1in),
    header: context {
      if counter(page).get().first() > 1 [
        #set text(size: 8pt, fill: text-muted)
        #grid(
          columns: (1fr, auto),
          [#project - #title],
          align(right)[#counter(page).display()],
        )
        #line(length: 100%, stroke: 0.4pt + border-light)
      ]
    },
    footer: context {
      set text(size: 7.5pt, fill: text-light)
      align(center)[Confidential - #project #sym.dot #date]
    },
  )

  // Typography - Libertinus Serif with fallback chain
  set text(
    font: ("Libertinus Serif", "Linux Libertine", "Georgia"),
    size: 10.5pt,
    fill: text-primary,
    hyphenate: false,
  )

  set par(
    justify: true,
    leading: 0.65em,
    spacing: 0.85em,
  )

  // Heading styles with colored underlines (no numbering)
  show heading.where(level: 1): it => {
    v(1.4em)
    block[
      #set text(size: 16pt, weight: "bold", fill: navy-dark)
      #it.body
      #v(0.15em)
      #line(length: 100%, stroke: 1.5pt + navy-dark)
    ]
    v(0.5em)
  }

  show heading.where(level: 2): it => {
    v(1.1em)
    block[
      #set text(size: 13pt, weight: "bold", fill: navy-medium)
      #it.body
      #v(0.1em)
      #line(length: 100%, stroke: 0.7pt + navy-medium)
    ]
    v(0.35em)
  }

  show heading.where(level: 3): it => {
    v(0.9em)
    block[
      #set text(size: 11pt, weight: "bold", fill: navy-light)
      #it.body
    ]
    v(0.25em)
  }

  // Block quote style
  show quote: it => {
    pad(left: 1.4em)[
      #line(start: (-1.4em, 0pt), length: 3pt, stroke: 2.5pt + navy-medium)
      #set text(style: "italic", fill: rgb("#333333"))
      #it
    ]
  }

  // Table styling with alternating rows and header emphasis
  set table(
    stroke: (x, y) => {
      if y == 0 { (bottom: 1.2pt + navy-medium) }
      else { (bottom: 0.4pt + border-light) }
    },
    fill: (x, y) => {
      if y == 0 { fill-header }
      else if calc.odd(y) { fill-alt-row }
      else { white }
    },
    inset: (x: 0.7em, y: 0.55em),
  )

  show table: it => {
    set text(size: 9.5pt)
    it
  }

  // Title page
  v(2em)
  align(center)[
    #block[
      #set text(size: 22pt, weight: "bold", fill: navy-dark)
      #title
    ]
    #v(0.3em)
    #block[
      #set text(size: 14pt, weight: "regular", fill: navy-medium)
      #project
    ]
    #v(1.2em)
    #line(length: 60%, stroke: 1.5pt + navy-dark)
    #v(1.2em)
    #grid(
      columns: (auto, auto),
      column-gutter: 2em,
      row-gutter: 0.5em,
      align: (right, left),
      strong[Date:], [#date],
      strong[Mode:], [#mode],
      strong[Prepared by:], [Claude],
    )
    #v(1fr)
    #text(size: 10pt, fill: text-light)[Confidential - Internal Use Only]
  ]

  pagebreak()

  doc
}

// ============================================================================
// Metric Pill (inline compact display)
// ============================================================================

#let metric(label, value) = box(
  fill: navy-dark,
  radius: 3pt,
  inset: (x: 0.6em, y: 0.3em),
)[
  #set text(fill: white, size: 9pt)
  #strong[#label:] #value
]

// ============================================================================
// Callout Box (flexible left-bordered box)
// ============================================================================

#let callout(body, color: fill-callout, border: navy-medium) = block(
  fill: color,
  stroke: (left: 3pt + border),
  radius: (right: 4pt),
  inset: (x: 1em, y: 0.7em),
  width: 100%,
  body,
)

// ============================================================================
// Comparison Block (dark navy side-by-side)
// ============================================================================

#let comparison-block(left-content, right-content, left-title: "", right-title: "") = block(
  fill: navy-dark,
  radius: 6pt,
  inset: (x: 1.4em, y: 1.0em),
  width: 100%,
)[
  #set text(fill: white, size: 10pt)
  #grid(
    columns: (0.5fr, 0.5fr),
    column-gutter: 2em,
    [
      #if left-title != "" [
        #block[#set text(size: 12pt, weight: "bold"); #left-title]
        #v(0.3em)
      ]
      #left-content
    ],
    [
      #if right-title != "" [
        #block[#set text(size: 12pt, weight: "bold"); #right-title]
        #v(0.3em)
      ]
      #right-content
    ],
  )
]

// ============================================================================
// Nested Market Diagram (TAM/SAM/SOM professional boxes)
// ============================================================================

#let nested-market-diagram(
  tam: "",
  sam: "",
  som: "",
  tam-breakdown: none,
  sam-description: "Serviceable market with geographic and segment filters",
  som-years: none,
) = {
  figure(
    block(width: 100%)[
      // Outer box: TAM
      #block(
        fill: fill-header,
        stroke: 1.2pt + navy-medium,
        radius: 6pt,
        inset: (x: 1.4em, y: 1.1em),
        width: 100%,
      )[
        #set text(size: 9.5pt)
        #block[
          #set text(size: 11pt, weight: "bold", fill: navy-dark)
          FILTERED TAM: #tam
        ]
        #if tam-breakdown != none [
          #set text(size: 9pt, fill: rgb("#333333"))
          #tam-breakdown
        ]

        #v(0.8em)

        // Middle box: SAM
        #block(
          fill: rgb("#d0dcea"),
          stroke: 1pt + navy-medium,
          radius: 5pt,
          inset: (x: 1.2em, y: 0.9em),
          width: 88%,
        )[
          #block[
            #set text(size: 10.5pt, weight: "bold", fill: navy-dark)
            SAM: #sam
          ]
          #set text(size: 8.5pt, fill: rgb("#333333"))
          #sam-description

          #v(0.7em)

          // Inner box: SOM
          #block(
            fill: rgb("#b8cce0"),
            stroke: 0.8pt + navy-medium,
            radius: 4pt,
            inset: (x: 1em, y: 0.8em),
            width: 85%,
          )[
            #block[
              #set text(size: 10pt, weight: "bold", fill: navy-dark)
              SOM (Conservative - Aggressive)
            ]
            #set text(size: 8.5pt, fill: text-primary)
            #if som-years != none [
              #grid(
                columns: (auto, auto),
                column-gutter: 2em,
                row-gutter: 0.25em,
                ..som-years.flatten()
              )
            ] else [
              #som
            ]
          ]
        ]
      ]
    ],
    caption: [TAM / SAM / SOM market sizing - nested view],
  )
}

// ============================================================================
// Executive Summary Block
// ============================================================================

#let executive-summary(content) = {
  rect(
    width: 100%,
    fill: fill-header,
    inset: 16pt,
    radius: 4pt,
  )[
    #text(weight: "bold", size: 12pt, fill: navy-dark)[Executive Summary]
    #v(0.5em)
    #content
  ]
}

// ============================================================================
// Key Metric Callout (large centered display)
// ============================================================================

#let metric-callout(label, value, subtitle: none) = {
  rect(
    width: 100%,
    fill: fill-callout,
    inset: 12pt,
    radius: 4pt,
  )[
    #align(center)[
      #text(size: 10pt, fill: text-muted)[#label]
      #v(0.2em)
      #text(size: 24pt, weight: "bold", fill: navy-dark)[#value]
      #if subtitle != none [
        #v(0.1em)
        #text(size: 9pt, fill: text-muted)[#subtitle]
      ]
    ]
  ]
}

// ============================================================================
// Metric Row (multiple metrics side by side)
// ============================================================================

#let metric-row(..metrics) = {
  let items = metrics.pos()
  grid(
    columns: items.len(),
    column-gutter: 12pt,
    ..items.map(m => metric-callout(m.label, m.value, subtitle: m.at("subtitle", default: none)))
  )
}

// ============================================================================
// Highlight Box (key insights)
// ============================================================================

#let highlight-box(title: "Key Insight", content) = {
  rect(
    width: 100%,
    stroke: (left: 3pt + navy-medium),
    fill: fill-callout,
    inset: 12pt,
  )[
    #text(weight: "bold", fill: navy-medium)[#title]
    #v(0.3em)
    #content
  ]
}

// ============================================================================
// Warning Box (red flags, risks)
// ============================================================================

#let warning-box(title: "Red Flag", content) = {
  rect(
    width: 100%,
    stroke: (left: 3pt + border-warning),
    fill: fill-warning,
    inset: 12pt,
  )[
    #text(weight: "bold", fill: border-warning)[#title]
    #v(0.3em)
    #content
  ]
}

// ============================================================================
// Success Box (validation, positive signals)
// ============================================================================

#let success-box(title: "Validation", content) = {
  rect(
    width: 100%,
    stroke: (left: 3pt + rgb("#16a34a")),
    fill: rgb("#f0fdf4"),
    inset: 12pt,
  )[
    #text(weight: "bold", fill: rgb("#16a34a"))[#title]
    #v(0.3em)
    #content
  ]
}

// ============================================================================
// Strategy Table (with header styling)
// ============================================================================

#let strategy-table(columns: auto, header: (), ..rows) = {
  let all-rows = rows.pos()
  table(
    columns: columns,
    align: (col, _) => if col == 0 { left } else { center },
    table.header(..header.map(h => [*#h*])),
    ..all-rows.flatten(),
  )
}

// ============================================================================
// Comparison Table (feature comparisons with "Us" column highlight)
// ============================================================================

#let comparison-table(columns: auto, header: (), ..rows) = {
  let all-rows = rows.pos()
  table(
    columns: columns,
    fill: (x, y) => {
      if y == 0 { fill-header }
      else if x == 1 { fill-callout }  // Highlight "Us" column
      else if calc.odd(y) { fill-alt-row }
      else { white }
    },
    align: (col, _) => if col == 0 { left } else { center },
    table.header(..header.map(h => [*#h*])),
    ..all-rows.flatten(),
  )
}

// ============================================================================
// Section Divider
// ============================================================================

#let section-divider() = {
  v(1em)
  line(length: 100%, stroke: 0.5pt + border-light)
  v(1em)
}

// ============================================================================
// Positioning Map (2x2 grid)
// ============================================================================

#let positioning-map(
  x-axis: "X Axis",
  y-axis: "Y Axis",
  quadrants: (
    top-left: [],
    top-right: [],
    bottom-left: [],
    bottom-right: [],
  ),
) = {
  rect(
    width: 100%,
    inset: 16pt,
    stroke: 0.5pt + border-light,
  )[
    #align(center)[
      #text(weight: "bold", size: 11pt, fill: navy-dark)[#y-axis]
      #v(0.3em)
      #grid(
        columns: (1fr, 1fr),
        rows: (auto, auto),
        gutter: 1pt,
        rect(fill: fill-alt-row, inset: 12pt)[
          #text(size: 9pt, fill: text-muted)[High #y-axis / Low #x-axis]
          #v(0.5em)
          #quadrants.top-left
        ],
        rect(fill: rgb("#f0fdf4"), inset: 12pt)[
          #text(size: 9pt, fill: text-muted)[High #y-axis / High #x-axis]
          #v(0.5em)
          #quadrants.top-right
        ],
        rect(fill: fill-warning, inset: 12pt)[
          #text(size: 9pt, fill: text-muted)[Low #y-axis / Low #x-axis]
          #v(0.5em)
          #quadrants.bottom-left
        ],
        rect(fill: fill-alt-row, inset: 12pt)[
          #text(size: 9pt, fill: text-muted)[Low #y-axis / High #x-axis]
          #v(0.5em)
          #quadrants.bottom-right
        ],
      )
      #v(0.3em)
      #text(weight: "bold", size: 11pt, fill: navy-dark)[#x-axis]
    ]
  ]
}

// ============================================================================
// Market Circles (legacy - prefer nested-market-diagram)
// ============================================================================

#let market-circles(tam: "", sam: "", som: "") = {
  // Use nested-market-diagram for professional appearance
  nested-market-diagram(tam: tam, sam: sam, som: som)
}

// ============================================================================
// Competitor Profile Card
// ============================================================================

#let competitor-card(
  name: "",
  category: "",
  positioning: "",
  strengths: (),
  weaknesses: (),
  pricing: "",
) = {
  rect(
    width: 100%,
    stroke: 1pt + navy-medium,
    fill: fill-alt-row,
    inset: 12pt,
    radius: 4pt,
  )[
    #grid(
      columns: (1fr, auto),
      [
        #text(weight: "bold", size: 14pt, fill: navy-dark)[#name]
        #h(8pt)
        #text(size: 10pt, fill: text-muted)[#category]
      ],
      text(size: 10pt, fill: navy-medium)[#pricing],
    )
    #v(0.3em)
    #text(style: "italic", size: 10pt)[#positioning]
    #v(0.5em)
    #grid(
      columns: (1fr, 1fr),
      column-gutter: 16pt,
      [
        #text(weight: "bold", fill: rgb("#16a34a"), size: 10pt)[Strengths]
        #for s in strengths [
          - #s
        ]
      ],
      [
        #text(weight: "bold", fill: border-warning, size: 10pt)[Weaknesses]
        #for w in weaknesses [
          - #w
        ]
      ],
    )
  ]
}

// ============================================================================
// Battle Card
// ============================================================================

#let battle-card(
  competitor: "",
  their-pitch: "",
  our-response: "",
  objections: (),
  win-signals: (),
  lose-signals: (),
) = {
  rect(
    width: 100%,
    stroke: 1pt + navy-medium,
    fill: fill-header,
    inset: 16pt,
    radius: 4pt,
  )[
    #text(weight: "bold", size: 14pt, fill: navy-dark)[vs #competitor]
    #v(0.5em)

    #grid(
      columns: (1fr, 1fr),
      column-gutter: 16pt,
      [
        #text(weight: "bold", size: 10pt, fill: navy-medium)[Their Pitch]
        #rect(fill: white, inset: 8pt, radius: 2pt)[
          #text(style: "italic")[#their-pitch]
        ]
      ],
      [
        #text(weight: "bold", size: 10pt, fill: navy-medium)[Our Response]
        #rect(fill: white, inset: 8pt, radius: 2pt)[
          #our-response
        ]
      ],
    )
    #v(0.5em)

    #if objections.len() > 0 [
      #text(weight: "bold", size: 10pt, fill: navy-medium)[Objections & Responses]
      #for obj in objections [
        - *"#obj.objection"* - #obj.response
      ]
      #v(0.3em)
    ]

    #grid(
      columns: (1fr, 1fr),
      column-gutter: 16pt,
      [
        #text(weight: "bold", fill: rgb("#16a34a"), size: 10pt)[Win Signals]
        #for s in win-signals [
          - #s
        ]
      ],
      [
        #text(weight: "bold", fill: border-warning, size: 10pt)[Lose Signals]
        #for s in lose-signals [
          - #s
        ]
      ],
    )
  ]
}

// ============================================================================
// Timeline Visualization
// ============================================================================

#let timeline(phases: ()) = {
  let phase-count = phases.len()
  rect(
    width: 100%,
    inset: 16pt,
    stroke: 0.5pt + border-light,
    radius: 4pt,
  )[
    #for (i, phase) in phases.enumerate() [
      #grid(
        columns: (auto, 1fr),
        column-gutter: 12pt,
        [
          #circle(
            radius: 12pt,
            fill: if phase.at("complete", default: false) { navy-medium } else { fill-alt-row },
            stroke: 1pt + if phase.at("complete", default: false) { navy-dark } else { border-light },
          )[
            #align(center + horizon)[
              #text(
                weight: "bold",
                size: 10pt,
                fill: if phase.at("complete", default: false) { white } else { text-muted },
              )[#str(i + 1)]
            ]
          ]
        ],
        [
          #text(weight: "bold", fill: navy-dark)[#phase.name]
          #if phase.at("duration", default: none) != none [
            #h(8pt)
            #text(size: 9pt, fill: text-muted)[#phase.duration]
          ]
          #v(0.2em)
          #text(size: 10pt)[#phase.description]
        ],
      )
      #if i < phase-count - 1 [
        #h(12pt)
        #line(start: (0pt, 0pt), end: (0pt, 16pt), stroke: 1pt + border-light)
        #v(4pt)
      ]
    ]
  ]
}

// ============================================================================
// Appendix Section
// ============================================================================

#let appendix(title: "Appendix", content) = {
  pagebreak()
  heading(level: 1, numbering: none)[#title]
  content
}
