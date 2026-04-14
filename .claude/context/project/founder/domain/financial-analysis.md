# Financial Analysis Frameworks

Domain knowledge for financial document analysis, verification methodology, and spreadsheet validation.

## Financial Statement Analysis

### Income Statement Components

| Component | What It Shows | Key Questions |
|-----------|---------------|---------------|
| **Revenue** | Top-line sales | Is it real? Recurring? Growing? |
| **COGS** | Direct delivery costs | What's included? Gross margin trend? |
| **Gross Profit** | Revenue - COGS | Is margin expanding or compressing? |
| **Operating Expenses** | SG&A, R&D, Marketing | Where is money going? What's discretionary? |
| **EBITDA** | Operating profitability | Is the core business viable? |
| **Net Income** | Bottom line after everything | Any one-time items distorting this? |

**Revenue Quality Signals**:
- Recurring > one-time (MRR/ARR vs project revenue)
- Contracted > at-risk (signed agreements vs verbal)
- Diversified > concentrated (no single customer > 20%)
- Growing > flat > declining (trajectory matters most)

### Balance Sheet Health Indicators

| Indicator | Healthy Signal | Warning Signal |
|-----------|---------------|----------------|
| **Cash position** | > 6 months runway | < 3 months runway |
| **Accounts receivable** | Aging < 60 days | Aging > 90 days, growing faster than revenue |
| **Accounts payable** | Current, within terms | Stretching beyond terms, growing |
| **Debt-to-equity** | < 2:1 for startups | > 3:1, or debt growing faster than equity |
| **Working capital** | Positive, stable | Negative or deteriorating |

### Cash Flow Statement Analysis

```
Operating Cash Flow
  = Net Income
  + Non-cash adjustments (depreciation, stock comp)
  + Working capital changes
  -> KEY: Is this positive or trending positive?

Investing Cash Flow
  = CapEx + acquisitions - asset sales
  -> KEY: What are they investing in?

Financing Cash Flow
  = Debt raised + equity raised - repayments
  -> KEY: How are they funded?
```

**The Critical Question**: Does operating cash flow cover operating expenses? If not, how long until it does (or funding runs out)?

### Statement Interconnection Verification

| Connection | Check | Red Flag |
|------------|-------|----------|
| IS -> BS | Net income flows to retained earnings | Retained earnings delta does not match net income |
| IS -> CF | Net income is starting point for operating CF | Operating CF and net income diverge significantly |
| BS -> CF | Cash on BS matches ending cash on CF | Cash balances do not reconcile |
| BS -> BS | Assets = Liabilities + Equity | Balance sheet does not balance |

---

## Ratio Analysis Framework

### Liquidity Ratios

| Ratio | Formula | Healthy Range | Startup Context |
|-------|---------|---------------|-----------------|
| **Current Ratio** | Current Assets / Current Liabilities | 1.5 - 3.0 | Lower OK if VC-funded with runway |
| **Quick Ratio** | (Cash + Receivables) / Current Liabilities | > 1.0 | More relevant than current ratio |
| **Cash Ratio** | Cash / Current Liabilities | > 0.5 | Most conservative measure |

### Profitability Ratios

| Ratio | Formula | Healthy Range | Startup Context |
|-------|---------|---------------|-----------------|
| **Gross Margin** | Gross Profit / Revenue | > 70% for SaaS | Below 50% is concerning for software |
| **Operating Margin** | Operating Income / Revenue | Varies | Often negative pre-profitability |
| **Net Margin** | Net Income / Revenue | Varies | Track trajectory, not absolute |
| **ROE** | Net Income / Equity | > 15% | Often negative for early-stage |

### Leverage Ratios

| Ratio | Formula | Healthy Range | Startup Context |
|-------|---------|---------------|-----------------|
| **Debt-to-Equity** | Total Debt / Total Equity | < 2:1 | Many startups have minimal debt |
| **Interest Coverage** | EBITDA / Interest Expense | > 3x | Relevant only if debt-funded |

### Startup-Specific Metrics

| Metric | Formula | Benchmark |
|--------|---------|-----------|
| **Monthly Burn Rate** | Monthly Operating Expenses - Monthly Revenue | Track trend |
| **Runway** | Cash Balance / Monthly Burn Rate | > 12 months ideal |
| **Rule of 40** | Revenue Growth % + Profit Margin % | > 40% = excellent |
| **Magic Number** | Net New ARR / Prior Quarter S&M Spend | > 0.75 = efficient |
| **CAC Payback** | CAC / (Monthly ARPU x Gross Margin) | < 18 months |
| **Net Dollar Retention** | (Start MRR + Expansion - Churn) / Start MRR | > 110% |

---

## Verification Methodology

### Cross-Referencing Protocol

**Three-Way Match**: Every material financial claim should be verifiable through at least three independent data points.

```
Claim: "Revenue is $2M ARR"

Verification Path 1: Financial statements (P&L)
Verification Path 2: Bank statements or payment processor
Verification Path 3: Customer contracts or invoices

Match? -> Verified
Discrepancy? -> Investigate and document
```

### Source Document Hierarchy

