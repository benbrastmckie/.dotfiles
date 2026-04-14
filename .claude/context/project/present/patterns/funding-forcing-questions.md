# Funding Forcing Questions

A framework for extracting specific funding data through structured questioning. Used by the funds-agent to gather essential information before and during funding analysis.

## Core Principle

**"Every funding claim needs a source"**

Funding claims without verifiable details are not accepted. Every figure requires a specific source -- award letter, budget document, funder guidelines, or agency database. Questions are asked one at a time via AskUserQuestion, with push-back until specific details are provided.

---

## Mode-Specific Question Routing

### LANDSCAPE Mode Questions

For mapping funding opportunities across a research area.

**Q1: Research Area**
- **Question**: "What research project or area needs funding analysis?"
- **Push Until**: Specific discipline, aims, methodology identified
- **Acceptable**: "Computational modeling of protein-ligand interactions using molecular dynamics"
- **Reject**: "My research", "Biology", "The project we discussed"

**Q2: Current Funding**
- **Question**: "What current or past funding supports this research?"
- **Push Until**: Specific awards listed with numbers, amounts, dates
- **Acceptable**: "NIH R21 AI123456, $275K, 2024-2026; NSF MCB-2345678, $400K, 2023-2026"
- **Reject**: "We have some NIH funding", "Federally funded"

**Q3: Target Agencies**
- **Question**: "Which agencies or programs are you targeting? Or should we survey broadly?"
- **Push Until**: Specific agencies, institutes, or mechanisms named
- **Acceptable**: "NIH NIGMS and NSF MCB for computational work; DOE BES for materials aspect"
- **Reject**: "Federal funding", "Whatever fits"

**Q4: Budget Range**
- **Question**: "What annual budget range do you need? Any known constraints?"
- **Push Until**: Dollar range with constraints
- **Acceptable**: "$250K/year direct costs, 52% F&A, PI limited to 15% effort"
- **Reject**: "Standard funding", "Whatever they give"

**Q5: Decision Context**
- **Question**: "What decision does this landscape analysis inform?"
- **Push Until**: Specific strategic question identified
- **Acceptable**: "Whether to pursue R01 now or R21 for preliminary data first"
- **Reject**: "Just want to know what's out there"

---

### PORTFOLIO Mode Questions

For deep-diving into a specific funder's priorities and patterns.

**Q1: Target Funder**
- **Question**: "Which funder do you want to analyze?"
- **Push Until**: Specific funder and program identified
- **Acceptable**: "NIH NIGMS, particularly the Molecular Biophysics cluster"
- **Reject**: "NIH" (too broad), "A foundation" (unspecified)

**Q2: Research Alignment**
- **Question**: "How does your research align with this funder's stated priorities?"
- **Push Until**: Specific alignment points articulated
- **Acceptable**: "Our MD simulations directly address NIGMS strategic plan goal 2: understanding molecular interactions"
- **Reject**: "It's a good fit", "They fund this kind of work"

**Q3: Prior Awards**
- **Question**: "Have you received funding from this funder before? What was the outcome?"
- **Push Until**: Award history or explicit statement of no prior relationship
- **Acceptable**: "R21 AI123456 (2020-2022), published 3 papers, cited in 45 works; scored 25th percentile on R01 resubmission"
- **Reject**: "Yes, we've had grants before"

**Q4: Budget Constraints**
- **Question**: "What budget constraints does this funder impose?"
- **Push Until**: Specific constraints identified
- **Acceptable**: "Modular budget under $250K direct/year, 35% fringe rate, equipment excluded from MTDC"
- **Reject**: "Normal budget rules"

**Q5: Strategic Goals**
- **Question**: "What is your strategic goal with this funder?"
- **Push Until**: Clear objective stated
- **Acceptable**: "Establish an R01 funding relationship to support lab for next 5 years"
- **Reject**: "Get more funding"

---

### JUSTIFY Mode Questions

For verifying budget justification against funder guidelines.

**Q1: Budget Document**
- **Question**: "What budget document needs verification? Provide the file path or paste the budget."
- **Push Until**: Specific document identified or budget data provided
- **Acceptable**: "specs/500_nsf_career/budgets/01_line-item-budget.md" or pasted budget table
- **Reject**: "Our budget", "The one we submitted"

