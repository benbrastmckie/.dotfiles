// Project Timeline Template
// Professional template for project management visualizations
// Features: Gantt charts, PERT estimation, WBS hierarchy, resource allocation, risk matrix
// Uses: strategy-template.typ base styles, gantty for Gantt charts, fletcher for diagrams
// Output: PDF project timeline and planning documents

#import "strategy-template.typ": *
#import "@preview/gantty:0.5.1": gantt
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// ============================================================================
// Additional Timeline-Specific Colors
// ============================================================================

#let critical-path = rgb("#dc2626")
#let critical-path-light = rgb("#fef2f2")
#let milestone-marker = navy-dark
#let progress-complete = rgb("#16a34a")
#let progress-complete-light = rgb("#f0fdf4")
#let progress-remaining = rgb("#94a3b8")
#let overallocation = rgb("#ea580c")
#let overallocation-light = rgb("#fff7ed")

// ============================================================================
// Document Setup
// ============================================================================

#let project-timeline-doc(
  title: "Project Timeline",
  project: "",
  date: "",
  mode: "PLANNING",
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
// Gantt Chart Component
// ============================================================================
//
// Usage:
//   #project-gantt(
//     start-date: "2026-01-01",
//     end-date: "2026-06-30",
//     tasks: (
//       (name: "Planning", id: "plan", start: "2026-01-01", end: "2026-01-15"),
//       (name: "Development", id: "dev", start: "2026-01-16", end: "2026-03-01",
//        dependencies: ("plan",), critical: true),
//       (name: "Testing", id: "test", start: "2026-03-01", end: "2026-03-15",
//        dependencies: ("dev",)),
//     ),
//     milestones: (
//       (name: "MVP Release", date: "2026-02-15"),
//       (name: "Launch", date: "2026-03-15"),
//     ),
//   )

#let project-gantt(
  start-date: none,
  end-date: none,
  tasks: (),
  milestones: (),
  show-today: true,
  headers: ("year", "month"),
  caption: none,
) = {
  // Build gantty YAML configuration
  let yaml-tasks = tasks.map(t => {
    let task-entry = (
      name: t.name,
      intervals: ((start: t.start, end: t.end),),
    )
    if "id" in t { task-entry.insert("id", t.id) }
    if "dependencies" in t { task-entry.insert("dependencies", t.dependencies) }
    task-entry
  })

  let yaml-milestones = milestones.map(m => (
    name: m.name,
    date: m.date,
    show-date: m.at("show-date", default: true),
  ))

  let yaml-config = (
    show-today: show-today,
    headers: headers,
    tasks: yaml-tasks,
    milestones: yaml-milestones,
  )

  // Render the Gantt chart
  let chart = gantt(yaml-config)

  // Wrap in figure if caption provided
  if caption != none {
    figure(
      chart,
      caption: caption,
    )
  } else {
    chart
  }
}

// ============================================================================
// Critical Path Task Styling Helper
// ============================================================================

#let critical-task(name, start: "", end: "") = {
  rect(
    fill: critical-path-light,
    stroke: (left: 3pt + critical-path),
    inset: (x: 0.8em, y: 0.5em),
    radius: (right: 3pt),
  )[
    #text(weight: "bold", fill: critical-path)[#name]
    #h(1em)
    #text(size: 9pt, fill: text-muted)[#start - #end]
  ]
}

// ============================================================================
// Milestone Badge
// ============================================================================

#let milestone-badge(name, date: none) = {
  box(
    fill: milestone-marker,
    radius: 3pt,
    inset: (x: 0.6em, y: 0.3em),
  )[
    #set text(fill: white, size: 9pt)
    #sym.diamond.filled #strong[#name]
    #if date != none [ - #date]
  ]
}

// ============================================================================
// PERT Three-Point Estimation Component
// ============================================================================
//
// Usage:
//   #pert-estimate(
//     label: "Backend Development",
//     optimistic: 2,
//     likely: 4,
//     pessimistic: 8,
//     unit: "weeks",
//   )

