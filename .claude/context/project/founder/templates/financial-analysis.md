# Financial Analysis Template

Template for financial document analysis and verification report artifacts.

## Output File Format

**Location**: `founder/financial-analysis-{datetime}.md`

---

## Template

```markdown
# Financial Analysis Report

**Project**: {project_name}
**Date**: {YYYY-MM-DD}
**Mode**: {REVIEW|DILIGENCE|AUDIT|FORECAST}
**Document Type**: {Financial Statements|Cap Table|Financial Model|Investor Report|Mixed}
**Prepared by**: Claude

---

## Executive Summary

**Overall Financial Health**: {Healthy|Adequate|Concerning|Critical}

{2-3 sentence summary of key findings and financial position}

**Key Findings**:
1. {Top finding}
2. {Second finding}
3. {Third finding}

**Recommended Action**: {No concerns|Monitor specific items|Further investigation required|Significant issues identified}

---

## Document Inventory

| Document | Type | Period | Source | Quality |
|----------|------|--------|--------|---------|
| {Document 1} | {Statement/Model/Report} | {Period} | {Who prepared} | {Verified/Supported/Unverified} |
| {Document 2} | {Statement/Model/Report} | {Period} | {Who prepared} | {Verified/Supported/Unverified} |

### Document Completeness Assessment

| Required Document | Status | Notes |
|-------------------|--------|-------|
| Income statement | {Available|Missing|Partial} | {Context} |
| Balance sheet | {Available|Missing|Partial} | {Context} |
| Cash flow statement | {Available|Missing|Partial} | {Context} |
| Bank statements | {Available|Missing|Partial} | {Context} |
| Tax returns | {Available|Missing|Partial} | {Context} |
| Cap table | {Available|Missing|Partial} | {Context} |

---

## Financial Overview

### Revenue Analysis

| Metric | Value | Trend | Verification |
|--------|-------|-------|--------------|
| ARR/Annual Revenue | ${amount} | {Growing X%|Flat|Declining X%} | {Source} |
| MRR | ${amount} | {Growing X%|Flat|Declining X%} | {Source} |
| Revenue Growth (YoY) | {X}% | {Accelerating|Steady|Decelerating} | {Source} |
| Revenue Concentration | Top customer = {X}% | {Diversified|Moderate|Concentrated} | {Source} |
| Revenue Quality | {Recurring|Mixed|One-time} | {Improving|Stable|Declining} | {Source} |

### Expense Analysis

| Category | Monthly | Annual | % of Total | Trend |
|----------|---------|--------|-----------|-------|
| Personnel | ${amount} | ${amount} | {X}% | {trend} |
| Infrastructure | ${amount} | ${amount} | {X}% | {trend} |
| Marketing & Sales | ${amount} | ${amount} | {X}% | {trend} |
| Operations | ${amount} | ${amount} | {X}% | {trend} |
| Other | ${amount} | ${amount} | {X}% | {trend} |
| **Total** | **${amount}** | **${amount}** | **100%** | {trend} |

### Cash Position

| Metric | Value | Assessment |
|--------|-------|------------|
| Cash Balance | ${amount} as of {date} | {Adequate|Concerning|Critical} |
| Monthly Net Burn | ${amount} | {Improving|Stable|Worsening} |
| Gross Burn | ${amount} | {Context} |
| Runway | {X} months | {>18 = Comfortable|12-18 = Adequate|<12 = Concerning} |
| Restricted Cash | ${amount} | {Context if any} |

---

## Ratio Analysis

### Key Ratios

| Ratio | Value | Benchmark | Assessment |
|-------|-------|-----------|------------|
| Gross Margin | {X}% | > 70% (SaaS) | {Healthy|Below benchmark|Concerning} |
| Operating Margin | {X}% | Varies | {Context} |
| Current Ratio | {X} | 1.5 - 3.0 | {Healthy|Watch|Concerning} |
| Quick Ratio | {X} | > 1.0 | {Healthy|Watch|Concerning} |
| Debt-to-Equity | {X}:1 | < 2:1 | {Healthy|Watch|Concerning} |
| Burn Multiple | {X}x | < 2x = efficient | {Context} |

### Startup Metrics

| Metric | Value | Benchmark | Assessment |
|--------|-------|-----------|------------|
| Rule of 40 | {X}% | > 40% | {Excellent|Good|Below threshold} |
| Magic Number | {X} | > 0.75 | {Efficient|Moderate|Inefficient} |
| Net Dollar Retention | {X}% | > 110% | {Strong|Adequate|Weak} |
| CAC Payback | {X} months | < 18 months | {Efficient|Acceptable|Concerning} |
| LTV:CAC | {X}:1 | > 3:1 | {Healthy|Marginal|Unhealthy} |

---

## Verification Results

### Cross-Reference Summary

| Item | Source 1 | Source 2 | Source 3 | Status |
|------|----------|----------|----------|--------|
| {Revenue} | {P&L: $X} | {Stripe: $X} | {Contracts: $X} | {Match|Discrepancy} |
| {Cash} | {BS: $X} | {Bank: $X} | {CF: $X} | {Match|Discrepancy} |
| {Headcount} | {P&L: X} | {Payroll: X} | {Org chart: X} | {Match|Discrepancy} |

### Discrepancies Found

| # | Item | Magnitude | Sources | Explanation | Status |
|---|------|-----------|---------|-------------|--------|
| 1 | {Item} | ${amount} or {X}% | {Which sources conflict} | {Known reason or unknown} | {Explained|Investigating|Unresolved} |

### Statement Interconnection Check

| Connection | Expected | Actual | Status |
|------------|----------|--------|--------|
| Net income -> Retained earnings | ${amount} | ${amount} | {Pass|Fail} |
| Net income -> Operating CF start | ${amount} | ${amount} | {Pass|Fail} |
| BS cash -> CF ending cash | ${amount} | ${amount} | {Pass|Fail} |
| Assets = Liabilities + Equity | ${amount} | ${amount} | {Pass|Fail} |

---

## Red Flags and Concerns

### Identified Issues

| # | Category | Finding | Severity | Recommendation |
|---|----------|---------|----------|----------------|
| 1 | {Revenue|Expenses|Cash|Projections|Documents} | {Specific finding} | {Low|Medium|High|Critical} | {Action to take} |

### Risk Assessment

```
                    Severity of Impact
                    Low          High
              +----------------+----------------+
         Low  |   ACCEPT       |   MONITOR      |
