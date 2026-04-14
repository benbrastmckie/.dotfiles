# Competitive Analysis Template

Template for competitive landscape and positioning analysis artifacts.

## Output File Format

**Location**: `founder/competitive-analysis-{datetime}.md`

---

## Template

```markdown
# Competitive Analysis

**Project**: {project_name}
**Date**: {YYYY-MM-DD}
**Mode**: {LANDSCAPE|DEEP|POSITION|BATTLE}
**Prepared by**: Claude

---

## Executive Summary

{2-3 sentence summary of competitive landscape and key positioning insight}

---

## Competitive Landscape

### Categories

| Category | Description | Key Players |
|----------|-------------|-------------|
| **Direct** | Same problem, same solution | {Player 1, Player 2} |
| **Indirect** | Same problem, different solution | {Player 1, Player 2} |
| **Potential** | Adjacent, could enter | {Player 1, Player 2} |

### Status Quo

**Current Solution**: {What do customers do today without any product?}

This is your real competitor. Every other competitor is fighting for share of customers who have already decided to switch from status quo.

---

## Competitor Profiles

### {Competitor 1 Name}

| Dimension | Assessment |
|-----------|------------|
| **Category** | Direct / Indirect / Potential |
| **Positioning** | "{Their tagline or positioning statement}" |
| **Target Customer** | {Who do they serve?} |
| **Pricing** | {Pricing model and price points} |
| **Founded** | {Year} |
| **Funding** | {Total raised, last round} |
| **Team Size** | {Employees} |
| **Key Customers** | {Notable logos} |

**Strengths**:
1. {What they do better than you}
2. {Another strength}
3. {Another strength}

**Weaknesses**:
1. {Where they are vulnerable}
2. {Another weakness}
3. {Another weakness}

**Recent Moves** (last 6 months):
- {Product launch, funding, hiring, etc.}
- {Another move}

---

### {Competitor 2 Name}

{Same structure as above}

---

### {Competitor 3 Name}

{Same structure as above}

---

## Feature Comparison

| Feature | Us | {Comp 1} | {Comp 2} | {Comp 3} |
|---------|-----|----------|----------|----------|
| {Feature 1} | {status} | {status} | {status} | {status} |
| {Feature 2} | {status} | {status} | {status} | {status} |
| {Feature 3} | {status} | {status} | {status} | {status} |
| {Feature 4} | {status} | {status} | {status} | {status} |
| {Feature 5} | {status} | {status} | {status} | {status} |

**Legend**: [check] = Yes, [x] = No, ~ = Partial, ? = Unknown

---

## Positioning Map

### Axis Selection

| Axis | Rationale |
|------|-----------|
| **X-Axis**: {Dimension 1} | {Why this dimension matters to customers} |
| **Y-Axis**: {Dimension 2} | {Why this dimension matters to customers} |

### 2x2 Map

```
                              {Y-Axis Label}
                           Low              High
                        ┌──────────────┬──────────────┐
                        │              │              │
                   High │   [Comp A]   │   [US]       │
                        │              │   [Comp B]   │
        {X-Axis Label}  │              │              │
                        ├──────────────┼──────────────┤
                        │              │              │
                   Low  │   [Comp C]   │   [Comp D]   │
                        │              │              │
                        │              │              │
                        └──────────────┴──────────────┘
```

### White Space Analysis

**Identified White Spaces**:
1. {Quadrant or position not occupied}
2. {Another opportunity}

**Recommendation**: {Which white space to target and why}

---

## Battle Cards

### vs {Competitor 1}

**When we encounter them**: {Sales situation where this competitor appears}

**Their pitch**: "{What they say about themselves}"

**Our response**: "{How we differentiate}"

**Objections they raise about us**:
| Objection | Response |
|-----------|----------|
| "{Objection 1}" | "{Our response}" |
| "{Objection 2}" | "{Our response}" |

**Objections to raise about them**:
| Objection | Support |
|-----------|---------|
| "{Weakness 1}" | "{Evidence or framing}" |
| "{Weakness 2}" | "{Evidence or framing}" |

**Win/Lose Signals**:
- **Likely Win**: {Customer characteristic that favors us}
- **Likely Lose**: {Customer characteristic that favors them}

---

### vs {Competitor 2}

{Same structure as above}

---

## Strategic Implications

### Attack

Where can we win directly?

| Opportunity | Approach | Expected Impact |
|-------------|----------|-----------------|
| {Segment/feature to attack} | {How to win} | {Market share or revenue} |

### Defend

Where must we match competitors?

| Threat | Response | Priority |
|--------|----------|----------|
| {Competitor move} | {Our response} | {High|Medium|Low} |

### Ignore

What battles aren't worth fighting?

| Battle | Why Ignore |
|--------|------------|
| {Feature/segment} | {Rationale} |

### Differentiate

What makes us categorically different?

{2-3 sentences on sustainable differentiation that competitors cannot easily copy}

---

## What I Noticed

{Mentor-style observations about competitive dynamics, blind spots, or strategic opportunities}

---

## Next Steps

1. {Validation action}
2. {Strategic action}
3. {Monitoring action}
```

---

## Section Guidance

### Competitor Categories

- **Direct**: Solving same problem with same approach
- **Indirect**: Solving same problem differently (including manual processes)
- **Potential**: Not competing today but could enter

### Status Quo Importance

The biggest competitor is often "do nothing" or "use spreadsheets." Always analyze the status quo as a competitor.

### Feature Comparison Tips

- Focus on features customers actually care about
- Include "table stakes" features for completeness
- Note where "partial" means (what's missing?)

### Positioning Map Axes

Good axes:
- Enterprise vs SMB focus
- Self-serve vs high-touch
- Breadth vs depth
- Price vs features
- Horizontal vs vertical

Bad axes:
- "Good" vs "Bad" (too subjective)
- Features you don't have (biased)

### Battle Card Usage

Battle cards are for sales teams. Each card should:
- Fit on one page
- Be usable in real-time during calls
- Have specific, quotable responses
- Include win/lose signals for qualification

---

## Checklist Before Delivery

- [ ] All major competitors profiled
- [ ] Status quo analyzed as competitor
- [ ] Positioning map has clear, defensible axes
- [ ] Battle cards are practical and specific
- [ ] White space opportunities identified
- [ ] Strategic implications are actionable
- [ ] "What I Noticed" adds non-obvious insight
