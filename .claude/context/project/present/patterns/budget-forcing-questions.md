# Budget Forcing Questions

Grant-adapted forcing question framework for structured budget data gathering. Adapted from founder extension cost-forcing-questions pattern for medical research grant budgets.

## Overview

Budget forcing questions extract precise financial data through one-question-at-a-time interaction. Questions are split between two stages:

| Stage | Location | Questions | Purpose |
|-------|----------|-----------|---------|
| Pre-task (STAGE 0) | /budget command | 3 questions | Determine mode, scope, and constraints |
| Research phase | budget-agent | 7-10 questions | Gather detailed cost data |

## Pre-Task Questions (STAGE 0)

These questions run BEFORE task creation in the /budget command.

### Q0.1: Funder Type Selection

```
What type of grant budget are you preparing?

A) NIH MODULAR - Under $250K/year direct costs, requested in $25K modules
B) NIH DETAILED - $250K+ /year direct costs, full categorical breakdown
C) NSF - Standard NSF budget format (categories A through J)
D) FOUNDATION - Simplified format for private foundations
E) SBIR - Small Business Innovation Research (Phase I or II)

Which format?
```

Store as `forcing_data.mode` (values: MODULAR, DETAILED, NSF, FOUNDATION, SBIR).

### Q0.2: Project Period

```
What is the project period?

- Number of years (e.g., 3, 5)
- Start date (e.g., July 2026)
- Mechanism if known (e.g., R01, R21, NSF CAREER)
```

Store as `forcing_data.project_period`.

### Q0.3: Direct Cost Cap

```
What is your target annual direct cost amount?

This determines budget scale and (for NIH) whether modular or detailed format applies.
- NIH Modular: up to $250,000/year
- NIH Detailed: $250,000+/year
- NSF: varies by program

Enter approximate annual direct costs:
```

Store as `forcing_data.direct_cost_cap`.

## Research Phase Questions (Budget Agent)

These questions run during the budget-agent research phase, after task creation.

### Q1: PI and Senior Personnel

```
Who are the key personnel on this grant?

For each person, I need:
- Name (or TBN for to-be-named)
- Role (PI, Co-PI, Senior Personnel)
- Percent effort on this project
- Institutional base salary (annual)
- Fringe benefit rate (or institutional default)

Start with the PI:
```

**Follow-up**: After each person, ask "Any additional senior personnel?"

### Q2: Other Personnel

```
What other personnel will be supported?

Common categories:
- Postdoctoral associates (salary + fringe)
- Graduate students (stipend + tuition + fringe)
- Undergraduate students (hourly rate)
- Technical/research staff
- Administrative support

For each: role, number of positions, annual cost or hourly rate, effort%
```

### Q3: Equipment

```
Any equipment purchases over $5,000 per unit?

Equipment is excluded from indirect costs (F&A).
For each item:
- Description
- Quantity
- Unit cost
- Justification (why needed for the project)
- Year of purchase (typically Year 1)

Skip if no equipment needed.
```

### Q4: Travel

```
What travel is planned for this project?

Common grant travel:
- Domestic conferences (1-2 per year typical)
- International conferences
- Collaborator site visits
- Field work / data collection travel

For each trip type:
- Number of trips per year
- Estimated cost per trip
- Domestic or international
```

### Q5: Participant Support

```
Does this project involve participant support costs?

Participant support includes:
- Stipends paid to trainees/participants
- Travel allowances for participants
- Subsistence allowances
- Registration fees

Note: These costs are excluded from indirect and cannot be re-budgeted.
Enter details or skip if not applicable:
```

### Q6: Other Direct Costs

```
What other direct costs do you anticipate?

Common categories:
- Materials and supplies (lab, computing, office)
- Publication costs (page charges, open access)
- Consultant services (name, daily rate, days)
- Computer services (cloud, HPC)
- Sub-awards (institution, estimated annual cost)
- Other (IRB fees, subject payments, software licenses)

For each: category, annual amount, brief justification
```

**Sub-award follow-up**: If sub-awards mentioned, ask:
```
For each sub-award, I need:
- Sub-awardee institution
- PI at sub-awardee
- Annual direct costs
- Sub-awardee's F&A rate (if known)

Note: First $25K of each sub-award is subject to your indirect costs.
```

### Q7: Indirect Costs (F&A)

```
What is your institution's negotiated F&A rate?

Common rates: 50-65% for on-campus research
If unsure, check with your grants office.

- F&A rate: ____%
- On-campus or off-campus?
- MTDC base (standard) or other base?

Note: Off-campus rate is typically 26%.
```

### Q8: Cost-Sharing (if applicable)

```
Does this grant require cost-sharing?

- Mandatory cost-sharing (required by funder)?
- Voluntary committed cost-sharing (you plan to offer)?
- If yes, what percentage or amount?
- Source of cost-sharing (institutional funds, in-kind)?

Skip if no cost-sharing:
```

## Push-Back Patterns

When answers are vague, push back for specifics:

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "Standard salary" | "What is the exact institutional base salary? The salary cap may apply." |
| "Some travel" | "How many trips? Domestic or international? Estimated cost per trip?" |
| "A few grad students" | "How many exactly? What is the annual stipend + tuition + fringe per student?" |
| "Normal fringe rate" | "What is your institution's negotiated fringe rate? Common range is 25-40%." |
| "About 50% indirect" | "What is your exact negotiated F&A rate? On-campus or off-campus?" |
| "Some supplies" | "What specific supplies? What is the estimated annual amount? Break it down." |
| "Sub-award with collaborator" | "Which institution? What are their annual direct costs and F&A rate?" |
| "Equipment for the lab" | "What specific equipment? Each item over $5K needs individual listing." |
| "Market rate" | "What specific dollar amount? Based on current offer, payroll, or survey data?" |

## Mode-Specific Question Variations

### NIH Modular

- Skip detailed categorical breakdown questions
- Focus on total direct costs per year (must round to $25K modules)
- Still need personnel justification
- Ask about consortium/sub-award costs separately

### NIH Detailed

- Full categorical questions (all Q1-Q8)
- Emphasize salary cap compliance
- Require per-year breakdown for multi-year budgets

### NSF

- Map to NSF categories A through J
- Ask about cost-sharing if required by program
- Equipment threshold follows institutional policy

### Foundation

- Simplified questions (personnel, direct costs, overhead)
- Overhead often capped (10-15%) or excluded
- Shorter justification requirements

### SBIR

- Phase-specific questions (Phase I: $275K, Phase II: $1M typical)
- Fee/profit calculation (7-10% of cost)
- Subcontracting limitations (33% Phase I, 50% Phase II)
- Ask about commercialization plan costs

## Data Quality Assessment

After all questions, assess data quality:

| Quality Level | Criteria |
|---------------|----------|
| High | Actual salaries, negotiated rates, specific quotes |
| Medium | Estimated salaries based on ranges, approximate rates |
| Low | "Roughly" or "about" answers, missing fringe/F&A rates |

Push back on Low quality items before proceeding to XLSX generation.