**Q2: Funder Guidelines**
- **Question**: "What funder guidelines govern this budget? Include any cost caps, rate limits, or special rules."
- **Push Until**: Specific guidelines referenced
- **Acceptable**: "NSF PAPPG 24-1, Section II.D.2; modular budget; $250K cap; equipment >$5K excluded"
- **Reject**: "Standard NSF rules"

**Q3: Cost Categories of Concern**
- **Question**: "Which budget categories need the closest scrutiny?"
- **Push Until**: Specific categories identified with reasons
- **Acceptable**: "Personnel (effort allocation across 3 grants) and travel (justifying 4 conferences/year)"
- **Reject**: "All of it", "The usual suspects"

**Q4: Personnel Justification**
- **Question**: "For each person on the budget: name, role, % effort, salary, and which other grants support them."
- **Push Until**: Complete personnel table with cross-grant allocation
- **Acceptable**: "PI (15% effort, $180K salary, also 20% on R01 GM567890); Postdoc (100%, $60K, no other support)"
- **Reject**: "Standard team", "Three people"

**Q5: F&A Rate**
- **Question**: "What is your negotiated F&A rate? When was it last negotiated? What is the MTDC base?"
- **Push Until**: Rate, effective date, and base identified
- **Acceptable**: "52% on-campus research rate, negotiated with HHS July 2024, MTDC base excluding equipment and subs >$25K"
- **Reject**: "Our standard rate"

---

### GAP Mode Questions

For identifying unfunded areas and strategic opportunities.

**Q1: Research Portfolio**
- **Question**: "List all active research projects, funded and unfunded."
- **Push Until**: Complete portfolio inventory
- **Acceptable**: "Project A: MD simulations (R01 funded $1.2M); Project B: ML methods (unfunded); Project C: Drug discovery collaboration (industry $100K/yr)"
- **Reject**: "Several active projects"

**Q2: Current Awards**
- **Question**: "For each active award: funder, mechanism, amount, period, and renewal status."
- **Push Until**: Complete award inventory with timeline
- **Acceptable**: "R01 GM123456, $250K/yr, 2022-2027, competing renewal in Year 4; NSF MCB-2345678, $133K/yr, 2023-2026, no renewal planned"
- **Reject**: "About $500K/year total"

**Q3: Unfunded Priorities**
- **Question**: "What research directions need funding that you currently lack?"
- **Push Until**: Specific unfunded directions with estimated costs
- **Acceptable**: "ML infrastructure ($150K/yr for GPU cluster), postdoc for drug discovery ($80K/yr + fringe), sequencing costs ($50K/yr)"
- **Reject**: "We need more funding generally"

**Q4: Timeline**
- **Question**: "What is your planning horizon? When do current awards end?"
- **Push Until**: Timeline with renewal/expiration dates
- **Acceptable**: "5-year plan; R01 ends 2027 (must submit renewal 2026); NSF ends 2026 (no renewal); Need new R01 by 2025"
- **Reject**: "Next few years"

**Q5: Strategic Plan Reference**
- **Question**: "Do you have a department or institutional strategic plan that guides funding priorities?"
- **Push Until**: Reference to plan or explicit statement of none
- **Acceptable**: "Department strategic plan 2024-2029 prioritizes computational biology; college identified AI/ML as growth area"
- **Reject**: "We have one somewhere"

---

## Push-Back Patterns

When answers are too vague, push back with specific guidance.

### Vague Funding Claims

| Vague Answer | Push-Back |
|-------------|-----------|
| "Some grants" | "List each grant: funder, mechanism number, title, amount, period. Example: NIH R01 GM123456, $1.2M, 2022-2027" |
| "NIH-funded" | "Which institute? Which mechanism? What award number? Example: NIGMS R01 GM123456" |
| "Federal funding" | "Which agency? NIH, NSF, DOD, DOE? Which specific program or division?" |
| "About $500K" | "Exact amount from the award letter or budget. Is that total or annual? Direct costs only or total with F&A?" |
| "Standard budget" | "What dollar amount per year? What F&A rate? Any salary caps? Equipment needs?" |

### Vague Research Claims

| Vague Answer | Push-Back |
|-------------|-----------|
| "My research" | "What specific aims? What methodology? What discipline? Example: Computational modeling of membrane transport using coarse-grained MD simulations" |
| "Biology" | "Which sub-field? Molecular, cellular, systems, computational, structural?" |
| "We do AI" | "What type? ML, deep learning, NLP, computer vision? Applied to what domain?" |
| "Important work" | "What is the specific scientific question? What gap in knowledge does this address?" |

