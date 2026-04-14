# Timeline Frameworks

Domain knowledge for project planning, estimation, and risk management.

## Work Breakdown Structure (WBS)

A deliverable-oriented hierarchical decomposition of project work into manageable components.

### The 100% Rule

The most critical WBS principle: each level must capture 100% of the work defined by its parent.
- Sum of child elements equals 100% of parent element
- No gaps (missing work) or overlaps (duplicate work)
- Validates completeness at every decomposition level

### WBS Best Practices

| Practice | Description |
|----------|-------------|
| **Use Nouns** | WBS describes deliverables (what), not actions (how) |
| **Maintain Hierarchy** | Consistent naming, clear parent-child relationships |
| **Be Thorough** | Dictionary descriptions at work package level |
| **Avoid Over-Decomposition** | Too much detail creates management overhead |

### WBS Types

| Type | Organization | Best For |
|------|--------------|----------|
| **Deliverable-Based** | By project outputs | Complex products, clear deliverables |
| **Phase-Based** | By project phases | Sequential projects, predictable flow |

### Example Hierarchy

```
1.0 Website Redesign
├── 1.1 Design
│   ├── 1.1.1 Wireframes
│   ├── 1.1.2 Visual mockups
│   └── 1.1.3 Design approval
├── 1.2 Development
│   ├── 1.2.1 Frontend
│   ├── 1.2.2 Backend
│   └── 1.2.3 Integration
└── 1.3 Launch
    ├── 1.3.1 Testing
    ├── 1.3.2 Migration
    └── 1.3.3 Go-live
```

---

## Milestone Types

Five milestone categories covering the project lifecycle. Milestones are zero-duration markers, not tasks.

### Milestone Categories

| Type | Purpose | Examples |
|------|---------|----------|
| **Initiation** | Formal authorization/setup | Charter approval, team assembly, kickoff |
| **Approval** | External stakeholder decisions | Requirements sign-off, budget authorization |
| **Execution** | Tangible progress markers | Prototype delivery, beta launch, integration |
| **Delivery** | Output release to stakeholders | Product launch, feature release, go-live |
| **Review** | Post-delivery assessment | Lessons learned, benefits realization |

### Lifecycle Placement

```
Project Timeline
──────────────────────────────────────────────────────────────────►
│                                                                 │
│   [Initiation]    [Approval]    [Execution]    [Delivery]  [Review]
│       │              │              │             │           │
│   Charter        Requirements    Prototype      Launch      Retro
│   Kickoff        Sign-off        Complete       Release     Report
│                  Budget OK       Beta Ready
```

### Milestone Attributes

- **Zero Duration**: Mark completion, not activity
- **Measurable**: Clear pass/fail criteria
- **Stakeholder-Visible**: Communication touchpoints
- **Gate Function**: Proceed/no-proceed decision points

## Dependency Mapping

Four dependency types define how tasks relate to each other in a schedule.

### Dependency Types

| Type | Notation | Meaning | Example |
|------|----------|---------|---------|
| **Finish-to-Start** | FS | B cannot start until A finishes | Design -> Development |
| **Start-to-Start** | SS | B cannot start until A starts | Testing -> Documentation |
| **Finish-to-Finish** | FF | B cannot finish until A finishes | Electrical -> Drywall |
| **Start-to-Finish** | SF | B cannot finish until A starts | Guard shift handoff |

**Usage Frequency**: FS is most common (~90% of dependencies). SF is rare but useful for handoff scenarios.

### Lag and Lead Time

| Concept | Definition | Example |
|---------|------------|---------|
| **Lag** | Delay between dependent tasks | FS+2d: Wait 2 days after A finishes to start B |
| **Lead** | Overlap between dependent tasks | FS-3d: Start B 3 days before A finishes |

### Network Diagram Notation

```
┌───────────┐     FS      ┌───────────┐
│  Task A   │────────────►│  Task B   │
│  5 days   │             │  3 days   │
└───────────┘             └───────────┘
      │                         │
      │ SS+1d                   │ FF
      ▼                         ▼
┌───────────┐             ┌───────────┐
│  Task C   │             │  Task D   │
│  4 days   │             │  2 days   │
└───────────┘             └───────────┘
```

---

## Three-Point Estimation (PERT)

The Program Evaluation and Review Technique uses three estimates to account for uncertainty.

### PERT Formula (Beta Distribution)

```
Expected Duration (E) = (O + 4M + P) / 6
```

| Variable | Meaning |
|----------|---------|
| **O** | Optimistic estimate (best-case, 1% probability) |
| **M** | Most Likely estimate (realistic expectation) |
| **P** | Pessimistic estimate (worst-case, 1% probability) |
| **E** | Expected value (weighted average) |

### Standard Deviation

```
Standard Deviation (SD) = (P - O) / 6
```

Use for confidence intervals:
- 68% confidence: E +/- 1 SD
- 95% confidence: E +/- 2 SD
- 99% confidence: E +/- 3 SD

### Alternative: Triangular Distribution

```
E = (O + M + P) / 3
```

Simpler calculation when equal weight is acceptable.

### Practical Example

```
Task: API Integration
  Optimistic (O):  3 days (everything goes perfectly)
  Most Likely (M): 5 days (realistic expectation)
  Pessimistic (P): 12 days (complications arise)

PERT Calculation:
  E = (3 + 4*5 + 12) / 6
  E = (3 + 20 + 12) / 6
  E = 35 / 6 = 5.83 days

Standard Deviation:
  SD = (12 - 3) / 6 = 1.5 days

Result: 5.8 days expected, with 95% confidence between 2.8 and 8.8 days
```