Likelihood    |   Note for     |   Track during |
of Issue      |   awareness    |   relationship |
              +----------------+----------------+
         High |   INVESTIGATE  |   MUST ADDRESS |
              |   Clarify and  |   Cannot proceed|
              |   document     |   without fix   |
              +----------------+----------------+
```

**MUST ADDRESS**:
- {Issue if any}

**INVESTIGATE**:
- {Issue if any}

**MONITOR**:
- {Issue if any}

---

## Projection Assessment

### Assumptions Review

| # | Assumption | Value | Basis | Confidence | Sensitivity |
|---|------------|-------|-------|------------|-------------|
| 1 | {Assumption} | {Value} | {Historical data|Benchmark|Estimate} | {High|Medium|Low} | {High|Medium|Low} |

### Scenario Analysis

| Scenario | Revenue | Expenses | Runway | Key Driver |
|----------|---------|----------|--------|------------|
| **Upside** | ${amount} | ${amount} | {X months} | {What goes right} |
| **Base** | ${amount} | ${amount} | {X months} | {Expected outcome} |
| **Downside** | ${amount} | ${amount} | {X months} | {What goes wrong} |

### Forecast Credibility

| Factor | Assessment | Notes |
|--------|------------|-------|
| Historical basis | {Strong|Moderate|Weak} | {How forecasts compare to actuals} |
| Assumption transparency | {Explicit|Partial|Opaque} | {Are all inputs visible?} |
| Sensitivity testing | {Done|Partial|None} | {Key variables tested?} |
| Conservative bias | {Appropriately conservative|Optimistic|Aggressive} | {Context} |

---

## What I Noticed

{Mentor-style observations about financial health, patterns, or blind spots that may not be obvious from the numbers alone. This section adds qualitative insight beyond the quantitative analysis.}

---

## Recommendations

### Immediate Actions

1. {Highest priority action}
2. {Second priority action}
3. {Third priority action}

### Further Investigation Needed

| Area | What to Investigate | Why |
|------|---------------------|-----|
| {Area 1} | {Specific investigation} | {What it would reveal} |
| {Area 2} | {Specific investigation} | {What it would reveal} |

### Monitoring Plan

| Metric | Frequency | Threshold | Action if Triggered |
|--------|-----------|-----------|---------------------|
| {Metric 1} | {Monthly/Quarterly} | {Threshold} | {What to do} |
| {Metric 2} | {Monthly/Quarterly} | {Threshold} | {What to do} |

---

## Appendix: Detailed Calculations

{Any detailed ratio calculations, reconciliation workpapers, or sensitivity tables}

---

## Appendix: Source Documents

| Document | Version | Date | Received | Notes |
|----------|---------|------|----------|-------|
| {Document name} | {v1.0} | {Date} | {Date received} | {Any context} |
```

