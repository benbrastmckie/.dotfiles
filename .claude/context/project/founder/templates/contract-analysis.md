# Contract Analysis Template

Template for contract review and negotiation analysis artifacts.

## Output File Format

**Location**: `founder/contract-analysis-{datetime}.md`

---

## Template

```markdown
# Contract Analysis Report

**Project**: {project_name}
**Date**: {YYYY-MM-DD}
**Mode**: {REVIEW|NEGOTIATE|TERMS|DILIGENCE}
**Contract Type**: {SaaS|Employment|Partnership|Data License|SAFE|AI Service|NDA|Other}
**Prepared by**: Claude

---

## Executive Summary

**Overall Risk Level**: {Low|Medium|High|Critical}

{2-3 sentence summary of key findings and recommendation}

**Key Concerns**:
1. {Top concern}
2. {Second concern}
3. {Third concern}

**Recommended Action**: {Sign as-is|Negotiate specific terms|Attorney review required|Do not sign}

---

## Contract Overview

### Parties

| Party | Role | Notes |
|-------|------|-------|
| {Party 1} | {Vendor/Customer/Partner} | {Relevant context} |
| {Party 2} | {Vendor/Customer/Partner} | {Relevant context} |

### Key Terms Summary

| Term | Value | Assessment |
|------|-------|------------|
| Term length | {duration} | {Standard/Short/Long} |
| Auto-renewal | {Yes/No} | {Details} |
| Total value | ${amount} | {Context} |
| Liability cap | ${amount} | {Adequate/Inadequate} |
| Governing law | {jurisdiction} | {Favorable/Neutral/Unfavorable} |

---

## Clause-by-Clause Analysis

| Section | Risk Level | Issue | Recommendation |
|---------|-----------|-------|----------------|
| {Section name} | {Low|Medium|High|Critical} | {Specific issue identified} | {Suggested change or acceptance} |
| {Section name} | {Low|Medium|High|Critical} | {Specific issue identified} | {Suggested change or acceptance} |

### Detailed Analysis

#### {Section 1: e.g., Data Rights}

**Current Language**: "{Quoted text from contract}"

**Risk**: {Low|Medium|High|Critical}

**Issue**: {What's problematic about this clause}

**Recommendation**: {Specific alternative language or acceptance rationale}

---

#### {Section 2: e.g., IP Ownership}

**Current Language**: "{Quoted text from contract}"

**Risk**: {Low|Medium|High|Critical}

**Issue**: {What's problematic about this clause}

**Recommendation**: {Specific alternative language or acceptance rationale}

---

## Risk Assessment Matrix

```
                    Severity of Impact
                    Low          High
              ┌───────────────┬───────────────┐
         Low  │   ACCEPT      │   MONITOR     │
Likelihood    │   Low priority│   Track during│
of Issue      │   to change   │   relationship│
              ├───────────────┼───────────────┤
         High │   NEGOTIATE   │   MUST FIX    │
              │   Worth effort│   Do not sign │
              │   to improve  │   without fix │
              └───────────────┴───────────────┘
