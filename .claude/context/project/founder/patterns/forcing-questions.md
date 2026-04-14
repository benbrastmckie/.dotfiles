# Forcing Questions Pattern

A framework for extracting specificity and validating assumptions through structured questioning.

## Core Principle

**"Specificity is the only currency"**

Vague answers are not accepted. Every question is asked individually via AskUserQuestion, with explicit push-back until specific evidence is provided.

## Question Structure

### Format Per Question

```
1. Re-ground: State project, current context (1-2 sentences)
2. Simplify: Explain in plain language; avoid jargon
3. Ask: One specific question
4. Push: If answer is vague, push back with "Can you be more specific about..."
```

### Push-Back Triggers

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "Many people..." | "Name one specific person." |
| "Everyone needs..." | "Who specifically asked for this?" |
| "The market wants..." | "What behavior proves this?" |
| "Users will love..." | "Which user said this? Quote them." |
| "It's obvious that..." | "What data supports this?" |
| "I think..." | "What have you observed or measured?" |

---

## The Six Forcing Questions

### Q1: Demand Reality

**Question**: "What's the strongest evidence someone actually wants this?"

**Push Until**: Specific behavior, payment, or workflow dependency

**Anti-Patterns to Reject**:
- Interest signals ("people are excited")
- Survey responses ("80% said they'd use it")
- Intentions ("they plan to buy")

**Acceptable Answers**:
- "Company X is paying us $500/month for early access"
- "User Y uses our MVP 3x daily for core workflow"
- "Team Z stopped using competitor after our demo"

---

### Q2: Status Quo

**Question**: "What are users doing right now to solve this problem?"

**Push Until**: Specific workflow, hours wasted, dollars spent

**Framework**:
```
Current Solution: [What tool/process?]
Time Investment: [Hours per week?]
Cost Investment: [Dollars per month?]
Pain Points: [Specific frustrations?]
```

**Why This Matters**: The status quo is your real competitor, not other startups.

---

### Q3: Desperate Specificity

**Question**: "Name the actual human who needs this most. What's their title?"

**Push Until**: Name, role, specific consequence heard directly

**Ideal Response**:
```
Name: Sarah Chen
Title: Head of Operations at Acme Corp
Consequence: "If we can't automate this, I'll need to hire 2 more people"
Heard: In our user interview on March 15
```

**Why Single Person**: If you can't name one desperate user, you don't have PMF.

---

### Q4: Narrowest Wedge

**Question**: "What's the smallest version someone would pay for this week?"

**Push Until**: One feature, one workflow, shippable in days

**Wedge Criteria**:
- Solves one specific pain point completely
- Can be built in days, not months
- Someone would pay for it alone
- Opens door to broader relationship

**Example**:
- Full vision: "AI-powered project management suite"
- Narrowest wedge: "Automated standup collection via Slack"

---

### Q5: Observation & Surprise

**Question**: "Have you watched someone use this? What surprised you?"

**Push Until**: Specific surprise contradicting prior assumptions

**Observation Protocol**:
1. Watch user in their environment
2. Minimal intervention (don't help)
3. Note where they struggle
4. Note unexpected use patterns
5. Ask "why did you do that?"

**Valuable Surprises**:
- User ignored your "killer feature"
- User found workaround you didn't expect
- User's mental model differs from yours
- User's environment has constraints you missed

---

### Q6: Future-Fit

**Question**: "If the world looks different in 3 years, does your product become more essential or less?"

**Push Until**: Specific claim about how user's world changes

**Framework**:
```
Trend: [What's changing?]
Timeline: [When does it hit mainstream?]
Impact: [How does it affect our users?]
Product Response: [Do we become more/less valuable?]
```

**Examples**:
- AI adoption: Does AI make you obsolete or essential?
- Remote work: Does distributed work help or hurt you?
- Regulation: Does compliance create moat or burden?

---

## Smart Routing by Stage

| Founder Stage | Focus Questions | Skip |
|---------------|-----------------|------|
| Pre-product (idea) | Q1, Q2, Q3 | Q5 (no product to observe) |
| Has MVP users | Q2, Q4, Q5 | Q1 (already validated) |
| Paying customers | Q4, Q5, Q6 | Q1, Q2 (already validated) |
| Scaling | Q5, Q6 | Q1-Q4 (foundation laid) |

---

## Anti-Patterns to Detect

### Category-Level Answers

**Bad**: "SMBs need this"
**Good**: "Sarah Chen at Acme Corp (50 employees) needs this"

### Interest Without Behavior

**Bad**: "Everyone loves our demo"
**Good**: "3 companies signed up for paid pilot after demo"

### Made-Up Numbers

**Bad**: "Our TAM is $10B"
**Good**: "Based on Gartner report X, our segment is $400M"

### "Everyone Needs This"

**Bad**: "Every business has this problem"
**Good**: "Consulting firms with 20-100 employees have this problem"

---

## Implementation Notes

### One Question at a Time

Never batch questions. Each question should be:
1. Asked via individual AskUserQuestion
2. Answered before proceeding
3. Pushed back on if vague
4. Only then move to next question

### Preserve Context

After each question, summarize what was learned before asking the next:

```
"You mentioned Sarah Chen at Acme Corp is your most desperate user.
Building on that - what is Sarah doing today to solve this problem?"
```

### Document Answers

Capture answers in structured format for artifact generation:

```json
{
  "q1_demand": {
    "evidence": "3 companies paying for early access",
    "specificity_score": 8
  },
  "q2_status_quo": {
    "current_solution": "Spreadsheets + manual email",
    "time_investment": "10 hours/week",
    "dollar_cost": "$0 but high opportunity cost"
  }
}
```
