// Research Timeline Template
// Professional template for medical research project timeline visualizations
// Features: Aims-based Gantt charts, PERT estimation, regulatory timelines,
//   effort allocation, reporting schedules
// Self-contained: does not import from founder extension
// Output: PDF research project timeline and planning documents

#import "@preview/gantty:0.5.1": gantt

// ============================================================================
// Color Palette
// ============================================================================

#let navy-dark = rgb("#1e3a5f")
#let navy-medium = rgb("#2c5282")
#let navy-light = rgb("#ebf4ff")
#let text-muted = rgb("#64748b")
#let border-light = rgb("#e2e8f0")
#let fill-alt-row = rgb("#f8fafc")
#let fill-callout = rgb("#eff6ff")
#let critical-path = rgb("#dc2626")
#let critical-path-light = rgb("#fef2f2")
#let milestone-marker = navy-dark
#let progress-complete = rgb("#16a34a")
#let progress-complete-light = rgb("#f0fdf4")
#let progress-remaining = rgb("#94a3b8")
#let regulatory-color = rgb("#7c3aed")
#let regulatory-light = rgb("#f5f3ff")
#let reporting-color = rgb("#0891b2")
#let reporting-light = rgb("#ecfeff")

// ============================================================================
// Document Setup
// ============================================================================

#let research-timeline-doc(
  title: "Research Timeline",
  project: "",
  pi: "",
  mechanism: "",
  date: "",
  doc,
) = {
  set document(title: title, author: pi)
  set page(
    paper: "us-letter",
    margin: (top: 1in, bottom: 1in, left: 1in, right: 1in),
    header: context {
      if counter(page).get().first() > 1 [
        #set text(size: 9pt, fill: text-muted)
        #title -- #project
        #h(1fr)
        #mechanism
      ]
    },
    footer: [
      #set text(size: 9pt, fill: text-muted)
      #h(1fr)
      #counter(page).display("1 / 1", both: true)
      #h(1fr)
    ],
  )
  set text(font: "New Computer Modern", size: 11pt)
  set heading(numbering: "1.1")
  set par(justify: true)

  // Title block
  align(center)[
    #block(
      width: 100%,
      fill: navy-dark,
      inset: (x: 2em, y: 1.5em),
      radius: 4pt,
    )[
      #set text(fill: white)
      #text(size: 20pt, weight: "bold")[#title]
      #v(0.5em)
      #text(size: 14pt)[#project]
      #v(0.3em)
      #text(size: 11pt)[#pi #h(2em) #mechanism #h(2em) #date]
    ]
  ]
  v(1em)

  doc
}

// ============================================================================
// Aims-Based Gantt Chart
// ============================================================================

#let aims-gantt(
  start-date: none,
  end-date: none,
  aims: (),
  milestones: (),
  regulatory: (),
  show-today: true,
  caption: none,
) = {
  // Build task list from aims and sub-aims
  let yaml-tasks = ()
  for aim in aims {
    // Add aim as a group header task
    yaml-tasks.push((
      name: "Aim " + str(aim.number) + ": " + aim.title,
      intervals: ((start: aim.start, end: aim.end),),
      id: "aim" + str(aim.number),
    ))
    // Add sub-aims
    if "sub_aims" in aim {
      for sa in aim.sub_aims {
        let task-entry = (
          name: "  " + sa.id + ": " + sa.title,
          intervals: ((start: sa.start, end: sa.end),),
          id: sa.id,
        )
        if "dependencies" in sa and sa.dependencies.len() > 0 {
          task-entry.insert("dependencies", sa.dependencies)
        }
        yaml-tasks.push(task-entry)
      }
    }
  }

  // Add regulatory milestones
  for reg in regulatory {
    yaml-tasks.push((
      name: reg.name,
      intervals: ((start: reg.start, end: reg.end),),
      id: "reg-" + lower(reg.type),
    ))
  }

  let yaml-milestones = milestones.map(m => (
    name: m.name,
    date: m.date,
    show-date: m.at("show-date", default: true),
  ))

  let yaml-config = (
    show-today: show-today,
    headers: ("year", "month"),
    tasks: yaml-tasks,
    milestones: yaml-milestones,
  )

  let chart = gantt(yaml-config)

  if caption != none {
    figure(chart, caption: caption)
  } else {
    chart
  }
}

