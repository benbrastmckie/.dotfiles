# Timeline Patterns

Reference material for research timeline planning and validation.

## Research Timeline Terminology

| Term | Definition |
|------|-----------|
| **Specific Aim** | Major research objective corresponding to a WBS phase |
| **Sub-Aim** | Component experiment or analysis within an aim |
| **Budget Period** | Annual funding increment (typically 12 months) |
| **Calendar Months** | Unit of personnel effort (1 cal month = 1/12 annual effort) |
| **NCE** | No-Cost Extension -- additional time without additional funds |
| **RPPR** | Research Performance Progress Report (NIH annual report) |
| **IRB** | Institutional Review Board (human subjects approval) |
| **IACUC** | Institutional Animal Care and Use Committee (animal protocol approval) |
| **DSMB** | Data Safety Monitoring Board (clinical trial oversight) |
| **PERT** | Program Evaluation and Review Technique (three-point estimation) |
| **Critical Path** | Longest sequence of dependent tasks determining project duration |

## Timeline Validation Rules

### Structure Validation

- [ ] Every specific aim has at least one sub-aim or milestone
- [ ] All regulatory prerequisites are identified for each aim
- [ ] Cross-aim dependencies are explicitly declared
- [ ] Reporting milestones align with budget period boundaries
- [ ] Personnel effort sums do not exceed 12 cal months per person per year
- [ ] NCE provisions are noted if applicable

### Schedule Validation

- [ ] No aim starts before its regulatory prerequisite is approved
- [ ] Recruitment tasks have realistic enrollment rate assumptions
- [ ] PERT estimates use months as the standard unit
- [ ] Critical path does not exceed project period (including any NCE)
- [ ] Each budget period has sufficient funded effort allocated
- [ ] Publication milestones account for peer review cycles

### Completeness Validation

- [ ] 100% of funded work appears in the WBS
- [ ] All personnel listed have effort allocations by budget period
- [ ] Every regulatory milestone has a lead time estimate
- [ ] Risk register identifies at least the top 3 schedule risks
- [ ] Reporting schedule matches funder requirements

## PERT Calculation Formulas

### Three-Point Estimation (Research Adapted)

Given three estimates per milestone (in months):
- **O** = Optimistic (everything works first time)
- **M** = Most Likely (normal research conditions, minor setbacks)
- **P** = Pessimistic (significant delays, experimental repeats)

### Expected Duration

```
Expected (E) = (O + 4M + P) / 6
```

### Standard Deviation

```
SD = (P - O) / 6
```

### Project Duration Confidence

For the critical path total:
```
Project SD = sqrt(sum of variances on critical path)
```
- 68% confidence: E +/- 1 SD
- 95% confidence: E +/- 2 SD
- 99.7% confidence: E +/- 3 SD

### Research-Specific Estimation Adjustments

| Task Type | Optimistic Multiplier | Pessimistic Multiplier |
|-----------|----------------------|----------------------|
| Established protocol | 1.0x | 1.5x |
| Novel methodology | 1.0x | 2.0-3.0x |
| Regulatory submission | 1.0x | 2.0x |
| Recruitment/enrollment | 1.0x | 2.5-3.0x |
| Data analysis | 1.0x | 1.5-2.0x |
| Publication (submission to acceptance) | 1.0x | 2.0-3.0x |

## Effort Conversion Rules

### Calendar Months to Percentage

```
Percentage = (Calendar Months / 12) * 100
```

### Common Effort Levels

| Calendar Months | Percentage | Description |
|----------------|-----------|-------------|
| 1.2 | 10% | Minimal involvement |
| 2.4 | 20% | Part-time contribution |
| 3.6 | 30% | Significant involvement |
| 6.0 | 50% | Half-time |
| 9.0 | 75% | K-series minimum (PI) |
| 12.0 | 100% | Full-time |

### Effort Validation

- PI effort on R01: minimum 1.2 cal months (NIH expectation varies by institute)
- K-series awardee: minimum 9 cal months (75% effort)
- Postdoc: typically 9-12 cal months
- Total effort per person across all grants must not exceed 12 cal months

## Milestone Lead Time Estimates

### Regulatory Milestones

| Milestone | Optimistic | Most Likely | Pessimistic | Notes |
|-----------|-----------|-------------|-------------|-------|
| IRB initial review | 1 month | 2 months | 4 months | Full board vs. expedited |
| IRB amendment | 0.5 months | 1 month | 2 months | Minor vs. major |
| IACUC initial review | 0.75 months | 1.5 months | 3 months | Species-dependent |
| IACUC amendment | 0.5 months | 1 month | 1.5 months | |
| DSMB setup | 1.5 months | 3 months | 5 months | Member recruitment |
| IND submission | 1 month | 1.5 months | 3 months | FDA 30-day review |

### Personnel Milestones

| Milestone | Optimistic | Most Likely | Pessimistic |
|-----------|-----------|-------------|-------------|
| Postdoc recruitment | 2 months | 4 months | 6 months |
| Technician hiring | 1 month | 2 months | 4 months |
| Graduate student rotation | Fixed | Fixed | Fixed |
| Visiting scholar visa | 2 months | 4 months | 8 months |

## Report Template Structure

### Timeline Research Report Sections

1. **Project Overview** -- Grant mechanism, PI, project period, total aims
2. **Specific Aims WBS** -- Hierarchical breakdown with sub-aims
3. **Regulatory Milestones** -- Required approvals with lead times
4. **PERT Estimates Table** -- Three-point estimates for all milestones
5. **Resource Allocation** -- Key personnel with effort by budget period
6. **Critical Path** -- Longest dependency chain with total duration
7. **Reporting Schedule** -- Annual and terminal report due dates
8. **Risk Register** -- Top schedule risks with likelihood, impact, mitigation
9. **Raw JSON Data Block** -- Machine-readable timeline data for Typst rendering
