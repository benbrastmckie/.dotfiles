# Cost Forcing Questions

A framework for extracting specific cost data through structured questioning.

## Core Principle

**"Every cost has a basis"**

Vague cost estimates are not accepted. Each line item requires a unit, quantity, and unit cost with supporting rationale. Questions are asked one at a time via AskUserQuestion.

---

## Mode Selection

### Step 1: Determine Analysis Mode

Ask first to scope the engagement:

```
What type of cost analysis do you need?

- ESTIMATE: Rough order of magnitude for early planning
- BUDGET: Detailed operational budget with line items
- FORECAST: Forward-looking projection with scenarios
- ACTUALS: Historical data for variance analysis
```

| Mode | Precision | Time Investment | Output Detail |
|------|-----------|-----------------|---------------|
| **ESTIMATE** | +/- 50% | 15 minutes | Category totals only |
| **BUDGET** | +/- 15% | 1-2 hours | Full line items |
| **FORECAST** | +/- 25% | 30-60 minutes | Scenarios + assumptions |
| **ACTUALS** | Exact | Varies | Reconciled to records |

---

## The Core Forcing Questions

### Q1: Scope Definition

**Question**: "What time period and scope are we budgeting for?"

**Push Until**: Specific dates, entity boundary, currency

**Acceptable Answers**:
- "Q2 2026 (April-June) for US operations, in USD"
- "FY2027 full year, all entities, consolidated USD"
- "Next 18 months from April 2026"

**Anti-Patterns to Reject**:
- "Roughly the next year"
- "Our costs"
- "The usual stuff"

---

### Q2: Team Composition

**Question**: "Who are you paying? List each role, count, and compensation."

**Push Until**: Specific roles, headcount, compensation numbers

**Framework**:
```
Role: [Job title]
Count: [Number of people]
Compensation: [Annual fully-loaded cost or monthly]
Basis: [Market rate, actual offer, benchmark source]
```

**Acceptable Answers**:
- "3 senior engineers at $180K fully-loaded each (Levels.fyi Bay Area median)"
- "1 product designer, $120K salary + 30% benefits = $156K loaded"

**Anti-Patterns to Reject**:
- "A few engineers"
- "Normal startup salaries"
- "Whatever the market rate is"

---

### Q3: Infrastructure Costs

**Question**: "What systems and tools do you pay for? List provider, plan, and cost."

**Push Until**: Specific vendors, tiers, monthly/annual cost

**Framework**:
```
Provider: [Vendor name]
Service: [What you're using]
Tier/Plan: [Specific plan]
Cost: [Monthly or annual]
Basis: [Current bill, pricing page, quote]
```

**Acceptable Answers**:
- "AWS: $4,500/month current bill, expect $6,000 by Q3"
- "Figma: Team plan, $15/seat/month x 6 seats = $90/month"

**Anti-Patterns to Reject**:
- "Cloud costs"
- "The usual SaaS stack"
- "About $500/month for tools"

---

### Q4: Marketing & Sales Costs

**Question**: "What are you spending to acquire customers? Break down by channel."

**Push Until**: Specific channels, spend amounts, expected efficiency

**Framework**:
```
Channel: [Where you're spending]
Monthly Spend: [Amount]
Expected CAC: [Cost per customer if known]
Basis: [Current spend, planned increase, benchmark]
```

**Acceptable Answers**:
- "Google Ads: $5,000/month, currently $150 CAC"
- "Content marketing: $3,000/month (writer + SEO tools)"
- "Events: $10,000 one-time for SaaStr sponsorship"

**Anti-Patterns to Reject**:
- "Marketing budget"
- "Some ads"
- "Standard customer acquisition"

---

### Q5: Operations & Overhead

**Question**: "What fixed operational costs do you have? Include legal, accounting, insurance, office."

**Push Until**: Specific line items with monthly/annual amounts

**Common Items Checklist**:
- [ ] Legal retainer or fees
- [ ] Accounting/bookkeeping
- [ ] Business insurance (D&O, E&O, cyber)
- [ ] Office space or coworking
- [ ] Travel and meetings
- [ ] Professional services
- [ ] Bank fees

**Acceptable Answers**:
- "Legal: $2,500/month retainer with [Firm Name]"
- "Accounting: $800/month with Pilot"
- "Office: $0, fully remote"

