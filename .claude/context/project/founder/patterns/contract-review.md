# Contract Review Pattern

A framework for systematic contract review with AI startup-specific red flags and escalation criteria.

## Core Principle

**"Every contract is a risk allocation document"**

The goal of contract review is not to eliminate risk but to understand, price, and appropriately allocate it. Push for specificity on every term that affects ownership, liability, or exit.

## Review Methodology

### Five-Step Review Flow

```
1. IDENTIFY OWNERSHIP
   What: Background IP, customer data, generated outputs
   Look for: "work product", "deliverables", "improvements"

2. TRACE DATA FLOW
   What: What goes in, comes out, vendor retains
   Look for: "training", "improvement", "aggregate data"

3. CHECK LIABILITY EXCLUSIONS
   What: "As-is" disclaimers, warranty limitations
   Look for: "disclaimer", "limitation", "exclusion"

4. MAP INDEMNIFICATION
   What: Who defends whom against what claims
   Look for: "indemnify", "hold harmless", "defend"

5. FIND THE EXIT
   What: Termination rights, data deletion, continuity
   Look for: "termination", "return", "deletion"
```

### Per-Section Review Checklist

| Section | Key Questions |
|---------|---------------|
| **Definitions** | Are key terms (IP, data, output) precisely defined? |
| **Scope of Services** | What exactly is being delivered? |
| **Data Rights** | Who owns input/output/training data? |
| **IP Ownership** | Who owns work product, improvements? |
| **Confidentiality** | What survives termination? |
| **Reps & Warranties** | What does each party guarantee? |
| **Indemnification** | Who defends whom? What triggers? |
| **Limitation of Liability** | What's the cap? What's excluded? |
| **Termination** | What triggers? What survives? |
| **Miscellaneous** | Governing law? Assignment rights? |

---

## Red Flags Checklist by Category

### Data and IP Red Flags

| Red Flag | Why It Matters | What to Negotiate |
|----------|----------------|-------------------|
| Vendor uses data for training without opt-in | Your data improves their product for free | Explicit opt-in, not opt-out |
| Ambiguous output ownership ("may be subject to third-party rights") | You can't use outputs commercially | Clear customer ownership |
| No data deletion obligation on termination | Vendor retains your data indefinitely | Certified deletion within 30 days |
| Vague IP assignment ("related to services") | Overbroad; courts interpret narrowly | Explicitly enumerate assigned IP |
| No prior inventions schedule | Disputes over what contractor brought in | Require schedule before work starts |

### Liability and Risk Red Flags

| Red Flag | Why It Matters | What to Negotiate |
|----------|----------------|-------------------|
| Liability capped at fees only | $10K fees, $1M damages = you eat $990K | Cap at 2-3x annual fees minimum |
| One-sided indemnification | You defend them, they don't defend you | Make it mutual |
| Mandatory arbitration (AAA/JAMS) | Expensive, tilts against startups | Court option or lower-cost arbitration |
| Class action waiver | Cannot join collective claims | Remove or carve out egregious conduct |
| Governing law in unfavorable jurisdiction | Their home turf advantage | Negotiate neutral or your jurisdiction |

### Business Control Red Flags

| Red Flag | Why It Matters | What to Negotiate |
|----------|----------------|-------------------|
| Unilateral term modifications | They can change terms anytime | Require 30-day notice, opt-out right |
| Auto-renewal < 30-day opt-out | Trapped in bad contracts | 60-90 day opt-out window |
| Change-of-control consent required | Need permission to be acquired | Remove or limit to material changes |
| Most-favored pricing restrictions | Can't offer discounts | Carve out volume discounts |
| Assignment restrictions | Can't sell company easily | Allow assignment to acquirer |

### Investment and Fundraising Red Flags

| Red Flag | Why It Matters | What to Negotiate |
|----------|----------------|-------------------|
| Participating preferred (unlimited) | Double-dip on liquidation | Cap participation or remove |
| Full-ratchet anti-dilution | Brutal for founders in down rounds | Weighted average instead |
| Overly broad veto rights | Investors control operations | Limit to major events only |
| Cumulative dividends | Compounds over time | Non-cumulative or remove |
| Pay-to-play punishing non-followers | Limits new investor attraction | Remove or soften |

### Employment Red Flags