```

### Issues by Quadrant

**MUST FIX (High Likelihood, High Severity)**:
- {Issue 1}
- {Issue 2}

**NEGOTIATE (High Likelihood, Low Severity)**:
- {Issue 1}
- {Issue 2}

**MONITOR (Low Likelihood, High Severity)**:
- {Issue 1}
- {Issue 2}

**ACCEPT (Low Likelihood, Low Severity)**:
- {Issue 1}
- {Issue 2}

---

## Negotiation Position Summary

### Your Interests (Prioritized)

1. **{Highest priority interest}**: {Why this matters}
2. **{Second priority}**: {Why this matters}
3. **{Third priority}**: {Why this matters}

### Their Likely Interests

1. **{Their highest priority}**: {Evidence for this}
2. **{Their second priority}**: {Evidence for this}
3. **{Their third priority}**: {Evidence for this}

### BATNA Analysis

**Your BATNA (Best Alternative to Negotiated Agreement)**:
- Alternative 1: {Description} - Value: {estimate}
- Alternative 2: {Description} - Value: {estimate}
- **Bottom line**: {What you walk away to}

**Their Likely BATNA**:
- Alternative 1: {Description}
- Implication: {How this affects their leverage}

### ZOPA (Zone of Possible Agreement)

| Dimension | Your Minimum | Their Minimum | ZOPA Exists? |
|-----------|--------------|---------------|--------------|
| {Price/Cap/Term} | {Your floor} | {Their floor} | {Yes/No/Unclear} |
| {Another dimension} | {Your floor} | {Their floor} | {Yes/No/Unclear} |

### Trade-Off Opportunities

| Give | Get |
|------|-----|
| {Lower priority concession} | {Higher priority win} |
| {Another concession} | {What you gain} |

---

## Recommended Modifications

### Must-Have Changes (Do Not Sign Without)

| Current | Proposed | Rationale |
|---------|----------|-----------|
| "{Current language}" | "{Proposed language}" | {Why critical} |

### Should-Have Changes (Strong Recommendation)

| Current | Proposed | Rationale |
|---------|----------|-----------|
| "{Current language}" | "{Proposed language}" | {Why important} |

### Nice-to-Have Changes (Request If Possible)

| Current | Proposed | Rationale |
|---------|----------|-----------|
| "{Current language}" | "{Proposed language}" | {Why beneficial} |

---

## Walk-Away Conditions

Do not proceed if:

1. {Condition 1 - e.g., "Unlimited liability for AI outputs"}
2. {Condition 2 - e.g., "Vendor can use our data for training without opt-in"}
3. {Condition 3 - e.g., "No termination for convenience"}

---

## Action Items

| Priority | Action | Owner | Deadline |
|----------|--------|-------|----------|
| {1-5} | {Specific action} | {Who} | {When} |
| {1-5} | {Specific action} | {Who} | {When} |

---

## Escalation Recommendation

**Recommendation**: {Self-serve approval|Attorney review before signing|Attorney required}

**Rationale**: {Why this level of escalation}

**If Attorney Review**:
- Focus areas: {What attorney should prioritize}
- Budget estimate: {Expected legal cost}
- Timeline: {How long review will take}

---

## Appendix: Negotiation Frameworks Reference

### Anchoring Strategy

- Your anchor: {First position to stake}
- Rationale: {Why this anchor is credible}
- Fallback: {Where you can move}

### Principled Negotiation Approach

- **Separate people from problem**: {How to depersonalize}
- **Focus on interests**: {Questions to ask}
- **Invent options**: {Creative solutions to propose}
- **Use objective criteria**: {Market data, standards to cite}

### Objection Handling

| Their Objection | Your Response |
|-----------------|---------------|
| "{Expected objection}" | "{How to address}" |

---

## Appendix: Contract Comparison

If comparing to prior agreements or templates:

| Term | This Contract | Standard/Prior | Variance |
|------|---------------|----------------|----------|
| {Term} | {Value} | {Benchmark} | {Better/Worse/Same} |

---

## Appendix: Source Documents

| Document | Version | Date | Notes |
|----------|---------|------|-------|
| {Contract name} | {v1.0} | {Date} | {Any context} |
```

---

## Section Guidance

### Executive Summary

- Lead with risk level and recommended action
- Top 3 concerns should be actionable
- Keep to one short paragraph plus bullet points

### Clause-by-Clause Analysis

- Focus on sections with identified issues
- Skip low-risk standard sections
- Always quote specific language when flagging issues

### Risk Assessment Matrix

| Quadrant | Criteria |
|----------|----------|
| **MUST FIX** | Likely to occur AND significant financial/legal impact |
| **NEGOTIATE** | Likely to occur but limited impact |
| **MONITOR** | Unlikely but severe if occurs |
| **ACCEPT** | Low probability and low impact |

### BATNA Development

Strong BATNA comes from:
- Alternative vendors/partners
- Internal build option
- Delay option (time is on your side)
- Walking away credibly

Weak BATNA signals:
- No alternatives
- Time pressure
- Dependency on this deal

### Walk-Away Conditions

Should be:
- Specific and objective
- Tied to critical interests
- Communicated clearly internally
- Not bluffed (must be real)

---

## Mode-Specific Focus

### REVIEW Mode

Primary output: Risk assessment and clause analysis
Focus: What's problematic in this contract?
Deliverable: Marked-up contract or issue list

### NEGOTIATE Mode

Primary output: Negotiation strategy and position analysis
Focus: How do we get better terms?
Deliverable: Trade-off matrix and proposed modifications

### TERMS Mode

Primary output: Term sheet review and benchmark comparison
Focus: Are these terms market-standard?
Deliverable: Comparison table and recommendation

### DILIGENCE Mode

Primary output: Comprehensive review for transaction
Focus: What risks exist in this contract portfolio?
Deliverable: Risk register and remediation plan

---

## Checklist Before Delivery

- [ ] Executive summary is actionable
- [ ] All high-risk issues have specific recommendations
- [ ] BATNA is realistically assessed
- [ ] Walk-away conditions are objective and clear
- [ ] Escalation recommendation matches risk level
- [ ] Language recommendations are specific and quotable