### Vague Strategic Claims

| Vague Answer | Push-Back |
|-------------|-----------|
| "Get more funding" | "What specific amount? For what purpose? Over what timeframe?" |
| "Build the lab" | "How many positions? What equipment? What is the 3-year growth plan?" |
| "Diversify funding" | "Which new funders? What new mechanisms? What is the target portfolio mix?" |

---

## Data Quality Assessment Rubric

### Funding Information Quality Levels

| Level | Description | Criteria |
|-------|------------|----------|
| **A: Verified** | Data from official sources | Award letters, funder databases, audited financials |
| **B: Documented** | Data from institutional records | OSP records, departmental budgets, effort reports |
| **C: Estimated** | Reasonable estimates with basis | Based on published rates, comparable awards, guidelines |
| **D: Unverified** | Claims without supporting evidence | User assertions without documentation |

### Minimum Quality Requirements by Mode

| Mode | Required Level | Rationale |
|------|---------------|-----------|
| LANDSCAPE | C (Estimated) | Survey-level analysis can work with estimates |
| PORTFOLIO | B (Documented) | Funder-specific analysis needs institutional data |
| JUSTIFY | A (Verified) | Budget verification requires exact numbers |
| GAP | B (Documented) | Portfolio mapping needs current award data |

---

## Output Format Templates

### LANDSCAPE Mode Output Schema

```json
{
  "mode": "LANDSCAPE",
  "research_area": "...",
  "opportunities": [
    {
      "funder": "NIH NIGMS",
      "mechanism": "R01",
      "program": "Molecular Biophysics",
      "budget_range": {"min": 250000, "max": 1500000},
      "duration_years": 5,
      "deadline": "2026-02-05",
      "fit_score": 0.85,
      "notes": "Strong alignment with computational approaches"
    }
  ],
  "summary": {
    "total_opportunities": 8,
    "total_potential_funding": 5500000,
    "top_recommendation": "NIH NIGMS R01"
  }
}
```

### PORTFOLIO Mode Output Schema

```json
{
  "mode": "PORTFOLIO",
  "funder": "NIH NIGMS",
  "portfolio_analysis": {
    "total_awards_analyzed": 150,
    "median_award_size": 375000,
    "success_rate": 0.22,
    "priority_areas": ["computational biology", "structural biology"],
    "recent_trends": "Increasing emphasis on AI/ML approaches"
  },
  "past_awards": [
    {
      "pi": "...",
      "title": "...",
      "amount": 1200000,
      "years": "2022-2027",
      "relevance_score": 0.9
    }
  ]
}
```

### JUSTIFY Mode Output Schema

```json
{
  "mode": "JUSTIFY",
  "budget_document": "...",
  "verification_results": {
    "total_budget": 1250000,
    "categories_checked": 8,
    "issues_found": 2,
    "compliance_score": 0.92
  },
  "line_items": [
    {
      "category": "Personnel",
      "requested": 450000,
      "guideline_max": 500000,
      "status": "compliant",
      "notes": "PI effort within salary cap"
    }
  ],
  "issues": [
    {
      "category": "Travel",
      "issue": "Conference count exceeds typical allowance",
      "requested": 25000,
      "typical": 15000,
      "recommendation": "Justify each conference's relevance to project aims"
    }
  ]
}
```

### GAP Mode Output Schema

```json
{
  "mode": "GAP",
  "portfolio_summary": {
    "total_funded": 1500000,
    "total_needed": 2200000,
    "funding_gap": 700000,
    "coverage_ratio": 0.68
  },
  "funded_areas": [
    {
      "area": "MD simulations",
      "funder": "NIH R01",
      "amount": 1200000,
      "ends": "2027-03-31"
    }
  ],
  "unfunded_areas": [
    {
      "area": "ML infrastructure",
      "estimated_need": 150000,
      "priority": "high",
      "recommended_funders": ["NSF OAC", "DOE ASCR"]
    }
  ]
}
```

---

## Cross-References

- [Budget Patterns](budget-patterns.md) - Budget format templates and calculation patterns
- [Evaluation Patterns](evaluation-patterns.md) - Outcome measurement frameworks
- [Narrative Patterns](narrative-patterns.md) - Proposal writing structures
- [Proposal Structure](proposal-structure.md) - Section organization patterns