## Critical Path Analysis

The Critical Path Method (CPM) identifies the longest sequence of dependent tasks determining minimum project duration.

### Key Concepts

| Concept | Definition |
|---------|------------|
| **Critical Path** | Longest sequence of dependent tasks |
| **Critical Tasks** | Zero float; any delay extends project |
| **Non-Critical Tasks** | Have float; can slip without project impact |
| **Float/Slack** | Time a task can slip without affecting project end |

### CPM Steps

1. **Define Activities**: List all project tasks
2. **Identify Dependencies**: Map task relationships
3. **Estimate Durations**: Assign time to each task
4. **Construct Network**: Build dependency diagram
5. **Forward Pass**: Calculate early start/finish dates
6. **Backward Pass**: Calculate late start/finish dates
7. **Identify Critical Path**: Tasks with zero float

### Float Calculation

```
Total Float = Late Start - Early Start
            = Late Finish - Early Finish

Free Float  = Earliest Start of Successors - Early Finish
```

### Example Network

```
                    ┌─────────────────┐
         ┌─────────►│ Task B: 4 days  ├─────────┐
         │          │ Float: 0        │         │
         │          └─────────────────┘         │
┌────────┴────────┐                     ┌───────▼───────┐
│ Task A: 3 days  │                     │ Task D: 2 days│
│ Float: 0        │                     │ Float: 0      │
└────────┬────────┘                     └───────▲───────┘
         │          ┌─────────────────┐         │
         └─────────►│ Task C: 2 days  ├─────────┘
                    │ Float: 2        │
                    └─────────────────┘

Critical Path: A -> B -> D (9 days)
Non-Critical: C has 2 days float
```

---

## Resource Allocation

Two primary techniques for managing resource constraints.

### Leveling vs Smoothing

| Technique | Constraint | Result | Use When |
|-----------|------------|--------|----------|
| **Resource Leveling** | Resources fixed | Timeline extends | Resource shortage |
| **Resource Smoothing** | Timeline fixed | Workload redistributed | Deadline non-negotiable |

### Resource Leveling

- Adjusts schedule to match resource availability
- May extend project duration
- Question: "When will work finish with available resources?"

### Resource Smoothing

- Works within existing timeline
- Redistributes tasks to avoid peaks/troughs
- Question: "How do we meet deadline with even workload?"

### Decision Matrix

```
                   Deadline Flexible?
                      Yes          No
                  ┌───────────┬───────────┐
Resource      Yes │   Either  │ Smoothing │
Flexible?         ├───────────┼───────────┤
              No  │  Leveling │  Problem  │
                  └───────────┴───────────┘
```

---

## Risk Assessment Matrix

A 2D grid mapping probability against impact to prioritize risks.

### 5x5 Risk Matrix

```
              │ Negligible │   Minor   │  Moderate │   Major   │  Severe   │
              │     1      │     2     │     3     │     4     │     5     │
──────────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Almost        │            │           │           │           │           │
Certain  5    │     5      │    10     │    15     │    20     │    25     │
──────────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Likely   4    │     4      │     8     │    12     │    16     │    20     │
──────────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Possible 3    │     3      │     6     │     9     │    12     │    15     │
──────────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Unlikely 2    │     2      │     4     │     6     │     8     │    10     │
──────────────┼────────────┼───────────┼───────────┼───────────┼───────────┤
Rare     1    │     1      │     2     │     3     │     4     │     5     │
──────────────┴────────────┴───────────┴───────────┴───────────┴───────────┘
```

### Risk Score Formula

```
Risk Score = Probability x Impact
```

### Risk Response by Score

| Score Range | Priority | Action |
|-------------|----------|--------|
| **15-25** | Critical | Immediate attention, active mitigation required |
| **8-14** | High | Monitor closely, develop contingency plans |
| **4-7** | Medium | Track regularly, consider mitigation |
| **1-3** | Low | Accept risk, minimal monitoring |

### Risk Response Strategies

| Strategy | Description | Example |
|----------|-------------|---------|
| **Avoid** | Eliminate the threat | Change scope to remove risk |
| **Transfer** | Shift impact to third party | Insurance, outsourcing |
| **Mitigate** | Reduce probability or impact | Extra testing, prototypes |
| **Accept** | Acknowledge and monitor | Budget contingency reserve |

---

## References

- [PMI WBS Basic Principles](https://www.pmi.org/learning/library/work-breakdown-structure-basic-principles-4883)
- [Atlassian WBS Guide](https://www.atlassian.com/work-management/project-management/work-breakdown-structure)
- [Project Management Academy PERT](https://projectmanagementacademy.net/resources/blog/a-three-point-estimating-technique-pert/)
- [Wrike Critical Path Guide](https://www.wrike.com/blog/critical-path-is-easy-as-123/)
- [Asana Critical Path Method](https://asana.com/resources/critical-path-method)
- [APM Resource Leveling vs Smoothing](https://www.apm.org.uk/resources/find-a-resource/difference-between-resource-smoothing-and-resource-levelling/)
- [Asana Risk Matrix Template](https://asana.com/resources/risk-matrix-template)
