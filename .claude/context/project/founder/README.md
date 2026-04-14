# Founder Context

Strategic business analysis context for founders and entrepreneurs.

## Overview

This context directory provides domain knowledge, decision frameworks, templates, and a deck library for strategic business analysis. Inspired by Y Combinator office hours methodology and CEO cognitive patterns from gstack. Version 3.0 adds legal analysis, financial modeling, project planning, pitch deck construction, and Typst PDF output.

## Directory Structure

```
founder/
├── README.md                              (this file)
├── domain/                                Domain knowledge and frameworks (8 files)
│   ├── business-frameworks.md             TAM/SAM/SOM, business model canvas
│   ├── financial-analysis.md              Financial modeling, projections, metrics
│   ├── legal-frameworks.md                Corporate structure, IP, compliance
│   ├── migration-guide.md                 Version migration reference
│   ├── spreadsheet-frameworks.md          Cost structure, formulas, JSON export
│   ├── strategic-thinking.md              CEO patterns, YC principles
│   ├── timeline-frameworks.md             WBS, milestones, PERT, critical path
│   └── workflow-reference.md              Command workflows and agent routing
├── patterns/                              Reusable analysis patterns (11 files)
│   ├── contract-review.md                 Contract clause analysis patterns
│   ├── cost-forcing-questions.md          Cost-specific forcing questions
│   ├── decision-making.md                 Two-way doors, inversion, focus
│   ├── financial-forcing-questions.md     Financial model forcing questions
│   ├── forcing-questions.md               General question framework for specificity
│   ├── legal-planning.md                  Legal strategy and compliance planning
│   ├── mode-selection.md                  Operational modes pattern
│   ├── pitch-deck-structure.md            Deck structure guidance and slide design
│   ├── project-planning.md               Project scoping and timeline patterns
│   ├── slidev-deck-template.md            Slidev project scaffolding template
│   └── yc-compliance-checklist.md         YC format compliance validation rules
├── templates/                             Artifact templates (5 markdown + 7 Typst)
│   ├── competitive-analysis.md            Competitor landscape template
│   ├── contract-analysis.md               Contract review output template
│   ├── financial-analysis.md              Financial projections template
│   ├── gtm-strategy.md                    Go-to-market strategy template
│   ├── market-sizing.md                   TAM/SAM/SOM analysis template
│   └── typst/                             Typst PDF templates (7 files)
│       ├── competitive-analysis.typ       Competitor landscape PDF
│       ├── contract-analysis.typ          Contract review PDF
│       ├── cost-breakdown.typ             Cost analysis PDF
│       ├── gtm-strategy.typ              Go-to-market PDF
│       ├── market-sizing.typ              Market sizing PDF
│       ├── project-timeline.typ           Project timeline PDF
│       └── strategy-template.typ          Base styles and components
└── deck/                                  Slidev deck library (49 items, 6 categories)
    ├── README.md                          Comprehensive deck library documentation
    ├── index.json                         Library index for agent navigation
    ├── themes/                            5 Slidev theme presets
    ├── patterns/                          5 deck structural patterns
    ├── animations/                        6 animation pattern references
    ├── styles/                            9 composable CSS presets
    ├── components/                        4 reusable Vue components
    └── contents/                          23 slide content templates (11 topics)
```

## Key Concepts

### Forcing Questions

One question per interaction, push for specificity. Vague answers are not accepted.

**The Six Forcing Questions**:
1. **Demand Reality**: What evidence proves someone wants this?
2. **Status Quo**: What do users do today to solve this?
3. **Desperate Specificity**: Name one specific person who needs this
4. **Narrowest Wedge**: What's the smallest version someone would pay for?
5. **Observation**: What surprised you watching someone use this?
6. **Future-Fit**: Does your product become more essential over time?

### Decision Frameworks

- **Two-Way Doors**: Reversible decisions -- move fast, 70% information
- **One-Way Doors**: Irreversible decisions -- be rigorous, 90% information
- **Inversion**: Ask both "How do we win?" and "What makes us fail?"
- **Focus as Subtraction**: Document what NOT to do

### Operational Modes

Commands offer 3-4 modes giving users explicit scope control:
- Selection happens early in interaction
- All subsequent analysis adapts to mode
- Mode switches are explicit and confirmed

## Related Commands

| Command | Context Used | Purpose |
|---------|--------------|---------|
| `/market` | `domain/business-frameworks`, `patterns/forcing-questions`, `templates/market-sizing` | Market sizing analysis |
| `/analyze` | `domain/business-frameworks`, `patterns/forcing-questions`, `templates/competitive-analysis` | Competitive analysis |
| `/strategy` | `domain/strategic-thinking`, `patterns/decision-making`, `templates/gtm-strategy` | GTM strategy development |
| `/sheet` | `domain/spreadsheet-frameworks`, `patterns/cost-forcing-questions` | Cost breakdown spreadsheet |
| `/legal` | `domain/legal-frameworks`, `patterns/contract-review`, `patterns/legal-planning`, `templates/contract-analysis` | Contract review and legal analysis |
| `/project` | `domain/timeline-frameworks`, `patterns/project-planning` | Project scoping and timeline planning |
| `/finance` | `domain/financial-analysis`, `patterns/financial-forcing-questions`, `templates/financial-analysis` | Financial modeling and projections |
| `/deck` | `deck/` library, `patterns/pitch-deck-structure`, `patterns/slidev-deck-template` | Pitch deck construction with Slidev |

## Context Discovery

Context files are loaded automatically by agents via `index-entries.json`, which maps each file to the agents, languages, and commands that need it. The extension loader merges these entries into the main `.claude/context/index.json` at load time.

Query example -- find all context for the `/legal` command:

```
entries where load_when.commands contains "/legal"
```

This returns `domain/legal-frameworks.md`, `patterns/contract-review.md`, `patterns/legal-planning.md`, and `templates/contract-analysis.md`.

Manual loading via @-references is also supported:

```markdown
@.claude/extensions/founder/context/project/founder/domain/business-frameworks.md
@.claude/extensions/founder/context/project/founder/templates/market-sizing.md
```

## Deck Library

The `deck/` subdirectory contains a complete Slidev deck library with 49 indexed items across 6 categories: themes, patterns, animations, styles, components, and content templates. Agents use `deck/index.json` to select and compose items into pitch decks.

See [deck/README.md](deck/README.md) for full documentation including the content slot system, agent navigation patterns, and library extension guide.

## References

- [gstack (Garry Tan)](https://github.com/garrytan/gstack)
- [YC Library](https://www.ycombinator.com/library)
- [Paul Graham Essays](http://paulgraham.com/articles.html)
- [Business Model Canvas](https://www.strategyzer.com/canvas/business-model-canvas)
