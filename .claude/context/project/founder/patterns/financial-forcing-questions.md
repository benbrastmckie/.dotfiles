# Financial Forcing Questions

A framework for extracting specific financial data and validating claims through structured questioning.

## Core Principle

**"Every number tells a story"**

Financial claims without source documents are not accepted. Every figure requires a verifiable origin -- bank statement, contract, invoice, or accounting system. Questions are asked one at a time via AskUserQuestion, with push-back until documentary evidence is cited.

---

## Mode Selection

### Step 1: Determine Analysis Mode

Ask first to scope the engagement:

```
What type of financial analysis do you need?

- REVIEW: General financial health check
- DILIGENCE: Due diligence depth analysis for investment or acquisition
- AUDIT: Detailed verification and validation of specific claims
- FORECAST: Forward-looking financial assessment and projection review
```

| Mode | Precision | Time Investment | Document Depth |
|------|-----------|-----------------|----------------|
| **REVIEW** | Directional | 30 minutes | Summary financials sufficient |
| **DILIGENCE** | High | 2-4 hours | Full document set required |
| **AUDIT** | Exact | 4-8 hours | Source documents and cross-references |
| **FORECAST** | Range-based | 1-2 hours | Model + assumptions + historical basis |

---

## The Six Forcing Questions

### Q1: Document Inventory

**Question**: "What financial documents do you have available? List each document, its date, and who prepared it."

**Push Until**: Specific documents named with dates and sources

**Framework**:
```
Document: [Name]
Type: [Financial statement, tax return, bank statement, model, etc.]
Period: [What time period it covers]
Prepared by: [Internal, accountant, auditor]
Format: [PDF, spreadsheet, accounting export]
```

**Acceptable Answers**:
- "2025 audited financials from Deloitte, received January 2026"
- "Monthly P&L from QuickBooks, Jan-Dec 2025, exported March 2026"
- "Cap table from Carta as of March 2026"

**Anti-Patterns to Reject**:
- "We have our financials"
- "The usual documents"
- "I can get you whatever you need"

---

### Q2: Revenue Reality

**Question**: "Show me the revenue. What is the actual ARR/MRR, and how do you verify it?"

**Push Until**: Specific revenue figure with at least two verification sources

**Framework**:
```
Revenue Claim: [$X ARR/MRR]
Source 1: [P&L, accounting system]
Source 2: [Payment processor, bank deposits]
Source 3: [Customer contracts, invoices]
Match: [Yes/No/Discrepancy of $X]
```

**Acceptable Answers**:
- "MRR is $180K per Stripe dashboard, matches our P&L within 2%"
- "ARR is $2.1M based on signed contracts; $1.8M currently recognized"
- "Revenue was $1.2M in 2025 per our audited financials"

**Anti-Patterns to Reject**:
- "Revenue is growing fast"
- "We're at about $2M"
- "Our pipeline suggests $5M"
- "Revenue run rate based on last month"

**Key Distinctions**:
| Term | Definition | Watch For |
|------|------------|-----------|
| Recognized revenue | Earned and delivered | Premature recognition |
| Contracted ARR | Signed but not all recognized | Churn risk on renewals |
| Pipeline | Not closed | Not revenue |
| Run rate | Extrapolation | Seasonal distortion |

---

### Q3: Expense Completeness

**Question**: "Walk me through every cost category. What are the top 5 expenses by size?"

**Push Until**: Line-item detail with amounts and verification

**Framework**:
```
Category: [Personnel, Infrastructure, Marketing, Operations, etc.]
Monthly Amount: [$X]
% of Total: [X%]
Trend: [Growing, stable, declining]
Source: [P&L, bank statements, contracts]
```

**Acceptable Answers**:
- "Personnel is $320K/month (65% of spend): 12 engineers, 3 sales, 2 ops"
- "AWS is $45K/month, up from $30K six months ago due to scaling"
- "Legal is $8K/month retainer plus $25K one-time for patent work in Q1"

**Anti-Patterns to Reject**:
- "Normal startup expenses"
- "Mostly headcount"
- "We're lean"

**Completeness Checklist**:
- [ ] Personnel (salaries, benefits, contractors)
- [ ] Infrastructure (cloud, tools, office)
- [ ] Marketing and sales
- [ ] Professional services (legal, accounting)
- [ ] Insurance
- [ ] Travel and entertainment
- [ ] One-time costs identified separately

---

### Q4: Cash Position

**Question**: "What is today's cash balance, and what is the actual monthly burn rate?"

**Push Until**: Specific cash number with bank verification and burn calculation

**Framework**:
```
Cash Balance: [$X as of DATE]
Source: [Bank statement, treasury report]
Monthly Burn: [$X]
Burn Calculation: [Total expenses - Total revenue = $X net burn]
Runway: [X months at current burn]
```

**Acceptable Answers**:
- "Cash is $4.2M as of March 15, per SVB statement. Net burn is $280K/month. 15 months runway."
- "Cash is $800K. Burn is $120K/month gross, $85K net after revenue. 9.4 months runway."

**Anti-Patterns to Reject**:
- "We have plenty of runway"
- "Cash is fine"
- "We'll raise before it matters"

**Critical Follow-Ups**:
- Any restricted cash or escrow?
- Upcoming large payments (annual contracts, tax)?
- Expected inflows (receivables, grant)?
- Debt repayment schedule?

---

### Q5: Projection Basis

**Question**: "What assumptions drive your financial forecast? Show me the basis for each."

