# Project Planning Reference

Reference material for project-timeline report type planning and implementation.

## Project Management Terminology

| Term | Definition |
|------|-----------|
| **WBS** | Work Breakdown Structure - hierarchical decomposition of project scope into deliverables |
| **PERT** | Program Evaluation and Review Technique - three-point estimation method |
| **CPM** | Critical Path Method - identifies the longest sequence of dependent tasks |
| **Gantt Chart** | Bar chart showing task durations, dependencies, and timeline |
| **Milestone** | Zero-duration marker representing a significant project event |
| **Float/Slack** | Amount of time a task can be delayed without affecting the project end date |
| **Critical Path** | Sequence of tasks with zero float - any delay extends the project |
| **Resource Leveling** | Adjusting schedule to resolve resource overallocation |
| **BATNA** | Best Alternative To a Negotiated Agreement (used in stakeholder negotiations) |

## WBS Validation Rules

### The 100% Rule
The WBS must account for 100% of the project scope:
- Every deliverable in the project scope must appear in the WBS
- No work outside the scope should be included
- Sum of child elements must equal the parent element

### Deliverable-Based Decomposition
- Decompose by deliverable, not by activity
- Each leaf node (work package) should be estimable
- Recommended 3-5 levels of decomposition
- Work packages should represent 8-80 hours of effort

### Validation Checklist
- [ ] All scope items have corresponding WBS elements
- [ ] No orphan tasks (tasks not linked to a deliverable)
- [ ] Leaf nodes are at estimable granularity
- [ ] No duplication across branches
- [ ] Each element has a single owner

## PERT Calculation Formulas

### Three-Point Estimation
Given three estimates per task:
- **O** = Optimistic (best case)
- **M** = Most Likely (normal conditions)
- **P** = Pessimistic (worst case)

### Expected Duration
```
Expected (E) = (O + 4M + P) / 6
```

### Standard Deviation
```
SD = (P - O) / 6
```

### Variance
```
Variance = SD^2 = ((P - O) / 6)^2
```

### Project Duration Confidence
For the critical path total:
```
Project SD = sqrt(sum of variances on critical path)
```
- 68% confidence: E +/- 1 SD
- 95% confidence: E +/- 2 SD
- 99.7% confidence: E +/- 3 SD

## Critical Path Method (CPM)

### Forward Pass (Early Dates)
Calculate earliest possible start and finish for each task:
1. Start at project beginning (ES = 0 for first tasks)
2. Early Finish (EF) = Early Start (ES) + Duration
3. For tasks with predecessors: ES = max(EF of all predecessors)
4. Project duration = max(EF of all final tasks)

### Backward Pass (Late Dates)
Calculate latest allowable start and finish:
1. Start at project end (LF = project duration for final tasks)
2. Late Start (LS) = Late Finish (LF) - Duration
3. For tasks with successors: LF = min(LS of all successors)

### Float/Slack Calculation
```
Total Float = LS - ES = LF - EF
Free Float = min(ES of successors) - EF
```

### Critical Path Identification
- Tasks with Total Float = 0 are on the critical path
- The critical path is the longest path through the network
- Multiple critical paths are possible
- Near-critical paths (float < threshold) deserve monitoring

## Resource Leveling Guidance

### Overallocation Detection
A resource is overallocated when assigned > 100% capacity in any time period:
- Sum all task assignments per resource per time unit
- Flag periods where total exceeds availability percentage
- Priority resolution: critical path tasks take precedence

### Resolution Strategies (in order of preference)
1. **Delay non-critical tasks** - Use available float to shift tasks
2. **Split tasks** - Break a task across non-contiguous periods
3. **Reassign** - Move task to available resource with required skills
4. **Extend duration** - Reduce resource percentage, extend task duration
5. **Add resources** - Last resort, as it increases cost and communication overhead

### Availability Modeling
- Account for partial availability (e.g., 50% on Project A, 50% on Project B)
- Include non-working periods (vacation, holidays, other commitments)
- Build in buffer for unplanned interruptions (typically 10-20%)
