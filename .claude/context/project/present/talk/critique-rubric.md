# Slide Presentation Critique Rubric

Agent-consumable framework for evaluating slide presentations across 6 categories.
Designed for a slide-critic-agent to produce structured, severity-tagged feedback.

## Severity Definitions

| Severity | Definition | Action Required |
|----------|-----------|-----------------|
| Critical | Presentation will fail its purpose; audience will be confused or misled | Must fix before presenting |
| Major | Significantly weakens the presentation; noticeable quality gap | Should fix; presentation is suboptimal |
| Minor | Polish issue; would improve quality but not essential | Nice to fix; low priority |

## 1. Narrative Flow

Clear logical progression from motivation through evidence to conclusions.

### Criteria

| Criterion | Good | Problematic | Severity |
|-----------|------|-------------|----------|
| Logical progression | Each slide builds on the previous; no unexplained jumps | Topics appear out of order or without setup | Critical |
| Story arc | Hook -> Context -> Evidence -> Synthesis -> Takeaway | Missing motivation or abrupt ending | Critical |
| Slide transitions | Natural flow; audience anticipates the next point | Abrupt topic changes without bridges | Major |
| Glance test | Main point clear within 3 seconds of viewing each slide | Slide requires extended study to understand purpose | Major |
| Section bridges | Explicit transition slides or verbal cues between sections | Sections change without signaling | Minor |
| Conclusion landing | Final slides reinforce 2-4 key takeaways | Ends with "Questions?" without summarizing | Major |

### Anti-Patterns

- Wall of text on a single slide forcing the audience to read instead of listen
- "Outline" slide that is never referenced again
- Data presented before the question it answers is introduced
- Conclusion introduces new information not covered in the body

## 2. Audience Alignment

Content calibrated to the expected knowledge level and engagement style of the audience.

### Criteria

| Criterion | Good | Problematic | Severity |
|-----------|------|-------------|----------|
| Jargon level | Technical terms defined or appropriate to audience expertise | Undefined acronyms or jargon mismatch | Major |
| Assumed knowledge | Background slides fill gaps; no unexplained leaps | Assumes knowledge the audience lacks | Critical |
| Engagement strategies | Questions, examples, or relevance hooks maintain attention | Monotone delivery of facts with no engagement | Major |
| Scope calibration | Depth matches time and audience; no rushed or padded sections | Too much detail for a short talk or too shallow for experts | Major |
| Accessibility | Color-blind safe palettes; readable fonts; alt-text for figures | Relies solely on color to convey meaning | Minor |

### Anti-Patterns

- Using field-specific shorthand in a general audience talk
- Spending 5 minutes on background the audience already knows
- No motivating "why should you care?" framing in the first 2 slides
- Assuming the audience has read the paper or proposal

## 3. Timing Balance

Appropriate allocation of time across sections relative to their importance.

### Criteria

| Criterion | Good | Problematic | Severity |
|-----------|------|-------------|----------|
| Slides per section | Proportional to section importance | Introduction consumes >30% of slides | Major |
| Information density | 1-2 key points per slide; ~1.5 min per slide for conference | >3 key points per slide or <30 sec per slide | Critical |
| Pacing consistency | Even pacing; no sections that feel rushed or dragged | Last third crammed into remaining time | Critical |
| Time for questions | Adequate Q&A buffer planned | Presentation fills entire allotted time | Major |
| Section balance | Methods and results get proportional emphasis | Methods dominate at expense of results or vice versa | Major |

### Anti-Patterns

- 15 background slides followed by 3 rushed results slides
- Skipping slides during presentation because of time pressure
- Identical time allocation to all sections regardless of importance
- No time buffer for Q&A or technical difficulties

## 4. Content Depth

Appropriate level of detail -- neither too shallow nor too dense for the context.

### Criteria

| Criterion | Good | Problematic | Severity |
|-----------|------|-------------|----------|
| Completeness | All claims supported; no logical gaps | Key steps or results omitted | Critical |
| Accuracy | Data, citations, and claims are correct and current | Outdated references or incorrect statistics | Critical |
| Appropriate detail | Methodology sufficient for audience to evaluate validity | Either hand-waving or excessive minutiae | Major |
| Redundancy | Each slide adds new information | Multiple slides repeat the same point | Minor |
| Takeaway clarity | Each section ends with a clear "so what?" | Data presented without interpretation | Major |

### Anti-Patterns

- Presenting raw p-values without effect sizes or confidence intervals
- Claiming significance without showing the data
- Including every analysis performed rather than curating for the narrative
- Methods section that reads like a protocol rather than a rationale

## 5. Evidence Quality

Rigor of data presentation, citations, and support for claims.

### Criteria

| Criterion | Good | Problematic | Severity |
|-----------|------|-------------|----------|
| Data presentation | Clear figures with labeled axes, units, and legends | Unlabeled axes, missing units, or ambiguous legends | Critical |
| Citations | Key claims attributed; recent and relevant references | Uncited claims or outdated sole references | Major |
| Statistical reporting | Effect sizes, confidence intervals, appropriate tests | p-values alone without context or wrong test choice | Major |
| Claims support | Every conclusion traceable to presented evidence | Overclaiming beyond what data supports | Critical |
| Figure quality | High resolution; appropriate chart type for data | Pixelated images, pie charts for >5 categories, truncated axes | Major |

### Anti-Patterns

- Screenshot of a spreadsheet as a "figure"
- Citing only the presenter's own work when broader literature exists
- Bar charts without error bars for quantitative comparisons
- "Data not shown" for critical supporting evidence