#let pert-estimate(
  label: "Duration",
  optimistic: 0,
  likely: 0,
  pessimistic: 0,
  unit: "days",
  show-formula: true,
  show-confidence: true,
) = {
  // PERT formula: E = (O + 4M + P) / 6
  let expected = (optimistic + 4 * likely + pessimistic) / 6
  // Standard deviation: SD = (P - O) / 6
  let stddev = (pessimistic - optimistic) / 6
  // 95% confidence interval: E +/- 2*SD
  let ci-low = expected - 2 * stddev
  let ci-high = expected + 2 * stddev

  rect(
    width: 100%,
    stroke: 0.5pt + border-light,
    fill: fill-alt-row,
    inset: 12pt,
    radius: 4pt,
  )[
    #text(weight: "bold", size: 11pt, fill: navy-dark)[#label]
    #v(0.5em)

    // Three-point inputs
    #grid(
      columns: (1fr, 1fr, 1fr),
      column-gutter: 8pt,
      // Optimistic
      rect(
        fill: progress-complete-light,
        inset: 8pt,
        radius: 3pt,
        width: 100%,
      )[
        #align(center)[
          #text(size: 8pt, fill: text-muted)[Optimistic]
          #v(0.2em)
          #text(size: 16pt, weight: "bold", fill: progress-complete)[#optimistic]
          #text(size: 9pt, fill: text-muted)[ #unit]
        ]
      ],
      // Most Likely
      rect(
        fill: fill-callout,
        inset: 8pt,
        radius: 3pt,
        width: 100%,
      )[
        #align(center)[
          #text(size: 8pt, fill: text-muted)[Most Likely]
          #v(0.2em)
          #text(size: 16pt, weight: "bold", fill: navy-medium)[#likely]
          #text(size: 9pt, fill: text-muted)[ #unit]
        ]
      ],
      // Pessimistic
      rect(
        fill: critical-path-light,
        inset: 8pt,
        radius: 3pt,
        width: 100%,
      )[
        #align(center)[
          #text(size: 8pt, fill: text-muted)[Pessimistic]
          #v(0.2em)
          #text(size: 16pt, weight: "bold", fill: critical-path)[#pessimistic]
          #text(size: 9pt, fill: text-muted)[ #unit]
        ]
      ],
    )

    #v(0.8em)

    // Formula display
    #if show-formula [
      #rect(
        fill: white,
        inset: 6pt,
        radius: 2pt,
        width: 100%,
      )[
        #set text(size: 9pt, fill: text-muted)
        #align(center)[
          E = (O + 4M + P) / 6 = (#optimistic + 4 #sym.times #likely + #pessimistic) / 6
        ]
      ]
      #v(0.5em)
    ]

    // Expected value (prominent)
    #align(center)[
      #rect(
        fill: navy-dark,
        inset: (x: 1.2em, y: 0.6em),
        radius: 4pt,
      )[
        #set text(fill: white)
        #text(size: 10pt)[Expected: ]
        #text(size: 18pt, weight: "bold")[#calc.round(expected, digits: 1)]
        #text(size: 10pt)[ #unit]
      ]
    ]

    // Confidence interval
    #if show-confidence [
      #v(0.5em)
      #align(center)[
        #set text(size: 9pt, fill: text-muted)
        95% CI: #calc.round(ci-low, digits: 1) - #calc.round(ci-high, digits: 1) #unit
        #h(1em)
        #sym.sigma = #calc.round(stddev, digits: 2) #unit
      ]
    ]
  ]
}

// ============================================================================
// PERT Estimates Table (for multiple tasks)
// ============================================================================
//
// Usage:
//   #pert-table(
//     unit: "days",
//     estimates: (
//       (task: "Design", optimistic: 3, likely: 5, pessimistic: 10),
//       (task: "Backend", optimistic: 10, likely: 15, pessimistic: 25),
//       (task: "Frontend", optimistic: 8, likely: 12, pessimistic: 20),
//     ),
//   )

