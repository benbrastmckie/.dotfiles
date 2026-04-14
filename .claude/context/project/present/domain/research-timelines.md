# Research Timelines

Domain knowledge for medical research project planning, estimation, and timeline management.

## Specific Aims as WBS Phases

NIH-style grants organize research around 2-4 Specific Aims, which map naturally to a Work Breakdown Structure:

### Hierarchy Mapping

```
1.0 Research Project
├── 1.1 Specific Aim 1: {Descriptive title}
│   ├── 1.1.1 Sub-Aim 1a: {Experiment/analysis}
│   ├── 1.1.2 Sub-Aim 1b: {Experiment/analysis}
│   └── 1.1.3 Milestone: {Deliverable}
├── 1.2 Specific Aim 2: {Descriptive title}
│   ├── 1.2.1 Sub-Aim 2a: {Experiment/analysis}
│   └── 1.2.2 Sub-Aim 2b: {Experiment/analysis}
├── 1.3 Specific Aim 3: {Descriptive title}
│   └── 1.3.1 Sub-Aim 3a: {Experiment/analysis}
└── 1.4 Cross-Cutting Activities
    ├── 1.4.1 Regulatory Compliance
    ├── 1.4.2 Data Management
    └── 1.4.3 Dissemination
```

### Cross-Aim Dependencies

Research aims frequently have dependencies:
- **Sequential**: Aim 2 depends on Aim 1 results (e.g., model validation before application)
- **Shared Resource**: Aims share animal cohorts, equipment, or personnel
- **Data Flow**: Aim 3 analysis depends on Aim 1 and Aim 2 data collection
- **Methodological**: Aim 2 uses methods developed in Aim 1

### The 100% Rule (Research Adaptation)

All funded work must appear in the WBS:
- Every experiment described in the funded proposal must map to a sub-aim
- Regulatory activities (IRB, IACUC) must be included as cross-cutting tasks
- Reporting obligations (RPPR, final report) must appear as milestones
- No unfunded work should be included in the timeline scope

---

## Regulatory Milestone Categories

Research projects require regulatory approvals that are zero-duration milestones with external dependencies and significant lead times.

### Milestone Taxonomy

| Category | Acronym | Purpose | Typical Lead Time | Renewal |
|----------|---------|---------|-------------------|---------|
| **Human Subjects** | IRB | Ethical review of human research | 2-4 months | Annual continuing review |
| **Animal Use** | IACUC | Animal protocol approval | 1-3 months | Triennial renewal |
| **Data Safety** | DSMB | Trial monitoring board | 2-4 months setup | Per-protocol meetings |
| **Drug/Device** | IND/IDE | FDA regulatory submission | 6-12 months | Annual reports |
| **Trial Registration** | ClinicalTrials.gov | Public trial registration | 2-4 weeks | Results reporting |
| **Data Sharing** | DMS Plan | Data management and sharing | Pre-award | Per DMSP schedule |
| **Export Control** | EAR/ITAR | International collaboration | 1-6 months | Per-agreement |

### Regulatory Prerequisite Chains

```
IRB Submission
    → IRB Approval
    → Participant Recruitment Start
    → First Enrollment
    → Data Collection Begin

IACUC Submission
    → IACUC Approval
    → Animal Ordering
    → Acclimation Period
    → Experiment Start

IND Submission
    → FDA 30-Day Review
    → IND Active
    → First-in-Human Dosing
```

### Lead Time Estimates

| Milestone | Optimistic | Most Likely | Pessimistic |
|-----------|-----------|-------------|-------------|
| IRB initial review | 4 weeks | 8 weeks | 16 weeks |
| IRB amendment | 2 weeks | 4 weeks | 8 weeks |
| IACUC initial review | 3 weeks | 6 weeks | 12 weeks |
| IACUC amendment | 2 weeks | 4 weeks | 6 weeks |
| DSMB setup | 6 weeks | 12 weeks | 20 weeks |
| IND submission to clearance | 4 weeks | 6 weeks | 12 weeks |
| ClinicalTrials.gov registration | 1 week | 2 weeks | 4 weeks |

---

## Reporting Schedule Patterns

### NIH Reporting

| Report | Frequency | Due Date | Scope |
|--------|-----------|----------|-------|
| **RPPR** | Annual | Within 90 days of budget period end | Progress, publications, personnel changes |
| **Final RPPR** | Terminal | Within 120 days of project end | Cumulative progress |
| **Final FFR** | Terminal | Within 120 days of project end | Financial expenditures |
| **Final Invention Statement** | Terminal | Within 120 days of project end | IP disclosures |
| **Inclusion Enrollment Report** | Annual (if applicable) | With RPPR | Demographic enrollment data |

### NSF Reporting

| Report | Frequency | Due Date |
|--------|-----------|----------|
| **Annual Project Report** | Annual | Within 90 days of anniversary |
| **Final Project Report** | Terminal | Within 120 days of expiration |
| **Project Outcomes Report** | Terminal | Within 1 year of expiration |