## 6. Visual Design

Slide readability, layout consistency, and effective use of visual elements.

### Criteria

| Criterion | Good | Problematic | Severity |
|-----------|------|-------------|----------|
| Text density | 6-8 lines, 30-40 words per slide | >10 lines or >80 words per slide | Critical |
| Font size (body) | 24-28pt minimum | <20pt | Major |
| Font size (title) | 36-44pt | <28pt | Major |
| Figures per slide | 1-2 with clear labels | >3 figures or unlabeled figures | Major |
| Color contrast | WCAG AA ratio (4.5:1 minimum) | Low contrast text on background | Major |
| Bullet depth | 1 level preferred, 2 maximum | 3+ nested bullet levels | Minor |
| Layout consistency | Same positioning, fonts, and spacing throughout | Mixed styles, shifting layouts between slides | Major |
| Animations | Purposeful reveals that aid understanding | Decorative or distracting transitions | Minor |

### Anti-Patterns

- Full paragraphs of text copied from a manuscript
- Different fonts or color schemes across slides without reason
- Logo or decorative elements that crowd the content area
- Dark text on dark background or light text on light background

## Talk-Type Priority Matrix

Category priority by presentation mode (Critical > High > Medium > Low > N/A).

| Category | CONFERENCE | SEMINAR | DEFENSE | POSTER | JOURNAL_CLUB |
|----------|-----------|---------|---------|--------|--------------|
| Narrative Flow | High | Critical | High | Medium | High |
| Audience Alignment | Critical | High | High | High | Medium |
| Timing Balance | Critical | High | Medium | N/A | Medium |
| Content Depth | Medium | High | Critical | Medium | Critical |
| Evidence Quality | High | High | Critical | High | Critical |
| Visual Design | High | Medium | Medium | Critical | Low |

## Talk-Type Adjustment Notes

### CONFERENCE

- Time discipline is paramount -- strict enforcement by session chairs
- One message per slide principle; if a slide needs two points, split it
- Figures strongly preferred over tables (audience cannot read dense tables from distance)
- Maximum 3-4 concluding takeaways
- Must be self-contained; audience may not have read the paper
- Pattern reference: `talk/patterns/conference-standard.json` (12 slides, ~1.5 min/slide)

### SEMINAR

- Research program narrative arc -- show how aims connect across 45-60 minutes
- Transitions between sections are critical for maintaining coherence over long duration
- Deeper methodology is expected; audience wants to evaluate rigor
- Balance between comprehensive coverage and cognitive overload
- Future directions section signals an active research program
- Pattern reference: `talk/patterns/seminar-deep-dive.json` (35 slides, 5 sections)

### DEFENSE

- Committee has read the proposal -- do not read slides aloud or over-explain basics
- Preliminary data must be strong and clearly presented as proof of feasibility
- Pitfalls and alternatives demonstrate intellectual rigor and preparedness
- Innovation must be explicitly stated, not left for the committee to infer
- Q&A preparation often matters more than slide polish
- Pattern reference: `talk/patterns/defense-grant.json` (30 slides, 5 sections)

### POSTER

- Readability from 4-6 feet is the single most important criterion
- Maximum 50-75 words per section; visuals carry the narrative
- Visual hierarchy must guide the eye through the poster in reading order
- Must stand alone without presenter narration
- Include QR code or contact information for follow-up
- No pattern JSON (single-page layout, not sequential slides)

### JOURNAL_CLUB

- Present the paper's findings objectively before offering critique
- Strengths before limitations ordering maintains balanced evaluation
- Discussion questions should be specific and debatable, not generic
- Connect the paper's findings to the group's own research context
- Methodological critique depth: biases, confounders, study design limitations
- Pattern reference: `talk/patterns/journal-club.json` (12 slides, flat structure)

## Cross-References

| Resource | Path | Relevance |
|----------|------|-----------|
| Presentation types | `domain/presentation-types.md` | Audience, duration, format per mode |
| Talk structure | `patterns/talk-structure.md` | Slide density, visual elements, timing rules |
| Narrative patterns | `patterns/narrative-patterns.md` | Impact statements, specificity ladder, active voice |
| Writing standards | `standards/writing-standards.md` | Precision, evidence hierarchy, terminology |
| Conference pattern | `talk/patterns/conference-standard.json` | Expected structure for CONFERENCE mode |
| Seminar pattern | `talk/patterns/seminar-deep-dive.json` | Expected structure for SEMINAR mode |
| Defense pattern | `talk/patterns/defense-grant.json` | Expected structure for DEFENSE mode |
| Journal club pattern | `talk/patterns/journal-club.json` | Expected structure for JOURNAL_CLUB mode |
| Theme: academic | `talk/themes/academic-clean.json` | Palette, typography, spacing reference |
| Theme: clinical | `talk/themes/clinical-teal.json` | Palette, typography, spacing reference |
| Theme: institutional | `talk/themes/ucsf-institutional.json` | Palette, typography, spacing reference |

## Output Format Guidance

A critic agent consuming this rubric should structure feedback as follows.

### Per-Slide Findings

```
- Slide {N} ({slide_type}):
  - [{severity}] {category}: {finding}
  - [{severity}] {category}: {finding}
```

### Summary

```
- Critical: {count} findings
- Major: {count} findings
- Minor: {count} findings
- Top issues: {ranked list of most impactful findings}
- Strengths: {what the presentation does well}
```

### Recommendations

```
- Must fix: {critical items, ordered by impact}
- Should fix: {major items, ordered by effort}
- Nice to fix: {minor items}
```
