# Market Sizing Template

Template for TAM/SAM/SOM market analysis artifacts.

## Output File Format

**Location**: `founder/market-sizing-{datetime}.md`

---

## Template

```markdown
# Market Sizing Analysis

**Project**: {project_name}
**Date**: {YYYY-MM-DD}
**Mode**: {VALIDATE|SIZE|SEGMENT|DEFEND}
**Prepared by**: Claude

---

## Executive Summary

{2-3 sentence summary of market opportunity and key findings}

---

## Market Definition

### Problem Statement

{What specific problem does your product solve?}

### Target Customer

{Who experiences this problem? Be specific.}

| Dimension | Definition |
|-----------|------------|
| Industry | {e.g., SaaS, Healthcare, Finance} |
| Size | {e.g., SMB 10-100 employees} |
| Geography | {e.g., North America} |
| Role | {e.g., Marketing managers} |

---

## TAM: Total Addressable Market

**Value**: ${amount}

### Methodology: {Top-Down | Bottom-Up | Value Theory}

{Explanation of calculation approach}

### Calculation

```
{Step-by-step calculation}
{Show all assumptions}
{Include data sources}
```

### Data Sources

| Source | Data Point | Confidence |
|--------|-----------|------------|
| {Source 1} | {What it provided} | {High|Medium|Low} |
| {Source 2} | {What it provided} | {High|Medium|Low} |

---

## SAM: Serviceable Available Market

**Value**: ${amount} ({X}% of TAM)

### Narrowing Factors

| Factor | TAM Reduction | Rationale |
|--------|---------------|-----------|
| Geography | -{X}% | {Why you can't serve certain regions} |
| Segment | -{X}% | {Why you can't serve certain segments} |
| Technical | -{X}% | {Technical limitations} |
| Regulatory | -{X}% | {Compliance constraints} |

### Calculation

```
TAM: ${TAM}
  - {Factor 1}: -{X}%
  - {Factor 2}: -{X}%
  - {Factor 3}: -{X}%
  = SAM: ${SAM}
```

---

## SOM: Serviceable Obtainable Market

**Value**: ${amount} ({X}% of SAM)

### Capture Rate Assumptions

| Timeframe | Capture Rate | SOM Value | Rationale |
|-----------|--------------|-----------|-----------|
| Year 1 | {0.5-2}% | ${amount} | {Why this is realistic} |
| Year 3 | {2-5}% | ${amount} | {Growth trajectory} |
| Year 5 | {5-15}% | ${amount} | {Market position} |

### Competitive Context

| Competitor | Est. Market Share | Your Advantage |
|------------|-------------------|----------------|
| {Competitor 1} | {X}% | {How you differentiate} |
| {Competitor 2} | {X}% | {How you differentiate} |
| {Competitor 3} | {X}% | {How you differentiate} |

---

## Market Visualization

```
                    ┌─────────────────────────────────┐
                    │                                 │
                    │         TAM: ${TAM}             │
                    │   Total market opportunity      │
                    │                                 │
                    │    ┌───────────────────────┐    │
                    │    │                       │    │
                    │    │      SAM: ${SAM}      │    │
                    │    │   Segments we can     │    │
                    │    │   realistically serve │    │
                    │    │                       │    │
                    │    │   ┌───────────────┐   │    │
                    │    │   │               │   │    │
                    │    │   │  SOM: ${SOM}  │   │    │
                    │    │   │  Our target   │   │    │
                    │    │   │               │   │    │
                    │    │   └───────────────┘   │    │
                    │    │                       │    │
                    │    └───────────────────────┘    │
                    │                                 │
                    └─────────────────────────────────┘
```

---

## Key Assumptions

| # | Assumption | Sensitivity | If Wrong |
|---|------------|-------------|----------|
| 1 | {Assumption} | {High|Medium|Low} | {Impact if incorrect} |
| 2 | {Assumption} | {High|Medium|Low} | {Impact if incorrect} |
| 3 | {Assumption} | {High|Medium|Low} | {Impact if incorrect} |

---

## Red Flags & Validation

### VC Threshold Check

| Criterion | Status | Notes |
|-----------|--------|-------|
| TAM > $1B | {Pass|Fail|N/A} | {Commentary} |
| SAM > $100M | {Pass|Fail|N/A} | {Commentary} |
| SOM credible | {Pass|Fail} | {Commentary} |
| Bottom-up for SAM/SOM | {Yes|No} | {Commentary} |

### Validation Next Steps

1. {Validation action 1}
2. {Validation action 2}
3. {Validation action 3}

---

## Investor One-Pager

### The Opportunity

{1 paragraph summary suitable for investor conversations}

### Key Numbers

- **TAM**: ${TAM} ({source})
- **SAM**: ${SAM} ({rationale})
- **SOM Y1**: ${SOM_Y1} ({basis})
- **SOM Y3**: ${SOM_Y3} ({growth trajectory})

### Why This Market, Why Now

{2-3 bullets on market timing and opportunity}

---

## Appendix: Detailed Calculations

{Any detailed math or data tables}

---

## Appendix: Source Links

{Links to all referenced data sources}
```

---

## Section Guidance

### Executive Summary

- Lead with opportunity size
- Highlight key insight or finding
- Note any concerns about assumptions

### TAM Methodology Selection

| Methodology | When to Use |
|-------------|-------------|
| **Top-Down** | Well-established market with industry reports |
| **Bottom-Up** | Novel market or when you have customer data |
| **Value Theory** | No comparable market exists |

### SOM Capture Rates

| Stage | Typical Range | Notes |
|-------|---------------|-------|
| Pre-PMF | 0.5-1% | Prove you can capture any |
| Post-PMF | 1-3% | Demonstrate repeatability |
| Scale | 3-10% | Show leadership trajectory |
| Leader | 10-30% | Dominant position |

### Assumptions Sensitivity

Rank assumptions by impact:
- **High**: >20% change in market size if wrong
- **Medium**: 5-20% change if wrong
- **Low**: <5% change if wrong

---

## Checklist Before Delivery

- [ ] All numbers have sources cited
- [ ] Bottom-up calculation included (VCs prefer)
- [ ] Assumptions are explicit and testable
- [ ] Competitive context provides reality check
- [ ] Red flags section is honest about weaknesses
- [ ] Investor one-pager is standalone readable
