# Financial Analysis Forcing Questions

A framework for extracting financial data through structured questioning for financial analysis reports. Produces `financial-metrics.json` consumed by `financial-analysis.typ`.

## Core Principle

**"Every number has a source"**

Financial figures without sources are not accepted. Each metric requires a value, source reference, and confidence level. Questions are asked one at a time via AskUserQuestion.

---

## Mode Selection

### Step 1: Determine Analysis Mode

Ask first to scope the engagement:

```
What type of financial analysis do you need?

- REVIEW: General financial health assessment
- DILIGENCE: Due diligence deep dive with verification
- AUDIT: Detailed verification and reconciliation focus
- FORECAST: Forward-looking projections and scenarios
```

| Mode | Focus | Time Investment | Detail Level |
|------|-------|-----------------|--------------|
| **REVIEW** | Key metrics and health | 15-30 minutes | Summary ratios |
| **DILIGENCE** | Full verification | 1-2 hours | Line-item verification |
| **AUDIT** | Reconciliation | 2-3 hours | Three-way matching |
| **FORECAST** | Projections | 30-60 minutes | Scenarios + assumptions |

---

## Smart Routing by Mode

| Mode | Focus Questions | Skip/Minimize |
|------|-----------------|---------------|
| REVIEW | Q1, Q2, Q3, Q5 (key ratios) | Q4 detail, Q7, Q8 |
| DILIGENCE | All questions, full detail | None |
| AUDIT | Q1, Q4 (verification focus), Q6 | Q3 marketing detail, Q7 scenarios |
| FORECAST | Q1, Q2, Q3, Q7, Q8 | Q4 verification, Q6 red flags |

---

## The Core Forcing Questions

### Q1: Scope Definition

**Question**: "What company/entity are we analyzing, and for what period?"

**Push Until**: Entity name, time period, currency, document type

**Framework**:
```
Entity: [Company or division name]
Period: [Fiscal year, quarter, or date range]
Currency: [USD, EUR, etc.]
Purpose: [Investment review, board report, fundraising, internal]
```

**Acceptable Answers**:
- "Acme SaaS Inc, FY2025 (Jan-Dec), USD, for Series A diligence"
- "Engineering division Q1 2026, USD, quarterly board review"

**Anti-Patterns to Reject**:
- "Our company"
- "Recent financials"

---

### Q2: Revenue Data

**Question**: "What is your revenue? Break down ARR/MRR, growth rate, and revenue quality."

**Push Until**: Specific revenue figures with sources

**Framework**:
```
ARR (or Annual Revenue): $[amount] - Source: [P&L, Stripe, contracts]
MRR: $[amount] - Source: [billing system, manual calc]
YoY Growth: [X]% - Basis: [prior year comparison]
Revenue Mix: [X]% recurring, [Y]% one-time
Top Customer Concentration: [X]% of revenue
```

**Acceptable Answers**:
- "ARR is $2.4M per Stripe dashboard, growing 85% YoY from $1.3M"
- "MRR is $200K, 92% recurring SaaS, top customer is 12% of revenue"

**Anti-Patterns to Reject**:
- "Revenue is growing fast"
- "We have good recurring revenue"

---

### Q3: Expense Breakdown

**Question**: "What are your expenses by category? Personnel, infrastructure, marketing, operations."

**Push Until**: Monthly/annual amounts per category with basis

**Framework**:
```
Category: [Personnel/Infrastructure/Marketing/Operations/Other]
Monthly: $[amount]
Annual: $[amount]
Trend: [Growing/Stable/Declining]
Basis: [Current P&L, actual bills, budget]
```

**Note**: Reuse cost-forcing-questions.md patterns (Q2-Q5) for detailed breakdowns within each category if mode is DILIGENCE or AUDIT.

**Acceptable Answers**:
- "Personnel: $120K/month (8 FTEs avg $15K loaded), growing as we hire"
- "Infrastructure: $18K/month (AWS $12K, tools $6K), current bills"

