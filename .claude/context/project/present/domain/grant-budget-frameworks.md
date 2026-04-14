# Grant Budget Frameworks

Domain knowledge for grant budget cost structures, F&A calculation, salary caps, and multi-year conventions.

## Cost Category Structure

Grant budgets follow a standard hierarchy of cost categories, regardless of funder:

```
Total Project Cost
  = Total Direct Costs + Indirect Costs (F&A)

Total Direct Costs
  = Personnel + Equipment + Travel + Participant Support + Other Direct Costs

Personnel
  = Sum(Salary x min(1, Cap/Salary) x Effort% + Fringe)

Indirect Costs
  = MTDC x F&A Rate
```

### Personnel Costs

Personnel is typically the largest budget category (60-80% of direct costs).

| Component | Description | Calculation |
|-----------|-------------|-------------|
| Base Salary | Institutional base salary (IBS) | Input value |
| Salary Cap | NIH Executive Level II limit | min(IBS, Cap) |
| Effort | Percent of time on project | 0-100% |
| Requested Salary | Amount charged to grant | min(IBS, Cap) x Effort% |
| Fringe Benefits | Institutional fringe rate | Requested Salary x Fringe Rate |
| Total Personnel | Per-person total | Requested Salary + Fringe |

**Roles**: PI, Co-PI, Senior Personnel, Postdoctoral Associates, Graduate Students, Undergraduate Students, Technical Staff, Administrative Staff, Consultants (not subject to fringe).

### Equipment

Items costing $5,000 or more per unit (threshold varies by institution). Equipment is:
- Excluded from MTDC base (not subject to indirect costs)
- Not subject to inflation escalation in multi-year budgets
- Typically purchased in Year 1

### Travel

| Type | Components |
|------|------------|
| Domestic | Airfare + hotel + per diem + ground transport |
| International | Same + visa/passport + additional per diem |
| Conference | Registration + travel + lodging |
| Field/Site | Vehicle + lodging + per diem |

Standard estimates: Domestic trip $1,500-2,500, International trip $3,000-5,000.

### Participant Support Costs

Costs paid directly to (or on behalf of) participants or trainees:
- Stipends
- Travel allowances
- Subsistence allowances
- Registration fees

**Key rule**: Participant support costs are excluded from MTDC base and cannot be re-budgeted without sponsor approval.

### Other Direct Costs

| Category | Examples |
|----------|----------|
| Materials/Supplies | Lab supplies, computing supplies, reagents |
| Publication | Page charges, open access fees |
| Consultant Services | Expert fees (not subject to fringe) |
| Computer Services | Cloud computing, HPC time |
| Sub-awards | Collaborative agreements with other institutions |
| Other | IRB fees, subject payments, software licenses |

### Sub-Award Rules

Sub-awards have special indirect cost treatment:
- **First $25,000** of each sub-award is included in MTDC base
- **Amounts exceeding $25,000** are excluded from MTDC base
- Each sub-awardee applies their own F&A rate to their portion

## F&A (Indirect) Cost Calculation

### Modified Total Direct Costs (MTDC)

MTDC is the base for calculating indirect costs:

```
MTDC = Total Direct Costs
     - Equipment (items >= $5,000)
     - Participant Support Costs
     - Sub-award amounts exceeding $25,000 per sub-award
     - Patient Care Costs
     - Tuition Remission
     - Rental Costs of Off-Site Facilities (if applicable)
```

### F&A Rate Application

```
Indirect Costs = MTDC x Negotiated F&A Rate

Common rates:
- Research (on-campus): 50-65%
- Research (off-campus): 26%
- Instruction: 40-55%
- Other sponsored: 30-40%
```

Rates are negotiated between institution and cognizant federal agency (usually DHHS or ONR).

### Administrative Cap

Per 2 CFR 200, the administrative portion of F&A is capped at 26% of MTDC for federal grants.

## NIH Salary Cap

The NIH limits salary charges on grants to Executive Level II of the Federal Executive Pay Scale.

| Fiscal Year | Cap Amount | Effective Date |
|-------------|------------|----------------|
| FY2026 | $221,900 | January 2026 |
| FY2025 | $221,900 | January 2025 |
| FY2024 | $221,900 | January 2024 |

**Calculation with cap**:
```
Capped Salary = min(Base Salary, $221,900)
Requested Amount = Capped Salary x Effort%
Institutional Cost Share = (Base Salary - Capped Salary) x Effort%  [if salary > cap]
```

**Note**: The salary cap applies to the annualized rate, not the amount requested. If PI salary is $250,000 at 25% effort, charge 25% x $221,900 = $55,475 (not 25% x $250,000).

## NIH Budget Modes

### Modular Budget (< $250,000/year direct costs)

- Budget requested in $25,000 modules
- Maximum 10 modules ($250,000) per year
- No detailed categorical breakdown required
- Must provide personnel justification
- Consortium/sub-award costs shown separately

```
Modules = ceil(Direct Costs / 25000)
Requested Amount = Modules x $25,000
```

### Detailed Budget (>= $250,000/year direct costs)

- Full categorical breakdown required
- Detailed justification for each category
- Per-year worksheets with all cost items
- Cumulative budget summary

## Multi-Year Budget Conventions

### Inflation Escalation

Standard federal grant escalation rates:
- **Personnel**: 3% annual increase (salary + fringe)
- **Supplies/Materials**: 3% annual increase
- **Travel**: 3% annual increase
- **Equipment**: No escalation (typically Year 1 only)
- **Participant Support**: No escalation (fixed amounts)
- **Sub-awards**: Per sub-awardee's own escalation

### Year-to-Year Formulas

```
Year N Salary = Year 1 Salary x (1.03)^(N-1)
Year N Fringe = Year N Salary x Fringe Rate
Year N Supplies = Year 1 Supplies x (1.03)^(N-1)
```

### Typical Project Periods

| Funder | Typical Period | Maximum |
|--------|---------------|---------|
| NIH R01 | 5 years | 5 years |
| NIH R21 | 2 years | 2 years |
| NSF Standard | 3 years | 5 years |
| Foundation | 1-3 years | Varies |
| SBIR Phase I | 6-12 months | 1 year |
| SBIR Phase II | 2 years | 2 years |

## Cost-Sharing

Some grants require institutional cost-sharing:
- **Mandatory**: Required by sponsor (e.g., NSF MRI requires 30%)
- **Voluntary committed**: Offered in proposal, becomes binding
- **Voluntary uncommitted**: Not in proposal, not binding

Cost-sharing must be:
- Verifiable from institutional records
- Not from other federal funds (usually)
- Necessary and reasonable
- Allowable under sponsor and institutional guidelines

## Key Formulas Reference

```
Personnel Cost     = min(Base_Salary, Salary_Cap) x Effort%
Fringe Benefits    = Personnel_Cost x Fringe_Rate%
Total Personnel    = Personnel_Cost + Fringe_Benefits
Total Direct Costs = Personnel + Equipment + Travel + Participant + Other
MTDC              = TDC - Equipment - Participant - SubAward_Over_25K
Indirect Costs     = MTDC x F&A_Rate%
Total Project Cost = TDC + Indirect_Costs
NIH Modules        = ceil(TDC / 25000) x $25,000
Year_N_Cost        = Year_1_Cost x (1 + Escalation_Rate)^(N-1)
```
