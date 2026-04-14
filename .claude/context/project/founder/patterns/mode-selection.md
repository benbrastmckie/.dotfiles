# Mode Selection Pattern

Operational modes for strategic analysis commands that give users explicit control over scope and approach.

## Core Principle

**"User is 100% in control. Every scope change is explicit opt-in."**

Mode selection happens early in the interaction and affects all subsequent analysis.

## Mode Selection Protocol

### Step 1: Present Modes

Use AskUserQuestion with clear mode descriptions:

```
Before we begin, select your operational mode:

A) LAUNCH - "Maximize splash" - New product, category creation
B) SCALE - "Optimize engine" - PMF achieved, scaling up
C) PIVOT - "Find new wedge" - Current approach not working
D) EXPAND - "Adjacent markets" - Core market captured

Which mode best describes your situation?
```

### Step 2: Confirm Understanding

After selection, confirm the mode's implications:

```
You selected LAUNCH mode. This means:
- We'll focus on awareness and initial traction
- Channel analysis will prioritize high-reach, low-cost options
- Positioning will emphasize differentiation from status quo
- Metrics will focus on awareness and early adoption

Is this correct? [Yes/No]
```

### Step 3: Adapt Analysis

All subsequent questions and outputs adapt to the selected mode.

---

## Standard Mode Definitions

### /strategy Command Modes

| Mode | Posture | Focus | Output Emphasis |
|------|---------|-------|-----------------|
| **LAUNCH** | Maximize splash | Awareness, differentiation | PR angles, launch timing, initial traction |
| **SCALE** | Optimize engine | Efficiency, repeatability | CAC optimization, channel scaling, automation |
| **PIVOT** | Find new wedge | Experimentation, learning | Customer segments, value prop testing |
| **EXPAND** | Adjacent markets | New segments, offerings | Market analysis, expansion playbook |

### /market Command Modes

| Mode | Posture | Focus | Output Emphasis |
|------|---------|-------|-----------------|
| **VALIDATE** | Test assumptions | Evidence gathering | Bottom-up sizing, customer interviews |
| **SIZE** | Comprehensive sizing | TAM/SAM/SOM | All three tiers with methodology |
| **SEGMENT** | Deep segment analysis | Specific segments | Segment-by-segment breakdown |
| **DEFEND** | Investor-ready | Credibility | Data sources, conservative estimates |

### /analyze Command Modes

| Mode | Posture | Focus | Output Emphasis |
|------|---------|-------|-----------------|
| **LANDSCAPE** | Map the field | All competitors | Comprehensive listing, categories |
| **DEEP** | Focus on key rivals | Top 3-5 competitors | Detailed per-competitor analysis |
| **POSITION** | Find white space | Differentiation | 2x2 maps, positioning options |
| **BATTLE** | Prepare for competition | Win/loss | Battle cards, objection handling |

---

## Mode-Specific Question Routing

### Example: /strategy Question Routing

| Question | LAUNCH | SCALE | PIVOT | EXPAND |
|----------|--------|-------|-------|--------|
| Target customer | Who first? | Who next? | Who instead? | Who adjacent? |
| Value prop | What's different? | What's proven? | What else? | What else for new? |
| Channels | Highest reach? | Most efficient? | Untried? | New + existing? |
| Pricing | Premium or free? | Optimize margins? | Test new models? | Segment pricing? |
| Metrics | Awareness, trials | CAC, LTV, NRR | Experiment velocity | Expansion revenue |

---

## Implementation Pattern

### Mode Selection Component

```markdown
## Mode Selection

<mode-selection>
Before proceeding, I need to understand your context.

Select the mode that best describes your situation:

**A) [MODE_1_NAME]** - "[Posture]"
   [1-2 sentence description of when to use]

**B) [MODE_2_NAME]** - "[Posture]"
   [1-2 sentence description of when to use]

**C) [MODE_3_NAME]** - "[Posture]"
   [1-2 sentence description of when to use]

**D) [MODE_4_NAME]** - "[Posture]"
   [1-2 sentence description of when to use]

Which mode best matches where you are?
</mode-selection>
```

### Mode Confirmation Component

```markdown
## Mode Confirmation

You selected **[MODE_NAME]** mode.

This means our analysis will:
- [Implication 1]
- [Implication 2]
- [Implication 3]

Output will emphasize:
- [Output focus 1]
- [Output focus 2]

Does this match your intent? If not, we can switch modes.
```

### Mode Context Header

Add to all outputs:

```markdown
---
**Mode**: [SELECTED_MODE]
**Generated**: [TIMESTAMP]
**Project**: [PROJECT_NAME]
---
```

---

## Mode Switching

### When to Offer Mode Switch

- User's answers don't match selected mode
- New information changes context
- User explicitly requests reconsideration

### Switch Protocol

```markdown
Based on your answers, SCALE mode might be a better fit than LAUNCH.

Your responses indicate:
- You have paying customers (not pre-launch)
- You're optimizing conversion (not awareness)
- You're looking for efficiency (not reach)

Would you like to switch to SCALE mode? This would:
- Shift focus to channel efficiency over reach
- Emphasize CAC/LTV over awareness metrics
- Prioritize proven channels over experimental ones
```

---

## Default Mode Behavior

If user doesn't want to select a mode:

1. **Infer from context**: Use prior conversation to guess
2. **Default to most common**: Usually the middle ground
3. **Flag as inferred**: Note that mode was auto-selected
4. **Offer to change**: Always allow mode switch later

```markdown
Since you didn't select a specific mode, I'll proceed with **LAUNCH** mode
(most common for new projects). We can switch modes at any time if this
doesn't fit your situation.
```

---

## Mode Combinations

Some commands may support mode combinations:

```markdown
Select your primary and secondary focus:

**Primary** (main emphasis):
[ ] A) LAUNCH - Maximize awareness
[ ] B) SCALE - Optimize efficiency

**Secondary** (supporting analysis):
[ ] A) LAUNCH - Also consider awareness angles
[ ] B) SCALE - Also consider efficiency

Selected: Primary=LAUNCH, Secondary=SCALE

This means: Lead with awareness strategy, but include efficiency metrics.
```

---

## Anti-Patterns

### Mode Creep

**Bad**: Silently shifting mode partway through analysis
**Good**: Explicitly note and confirm any mode shift

### Mode Overload

**Bad**: Offering 8+ modes with subtle distinctions
**Good**: 3-4 clearly differentiated modes per command

### Ignoring Mode

**Bad**: Asking same questions regardless of mode
**Good**: Adapting every question to selected mode

### Missing Mode Context

**Bad**: Output doesn't indicate which mode was used
**Good**: Clear mode header on all artifacts