**Anti-Patterns to Reject**:
- "Normal startup expenses"
- "About $150K/month total"

---

### Q4: Cash Position

**Question**: "What is your current cash position? Include balance, burn rate, and recent funding."

**Push Until**: Specific balance, burn, and runway numbers

**Framework**:
```
Cash Balance: $[amount] as of [date]
Monthly Net Burn: $[amount] (revenue minus expenses)
Monthly Gross Burn: $[amount] (total expenses)
Runway: [X] months at current burn
Restricted Cash: $[amount] if any
Recent Funding: [amount, date, type] if recent
```

**Acceptable Answers**:
- "Cash: $3.2M as of March 31, net burn $50K/month, 64 months runway"
- "Cash: $800K, gross burn $166K, MRR $116K, net burn $50K, ~16 months"

**Anti-Patterns to Reject**:
- "We have enough cash"
- "Runway is fine"

---

### Q5: Key Ratios and Metrics

**Question**: "What are your key SaaS/financial ratios? Gross margin, LTV:CAC, Rule of 40, etc."

**Push Until**: Specific ratio values with calculation basis

**Framework**:
```
Gross Margin: [X]% - Basis: [revenue minus COGS / revenue]
Operating Margin: [X]% - Basis: [EBIT / revenue]
LTV:CAC Ratio: [X]:1 - Basis: [LTV calc, CAC calc]
CAC Payback: [X] months
Burn Multiple: [X]x - Basis: [net burn / net new ARR]
Net Dollar Retention: [X]%
Rule of 40: [X]% - Basis: [growth rate + profit margin]
```

**Acceptable Answers**:
- "Gross margin 72% (COGS is mainly hosting), LTV:CAC is 4.2:1"
- "Burn multiple is 1.8x, Rule of 40 is 55% (85% growth - 30% margin)"

**Anti-Patterns to Reject**:
- "Our unit economics are good"
- "Margins are healthy"

---

### Q6: Verification Data (DILIGENCE/AUDIT modes)

**Question**: "What source documents are available for verification? Any known discrepancies?"

**Push Until**: Specific documents, cross-reference results

**Framework**:
```
Available Documents:
- [ ] Income statement (period, source)
- [ ] Balance sheet (date, source)
- [ ] Cash flow statement (period, source)
- [ ] Bank statements (period)
- [ ] Tax returns (year)
- [ ] Cap table (current)
- [ ] Contracts/invoices (sample)

Known Discrepancies:
- [Item]: [Source A says X, Source B says Y] - [Explained/Investigating]
```

**Acceptable Answers**:
- "P&L from CFO, bank statements from SVB, Stripe dashboard for revenue verification"
- "Revenue matches within 1% across P&L and Stripe; headcount mismatch in org chart vs payroll (contractor vs FTE classification)"

---

### Q7: Scenarios and Projections (FORECAST mode)

**Question**: "What are your upside, base, and downside scenarios? What drives each?"

**Push Until**: Specific numbers per scenario with key drivers

**Framework**:
```
Scenario: [Upside/Base/Downside]
Revenue: $[annual amount]
Expenses: $[annual amount]
Runway: [months] at this rate
Key Driver: [What makes this scenario happen]
Probability: [rough % confidence]
```

**Acceptable Answers**:
- "Upside: $3.6M revenue if enterprise deal closes, expenses $2.2M, extends runway to 36 months"
- "Downside: $1.8M revenue if churn increases to 5%/month, need to cut to $1.5M expenses"

---

### Q8: Assumptions and Risks

**Question**: "What are your key assumptions? What keeps you up at night financially?"

**Push Until**: Explicit assumptions with confidence levels

**Framework**:
```
Assumption: [What you're assuming]
Value: [The specific assumption]
Basis: [Historical data, benchmark, estimate]
Confidence: [High/Medium/Low]
Sensitivity: [High/Medium/Low - how much does the outcome change if wrong?]
```

---

