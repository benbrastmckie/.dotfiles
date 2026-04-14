# Decision-Making Frameworks

Structured approaches to strategic decisions, inspired by CEO cognitive patterns.

## Two-Way vs One-Way Doors

### Framework

**Two-Way Doors** (Reversible):
- Decision can be changed with low cost
- Consequences are easily undone
- Learning can happen through action

**One-Way Doors** (Irreversible):
- Decision is difficult or impossible to reverse
- High switching costs or permanent consequences
- Must get it right the first time

### Decision Protocol

```
┌─────────────────────────────────────────────────────┐
│                 Decision Point                      │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │ Is this reversible?  │
              │ (Cost to undo < 10%  │
              │  of cost to do)      │
              └──────────┬───────────┘
                         │
           ┌─────────────┴─────────────┐
           │                           │
           ▼                           ▼
   ┌───────────────┐           ┌───────────────┐
   │  TWO-WAY DOOR │           │  ONE-WAY DOOR │
   │               │           │               │
   │ - Move fast   │           │ - Slow down   │
   │ - 70% info ok │           │ - 90% info    │
   │ - Bias action │           │ - Seek counsel│
   │ - Learn fast  │           │ - Document why│
   └───────────────┘           └───────────────┘
```

### Examples

| Decision | Type | Approach |
|----------|------|----------|
| Feature naming | Two-way | Ship and rename if needed |
| Price point testing | Two-way | A/B test, iterate |
| Tech stack choice | One-way | Research thoroughly |
| Co-founder selection | One-way | Take time, validate fit |
| Fundraising terms | One-way | Negotiate carefully |
| Hiring senior leader | One-way | Multiple interviews |
| UI color scheme | Two-way | Ship and learn |
| Domain name | One-way | Secure it right |

---

## Inversion Framework

"Invert, always invert" - Charlie Munger

### Process

1. **Forward Question**: What should we do to succeed?
2. **Inverted Question**: What would guarantee failure?
3. **Cross-Reference**: Does our plan avoid all failure modes?
4. **Risk Registry**: Document and mitigate failure modes

### Application Template

```markdown
## Forward Analysis: How do we win?

1. [Success factor 1]
2. [Success factor 2]
3. [Success factor 3]

## Inverted Analysis: How do we fail?

1. [Failure mode 1]
2. [Failure mode 2]
3. [Failure mode 3]

## Cross-Reference

| Success Factor | Potential Failure Mode | Mitigation |
|----------------|------------------------|------------|
| [Factor 1] | [Related failure] | [How to prevent] |
| [Factor 2] | [Related failure] | [How to prevent] |

## Failure Modes Registry

| Failure Mode | Likelihood | Impact | Early Warning | Response |
|--------------|------------|--------|---------------|----------|
| [Mode 1] | H/M/L | H/M/L | [Signal] | [Action] |
```

### Examples

| Forward Question | Inverted Question |
|------------------|-------------------|
| How do we get users? | What would make users leave? |
| How do we raise funding? | What would make VCs say no? |
| How do we scale? | What would break at scale? |
| How do we beat competitors? | How could competitors beat us? |

---

## Focus as Subtraction

### Principle

"Deciding what NOT to do is as important as deciding what to do."

### Process

1. **List all options**: Brainstorm everything possible
2. **Force-rank**: Order by impact and feasibility
3. **Draw the line**: Top 3-5 items above, rest below
4. **Document exclusions**: Why each item is NOT in scope
5. **Communicate clearly**: Share what you're NOT doing

### NOT IN SCOPE Template

```markdown
## NOT IN SCOPE (with rationale)

| Initiative | Reason for Exclusion | Revisit When |
|------------|----------------------|--------------|
| Mobile app | Core users desktop-first | After 1000 DAU |
| Enterprise tier | Requires SOC2 (6mo) | After Series A |
| Internationalization | Focus on core market | After $1M ARR |
| API access | Low demand signal | After 10 requests |

## Commitment

We will NOT pursue the above initiatives in this planning period.
If circumstances change, we will re-evaluate explicitly.
```

### Benefits

1. **Clarity**: Team knows what's off-limits
2. **Speed**: Fewer decisions to make
3. **Accountability**: Can't add scope silently
4. **Communication**: Stakeholders understand constraints

---

## Speed Calibration

### Information Thresholds

| Decision Type | Information Needed | Max Decision Time |
|---------------|-------------------|-------------------|
| Tactical (daily) | 50% | Same day |
| Operational (weekly) | 70% | 2-3 days |
| Strategic (quarterly) | 80% | 1-2 weeks |
| Irreversible (rare) | 90% | As needed |

### Speed vs Quality Trade-off

```
                     Decision Quality
                  Low              High
             ┌───────────────┬───────────────┐
        Fast │   DANGEROUS   │   IDEAL       │
             │   Moving fast │   Fast AND    │
    Speed    │   but wrong   │   right       │
             ├───────────────┼───────────────┤
        Slow │   WASTEFUL    │   ACCEPTABLE  │
             │   Slow AND    │   Slow but    │
             │   wrong       │   right       │
             └───────────────┴───────────────┘
```

### Speeding Up Decisions

| Blocker | Solution |
|---------|----------|
| Missing data | Define minimum viable data |
| Fear of wrong choice | Identify reversibility |
| Need consensus | Define decision owner |
| Analysis paralysis | Set decision deadline |
| Unclear criteria | Define success metrics |

---

## Leverage Assessment

### Leverage Matrix

```
                     Effort Required
                   Low            High
              ┌────────────┬────────────┐
         High │  DO FIRST  │  CONSIDER  │
    Impact    │  (Leverage)│  CAREFULLY │
              ├────────────┼────────────┤
         Low  │  IF TIME   │  AVOID     │
              │  PERMITS   │            │
              └────────────┴────────────┘
```

### High Leverage Indicators

- **One-to-Many**: Action benefits multiple areas
- **Compounding**: Returns grow over time
- **Enabling**: Unlocks other opportunities
- **De-Bottlenecking**: Removes constraint for others

### Leverage Assessment Questions

1. Does this action enable other actions?
2. Will the impact grow or shrink over time?
3. Does this remove a bottleneck?
4. Is this a one-time cost for recurring benefit?
5. Would this be hard for competitors to replicate?

### Example Analysis

| Initiative | Effort | Impact | Leverage Score | Priority |
|------------|--------|--------|----------------|----------|
| Hire senior eng | High | High | Medium | 2 |
| Automate deploy | Medium | High | High (compounds) | 1 |
| Redesign homepage | Low | Low | Low | 4 |
| Write docs | Low | Medium | Medium (enables) | 3 |

---

## Decision Documentation

### Decision Record Template

```markdown
# Decision: [Title]

**Date**: [YYYY-MM-DD]
**Owner**: [Name]
**Status**: [Proposed | Decided | Implemented]

## Context
[What situation led to this decision?]

## Decision
[What was decided?]

## Rationale
[Why was this decided?]

## Alternatives Considered
1. [Alternative 1]: [Why rejected]
2. [Alternative 2]: [Why rejected]

## Consequences
- [Expected positive outcome]
- [Expected negative outcome or risk]

## Door Type
[Two-way | One-way]
[If one-way, what makes it irreversible?]

## Review Date
[When should this decision be revisited?]
```

---

## References

- [Thinking in Bets - Annie Duke](https://www.annieduke.com/books/)
- [Poor Charlie's Almanack](https://www.stripe.press/poor-charlies-almanack)
- [The Effective Executive - Peter Drucker](https://www.drucker.institute/)
