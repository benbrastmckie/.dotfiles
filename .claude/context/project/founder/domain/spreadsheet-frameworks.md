# Spreadsheet Frameworks

Domain knowledge for cost modeling, financial spreadsheets, and startup financial planning.

## Cost Breakdown Structure

### Hierarchy

Cost breakdowns follow a consistent hierarchy for clarity and aggregation:

```
Project/Company
  -> Category (Major cost bucket)
      -> Subcategory (Optional grouping)
          -> Line Item (Individual cost)
              -> Unit, Quantity, Unit Cost, Total
```

### Standard Cost Categories

| Category | Description | Typical Line Items |
|----------|-------------|-------------------|
| **Personnel** | Human resources costs | Salaries, benefits, contractors, recruiting |
| **Infrastructure** | Technology and facilities | Cloud services, software licenses, office space |
| **Marketing** | Customer acquisition | Ads, content, events, PR, partnerships |
| **Operations** | Day-to-day business | Legal, accounting, insurance, travel |
| **R&D** | Product development | Research tools, prototyping, testing |
| **COGS** | Cost of goods sold | Direct delivery costs, support, hosting per customer |

### Category Allocation Benchmarks

Typical SaaS startup cost allocation (Series A):

| Category | % of Total Spend | Notes |
|----------|-----------------|-------|
| Personnel | 60-75% | Largest expense for tech startups |
| Infrastructure | 10-15% | Cloud, tools, office |
| Marketing | 5-15% | Varies by GTM strategy |
| Operations | 5-10% | Legal, accounting, admin |
| R&D | 5-10% | Beyond personnel R&D |

---

## Financial Modeling Conventions

### Cell Color Coding

Standard financial modeling color convention (widely used in investment banking):

| Color | Meaning | Usage |
|-------|---------|-------|
| **Blue** | Input/Assumption | Hard-coded values user provides |
| **Black** | Formula/Calculation | Computed from other cells |
| **Green** | Link to other sheet | References external data |
| **Red** | Warning/Check | Validation or error indicators |

### Number Formatting

| Type | Format | Example |
|------|--------|---------|
| Currency | `$#,##0` or `$#,##0.00` | $1,234 or $1,234.56 |
| Percentage | `0.0%` or `0.00%` | 25.5% |
| Date | `YYYY-MM-DD` | 2026-03-27 |
| Count | `#,##0` | 1,234 |
| Ratio | `0.00x` | 3.50x |

### Formula Best Practices

1. **Single responsibility**: Each cell does one calculation
2. **Named ranges**: Use descriptive names for key inputs
3. **Row labels**: Always include row labels for readability
4. **Hardcoded inputs**: Blue cells, easy to change
5. **Formula cells**: Black, never hardcode values inline
6. **Error handling**: Use IFERROR for division by zero

---

## Common Formula Patterns

### Aggregation

```
SUM(range)           - Total of values
AVERAGE(range)       - Mean of values
MAX(range), MIN(range) - Extremes
COUNT(range)         - Count of numeric values
COUNTA(range)        - Count of non-empty cells
```

### Percentage Calculations

```
=value/total                    - Percentage of total
=new_value/old_value - 1        - Percent change
=(new_value - old_value)/old_value - Percent change (explicit)
```

### Conditional Aggregation

```
SUMIF(range, criteria, sum_range)
SUMIFS(sum_range, criteria_range1, criteria1, ...)
COUNTIF(range, criteria)
AVERAGEIF(range, criteria, average_range)
```

### Time-Based

```
=EOMONTH(start_date, 0)         - End of current month
=EOMONTH(start_date, months)    - End of future month
=YEARFRAC(start, end)           - Years between dates
=NETWORKDAYS(start, end)        - Working days between
```

---

## Cost Breakdown Table Structure

### Standard Columns

| Column | Type | Description |
|--------|------|-------------|
| Category | Text | Major cost bucket |
| Subcategory | Text | Optional grouping |
| Line Item | Text | Specific cost name |
| Unit | Text | What's being counted (month, seat, hour) |
| Quantity | Number (blue) | How many units |
| Unit Cost | Currency (blue) | Cost per unit |
| Monthly Cost | Formula (black) | =Quantity * Unit Cost |
| Annual Cost | Formula (black) | =Monthly Cost * 12 |
| Notes | Text | Assumptions, data sources |

