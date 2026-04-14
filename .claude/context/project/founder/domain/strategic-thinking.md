# Strategic Thinking

CEO cognitive patterns and YC principles for strategic decision-making.

## CEO Cognitive Patterns

### Classification Instinct

Categorize decisions by reversibility and magnitude:

```
                         Magnitude of Impact
                      Low                High
                 ┌──────────────────┬──────────────────┐
                 │                  │                  │
            High │   DELIBERATE     │   ONE-WAY DOOR   │
Reversibility    │   Consider but   │   Maximum rigor  │
Difficulty       │   don't agonize  │   Get it right   │
                 │                  │                  │
                 ├──────────────────┼──────────────────┤
                 │                  │                  │
            Low  │   JUST DO IT     │   TWO-WAY DOOR   │
                 │   Delegate or    │   Move fast      │
                 │   automate       │   Learn quickly  │
                 │                  │                  │
                 └──────────────────┴──────────────────┘
```

**Two-Way Doors** (reversible decisions):
- Can be changed with low cost
- Bias toward action
- 70% information is enough
- Examples: Feature naming, UI tweaks, pricing experiments

**One-Way Doors** (irreversible decisions):
- High switching cost or impossible to reverse
- Require thorough analysis
- Seek 90%+ confidence
- Examples: Platform choice, co-founder selection, fundraising terms

### Inversion Pattern

For every strategic question, also ask the inverse:

| Forward Question | Inverted Question |
|------------------|-------------------|
| How do we win? | What makes us fail? |
| What should we build? | What should we NOT build? |
| Who is our customer? | Who is NOT our customer? |
| What makes us valuable? | What makes us replaceable? |

**Application Process**:
1. Ask the forward question, generate answers
2. Ask the inverted question, generate failure modes
3. Cross-reference: Does any forward answer trigger a failure mode?
4. Prioritize answers that both advance goals AND avoid failures

### Focus as Subtraction

"Deciding what not to do is as important as deciding what to do." - Steve Jobs

**Framework**:
1. List all possible initiatives
2. Force-rank by impact
3. Draw a line after top 3-5
4. Everything below the line goes to "NOT IN SCOPE"
5. Document why each item is excluded

**NOT IN SCOPE Example**:
```markdown
## NOT IN SCOPE (and why)

| Initiative | Reason for Exclusion |
|------------|----------------------|
| Mobile app | Core users are desktop-first; distracts from web |
| Enterprise tier | Requires SOC2, 6-month effort; not yet at scale |
| Internationalization | English-only for first 1000 customers |
| API access | Low demand signal, high maintenance |
```

### Speed Calibration

**70% Information Rule**:
- Most decisions can be made with ~70% of desired information
- Waiting for 100% means opportunity cost
- Exception: One-way doors may warrant waiting

**Decision Latency by Type**:
| Decision Type | Information Threshold | Max Decision Time |
|---------------|----------------------|-------------------|
| Tactical (daily) | 50% | Same day |
| Operational (weekly) | 70% | 2-3 days |
| Strategic (quarterly) | 80% | 1-2 weeks |
| Irreversible | 90% | As needed |

### Leverage Obsession

"Find inputs where small effort = massive output"

**Leverage Assessment**:
```
                     Effort Required
                    Low           High
               ┌────────────┬────────────┐
          High │  HIGH      │  CONSIDER  │
    Impact     │  LEVERAGE  │  CAREFULLY │
               │  Do first  │            │
               ├────────────┼────────────┤
          Low  │  QUICK     │  AVOID     │
               │  WINS      │  THESE     │
               │  If spare  │            │
               └────────────┴────────────┘
```

**Signs of High Leverage**:
- One action enables many others
- Compounds over time
- Creates platform for future value
- Removes bottleneck for team

---

## YC Principles

### Core Philosophy

**"Make something people want"**
- The only thing that matters pre-PMF
- Validated by behavior, not words
- Measured by usage, retention, payment

**"Talk to users"**
- Direct observation beats second-hand reports
- Watch them use the product
- Note surprises that contradict assumptions

**"Do things that don't scale"**
- Manual processes first, automation later
- Personal relationships with early users
- Concierge onboarding
- Quality over quantity early on

### The Six Forcing Questions

From YC office hours methodology:

| Question | Purpose | Push Until |
|----------|---------|------------|
| **Q1: Demand Reality** | "What's the strongest evidence someone actually wants this?" | Specific behavior, payment, workflow dependency |
| **Q2: Status Quo** | "What are users doing right now to solve this?" | Specific workflow, hours wasted, dollars spent |
| **Q3: Desperate Specificity** | "Name the actual human who needs this most. Title?" | Name, role, specific consequence heard directly |
| **Q4: Narrowest Wedge** | "What's the smallest version someone would pay for this week?" | One feature, one workflow, shippable in days |
| **Q5: Observation** | "Have you watched someone use this? What surprised you?" | Specific surprise contradicting assumptions |
| **Q6: Future-Fit** | "If the world looks different in 3 years, does your product become more essential or less?" | Specific claim about user world change |

### Stage-Based Question Selection

| Stage | Focus Questions | Rationale |
|-------|-----------------|-----------|
| Pre-product | Q1, Q2, Q3 | Validate demand exists |
| Has users | Q2, Q4, Q5 | Find narrowest wedge, observe |
| Paying customers | Q4, Q5, Q6 | Optimize wedge, long-term fit |

---

## Completeness Principle

**"When AI reduces marginal cost of completeness to near-zero, optimize for full implementation rather than shortcuts."**

### Compression Ratios (Human to AI-Assisted)

| Task Type | Traditional Time | AI-Assisted Time | Compression |
|-----------|-----------------|------------------|-------------|
| Boilerplate/scaffolding | 2 days | 15 min | ~100x |
| Feature implementation | 1 week | 30 min | ~30x |
| Bug fix + test | 4 hours | 15 min | ~20x |
| Documentation | 1 day | 30 min | ~50x |
| Analysis/research | 1 week | 2 hours | ~20x |

### Implications

1. **Evaluate ALL options**: Don't shortcut analysis
2. **Build ALL features**: If value-add, build it
3. **Write ALL docs**: Documentation is now cheap
4. **Test ALL paths**: Coverage is now affordable
5. **Model ALL scenarios**: No excuse for single-path thinking

---

## Willfulness Pattern

"The world yields to people who push hard in one direction" - YC Mantra

**Application**:
- Pick a direction with conviction
- Communicate it clearly and repeatedly
- Execute with intensity
- Ignore distractions
- Adapt tactics, not strategy

**Anti-Pattern**:
- Hedging on direction
- Pursuing multiple strategies simultaneously
- Changing strategy frequently
- Waiting for consensus
- Over-analyzing instead of acting

---

## References

- [YC Library](https://www.ycombinator.com/library)
- [Paul Graham Essays](http://paulgraham.com/articles.html)
- [Gstack CEO Patterns](https://github.com/garrytan/gstack)
