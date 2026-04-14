# Business Frameworks

Domain knowledge for market sizing, business models, and unit economics.

## TAM/SAM/SOM Framework

### Total Addressable Market (TAM)

TAM represents the total market demand for a product or service - the maximum revenue opportunity if 100% market share is achieved.

**Calculation Approaches**:

| Approach | Method | Best For |
|----------|--------|----------|
| **Top-Down** | Industry reports -> market size -> your segment | Broad markets with good data |
| **Bottom-Up** | Count customers x price point (VCs prefer this) | Specific segments, new markets |
| **Value Theory** | Pain cost x frequency x affected users | Novel solutions without comparables |

**Top-Down Example**:
```
Global enterprise software market: $500B
  -> Project management segment: $8B
    -> SMB-focused tools: $2B
      = TAM: $2B
```

**Bottom-Up Example**:
```
Number of SaaS companies in US: 15,000
  x Average relevant employees per company: 50
    x Annual price per seat: $200
      = TAM: $150M
```

### Serviceable Available Market (SAM)

SAM is the portion of TAM targeted by your products which is within your geographical reach.

**Narrowing Factors**:
- Geography (which regions can you serve?)
- Segments (which verticals/sizes are realistic?)
- Technical requirements (what infrastructure is needed?)
- Regulatory constraints (what compliance is required?)

**SAM Calculation**:
```
TAM: $2B
  - Cannot serve: Enterprise (need SOC2): -40%
  - Cannot serve: Non-English markets: -30%
  - Cannot serve: Regulated industries: -10%
  = SAM: $400M (20% of TAM)
```

### Serviceable Obtainable Market (SOM)

SOM is the realistic portion of SAM that you can capture given your resources and competition.

**Typical SOM Ranges**:
- Year 1: 0.5-2% of SAM (early startup)
- Year 3: 2-5% of SAM (established startup)
- Year 5: 5-15% of SAM (market leader)

**SOM Calculation**:
```
SAM: $400M
  x Realistic capture rate Year 1: 1%
  = SOM Year 1: $4M

  x Projected capture rate Year 3: 3%
  = SOM Year 3: $12M
```

### Concentric Circles Visualization

```
                    ┌─────────────────────────────────┐
                    │                                 │
                    │         TAM: $2B                │
                    │   Total market opportunity      │
                    │                                 │
                    │    ┌───────────────────────┐    │
                    │    │                       │    │
                    │    │      SAM: $400M       │    │
                    │    │   Segments you can    │    │
                    │    │   realistically serve │    │
                    │    │                       │    │
                    │    │   ┌───────────────┐   │    │
                    │    │   │               │   │    │
                    │    │   │  SOM: $4-12M  │   │    │
                    │    │   │  Your target  │   │    │
                    │    │   │               │   │    │
                    │    │   └───────────────┘   │    │
                    │    │                       │    │
                    │    └───────────────────────┘    │
                    │                                 │
                    └─────────────────────────────────┘
```

---

## Business Model Canvas

The 9 building blocks of a business model:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │     KEY      │ │     KEY      │ │    VALUE     │ │   CUSTOMER   │        │
│  │  PARTNERS    │ │  ACTIVITIES  │ │ PROPOSITIONS │ │ RELATIONSHIPS│        │
│  │              │ │              │ │              │ │              │        │
│  │ Who are our  │ │ What must we │ │ What problem │ │ How do we    │        │
│  │ key partners?│ │ do well?     │ │ do we solve? │ │ acquire and  │        │
│  │              │ │              │ │              │ │ retain?      │        │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                                             │
│  ┌──────────────┐ ┌─────────────────────────────────────────────────────┐   │
│  │     KEY      │ │                                                     │   │
│  │  RESOURCES   │ │                    CHANNELS                         │   │
│  │              │ │                                                     │   │
│  │ What assets  │ │     How do customers find and buy from us?          │   │
│  │ are required?│ │                                                     │   │
│  └──────────────┘ └─────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌───────────────────────────────┐ ┌───────────────────────────────────┐    │
│  │                               │ │                                   │    │
│  │        COST STRUCTURE         │ │         REVENUE STREAMS           │    │
│  │                               │ │                                   │    │
│  │   Fixed vs variable costs     │ │   How do we make money?           │    │
│  │   Economies of scale          │ │   Transaction vs recurring        │    │
│  │                               │ │                                   │    │
│  └───────────────────────────────┘ └───────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                       CUSTOMER SEGMENTS                              │    │
│  │   Who pays? Who uses? Mass market, niche, multi-sided platform?      │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Block Definitions