// ============================================================================
// PERT Estimates Table
// ============================================================================

#let pert-table(
  estimates: (),
  unit: "months",
  show-totals: true,
) = {
  let calc-expected(o, m, p) = (o + 4 * m + p) / 6
  let calc-stddev(o, p) = (p - o) / 6

  let header-cell(content) = table.cell(
    fill: navy-dark,
    text(fill: white, weight: "bold", size: 9pt, content),
  )

  let rows = ()
  let total-expected = 0
  let total-variance = 0

  for est in estimates {
    let e = calc-expected(est.optimistic, est.likely, est.pessimistic)
    let sd = calc-stddev(est.optimistic, est.pessimistic)
    total-expected += e
    total-variance += sd * sd

    let is-critical = est.at("critical", default: false)
    let row-fill = if is-critical { critical-path-light } else { none }

    rows.push(table.cell(fill: row-fill)[
      #if is-critical [#text(weight: "bold", fill: critical-path)[#est.task]]
      #if not is-critical [#est.task]
    ])
    rows.push(table.cell(fill: row-fill)[#est.optimistic])
    rows.push(table.cell(fill: row-fill)[#est.likely])
    rows.push(table.cell(fill: row-fill)[#est.pessimistic])
    rows.push(table.cell(fill: row-fill)[#text(weight: "bold")[#calc.round(e, digits: 1)]])
    rows.push(table.cell(fill: row-fill)[#calc.round(sd, digits: 2)])
  }

  // Totals row
  if show-totals {
    let total-sd = calc.sqrt(total-variance)
    rows.push(table.cell(fill: navy-light)[#text(weight: "bold")[Total (Critical Path)]])
    rows.push(table.cell(fill: navy-light)[])
    rows.push(table.cell(fill: navy-light)[])
    rows.push(table.cell(fill: navy-light)[])
    rows.push(table.cell(fill: navy-light)[#text(weight: "bold")[#calc.round(total-expected, digits: 1)]])
    rows.push(table.cell(fill: navy-light)[#text(weight: "bold")[#calc.round(total-sd, digits: 2)]])
  }

  table(
    columns: (1fr, auto, auto, auto, auto, auto),
    align: (left, center, center, center, center, center),
    stroke: 0.5pt + border-light,
    inset: 8pt,
    header-cell[Task],
    header-cell[O (#unit)],
    header-cell[M (#unit)],
    header-cell[P (#unit)],
    header-cell[Expected],
    header-cell[SD],
    ..rows,
  )
}

// ============================================================================
// Effort Allocation Table
// ============================================================================

#let effort-allocation(
  personnel: (),
  budget-periods: 5,
  unit: "cal months",
) = {
  let header-cell(content) = table.cell(
    fill: navy-dark,
    text(fill: white, weight: "bold", size: 9pt, content),
  )

  let bp-headers = range(1, budget-periods + 1).map(i =>
    header-cell[BP#i (#unit)]
  )

  let rows = ()
  for person in personnel {
    rows.push([#text(weight: "bold")[#person.role]])
    rows.push([#person.name])
    for effort in person.effort {
      let cell-fill = if effort >= 9 { fill-callout } else { none }
      rows.push(table.cell(fill: cell-fill)[#effort])
    }
    // Pad if fewer effort values than budget periods
    let remaining = budget-periods - person.effort.len()
    for _ in range(remaining) {
      rows.push([--])
    }
  }

  table(
    columns: (auto, 1fr, ..range(budget-periods).map(_ => auto)),
    align: (left, left, ..range(budget-periods).map(_ => center)),
    stroke: 0.5pt + border-light,
    inset: 8pt,
    header-cell[Role],
    header-cell[Name],
    ..bp-headers,
    ..rows,
  )
}

// ============================================================================
// Regulatory Timeline
// ============================================================================

#let regulatory-timeline(
  milestones: (),
) = {
  let header-cell(content) = table.cell(
    fill: regulatory-color,
    text(fill: white, weight: "bold", size: 9pt, content),
  )

  let rows = ()
  for m in milestones {
    let status-color = if m.status == "approved" { progress-complete }
      else if m.status == "pending" { regulatory-color }
      else { text-muted }

    rows.push([#text(weight: "bold")[#m.name]])
    rows.push([#m.type])
    rows.push([#m.required-by])
    rows.push([#m.lead-time])
    rows.push([#text(fill: status-color, weight: "bold")[#m.status]])
  }

  table(
    columns: (1fr, auto, auto, auto, auto),
    align: (left, center, left, center, center),
    stroke: 0.5pt + border-light,
    inset: 8pt,
    header-cell[Milestone],
    header-cell[Type],
    header-cell[Required By],
    header-cell[Lead Time],
    header-cell[Status],
    ..rows,
  )
}

// ============================================================================
// Reporting Schedule
// ============================================================================

#let reporting-schedule(
  reports: (),
) = {
  let header-cell(content) = table.cell(
    fill: reporting-color,
    text(fill: white, weight: "bold", size: 9pt, content),
  )

  let rows = ()
  for r in reports {
    let type-fill = if r.type == "Terminal" { reporting-light } else { none }
    rows.push(table.cell(fill: type-fill)[#r.name])
    rows.push(table.cell(fill: type-fill)[#r.due-date])
    rows.push(table.cell(fill: type-fill)[#r.budget-period])
    rows.push(table.cell(fill: type-fill)[#r.type])
  }

  table(
    columns: (1fr, auto, auto, auto),
    align: (left, center, center, center),
    stroke: 0.5pt + border-light,
    inset: 8pt,
    header-cell[Report],
    header-cell[Due Date],
    header-cell[Budget Period],
    header-cell[Type],
    ..rows,
  )
}

// ============================================================================
// Project Summary Card
// ============================================================================

#let project-summary(
  title: "",
  mechanism: "",
  pi: "",
  period: "",
  aims: 0,
  critical-path-months: 0,
  confidence-95: "",
  float-months: 0,
  personnel-count: 0,
  regulatory-count: 0,
) = {
  rect(
    width: 100%,
    fill: navy-light,
    stroke: 1pt + navy-medium,
    inset: 16pt,
    radius: 6pt,
  )[
    #text(size: 14pt, weight: "bold", fill: navy-dark)[Project Summary]
    #v(0.8em)

    #grid(
      columns: (1fr, 1fr),
      column-gutter: 16pt,
      row-gutter: 8pt,
      [#text(fill: text-muted, size: 9pt)[Title] \ #text(weight: "bold")[#title]],
      [#text(fill: text-muted, size: 9pt)[Mechanism] \ #text(weight: "bold")[#mechanism]],
      [#text(fill: text-muted, size: 9pt)[PI] \ #text(weight: "bold")[#pi]],
      [#text(fill: text-muted, size: 9pt)[Project Period] \ #text(weight: "bold")[#period]],
      [#text(fill: text-muted, size: 9pt)[Specific Aims] \ #text(weight: "bold")[#aims]],
      [#text(fill: text-muted, size: 9pt)[Key Personnel] \ #text(weight: "bold")[#personnel-count]],
      [#text(fill: text-muted, size: 9pt)[Critical Path] \ #text(weight: "bold")[#critical-path-months months] #text(size: 9pt, fill: text-muted)[(95% CI: #confidence-95)]],
      [#text(fill: text-muted, size: 9pt)[Schedule Float] \ #text(weight: "bold", fill: if float-months >= 6 { progress-complete } else if float-months >= 3 { navy-medium } else { critical-path })[#float-months months]],
      [#text(fill: text-muted, size: 9pt)[Regulatory Milestones] \ #text(weight: "bold")[#regulatory-count]],
    )
  ]
}