### Example Cost Table

```
| Category     | Line Item        | Unit  | Qty | Unit Cost | Monthly   | Annual    | Notes               |
|--------------|------------------|-------|-----|-----------|-----------|-----------|---------------------|
| Personnel    | Engineers        | FTE   | 5   | $12,000   | $60,000   | $720,000  | Avg fully-loaded    |
| Personnel    | Designer         | FTE   | 1   | $10,000   | $10,000   | $120,000  | Senior IC           |
| Infrastructure| AWS             | month | 1   | $5,000    | $5,000    | $60,000   | Production + staging|
| Infrastructure| Software tools  | seat  | 6   | $200      | $1,200    | $14,400   | GitHub, Figma, etc  |
| Marketing    | Google Ads       | month | 1   | $3,000    | $3,000    | $36,000   | US only initially   |
| Operations   | Legal            | month | 1   | $2,000    | $2,000    | $24,000   | Retainer            |
|              | **TOTAL**        |       |     |           | $81,200   | $974,400  |                     |
```

---

## Scenario Modeling

### Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **ESTIMATE** | Rough order of magnitude | Early planning, quick sizing |
| **BUDGET** | Detailed operational budget | Annual planning, board decks |
| **FORECAST** | Forward-looking projection | Financial planning, fundraising |
| **ACTUALS** | Historical data | Variance analysis, reporting |

### Scenario Analysis Structure

```
Base Case:   Expected outcome (50% confidence)
Upside Case: Optimistic scenario (+20-30%)
Downside Case: Conservative scenario (-20-30%)
```

### Sensitivity Analysis

Key variables to test:
- Personnel count: +/- 2 FTEs
- Unit costs: +/- 15%
- Timeline: +/- 3 months
- Customer growth: +/- 25%

---

## JSON Export Schema

For Typst integration, export summary metrics to JSON:

```json
{
  "metadata": {
    "project": "Project Name",
    "date": "2026-03-27",
    "mode": "BUDGET",
    "version": "1.0"
  },
  "summary": {
    "total_monthly": 81200,
    "total_annual": 974400,
    "largest_category": "Personnel",
    "category_count": 4
  },
  "categories": [
    {
      "name": "Personnel",
      "monthly": 70000,
      "annual": 840000,
      "percent_of_total": 0.862
    },
    {
      "name": "Infrastructure",
      "monthly": 6200,
      "annual": 74400,
      "percent_of_total": 0.076
    }
  ],
  "line_items": [
    {
      "category": "Personnel",
      "name": "Engineers",
      "unit": "FTE",
      "quantity": 5,
      "unit_cost": 12000,
      "monthly": 60000,
      "annual": 720000
    }
  ]
}
```

### JSON Type Preservation

**CRITICAL**: Export numbers as numbers, not strings.

```json
// CORRECT
{ "total_monthly": 81200 }

// WRONG (Typst can't do math on strings)
{ "total_monthly": "81200" }
```

---

## openpyxl Formula Generation

### Cell Formula Examples

```python
from openpyxl import Workbook

wb = Workbook()
ws = wb.active

# Input cells (blue styling)
ws['B2'] = 5           # Quantity
ws['C2'] = 12000       # Unit cost

# Formula cell (black styling)
ws['D2'] = '=B2*C2'    # Monthly cost

# SUM formula
ws['D10'] = '=SUM(D2:D9)'

# Named ranges
wb.defined_names.append(DefNamed('employee_count', 'Sheet1!$B$2'))
ws['D2'] = '=employee_count*C2'
```

### Cell Styling for Conventions

```python
from openpyxl.styles import Font, PatternFill

# Blue for inputs
input_fill = PatternFill(start_color='DCE6F1', end_color='DCE6F1', fill_type='solid')
input_font = Font(color='0000FF')

# Black for formulas (default)
formula_font = Font(color='000000')

# Apply styling
ws['B2'].fill = input_fill
ws['B2'].font = input_font
ws['D2'].font = formula_font
```

---

## References

- [Financial Modeling Guidelines (FAST)](https://www.fast-standard.org/)
- [Investment Banking Color Convention](https://www.wallstreetprep.com/knowledge/excel-color-coding/)
- [openpyxl Documentation](https://openpyxl.readthedocs.io/)
