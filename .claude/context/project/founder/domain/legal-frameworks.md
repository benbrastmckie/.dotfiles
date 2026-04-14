# Legal Frameworks

Domain knowledge for contract review, negotiation, and legal decision-making for AI startup founders.

## IP Assignment and Work-for-Hire

### Work-for-Hire Doctrine

**Work-for-hire** only applies to copyrightable works. For AI/ML work:
- Patent rights, trade secrets, and algorithm ownership require explicit assignment clauses
- "Work made for hire" for independent contractors must be agreed in writing *before* work begins
- Covers only specific enumerated categories of works under US copyright law

**Practical Rules**:
- All contractors and employees must sign IP assignment agreements before starting work
- Assignment clause should cover: inventions, discoveries, improvements, works created in scope
- "Prior inventions" schedule: let contractors list what they're keeping; everything else is yours
- Beware vague language like "related to company business" -- courts interpret this narrowly

### AI-Specific IP Complications

| Issue | Risk | Mitigation |
|-------|------|------------|
| RAG libraries | May contain third-party licensed materials | Audit data sources |
| Fine-tuned models | Base model (vendor's), fine-tuning data (yours?), weights (disputed) | Explicit ownership clause |
| AI-generated outputs | May not be copyrightable (Copyright Office May 2025) | Document human contribution |
| Training data | Provenance may be unclear | Require vendor warranties |

---

## Indemnification and Liability Caps

### Standard Structure

| Component | Standard | Negotiation Target |
|-----------|----------|-------------------|
| General cap | 12-month fees | 2-3x annual fees minimum |
| IP infringement | Often excluded from cap | Ensure unlimited for IP |
| Data breach | Varies | Unlimited or insurance-backed |
| Mutual indemnification | Each defends against own breach | Ensure it's truly mutual |

### Carve-Outs from Liability Cap

Always exclude from cap:
- IP infringement claims
- Gross negligence or willful misconduct
- Data breaches from vendor systems
- Confidentiality breaches
- Regulatory violations caused by vendor

### Red Flags

- Liability capped at subscription fees only (no floor for damages)
- Vendor disclaims all liability for AI output errors, hallucinations, or bias
- Indemnification only flows one way (vendor is indemnified, you are not)
- Mandatory arbitration with expensive forums (AAA, JAMS)

---

## Data Rights and AI Training

### Three Data Categories

| Category | Definition | Typical Ownership |
|----------|------------|-------------------|
| **Input data** | What you send to the AI system | Customer owns |
| **Output data** | What the AI generates | Negotiated |
| **Training/improvement data** | Whether vendor can use for training | Opt-in only |

### Critical Provisions

**Must Include**:
- Explicit prohibition: vendor may not use customer data to train models without opt-in
- Output ownership: customer owns all outputs from customer data and prompts
- License scope: any license granted is strictly limited to delivering contracted service
- Retention and deletion: specify timeline including backups, caches, shadow copies
- Subprocessors: require approval before vendor shares data with third parties

### Precedent Case

**Fastcase v. Alexi Technologies (Nov 2025)**: Licensor sued when licensee used licensed data to train commercial AI product. Illustrates why precise license drafting matters.

---

## Non-Compete and Non-Solicitation

### Federal Status (2026)

- FTC non-compete ban rule blocked by federal courts (2024)
- FTC dismissed appeal (Sep 2025)
- **No federal ban currently in effect; state law governs**

### State-by-State Landscape

| Category | States |
|----------|--------|
| **Complete bans** | CA, ND, MN, OK, MT, WY |
| **Wage-threshold bans** | CO, DC, IL, ME, MD, MA, NV, NH, OR, RI, VA, WA |
| **Enforceable if reasonable** | Most other states (12-24 months, limited geography) |

### AI Startup Strategy

- Hiring from Big Tech: Assess non-compete enforceability in your state
- CA-based employees: Non-competes essentially unenforceable
- Primary defense: Use NDAs + trade secret protection regardless of jurisdiction
- Non-solicitation survives in most states where non-competes banned
- Baseline employee agreements: IP assignment + NDA + non-solicitation

---

## Representations and Warranties

### Standard Vendor Disclaimers (Insufficient)

- "As-is, as-available" -- no guarantee of accuracy or reliability
- AI outputs not warranted to be correct
- "Independent verification required" language

### What to Negotiate

| Warranty Type | Coverage |
|--------------|----------|
| **Regulatory compliance** | Current and emerging AI regulations (EU AI Act, US state laws) |
| **AI governance** | Vendor conducts risk assessments, maintains audit logs |
| **Training data provenance** | Model trained only on permissioned data |
| **Data security** | SOC 2, ISO 27001, breach notification timeline |
| **Output quality** | SLAs for accuracy in specific measurable use cases |

### What You Should Warrant (as AI Vendor)

- You have rights to all training data used in your models
- Your AI complies with applicable laws in customer's jurisdiction
- You have processes to detect and mitigate bias in AI outputs

---

## Termination Provisions

### Termination Types

| Type | Trigger | Typical Terms |
|------|---------|---------------|
| **For convenience** | Either party with notice | 30-90 days notice |
| **For cause** | Material breach not cured | 30-day cure period |
| **Regulatory** | Compliance enforcement action | Immediate |
| **Change of control** | Acquisition of either party | Optional termination right |

### Post-Termination Obligations

**Must Include**:
- Data return or deletion (specify format, timeline, certification)
- Transition assistance: Vendor cooperates for N days to enable migration
- License survival: Clarify what survives and under what terms
- Payment: No payment for undelivered services; pro-rata refund of prepaid fees

### Watch For

- Automatic renewal with short opt-out window (< 30 days)
- Unilateral price increases mid-term
- Change-of-control clause requiring consent for your acquisition

---

## Contract Types for AI Startups

### SaaS Agreements

**Core Sections**:
- Scope of services and acceptable use
- Data processing addendum (GDPR, CCPA)
- SLAs and remedies for downtime
- IP ownership (background, foreground, outputs)
- Limitation of liability and indemnification
- Subscription terms, pricing, auto-renewal

**2026 Trend**: Agentic AI systems require different model than traditional SaaS. When AI agents take actions autonomously, liability allocation shifts.

### Data Licensing Agreements

**Essential Provisions**:
- Permitted use: training, inference, testing, commercial deployment
- Exclusivity: exclusive vs. non-exclusive license; field-of-use restrictions
- Sublicensing rights
- Quality and completeness warranties
- Audit rights to verify proper use
- Right to remove specific data points (deletion compliance)

### AI/ML Service Agreements (Custom Development)

**Key Negotiation Points**:
- Who owns the model and weights upon completion?
- Who owns improvements made during engagement?
- Can vendor reuse your data for other clients?
- Deliverable acceptance criteria
- Exclusivity: Is model built only for you?

### Employment Contracts for AI Engineers

**Must-Have Provisions**:
- IP assignment: all inventions in scope of employment
- Prior inventions schedule
- Confidentiality: trade secrets, model architectures, training data
- Side projects clause: explicit about what's allowed
- Open source contribution policy
- Equity vesting: standard 4-year vest, 1-year cliff

### SAFE Notes

**Key Negotiable Terms**:

| Term | Standard | Notes |
|------|----------|-------|
| Valuation cap | Post-money SAFE caps (YC model) | Maximum conversion valuation |
| Discount rate | 10-30% | Rewards early risk |
| Pro-rata rights | Common | Right to maintain ownership in next round |
| MFN clause | Common | Upgrade to better terms offered later |
| Information rights | Varies | Quarterly financials, cap table access |

**SAFE vs. Convertible Note**:
- SAFE: No maturity date, no interest; simpler, founder-friendly
- Convertible note: Has maturity, accrues interest; more pressure
- 2025 data: SAFEs in 90% of pre-seed deals, 64% of seed rounds (Carta)

### Partnership Agreements

**Types**: Technology, data, channel, strategic/commercial

**Key Provisions**:
- Revenue sharing formula with audit rights
- IP ownership of jointly developed technology
- Exclusivity carve-outs
- Post-termination asset ownership
- Non-compete with each other's competitors
- Change of control provisions

---

## References

- US Copyright Office AI Training Report (May 2025)
- Fastcase v. Alexi Technologies (Nov 2025)
- FTC Non-Compete Rule Status (Sep 2025)
- Carta SAFE Market Data (Q1 2025)
- EU AI Act Compliance Requirements (2024)
- Mayer Brown Agentic AI Contracting (Feb 2026)