#let pert-table(
  estimates: (),
  unit: "days",
  show-totals: true,
) = {
  // Calculate expected values
  let calc-expected(o, m, p) = (o + 4 * m + p) / 6
  let calc-stddev(o, p) = (p - o) / 6

  let processed = estimates.map(e => {
    let exp = calc-expected(e.optimistic, e.likely, e.pessimistic)
    let sd = calc-stddev(e.optimistic, e.pessimistic)
    (
      task: e.task,
      optimistic: e.optimistic,
      likely: e.likely,
      pessimistic: e.pessimistic,
      expected: exp,
      stddev: sd,
    )
  })

  // Calculate totals
  let total-expected = processed.map(e => e.expected).sum()
  let total-variance = processed.map(e => calc.pow(e.stddev, 2)).sum()
  let total-stddev = calc.sqrt(total-variance)

  table(
    columns: (2fr, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, center, center, center, center, center),
    fill: (x, y) => {
      if y == 0 { fill-header }
      else if y == processed.len() + 1 and show-totals { fill-callout }
      else if calc.odd(y) { fill-alt-row }
      else { white }
    },
    table.header(
      [*Task*], [*O*], [*M*], [*P*], [*E*], [*#sym.sigma*],
    ),
    ..processed.map(e => (
      e.task,
      str(e.optimistic),
      str(e.likely),
      str(e.pessimistic),
      text(weight: "bold")[#calc.round(e.expected, digits: 1)],
      text(fill: text-muted)[#calc.round(e.stddev, digits: 2)],
    )).flatten(),
    ..if show-totals {(
      text(weight: "bold")[Total (#unit)],
      [-], [-], [-],
      text(weight: "bold", fill: navy-dark)[#calc.round(total-expected, digits: 1)],
      text(fill: text-muted)[#calc.round(total-stddev, digits: 2)],
    )} else {()},
  )
}

// ============================================================================
// Resource Allocation Matrix
// ============================================================================
//
// Usage:
//   #resource-matrix(
//     team: ("Alice", "Bob", "Carol"),
//     periods: ("Week 1", "Week 2", "Week 3", "Week 4"),
//     allocations: (
//       // (member-index, period-index, task, percentage)
//       (0, 0, "Planning", 100),
//       (0, 1, "Design", 50),
//       (1, 1, "Design", 50),
//       (1, 2, "Backend", 100),
//       (2, 2, "Frontend", 100),
//       (2, 3, "Frontend", 80),
//       (2, 3, "Testing", 40),  // Overallocation example
//     ),
//   )

#let resource-matrix(
  team: (),
  periods: (),
  allocations: (),
  show-capacity: true,
) = {
  // Build allocation map: (member, period) -> list of (task, %)
  let alloc-map = (:)
  for a in allocations {
    let key = str(a.at(0)) + "-" + str(a.at(1))
    if key not in alloc-map {
      alloc-map.insert(key, ())
    }
    alloc-map.at(key).push((task: a.at(2), pct: a.at(3)))
  }

  // Calculate capacity per member per period
  let capacity-map = (:)
  for (key, tasks) in alloc-map {
    let total = tasks.map(t => t.pct).sum()
    capacity-map.insert(key, total)
  }

  // Calculate period totals
  let period-capacities = periods.enumerate().map(((pi, _)) => {
    let total = 0
    for mi in range(team.len()) {
      let key = str(mi) + "-" + str(pi)
      if key in capacity-map {
        total += capacity-map.at(key)
      }
    }
    total / team.len()  // Average capacity
  })

  // Render cell content
  let cell-content(member-idx, period-idx) = {
    let key = str(member-idx) + "-" + str(period-idx)
    if key in alloc-map {
      let tasks = alloc-map.at(key)
      let total = capacity-map.at(key)
      let is-over = total > 100

      rect(
        fill: if is-over { overallocation-light } else { fill-callout },
        stroke: if is-over { (left: 2pt + overallocation) } else { none },
        inset: 4pt,
        radius: 2pt,
        width: 100%,
      )[
        #set text(size: 8pt)
        #for t in tasks [
          #t.task (#t.pct%)
          #linebreak()
        ]
        #if is-over [
          #text(fill: overallocation, weight: "bold")[#total%]
        ]
      ]
    } else {
      text(fill: text-light)[--]
    }
  }

  table(
    columns: (1.2fr,) + (1fr,) * periods.len(),
    align: (left,) + (center,) * periods.len(),
    fill: (x, y) => {
      if y == 0 { fill-header }
      else if y == team.len() + 1 and show-capacity { navy-dark }
      else if calc.odd(y) { fill-alt-row }
      else { white }
    },
    // Header row
    table.header(
      [*Team Member*],
      ..periods.map(p => [*#p*]),
    ),
    // Team member rows
    ..team.enumerate().map(((mi, member)) => {
      (
        [#member],
        ..periods.enumerate().map(((pi, _)) => cell-content(mi, pi)),
      )
    }).flatten(),
    // Capacity row
    ..if show-capacity {(
      text(fill: white, weight: "bold")[Avg Capacity],
      ..period-capacities.map(c => {
        let color = if c > 100 { overallocation } else if c > 80 { border-warning } else { progress-complete }
        text(fill: white, weight: "bold")[#calc.round(c, digits: 0)%]
      }),
    )} else {()},
  )
}

// ============================================================================
// WBS Hierarchy Visualization
// ============================================================================
//
// Usage:
//   #wbs-tree(
//     project: "Product Launch",
//     phases: (
//       (name: "Planning", tasks: ("Requirements", "Design")),
//       (name: "Development", tasks: ("Backend", "Frontend", "API")),
//       (name: "Launch", tasks: ("Testing", "Deployment")),
//     ),
//   )

#let wbs-tree(
  project: "",
  phases: (),
  node-width: 90pt,
) = {
  // Calculate positions
  let phase-count = phases.len()
  let max-tasks = calc.max(..phases.map(p => p.tasks.len()))

  fletcher.diagram(
    spacing: (20pt, 25pt),
    node-stroke: 0.8pt + border-light,
    edge-stroke: 0.8pt + navy-medium,
    {
      // Project root node
      node(
        (0, calc.floor(phase-count / 2)),
        rect(
          fill: navy-dark,
          inset: 8pt,
          radius: 4pt,
          width: node-width,
        )[
          #align(center)[
            #text(fill: white, weight: "bold", size: 10pt)[#project]
          ]
        ],
        name: <root>,
      )

      // Phase nodes
      for (pi, phase) in phases.enumerate() {
        let phase-name = label("phase-" + str(pi))
        node(
          (1, pi),
          rect(
            fill: fill-header,
            stroke: 1pt + navy-medium,
            inset: 6pt,
            radius: 3pt,
            width: node-width,
          )[
            #align(center)[
              #text(fill: navy-dark, weight: "bold", size: 9pt)[#phase.name]
            ]
          ],
          name: phase-name,
        )
        edge(<root>, phase-name, "->")

        // Task nodes
        let task-count = phase.tasks.len()
        let start-offset = (max-tasks - task-count) / 2
        for (ti, task) in phase.tasks.enumerate() {
          let task-name = label("task-" + str(pi) + "-" + str(ti))
          let task-y = pi + (ti - task-count / 2 + 0.5) * 0.4
          node(
            (2, task-y),
            rect(
              fill: white,
              stroke: 0.5pt + border-light,
              inset: 5pt,
              radius: 2pt,
              width: node-width * 0.9,
            )[
              #align(center)[
                #text(size: 8pt)[#task]
              ]
            ],
            name: task-name,
          )
          edge(phase-name, task-name, "->")
        }
      }
    },
  )
}

// ============================================================================
// WBS as Nested Boxes (Alternative)
// ============================================================================

#let wbs-boxes(
  project: "",
  phases: (),
) = {
  rect(
    width: 100%,
    stroke: 1.5pt + navy-dark,
    fill: fill-header,
    inset: 12pt,
    radius: 6pt,
  )[
    #align(center)[
      #text(weight: "bold", size: 14pt, fill: navy-dark)[#project]
    ]
    #v(0.8em)

    #grid(
      columns: phases.len(),
      column-gutter: 8pt,
      ..phases.map(phase => {
        rect(
          fill: white,
          stroke: 1pt + navy-medium,
          inset: 8pt,
          radius: 4pt,
          width: 100%,
        )[
          #text(weight: "bold", size: 10pt, fill: navy-medium)[#phase.name]
          #v(0.5em)
          #for task in phase.tasks [
            #rect(
              fill: fill-alt-row,
              inset: 4pt,
              radius: 2pt,
              width: 100%,
            )[
              #text(size: 8pt)[#task]
            ]
            #v(0.2em)
          ]
        ]
      }),
    )
  ]
}