| Tier | Source | Reliability | Example |
|------|--------|-------------|---------|
| **Tier 1** | Third-party verified | Highest | Audited financials, bank statements, tax returns |
| **Tier 2** | Internal with controls | High | Accounting system exports, payment processor reports |
| **Tier 3** | Internal documents | Medium | Management-prepared financials, spreadsheet models |
| **Tier 4** | Verbal or estimates | Low | Founder estimates, "approximately" figures |

### Red Flag Detection Checklist

| Category | Red Flag | What to Investigate |
|----------|----------|---------------------|
| **Revenue** | Revenue growing but cash declining | Collection issues or revenue recognition problems |
| **Revenue** | Single customer > 30% of revenue | Concentration risk, customer dependency |
| **Revenue** | Revenue spikes at quarter-end | Channel stuffing or aggressive recognition |
| **Expenses** | R&D declining while claiming innovation | Underinvestment or miscategorization |
| **Expenses** | Large "other" or "miscellaneous" categories | Hidden costs or poor tracking |
| **Cash** | Cash burn accelerating without revenue growth | Operational efficiency problems |
| **Cash** | Related-party transactions | Potential conflicts of interest |
| **Projections** | Hockey stick without clear catalyst | Unrealistic optimism |
| **Projections** | Expenses flat while revenue doubles | Ignoring scaling costs |
| **Documents** | Reluctance to share specific documents | Potential issues being hidden |

### Reconciliation Patterns

```
Step 1: Obtain documents from multiple sources
Step 2: Map corresponding line items across documents
Step 3: Identify discrepancies (tolerance: +/- 1% for rounding)
Step 4: Investigate material discrepancies (> 5% variance)
Step 5: Document findings with source references
Step 6: Rate confidence level per line item
```

---

## Spreadsheet Validation Patterns

### Formula Audit Checklist

| Check | What to Look For | Risk |
|-------|------------------|------|
| **Hardcoded overrides** | Formulas replaced with values | Model breaks on input changes |
| **Broken references** | #REF! or #N/A errors | Corrupted calculations |
| **Inconsistent ranges** | SUM range misses rows | Understated totals |
| **Circular references** | Cell references itself | Unstable calculations |
| **Hidden rows/columns** | Data excluded from view | Missing information |
| **Mixed units** | Monthly and annual in same column | Incorrect comparisons |
| **Date alignment** | Periods do not match across sheets | Mismatched comparisons |

### Common Spreadsheet Errors

| Error | Description | Detection Method |
|-------|-------------|------------------|
| **Off-by-one** | SUM range starts or ends one row off | Compare subtotals to manual count |
| **Copy-paste drift** | Formula not updated after copy | Check formula consistency in column |
| **Unit mismatch** | Mixing thousands with actuals | Verify units in column headers |
| **Stale inputs** | Assumptions not updated | Check dates on input assumptions |
| **Missing inflation** | Multi-year model ignores cost growth | Review year-over-year cost changes |

### Assumption Sensitivity Testing

For each key assumption in a financial model:

```
1. Identify the assumption (e.g., "30% YoY revenue growth")
2. Determine reasonable range (e.g., 15% - 45%)
3. Test at pessimistic, base, and optimistic values
4. Measure impact on key outputs (runway, profitability date)
5. Rank assumptions by sensitivity (high impact = high risk)
```

**Sensitivity Classification**:
- **High**: > 20% change in key output when assumption varies by 25%
- **Medium**: 5-20% change in key output
- **Low**: < 5% change in key output

---

## Document Types and Review Points

### Cap Table Analysis

| Check Point | What to Verify |
|-------------|----------------|
| Fully diluted share count | Option pool, warrants, convertible notes, SAFEs |
| Ownership percentages | Verify math, check for dilution errors |
| Vesting schedules | Cliff dates, acceleration clauses |
| Preference stack | Liquidation preferences, participation rights |
| Anti-dilution provisions | Broad-based vs narrow-based weighted average |

### Financial Model Review

| Component | What to Validate |
|-----------|------------------|
| Revenue assumptions | Growth rate basis, pricing model, conversion rates |
| Cost structure | Fixed vs variable correctly classified |
| Headcount plan | Timing of hires, fully loaded costs |
| Cash flow timing | Revenue collection lag, prepaid expenses |
| Funding assumptions | When and how much additional capital needed |

### Investor Report Verification

| Element | Cross-Reference Against |
|---------|------------------------|
| ARR/MRR figures | Stripe/payment processor, accounting system |
| Customer count | CRM data, active subscriptions |
| Burn rate | Bank statements, P&L operating expenses |
| Runway statement | Cash balance / actual monthly burn |
| Key milestones | Product releases, signed contracts, team hires |

---

## References

- [SaaS Metrics 2.0 (David Skok)](https://www.forentrepreneurs.com/saas-metrics-2/)
- [Financial Modeling Best Practices (FAST Standard)](https://www.fast-standard.org/)
- [Rule of 40 (Bain & Company)](https://www.bain.com/insights/rule-of-40/)
- [YC Series A Guide](https://www.ycombinator.com/library/5b-how-to-raise-a-series-a)
- [Bessemer Cloud Index](https://www.bvp.com/cloud-index)
