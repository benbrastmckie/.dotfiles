# Legal Planning Context

Domain knowledge for generating high-quality contract analysis implementation plans.

## Contract Analysis Methodology

Contract analysis follows a structured three-stage approach:

1. **Decomposition**: Break the contract into individual clauses and provisions
2. **Assessment**: Evaluate each clause against the client's position, risk tolerance, and objectives
3. **Synthesis**: Produce actionable recommendations with prioritized negotiation strategy

The plan agent generates phases that map to these stages: Phase 1 (Decomposition), Phase 2 (Assessment), Phase 3 (Synthesis).

## Clause Categorization Taxonomy

When generating Phase 1 (Clause-by-Clause Analysis), the plan should instruct categorization into these standard clause types:

| Category | Description | Common Concerns |
|----------|-------------|-----------------|
| **Intellectual Property** | IP ownership, assignment, licensing, work-for-hire | Who owns what is created during the engagement |
| **Liability & Indemnification** | Liability caps, indemnification obligations, insurance | Maximum financial exposure and who bears risk |
| **Termination** | Termination triggers, notice periods, survival clauses | How and when either party can exit |
| **Data Rights** | Data ownership, processing, retention, deletion | Control over data generated or shared |
| **Non-Compete / Non-Solicitation** | Restrictive covenants, geographic/temporal scope | Constraints on future business activities |
| **Payment & Financial** | Payment terms, milestones, late fees, currency | Cash flow timing and financial obligations |
| **Representations & Warranties** | Accuracy claims, compliance assertions | What each party guarantees to be true |
| **Confidentiality** | NDA provisions, exceptions, duration | Information protection scope and duration |
| **Dispute Resolution** | Arbitration, jurisdiction, governing law | How disagreements are resolved |

## BATNA/ZOPA Framework (Phase 3)

When generating Phase 3 (Negotiation Strategy), the plan should define these analytical frameworks:

### BATNA (Best Alternative to Negotiated Agreement)
- The best outcome achievable WITHOUT reaching agreement on this contract
- Establishes the walk-away point: if the deal is worse than BATNA, walk away
- Derived from the research report's Walk-Away Conditions and Financial Exposure fields
- Example: "BATNA is to continue with current vendor at $X/year with known limitations"

### ZOPA (Zone of Possible Agreement)
- The range between each party's reservation price where agreement is possible
- If no ZOPA exists, negotiation cannot succeed without changing terms
- Derived from the research report's Negotiating Position and Financial Exposure
- Example: "ZOPA exists between $50K-80K annual license fee based on market comparables"

### Negotiation Priority Tiers
Plans should instruct the implementation agent to classify negotiation points into:
- **Redlines**: Non-negotiable items (walk away if not met)
- **High Priority**: Strongly preferred but tradeable for significant concessions
- **Negotiable**: Preferred position exists but flexible
- **Acceptable**: Current terms are adequate

## Risk Scoring Methodology (Phase 2)

When generating Phase 2 (Risk Assessment Matrix), the plan should use a likelihood x impact framework:

### Likelihood Scale
| Score | Label | Description |
|-------|-------|-------------|
| 1 | Unlikely | Remote possibility, requires multiple failures |
| 2 | Possible | Could occur under specific circumstances |
| 3 | Likely | Expected to occur during contract term |
| 4 | Almost Certain | Will occur without mitigation |

### Impact Scale
| Score | Label | Description |
|-------|-------|-------------|
| 1 | Minor | Negligible financial or operational impact |
| 2 | Moderate | Manageable cost or disruption |
| 3 | Significant | Material financial impact or major disruption |
| 4 | Severe | Existential threat or unrecoverable loss |

### Risk Rating
- **Risk Score** = Likelihood x Impact (range 1-16)
- **Critical** (12-16): Requires immediate attention, potential dealbreaker
- **High** (8-11): Must be addressed in negotiation
- **Medium** (4-7): Should be addressed if possible
- **Low** (1-3): Acceptable risk, monitor only

## Escalation Thresholds

The research report includes an Escalation Assessment. Plans should incorporate escalation criteria:

| Threshold | Action |
|-----------|--------|
| **Self-service** | Standard contract, low value, template-based terms |
| **Legal review recommended** | Non-standard terms, moderate financial exposure, unusual clauses |
| **Attorney required** | High-value contract, complex IP terms, cross-border jurisdiction |
| **Specialized counsel** | Regulatory compliance, M&A, securities, international trade |

The plan should ensure that the escalation level from the research report influences the depth and rigor of each phase. Higher escalation levels require more detailed analysis in Phases 1-3.

## Phase-Specific Planning Guidance

### Phase 1 Plans Should Include
- Instruction to read the full contract text (if available) or work from the research summary
- Categorization using the taxonomy above
- Cross-reference each clause with the research report's Primary Concerns
- Flag any clauses not covered by the research report's Red Flags list

### Phase 2 Plans Should Include
- Risk scoring using the likelihood x impact matrix
- Explicit comparison against Walk-Away Conditions from research
- Financial exposure calculation for each high-risk clause
- Aggregated risk profile summary

### Phase 3 Plans Should Include
- BATNA construction from research report's Walk-Away Conditions
- ZOPA estimation from research report's Financial Exposure and Position Assessment
- Priority tier assignment for each negotiation point
- Concession strategy (what to trade for what)
- Escalation recommendation based on overall risk profile