**Push Until**: Each assumption has a historical basis or external reference

**Framework**:
```
Assumption: [e.g., "30% YoY revenue growth"]
Basis: [Historical data, market benchmark, signed pipeline]
Confidence: [High/Medium/Low]
Sensitivity: [High/Medium/Low impact if wrong]
```

**Acceptable Answers**:
- "30% growth based on 35% trailing 12-month growth and $500K signed pipeline"
- "Gross margin stays at 78% based on last 6 quarters averaging 76-80%"
- "Headcount grows from 18 to 25 based on approved hiring plan with 3 signed offers"

**Anti-Patterns to Reject**:
- "Industry standard growth rate"
- "Conservative estimates"
- "We're being aggressive but realistic"
- "Best case / worst case" without basis

**Assumption Categories to Cover**:
| Category | Key Assumptions |
|----------|-----------------|
| Revenue | Growth rate, pricing, churn, expansion |
| Costs | Headcount growth, infrastructure scaling, marketing spend |
| Timing | When hires start, when revenue recognizes, when costs hit |
| External | Market conditions, competitive dynamics, regulatory |

---

### Q6: Discrepancy Detection

**Question**: "What doesn't add up? What number surprised you when you looked at the data?"

**Push Until**: Honest acknowledgment of at least one anomaly or concern

**Framework**:
```
Discrepancy: [What doesn't match]
Documents Involved: [Which sources conflict]
Magnitude: [$X or X%]
Explanation: [Known reason or needs investigation]
```

**Acceptable Answers**:
- "Revenue on our P&L is $50K higher than Stripe shows -- we think it's a timing issue with annual contracts"
- "Burn rate jumped 40% in February due to a one-time legal settlement"
- "Customer count in our board deck doesn't match CRM -- we're cleaning up trial vs paid definitions"

**Anti-Patterns to Reject**:
- "Everything checks out"
- "No surprises"
- "The numbers are solid"

**Why This Matters**: Every financial data set has anomalies. If the founder says everything is perfect, they either have not looked closely or are not being forthcoming.

---

## Smart Routing by Mode

| Mode | Focus Questions | Depth Level |
|------|-----------------|-------------|
| REVIEW | Q1, Q2, Q4 (overview level) | Category totals, key metrics |
| DILIGENCE | All questions, full detail | Line items, source verification |
| AUDIT | Q2, Q3, Q5, Q6 (verification focus) | Three-way match on every material item |
| FORECAST | Q2, Q5, Q6 (projection focus) | Assumption testing, sensitivity |

---

## Push-Back Patterns

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "About $X" | "What's the exact number? What source are you reading from?" |
| "Revenue is growing" | "What was MRR last month vs 3 months ago vs 12 months ago?" |
| "We're lean" | "What's total monthly spend? Break it into personnel vs non-personnel." |
| "Runway is fine" | "Cash balance divided by monthly net burn equals how many months?" |
| "Conservative forecast" | "What historical data supports each growth assumption?" |
| "Standard terms" | "What are the specific payment terms? Net 30? Net 60? Prepaid?" |
| "The auditor approved it" | "Which firm? Qualified or unqualified opinion? Any management letter items?" |

---

## Data Quality Assessment

After gathering answers, assess each area:

| Quality Level | Criteria | Action |
|---------------|----------|--------|
| **Verified** | Multiple sources match, third-party confirmed | High confidence, use as-is |
| **Supported** | Internal sources consistent, reasonable | Medium confidence, note assumptions |
| **Unverified** | Single source, no cross-reference | Low confidence, flag for validation |
| **Conflicting** | Sources disagree | Investigation required before proceeding |

---

## Output Format

Document all responses in structured format:

```json
{
  "mode": "DILIGENCE",
  "documents": [
    {
      "name": "2025 Audited P&L",
      "type": "financial_statement",
      "period": "FY2025",
      "source": "Deloitte",
      "quality": "verified"
    }
  ],
  "revenue": {
    "arr": 2100000,
    "mrr": 175000,
    "verification_sources": ["P&L", "Stripe", "contracts"],
    "match_status": "consistent",
    "quality": "verified"
  },
  "expenses": {
    "monthly_total": 350000,
    "top_categories": [
      {"name": "Personnel", "monthly": 280000, "pct": 80}
    ],
    "quality": "supported"
  },
  "cash": {
    "balance": 4200000,
    "monthly_burn": 175000,
    "runway_months": 24,
    "as_of": "2026-03-15",
    "quality": "verified"
  },
  "projections": {
    "assumptions_documented": true,
    "basis_quality": "supported",
    "sensitivity_tested": false
  },
  "discrepancies": [
    {
      "description": "P&L revenue $50K above Stripe",
      "magnitude": 50000,
      "explanation": "Annual contract timing",
      "status": "explained"
    }
  ]
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

### Build the Picture Incrementally

After each question, summarize what was learned before asking the next:

```
"You have audited 2025 financials from Deloitte and monthly Stripe data.
ARR is $2.1M verified across P&L and Stripe.
Now let's look at the expense side -- walk me through every cost category."
```

### Document Everything

Every number should have:
- The value
- The source document
- The date of the source
- Whether it was cross-referenced
- Confidence rating

---

## References

- [SaaS Metrics That Matter (a16z)](https://a16z.com/16-metrics/)
- [Financial Due Diligence Checklist (NVCA)](https://nvca.org/)
- [YC Series A Diligence Guide](https://www.ycombinator.com/library/5b-how-to-raise-a-series-a)
