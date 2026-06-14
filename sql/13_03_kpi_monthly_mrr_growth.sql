/*
===============================================================================
FILE: 13_03_kpi_monthly_mrr_growth.sql
===============================================================================

PURPOSE
-------------------------------------------------------------------------------
Creates a monthly MRR growth KPI table.

This table tracks:
    - Monthly Recurring Revenue (MRR)
    - Month-over-Month (MoM) MRR growth
    - Absolute revenue growth
    - Revenue acceleration trends

USED FOR
-------------------------------------------------------------------------------
    - SaaS growth analysis
    - Executive KPI dashboards
    - Investor reporting
    - Revenue forecasting
    - Growth trend analysis
    - Business momentum analysis

BUSINESS DEFINITION
-------------------------------------------------------------------------------
MRR Growth Rate (%) measures how much Monthly Recurring Revenue
increased or decreased compared to the previous month.

FORMULA
-------------------------------------------------------------------------------
MRR Growth Rate % =
(
    current_month_mrr - previous_month_mrr
)
/
previous_month_mrr
* 100

EXAMPLE
-------------------------------------------------------------------------------
Previous Month MRR = 100,000
Current Month MRR  = 120,000

Growth % =
(120,000 - 100,000) / 100,000 * 100
= 20%

BUSINESS INTERPRETATION
-------------------------------------------------------------------------------
Positive Growth:
    Revenue expanded compared to previous month.

Negative Growth:
    Revenue contracted compared to previous month.

Zero Growth:
    Revenue remained flat month-over-month.

IMPORTANT LOGIC NOTES
-------------------------------------------------------------------------------
- Uses base_mrr_monthly as source of truth
- Growth is calculated AFTER MRR aggregation
- First month has no previous month → growth fields become NULL
- NULLIF used to prevent division-by-zero
- MoM comparison uses previous calendar month only
- Growth measured at TOTAL business revenue level

WHY base_mrr_monthly IS USED
-------------------------------------------------------------------------------
base_mrr_monthly already contains:
    - total_mrr
    - arpu
    - paid_active_accounts
    - plan-wise revenue

Rebuilding subscription logic here would:
    - duplicate business rules
    - increase maintenance risk
    - create inconsistency across KPIs

This KPI layer should ONLY compute growth metrics.

OUTPUT
-------------------------------------------------------------------------------
month                   → month dimension
paid_active_accounts    → active paying accounts
total_mrr               → monthly recurring revenue
prev_month_mrr          → previous month revenue
mrr_change              → absolute revenue increase/decrease
mrr_growth_pct          → MoM growth percentage
arpu                    → average revenue per paid account
mrr_basic               → Basic plan revenue
mrr_pro                 → Pro plan revenue
mrr_enterprise          → Enterprise plan revenue
is_reliable             → FALSE for first month

EXAMPLE OUTPUT
-------------------------------------------------------------------------------
2024-06-01 | 333 | 3854007 | 3339785 | 514222 | 15.40

Meaning:
    - Revenue increased by 514,222
    - Business grew 15.4% vs previous month

DEPENDENCIES
-------------------------------------------------------------------------------
Depends on:
    - base_mrr_monthly

TECHNICAL NOTES
-------------------------------------------------------------------------------
- LAG() used for previous month lookup
- Window ordered chronologically by month
- ROUND() applied only in final presentation layer
- NULL growth for first month is intentional
- Growth metrics calculated after monthly aggregation

===============================================================================
*/

DROP VIEW IF EXISTS kpi_monthly_mrr_growth;

CREATE VIEW kpi_monthly_mrr_growth AS

WITH mrr_growth AS (
    /*
    -----------------------------------------------------------------------
    Step 1: Attach previous month MRR using window function
    -----------------------------------------------------------------------
    LAG(total_mrr) gets previous month's revenue.

    First month has no prior value → NULL
    which is expected and correct.
    -----------------------------------------------------------------------
    */
    SELECT
        month,
        paid_active_accounts,
        total_mrr,
        arpu,
        mrr_basic,
        mrr_pro,
        mrr_enterprise,
        LAG(total_mrr) OVER (
            ORDER BY month
        ) AS prev_month_mrr
    FROM base_mrr_monthly
)

