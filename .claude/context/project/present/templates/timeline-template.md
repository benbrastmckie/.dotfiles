# Research Timeline Report Template

Report template for timeline-agent structured output.

---

## {PROJECT_TITLE}

- **Grant Mechanism**: {mechanism} (e.g., R01, R21, K23)
- **PI**: {pi_name}
- **Project Period**: {start_date} - {end_date} ({N} years)
- **Budget Periods**: {N} annual periods
- **NCE Status**: {none | requested | approved}

---

## Specific Aims WBS

### Aim 1: {Aim Title}

- **Timeline**: Budget Period {N} - Budget Period {N} (Months {M}-{M})
- **Regulatory Prerequisites**: {IRB | IACUC | None}
- **Dependencies**: {None | Aim N sub-aim}

#### Sub-Aims

| Sub-Aim | Description | Duration (months) | Dependencies |
|---------|-------------|-------------------|--------------|
| 1a | {description} | {O/M/P -> E} | {none | sub-aim ref} |
| 1b | {description} | {O/M/P -> E} | {none | sub-aim ref} |

#### Deliverables

- {Publication / Dataset / Model / Report}
- {Publication / Dataset / Model / Report}

### Aim 2: {Aim Title}

(Same structure as Aim 1)

### Aim 3: {Aim Title}

(Same structure as Aim 1)

---

## Regulatory Milestones

| Milestone | Type | Required By | Lead Time (E) | Status |
|-----------|------|-------------|---------------|--------|
| {IRB Protocol Submission} | IRB | Aim 1 start | {E months} | {pending | approved | n/a} |
| {IACUC Protocol} | IACUC | Aim 2 start | {E months} | {pending | approved | n/a} |
| {ClinicalTrials.gov} | Registration | First enrollment | {E months} | {pending | completed | n/a} |

---

## PERT Estimates Table

| Task | Optimistic | Most Likely | Pessimistic | Expected | SD | Unit |
|------|-----------|-------------|-------------|----------|-----|------|
| {Aim 1a: experiment} | {O} | {M} | {P} | {E} | {SD} | months |
| {Aim 1b: analysis} | {O} | {M} | {P} | {E} | {SD} | months |
| {Aim 2a: experiment} | {O} | {M} | {P} | {E} | {SD} | months |
| ... | | | | | | |
| **Critical Path Total** | | | | **{E}** | **{SD}** | months |

### Confidence Intervals

- 68% CI: {E} +/- {1*SD} months = {low} - {high} months
- 95% CI: {E} +/- {2*SD} months = {low} - {high} months

---

## Resource Allocation

### Key Personnel

| Role | Name | BP1 (cal mo) | BP2 (cal mo) | BP3 (cal mo) | BP4 (cal mo) | BP5 (cal mo) |
|------|------|-------------|-------------|-------------|-------------|-------------|
| PI | {name} | {effort} | {effort} | {effort} | {effort} | {effort} |
| Co-I | {name} | {effort} | {effort} | {effort} | {effort} | {effort} |
| Postdoc | {name} | {effort} | {effort} | {effort} | {effort} | {effort} |
| Grad Student | {name} | {effort} | {effort} | {effort} | {effort} | {effort} |
| Technician | {name} | {effort} | {effort} | {effort} | {effort} | {effort} |

### Effort Validation

- Total effort per person per year does not exceed 12 cal months across all funding sources
- PI minimum effort requirement met: {yes/no} ({N} cal months)

---

## Critical Path

```
{Regulatory Approval} (E months)
  → {Aim 1 Setup} (E months)
  → {Aim 1 Core Experiments} (E months)
  → {Aim 2 Dependent Tasks} (E months)
  → {Aim 3 Analysis} (E months)
  → {Final Reporting} (E months)

Total Critical Path: {E} months (95% CI: {low}-{high})
Project Period: {N} months
Float: {N} months
```

---

## Reporting Schedule

| Report | Due Date | Budget Period | Type |
|--------|----------|---------------|------|
| RPPR #1 | {date} | End of BP1 | Annual |
| RPPR #2 | {date} | End of BP2 | Annual |
| RPPR #3 | {date} | End of BP3 | Annual |
| RPPR #4 | {date} | End of BP4 | Annual |
| Final RPPR | {date} | End of BP5 | Terminal |
| Final FFR | {date} | End of BP5 | Terminal |
| Final Invention Statement | {date} | End of BP5 | Terminal |

---

## Risk Register

| Risk | Likelihood | Impact | Schedule Effect | Mitigation |
|------|-----------|--------|-----------------|------------|
| {Regulatory delay} | {H/M/L} | {H/M/L} | +{N} months | {mitigation strategy} |
| {Recruitment shortfall} | {H/M/L} | {H/M/L} | +{N} months | {mitigation strategy} |
| {Key personnel departure} | {H/M/L} | {H/M/L} | +{N} months | {mitigation strategy} |
| {Experimental failure} | {H/M/L} | {H/M/L} | +{N} months | {mitigation strategy} |
| {Equipment/supply delay} | {H/M/L} | {H/M/L} | +{N} months | {mitigation strategy} |

---

## Raw JSON Data Block

```json
{
  "project": {
    "title": "",
    "mechanism": "",
    "pi": "",
    "start_date": "",
    "end_date": "",
    "budget_periods": 5
  },
  "aims": [
    {
      "number": 1,
      "title": "",
      "start_month": 1,
      "end_month": 24,
      "sub_aims": [
        {
          "id": "1a",
          "title": "",
          "optimistic": 0,
          "likely": 0,
          "pessimistic": 0,
          "dependencies": []
        }
      ],
      "regulatory": ["IRB"],
      "deliverables": []
    }
  ],
  "regulatory_milestones": [
    {
      "type": "IRB",
      "required_by": "Aim 1",
      "lead_time_months": 2,
      "status": "pending"
    }
  ],
  "personnel": [
    {
      "role": "PI",
      "name": "",
      "effort_by_period": [3, 3, 3, 3, 3]
    }
  ],
  "critical_path": {
    "tasks": [],
    "total_expected_months": 0,
    "total_sd_months": 0
  },
  "reporting": [
    {
      "type": "RPPR",
      "due_date": "",
      "budget_period": 1
    }
  ],
  "risks": []
}
```