---

### Q6: One-Time vs Recurring

**Question**: "Which costs are one-time vs recurring? When do one-time costs hit?"

**Push Until**: Clear classification, timing for one-time

**Framework**:
```
One-Time Costs:
- [Item]: $[Amount] in [Month]

Recurring Costs:
- [Item]: $[Amount]/month starting [Month]
```

**Important Distinction**:
- Hiring costs: One-time (recruiting, onboarding)
- Salaries: Recurring
- Equipment: One-time
- Software licenses: Recurring (usually)

---

### Q7: Contingency & Unknown

**Question**: "What haven't we covered? What's your contingency buffer?"

**Push Until**: Explicit unknowns acknowledged, buffer percentage stated

**Standard Contingencies**:
| Mode | Buffer | Rationale |
|------|--------|-----------|
| ESTIMATE | 20-30% | High uncertainty |
| BUDGET | 10-15% | Reasonable precision |
| FORECAST | 15-20% | Future uncertainty |
| ACTUALS | 0% | Known values |

**Acceptable Answers**:
- "10% contingency on infrastructure for unexpected scale"
- "I'm uncertain about legal costs for patent work - maybe $20-50K"

---

## Smart Routing by Mode

| Mode | Focus Questions | Skip/Minimize |
|------|-----------------|---------------|
| ESTIMATE | Q1, Q2, Q3 (category level) | Detail on Q4, Q5, Q6 |
| BUDGET | All questions, full detail | None |
| FORECAST | Q1, Q2, Q3, Q7 (scenarios) | Q5 detail if stable |
| ACTUALS | Data collection, not questions | All (pull from records) |

---

## Push-Back Patterns

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "A few engineers" | "How many exactly? What's their level and compensation?" |
| "Normal cloud costs" | "What provider? What's your current monthly bill?" |
| "Marketing budget" | "Which channels? What's the spend per channel?" |
| "Usual overhead" | "Can you list each line item? Legal, accounting, insurance?" |
| "Standard rates" | "What specific rate? What's your source for 'standard'?" |
| "Roughly $X" | "Is that based on a quote, current bill, or estimate?" |

---

## Data Quality Assessment

After gathering answers, assess each category:

| Quality Level | Criteria | Action |
|---------------|----------|--------|
| **High** | Actual bills, signed contracts, quotes | Use as-is |
| **Medium** | Benchmarks, comparable data, estimates | Note assumptions |
| **Low** | Guesses, "roughly", "probably" | Flag for validation |

---

## Output Format

Document all responses in structured format:

```json
{
  "mode": "BUDGET",
  "scope": {
    "period": "Q2 2026",
    "entity": "US operations",
    "currency": "USD"
  },
  "personnel": [
    {
      "role": "Senior Engineer",
      "count": 3,
      "annual_loaded": 180000,
      "basis": "Levels.fyi Bay Area median"
    }
  ],
  "infrastructure": [
    {
      "provider": "AWS",
      "service": "Production + staging",
      "monthly": 4500,
      "basis": "Current bill"
    }
  ],
  "marketing": [],
  "operations": [],
  "one_time": [],
  "contingency": {
    "percent": 10,
    "rationale": "Known scope, low uncertainty"
  },
  "data_quality": {
    "personnel": "high",
    "infrastructure": "high",
    "marketing": "medium",
    "operations": "medium"
  }
}
```

---

## Implementation Notes

### One Question at a Time

Never batch questions. Each question should be:
1. Asked via individual AskUserQuestion
2. Answered before proceeding
3. Pushed back on if vague
4. Only then move to next question

### Category Completion

Within a category (e.g., Personnel), iterate through all roles before moving to next category:

```
"You mentioned 3 engineers. Any other personnel?"
-> "1 designer"
"Got it. Any other roles? Product, sales, support?"
-> "Not yet"
"Okay, moving to infrastructure costs..."
```

### Document Assumptions

For each cost with uncertainty, note:
- The assumption made
- The basis for the assumption
- When it should be validated

---

## References

- [Startup Financial Model Best Practices](https://www.causal.app/blog/financial-model-best-practices)
- [SaaS Cost Benchmarks](https://openviewpartners.com/expansion-saas-benchmarks/)