SELECT
    month,
    paid_active_accounts,
    total_mrr,
    prev_month_mrr,

    /*
    -----------------------------------------------------------------------
    Absolute revenue change
    -----------------------------------------------------------------------
    */
    ROUND(
        total_mrr - prev_month_mrr,
        2
    ) AS mrr_change,

    /*
    -----------------------------------------------------------------------
    Month-over-Month growth percentage
    -----------------------------------------------------------------------
    Formula:
        (current - previous) / previous * 100
    -----------------------------------------------------------------------
    */
    ROUND(
        (
            (total_mrr - prev_month_mrr)::NUMERIC
            / NULLIF(prev_month_mrr, 0)
        ) * 100,
        2
    ) AS mrr_growth_pct,

    arpu,
    mrr_basic,
    mrr_pro,
    mrr_enterprise,

    /*
    -----------------------------------------------------------------------
    Reliability flag
    -----------------------------------------------------------------------
    First month has no comparison baseline.
    -----------------------------------------------------------------------
    */
    CASE
        WHEN prev_month_mrr IS NULL THEN FALSE
        ELSE TRUE
    END AS is_reliable

FROM mrr_growth
ORDER BY month;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Full table preview
SELECT *
FROM kpi_monthly_mrr_growth;

-- Validation 1: Revenue should never be negative
SELECT *
FROM kpi_monthly_mrr_growth
WHERE total_mrr < 0;

-- Validation 2: First month should have NULL growth
SELECT
    month,
    prev_month_mrr,
    mrr_change,
    mrr_growth_pct,
    is_reliable
FROM kpi_monthly_mrr_growth
ORDER BY month
LIMIT 1;

-- Validation 3: Highest growth months
SELECT
    month,
    total_mrr,
    prev_month_mrr,
    mrr_change,
    mrr_growth_pct
FROM kpi_monthly_mrr_growth
WHERE mrr_growth_pct IS NOT NULL
ORDER BY mrr_growth_pct DESC
LIMIT 10;

-- Validation 4: Lowest growth months
SELECT
    month,
    total_mrr,
    prev_month_mrr,
    mrr_change,
    mrr_growth_pct
FROM kpi_monthly_mrr_growth
WHERE mrr_growth_pct IS NOT NULL
ORDER BY mrr_growth_pct ASC
LIMIT 10;

-- Validation 5: Revenue acceleration trend
SELECT
    month,
    total_mrr,
    mrr_growth_pct
FROM kpi_monthly_mrr_growth
ORDER BY month;

-- Validation 6: ARPU trend alongside MRR growth
SELECT
    month,
    total_mrr,
    arpu,
    mrr_growth_pct
FROM kpi_monthly_mrr_growth
ORDER BY month;

-- Validation 7: Plan-wise revenue consistency
SELECT
    month,
    total_mrr,
    ROUND(
        COALESCE(mrr_basic, 0)
        + COALESCE(mrr_pro, 0)
        + COALESCE(mrr_enterprise, 0),
        2
    ) AS reconstructed_mrr,
    ROUND(
        total_mrr
        -
        (
            COALESCE(mrr_basic, 0)
            + COALESCE(mrr_pro, 0)
            + COALESCE(mrr_enterprise, 0)
        ),
        2
    ) AS difference
FROM kpi_monthly_mrr_growth
ORDER BY month;

-- Validation 8: Paid account growth trend
SELECT
    month,
    paid_active_accounts,
    LAG(paid_active_accounts) OVER (
        ORDER BY month
    ) AS prev_paid_accounts,
    paid_active_accounts
        - LAG(paid_active_accounts) OVER (
            ORDER BY month
        ) AS account_growth
FROM kpi_monthly_mrr_growth
ORDER BY month;

-- Validation 9: Reliability flag check
SELECT
    month,
    prev_month_mrr,
    is_reliable
FROM kpi_monthly_mrr_growth
ORDER BY month;

-- Validation 10: Average monthly growth rate
SELECT
    ROUND(AVG(mrr_growth_pct), 2) AS avg_mrr_growth_pct
FROM kpi_monthly_mrr_growth
WHERE mrr_growth_pct IS NOT NULL;