---

## Section Guidance

### Executive Summary

- Lead with overall health assessment
- Top 3 findings should be actionable
- Recommended action should be clear and specific
- Keep to one short paragraph plus bullets

### Revenue Analysis

| Quality Signal | Good | Concerning |
|----------------|------|------------|
| Recurring share | > 80% recurring | < 50% recurring |
| Concentration | No customer > 15% | Top customer > 30% |
| Growth trajectory | Accelerating or steady | Decelerating without explanation |
| Verification | Multi-source verified | Single-source only |

### Verification Results

- Always attempt three-way match for material items
- Tolerance for matching: +/- 1% for rounding
- Discrepancies > 5% are material and require investigation
- Document the source and date for every verified figure

### Red Flags Priority

| Severity | Criteria | Response |
|----------|----------|----------|
| **Critical** | Financial misrepresentation or fraud indicators | Stop, escalate immediately |
| **High** | Material discrepancies without explanation | Cannot proceed without resolution |
| **Medium** | Concerning patterns with possible explanations | Document, monitor, request clarification |
| **Low** | Minor inconsistencies or data quality issues | Note for awareness |

---

## Mode-Specific Focus

### REVIEW Mode

Primary output: Financial health snapshot
Focus: Key metrics, trends, obvious concerns
Deliverable: Summary with traffic-light ratings
Depth: Category-level analysis, top-line verification

### DILIGENCE Mode

Primary output: Comprehensive financial assessment
Focus: Every material line item verified
Deliverable: Full analysis with cross-reference tables
Depth: Line-item analysis, three-way matching

### AUDIT Mode

Primary output: Verification and validation report
Focus: Accuracy of specific claims or documents
Deliverable: Reconciliation workpapers and finding list
Depth: Source-document level verification

### FORECAST Mode

Primary output: Projection credibility assessment
Focus: Assumption basis, sensitivity, scenario analysis
Deliverable: Assumption review with scenario modeling
Depth: Each assumption traced to historical or external basis

---

## Checklist Before Delivery

- [ ] Executive summary is standalone readable
- [ ] All material figures cite source documents
- [ ] Verification cross-references completed for key items
- [ ] Discrepancies documented with status (explained/investigating/unresolved)
- [ ] Red flags section is honest about concerns
- [ ] Ratio analysis includes relevant benchmarks
- [ ] Recommendations are specific and actionable
- [ ] "What I Noticed" adds non-obvious insight
- [ ] Source document appendix is complete