| Block | Key Question | Examples |
|-------|--------------|----------|
| **Customer Segments** | Who pays? Who uses? | Mass market, niche, multi-sided |
| **Value Propositions** | What problem do you solve better? | Newness, performance, customization |
| **Channels** | How do customers find and buy? | Direct, web, retail, partner |
| **Customer Relationships** | How do you acquire and retain? | Self-service, community, dedicated |
| **Revenue Streams** | How do you make money? | Subscription, transaction, licensing |
| **Key Resources** | What assets are required? | Physical, IP, human, financial |
| **Key Activities** | What must you do well? | Production, problem-solving, platform |
| **Key Partnerships** | Who helps you deliver? | Suppliers, strategic alliances |
| **Cost Structure** | What are the major costs? | Fixed, variable, economies of scale |

---

## Unit Economics

### Key Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| **CAC** | Total acquisition cost / New customers | Varies by industry |
| **LTV** | ARPU x Gross margin x Customer lifetime | 3x CAC or higher |
| **LTV:CAC Ratio** | LTV / CAC | >= 3:1 |
| **Payback Period** | CAC / (ARPU x Gross margin) | < 12 months |
| **Churn Rate** | Lost customers / Total customers | < 5% monthly |
| **Net Revenue Retention** | (Starting MRR + Expansion - Churn) / Starting MRR | > 100% |

### Revenue Quality Assessment

| Factor | Low Quality (1-3) | High Quality (8-10) |
|--------|-------------------|---------------------|
| **Recurring** | One-time sales | Multi-year contracts |
| **Predictability** | Volatile, seasonal | Steady, predictable |
| **Defensibility** | Easily replaceable | High switching costs |
| **Margin** | < 50% gross margin | > 70% gross margin |
| **Growth** | Declining or flat | Growing 20%+ YoY |

### Unit Economics Example

```
Monthly:
  ARPU: $100/month
  Gross Margin: 80%
  Gross Profit per User: $80/month

Customer Acquisition:
  CAC: $400

Retention:
  Monthly Churn: 3%
  Customer Lifetime: 33 months (1/0.03)

LTV Calculation:
  LTV = $80 x 33 = $2,640

Ratio Analysis:
  LTV:CAC = $2,640 / $400 = 6.6x (excellent)
  Payback = $400 / $80 = 5 months (excellent)
```

---

## Pricing Models

| Model | Description | Best For |
|-------|-------------|----------|
| **Per-Seat** | Price per user | Collaborative tools |
| **Usage-Based** | Pay for consumption | Infrastructure, API |
| **Tiered** | Feature packages | Self-serve SaaS |
| **Flat Rate** | Single price for all | Simple products |
| **Freemium** | Free tier + paid upgrades | High-volume adoption |
| **Enterprise** | Custom negotiated | Large contracts |
| **Marketplace** | Transaction fee | Two-sided platforms |

### Pricing Strategy Matrix

```
                        Value to Customer
                    Low                High
                ┌───────────────┬───────────────┐
           Low  │   COMMODITY   │   PENETRATION │
Price           │   Compete on  │   Gain share  │
Point           │   cost only   │   then raise  │
                ├───────────────┼───────────────┤
           High │   PREMIUM     │   VALUE-BASED │
                │   Brand/niche │   Ideal zone  │
                │   positioning │   to be in    │
                └───────────────┴───────────────┘
```

---

## References

- [TAM SAM SOM Guide](https://www.charlia.io/en/blog/tam-sam-som-market-sizing-complete-guide)
- [Business Model Canvas](https://www.strategyzer.com/canvas/business-model-canvas)
- [SaaS Metrics](https://www.forentrepreneurs.com/saas-metrics-2/)