## Push-Back Patterns

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "Revenue is growing" | "What's the specific ARR? What's the YoY growth rate?" |
| "Margins are healthy" | "What's the gross margin percentage? Operating margin?" |
| "We have enough runway" | "How many months at current burn? What's the cash balance?" |
| "Unit economics work" | "What's your LTV:CAC ratio? CAC payback period?" |
| "Expenses are under control" | "What's the monthly total? Break down by category." |
| "The model shows growth" | "What's the growth rate assumption? Based on what data?" |
| "Burn is reasonable" | "What's the burn multiple? Net burn vs new ARR?" |

---

## Data Quality Assessment

After gathering answers, assess each section:

| Quality Level | Criteria | Action |
|---------------|----------|--------|
| **High** | Audited statements, verified against multiple sources | Use as-is |
| **Medium** | Management-prepared, single-source, reasonable basis | Note source |
| **Low** | Estimates, benchmarks used instead of actuals, guesses | Flag prominently |

---

## Output Schema: financial-metrics.json

```json
{
  "metadata": {
    "project": "",
    "date": "",
    "mode": "REVIEW|DILIGENCE|AUDIT|FORECAST",
    "currency": "USD",
    "version": "1.0"
  },
  "revenue": {
    "arr": 0,
    "mrr": 0,
    "growth_yoy_pct": 0,
    "top_customer_pct": 0,
    "recurring_pct": 0,
    "metrics": [
      {"metric": "", "value": "", "trend": "up|down|flat", "verification": "verified|supported|unverified"}
    ]
  },
  "expenses": {
    "categories": [
      {"name": "", "monthly": 0, "annual": 0, "pct_of_total": 0.0, "trend": "up|down|flat"}
    ],
    "total_monthly": 0,
    "total_annual": 0
  },
  "cash": {
    "balance": 0,
    "monthly_net_burn": 0,
    "gross_burn": 0,
    "runway_months": 0,
    "restricted": 0
  },
  "ratios": {
    "items": [
      {"name": "", "value": "", "benchmark": "", "assessment": "healthy|adequate|concerning|critical"}
    ]
  },
  "startup_metrics": {
    "items": [
      {"name": "", "value": "", "benchmark": "", "assessment": "healthy|adequate|concerning|critical"}
    ]
  },
  "verification": {
    "items": [
      {"item": "", "source1": "", "source2": "", "source3": "", "status": "match|discrepancy"}
    ]
  },
  "scenarios": {
    "items": [
      {"name": "", "revenue": 0, "expenses": 0, "runway_months": 0, "key_driver": ""}
    ]
  },
  "assumptions": {
    "items": [
      {"assumption": "", "value": "", "confidence": "healthy|adequate|concerning", "sensitivity": "high|medium|low"}
    ]
  },
  "red_flags": {
    "items": [
      {"category": "", "finding": "", "severity": "critical|high|medium|low", "recommendation": ""}
    ]
  },
  "monitoring": {
    "items": [
      {"metric": "", "frequency": "", "threshold": "", "action": ""}
    ]
  },
  "documents": {
    "inventory": [
      {"name": "", "type": "", "period": "", "source": "", "quality": "verified|supported|unverified"}
    ],
    "completeness": [
      {"document": "", "status": "Available|Partial|Missing", "notes": ""}
    ]
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

### XLSX Generation

After all questions are complete, generate an XLSX spreadsheet with:
- **Revenue** worksheet: ARR, MRR, growth, concentration
- **Expenses** worksheet: Category breakdown with formulas (following cost-breakdown conventions)
- **Cash Flow** worksheet: Balance, burn, runway calculation
- **Ratios** worksheet: All ratios with benchmark comparisons
- **Scenarios** worksheet: Three-scenario comparison with formulas

Use the same color conventions as cost-breakdown (blue inputs, black formulas).

### JSON Export

Export `financial-metrics.json` matching the schema above. All numbers must be numbers (not strings).

---

## References

- cost-forcing-questions.md - Base forcing question patterns
- spreadsheet-frameworks.md - XLSX generation conventions
- financial-analysis.typ - Typst template consuming this data