### Reporting Period Alignment

Reports align with budget periods, not calendar years:
- Budget Period 1: Award start -> 12 months
- Budget Period 2: Month 13 -> Month 24
- Etc.

---

## Grant Mechanism Timeline Patterns

### Common NIH Mechanisms

| Mechanism | Duration | Budget Periods | Key Features |
|-----------|----------|----------------|--------------|
| **R01** | 3-5 years | Annual | Standard research project |
| **R21** | 2 years | 2 periods | Exploratory/developmental |
| **R03** | 2 years | 2 periods | Small research grant |
| **K-series** | 3-5 years | Annual | Career development (75% effort minimum) |
| **U01** | 3-5 years | Annual | Cooperative agreement |
| **P01** | 5 years | Annual | Program project (multiple components) |
| **T32** | 5 years | Annual | Training grant |
| **F31/F32** | 2-3 years | Annual | Fellowship |

### R01 5-Year Timeline Pattern

```
Year 1: Setup + Aim 1 begins
  - Regulatory approvals (Months 1-4)
  - Personnel hiring (Months 1-3)
  - Aim 1 experiments (Months 3-12)

Year 2: Aim 1 completes + Aim 2 begins
  - Aim 1 data analysis (Months 13-18)
  - Aim 2 setup and pilot (Months 15-24)
  - RPPR #1

Year 3: Aim 2 core + Aim 3 begins
  - Aim 2 main experiments (Months 25-36)
  - Aim 3 pilot studies (Months 30-36)
  - RPPR #2

Year 4: Aim 2 completes + Aim 3 core
  - Aim 2 analysis and publications (Months 37-42)
  - Aim 3 main experiments (Months 37-48)
  - RPPR #3, Renewal application (if applicable)

Year 5: Aim 3 completes + Dissemination
  - Aim 3 analysis (Months 49-54)
  - Publications and presentations (Months 49-60)
  - RPPR #4, Final reports
```

---

## No-Cost Extensions (NCEs)

### NCE Types

| Type | Duration | Approval | Justification |
|------|----------|----------|---------------|
| **Standard NCE** | Up to 12 months | PI-initiated (NIH automatic) | Needed to complete aims |
| **Second NCE** | Up to 12 months | Agency approval required | Written justification with timeline |

### NCE Impact on Timeline

When an NCE is granted:
1. Project end date extends by approved duration
2. All pending milestones shift forward
3. Reporting schedule adjusts to new end date
4. No additional funds (existing budget must cover extended period)
5. Effort allocations may need adjustment

### NCE Decision Factors

- Remaining balance vs. remaining work
- Personnel availability during extension
- Impact on dependent projects
- Competitive renewal timing implications

---

## Effort Allocation

### Calendar Month Units

Research effort is measured in calendar months, not percentages:
- 1 calendar month = 1/12 of total annual effort
- 12 calendar months = 100% effort on one project
- A PI committing 3 calendar months = 25% effort

### Effort by Role

| Role | Typical R01 Effort | Notes |
|------|-------------------|-------|
| PI | 2.4-6 cal months | NIH expects meaningful commitment |
| Co-I | 1.2-3 cal months | Per co-investigator |
| Postdoc | 9-12 cal months | Often full-time on project |
| Graduate Student | 6-12 cal months | Academic year + summer |
| Research Technician | 6-12 cal months | Often shared across grants |
| Biostatistician | 1.2-3 cal months | Analysis phases heavier |

### Budget Period Alignment

Effort must be specified per budget period:
- Year 1: Higher setup effort (hiring, training)
- Middle years: Peak experimental effort
- Final year: Analysis and dissemination effort

---

## PERT for Research Tasks

### Three-Point Estimation Adaptations

Research tasks have higher uncertainty than business projects:
- Use months as the standard unit (not days/weeks)
- Pessimistic estimates should account for experimental failure and repeats
- Regulatory milestones use external dependency lead times
- Publication timelines include peer review cycles (3-12 months)

### Research-Specific Uncertainty Factors

| Factor | Impact on Estimates |
|--------|-------------------|
| Novel methodology | Increase pessimistic by 50-100% |
| Regulatory approval | Add lead time as prerequisite, not task duration |
| Recruitment | Highly variable; use historical enrollment rates |
| Animal breeding | Seasonal and genetic variability |
| Equipment procurement | Supply chain delays possible |
| Personnel hiring | 3-6 months for postdoc recruitment |

---

## Critical Path in Research

### Typical Critical Path Elements

1. Regulatory approvals (longest lead time in early project)
2. Personnel recruitment and training
3. Sequential aim dependencies
4. Recruitment/enrollment targets
5. Data analysis bottlenecks (shared biostatistician)
6. Publication cycles for aim completion metrics

### Research-Specific Float

- **Regulatory float**: Time between planned submission and latest acceptable approval date
- **Recruitment float**: Buffer between enrollment target and statistical power minimum
- **Publication float**: Time between submission and grant reporting deadline