| Red Flag | Why It Matters | What to Negotiate |
|----------|----------------|-------------------|
| Overbroad IP assignment ("any invention") | Captures side projects | Limit to scope of employment |
| Non-compete in ban state | Unenforceable but creates chilling effect | Remove entirely |
| No acceleration on change of control | Unvested equity lost at acquisition | Single or double trigger acceleration |
| Ambiguous "cause" definition | Employer too much discretion | Objective, enumerated triggers |
| No severance on termination without cause | No protection for employee | Negotiate severance package |

---

## Push-Back Patterns for Vague Answers

| Vague Pattern | Push-Back Response |
|---------------|-------------------|
| "Standard agreement" | "Standard in what industry? AI contracts have unique terms. What type specifically?" |
| "We need protection" | "Protection from what specifically? IP infringement? Data breach? Liability from AI outputs?" |
| "Fair terms" | "Fair based on what benchmark? What are the 3 terms that matter most to you?" |
| "Reasonable liability" | "What dollar amount? 1x fees? 2x? Unlimited for certain categories?" |
| "Industry standard cap" | "Which industry? Show me a comparable deal. What's the floor?" |
| "We can't change that" | "Is that legal requirement or business policy? Who has authority to approve?" |
| "Our lawyers require it" | "Can we speak with them directly? What's the underlying concern?" |
| "It protects both parties" | "How does it protect me? Walk me through the scenario." |

---

## Attorney Escalation Guide

### Always Use an Attorney For

- **Incorporation and equity structure**: Cap table mistakes are extremely costly to fix
- **First funding round**: SAFE or priced round with any investor
- **Material commercial contracts**: > $100K ARR, data access to core systems, IP assignment
- **Employment agreements for co-founders and key executives**: Equity vesting, change of control
- **Any regulatory matter**: Data privacy enforcement, AI compliance, IP disputes
- **Acquisition discussions**: LOI, due diligence, definitive agreements

### Use Attorney to Review (Not Just AI Tools)

- Any contract where you're the weaker party with little leverage
- Contracts in regulated industries (healthcare, finance, legal) with AI components
- International contracts with unfamiliar governing law
- Any indemnification clause exposing you to unlimited liability
- Contracts with unusual or non-standard terms

### Can Use AI Tools + Self-Review For

- Standard vendor agreements under $50K with mutual limitation of liability
- NDAs with established counterparties (use NVCA or Bonterms templates)
- Standard terms of service for consumer products (from reputable templates)
- Initial contract markup before attorney review
- Contract comparison against prior agreements

### Signals Requiring Immediate Attorney Involvement

| Signal | Urgency | Action |
|--------|---------|--------|
| Demand letter or cease-and-desist | High | Do not respond; call attorney immediately |
| IP ownership dispute discovered | High | Preserve documents; seek counsel |
| Regulatory agency contact (FTC, state AG, EU DPA) | Critical | Attorney before any response |
| Investor misrepresentation claim | Critical | Attorney immediately |
| Contract > $500K or affects core IP | High | Attorney review before signing |

---

## Finding AI-Knowledgeable Startup Counsel

### Qualification Questions

1. "Have you advised AI startups on data licensing and model IP?"
2. "Are you familiar with YC SAFE documents?"
3. "Have you handled EU AI Act compliance work?"
4. "What's your experience with AI vendor/customer contracts?"

### Avoid

- General commercial attorneys without tech or startup experience
- Attorneys who haven't seen AI-specific contract issues
- Firms without startup pricing (fixed fee, deferred billing)

### Consider

- Firms specializing in technology startups: Cooley, Wilson Sonsini, Gunderson
- Boutique firms with AI practice areas
- Attorneys who have been in-house at AI companies
- YC attorney network recommendations

---

## Review Output Structure

After reviewing a contract, structure findings as:

```
1. EXECUTIVE ASSESSMENT
   - Overall risk level (Low/Medium/High/Critical)
   - Key concerns (top 3)
   - Recommended action (sign/negotiate/attorney/walk)

2. CLAUSE-BY-CLAUSE ANALYSIS
   - Section | Risk | Issue | Recommendation

3. MUST-NEGOTIATE ITEMS
   - Non-negotiable changes before signing

4. NICE-TO-HAVE ITEMS
   - Improvements to request if possible

5. ESCALATION RECOMMENDATION
   - Self-serve / Attorney review / Attorney required
```

---

## References

- NVCA Model Legal Documents
- Bonterms Open Source Legal Forms
- YC Standard Documents (SAFE, Template Agreements)