// ============================================================================
// Project Risk Matrix
// ============================================================================
//
// Usage:
//   #project-risk-matrix(
//     high-high: ("Data breach", "Key person leaves"),
//     high-low: ("Budget overrun", "Scope creep"),
//     low-high: ("Vendor issues"),
//     low-low: ("Minor delays"),
//   )

#let project-risk-matrix(
  high-high: (),
  high-low: (),
  low-high: (),
  low-low: (),
  title: "Risk Assessment Matrix",
) = {
  rect(
    width: 100%,
    inset: 16pt,
    stroke: 0.5pt + border-light,
    radius: 4pt,
  )[
    #align(center)[
      #text(weight: "bold", size: 11pt, fill: navy-dark)[#title]
      #v(0.5em)
      #grid(
        columns: (auto, 1fr, 1fr),
        rows: (auto, auto, auto),
        gutter: 2pt,
        // Header row
        [],
        align(center)[#text(size: 9pt, fill: text-muted)[Low Impact]],
        align(center)[#text(size: 9pt, fill: text-muted)[High Impact]],

        // High likelihood row
        rotate(-90deg, reflow: true)[#text(size: 9pt, fill: text-muted)[High Likelihood]],
        rect(fill: rgb("#fef9c3"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#854d0e"))[MONITOR]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in high-low [
            - #item
          ]
        ],
        rect(fill: rgb("#fef2f2"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#dc2626"))[CRITICAL]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in high-high [
            - #item
          ]
        ],

        // Low likelihood row
        rotate(-90deg, reflow: true)[#text(size: 9pt, fill: text-muted)[Low Likelihood]],
        rect(fill: rgb("#f0fdf4"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#16a34a"))[ACCEPT]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in low-low [
            - #item
          ]
        ],
        rect(fill: rgb("#eff6ff"), inset: 10pt, radius: 2pt)[
          #text(weight: "bold", size: 10pt, fill: rgb("#1d4ed8"))[MITIGATE]
          #v(0.3em)
          #set text(size: 8pt)
          #for item in low-high [
            - #item
          ]
        ],
      )
    ]
  ]
}

// ============================================================================
// Risk Register Table
// ============================================================================
//
// Usage:
//   #risk-register(
//     risks: (
//       (id: "R1", name: "Data breach", likelihood: "High", impact: "High",
//        owner: "Security", mitigation: "Implement encryption"),
//       (id: "R2", name: "Budget overrun", likelihood: "Medium", impact: "High",
//        owner: "PM", mitigation: "Monthly reviews"),
//     ),
//   )

#let risk-register(
  risks: (),
) = {
  let risk-color(likelihood, impact) = {
    if likelihood == "High" and impact == "High" { rgb("#fef2f2") }
    else if likelihood == "High" or impact == "High" { rgb("#fefce8") }
    else { rgb("#f0fdf4") }
  }

  table(
    columns: (auto, 1.5fr, auto, auto, 1fr, 2fr),
    align: (center, left, center, center, left, left),
    fill: (x, y) => {
      if y == 0 { fill-header }
      else {
        let risk = risks.at(y - 1)
        risk-color(risk.likelihood, risk.impact)
      }
    },
    table.header(
      [*ID*], [*Risk*], [*L*], [*I*], [*Owner*], [*Mitigation*],
    ),
    ..risks.map(r => (
      text(weight: "bold")[#r.id],
      r.name,
      r.likelihood,
      r.impact,
      r.owner,
      text(size: 9pt)[#r.mitigation],
    )).flatten(),
  )
}

// ============================================================================
// Project Summary Card
// ============================================================================

#let project-summary(
  name: "",
  start: "",
  end: "",
  status: "On Track",
  progress: 0,
  budget: none,
  team-size: none,
) = {
  let status-color = if status == "On Track" { progress-complete }
    else if status == "At Risk" { border-warning }
    else if status == "Delayed" { critical-path }
    else { text-muted }

  rect(
    width: 100%,
    fill: fill-header,
    stroke: 1pt + navy-medium,
    inset: 16pt,
    radius: 6pt,
  )[
    #grid(
      columns: (1fr, auto),
      [
        #text(weight: "bold", size: 16pt, fill: navy-dark)[#name]
        #v(0.3em)
        #text(size: 10pt, fill: text-muted)[#start - #end]
      ],
      box(
        fill: status-color,
        radius: 4pt,
        inset: (x: 0.8em, y: 0.4em),
      )[
        #text(fill: white, weight: "bold", size: 10pt)[#status]
      ],
    )

    #v(0.8em)

    // Progress bar
    #rect(
      width: 100%,
      fill: progress-remaining,
      height: 8pt,
      radius: 4pt,
    )[
      #rect(
        width: calc.min(100, progress) * 1%,
        fill: if progress >= 100 { progress-complete } else { navy-medium },
        height: 100%,
        radius: 4pt,
      )[]
    ]
    #align(right)[
      #text(size: 10pt, fill: text-muted)[#progress% Complete]
    ]

    #if budget != none or team-size != none [
      #v(0.5em)
      #grid(
        columns: (auto, auto),
        column-gutter: 2em,
        if budget != none [#text(weight: "bold")[Budget:] #budget],
        if team-size != none [#text(weight: "bold")[Team:] #team-size members],
      )
    ]
  ]
}

// ============================================================================
// Dependency List
// ============================================================================

#let dependency-list(
  dependencies: (),
) = {
  for dep in dependencies [
    #rect(
      width: 100%,
      fill: fill-alt-row,
      inset: 8pt,
      radius: 3pt,
    )[
      #grid(
        columns: (auto, 1fr, auto),
        column-gutter: 8pt,
        align: (left, left, right),
        text(weight: "bold", fill: navy-dark)[#dep.from],
        [#sym.arrow.r],
        text(weight: "bold", fill: navy-medium)[#dep.to],
      )
      #if "type" in dep [
        #text(size: 9pt, fill: text-muted)[ (#dep.type)]
      ]
    ]
    #v(0.2em)
  ]
}
