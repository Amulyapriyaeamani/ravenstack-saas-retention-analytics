/*
===============================================================================
FILE: 13_02_kpi_monthly_retention_rate.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Creates a reusable monthly customer retention KPI view.

This KPI measures the percentage of accounts that were active at the
START of a month and remained active throughout that same month
(i.e., did NOT churn during the month).

This is the complementary KPI to monthly churn rate.

USED FOR
------------------------------------------------------------------------------
- Customer health monitoring
- Retention trend analysis
- Executive SaaS KPI dashboards
- Cohort retention analysis
- Revenue forecasting
- Churn benchmarking
- Lifecycle analysis
- Investor reporting

BUSINESS DEFINITION
------------------------------------------------------------------------------
Retention Rate (%) =
(
    Accounts active at start of month
    that did NOT churn during month
)
/
(
    Accounts active at start of month
)
* 100

IMPORTANT:
------------------------------------------------------------------------------
Retention is calculated independently for clarity and auditability.

Mathematically:

    Retention Rate = 100 - Churn Rate

However this KPI is still modeled explicitly because:
- retention is commonly reported separately
- downstream dashboards often require direct access
- validation/reconciliation becomes easier
- avoids recalculating logic repeatedly

DEPENDENCY DESIGN
------------------------------------------------------------------------------
This KPI intentionally depends on:

    kpi_monthly_churn_rate

instead of rebuilding denominator logic again.

Reason:
- guarantees denominator consistency
- prevents KPI drift
- follows DRY principle
- improves maintainability
- keeps churn + retention perfectly aligned

This means:
IF churn denominator logic changes,
retention automatically stays consistent.

OUTPUT
------------------------------------------------------------------------------
month                           → month dimension
start_month_active_accounts     → denominator
churned_accounts                → churn numerator
retained_accounts               → retained customers
monthly_churn_rate_pct          → included for reconciliation
monthly_retention_rate_pct      → primary KPI
is_reliable                     → FALSE when denominator < 10

RELIABILITY FLAG
------------------------------------------------------------------------------
Early months may contain very small customer counts.

Example:
    1 churn out of 2 accounts = 50% churn

Technically correct,
but statistically unreliable.

To prevent misleading interpretations:

    is_reliable = FALSE
    when denominator < 10

This flag should be used in dashboards and analysis.

ASSUMPTIONS
------------------------------------------------------------------------------
- Churn logic already validated in kpi_monthly_churn_rate
- One account counted once per month
- Churn measured at account level
- Trial + paid accounts included
- Monthly granularity sufficient

EXAMPLE
------------------------------------------------------------------------------
month       | active | churned | retained | retention_rate
2024-05-01  | 302    | 25      | 277      | 91.72%

INTERPRETATION:
------------------------------------------------------------------------------
91.72% of accounts active at the start of May 2024
remained active throughout the month.

===============================================================================
*/

DROP VIEW IF EXISTS kpi_monthly_retention_rate;

CREATE VIEW kpi_monthly_retention_rate AS

SELECT
    month,
    start_month_active_accounts,
    churned_accounts,

    /*
    --------------------------------------------------------
    Retained accounts
    --------------------------------------------------------
    Accounts that were active at start of month
    and did NOT churn during the month.
    --------------------------------------------------------
    */
    start_month_active_accounts
        - churned_accounts AS retained_accounts,

    /*
    --------------------------------------------------------
    Churn rate included for reconciliation
    --------------------------------------------------------
    Allows:
        retention + churn = 100%
    validation downstream.
    --------------------------------------------------------
    */
    monthly_churn_rate_pct,

    /*
    --------------------------------------------------------
    Monthly retention rate
    --------------------------------------------------------
    Formula:
    retained / start_month_active_accounts * 100
    --------------------------------------------------------
    */
    ROUND(
        (
            start_month_active_accounts
            - churned_accounts
        )::NUMERIC
        / NULLIF(start_month_active_accounts, 0)
        * 100,
        2
    ) AS monthly_retention_rate_pct,

    /*
    --------------------------------------------------------
    Reliability flag
    --------------------------------------------------------
    FALSE when denominator is too small for
    statistically meaningful interpretation.
    --------------------------------------------------------
    */
    is_reliable

FROM kpi_monthly_churn_rate

ORDER BY month;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Full KPI output
SELECT *
FROM kpi_monthly_retention_rate;


-- ============================================================================
-- Validation 1: Retention rate bounds check
-- Should always be between 0 and 100
-- ============================================================================

SELECT *
FROM kpi_monthly_retention_rate
WHERE monthly_retention_rate_pct < 0
   OR monthly_retention_rate_pct > 100;


-- ============================================================================
-- Validation 2: Retained accounts should never exceed denominator
-- ============================================================================

SELECT *
FROM kpi_monthly_retention_rate
WHERE retained_accounts > start_month_active_accounts;


-- ============================================================================
-- Validation 3: Retained + churned should equal denominator
-- ============================================================================

SELECT
    month,
    start_month_active_accounts,
    retained_accounts,
    churned_accounts,
    retained_accounts + churned_accounts AS reconstructed_total
FROM kpi_monthly_retention_rate
ORDER BY month;


-- ============================================================================
-- Validation 4: Retention + churn should equal 100%
-- Most important reconciliation test
-- ============================================================================

SELECT
    month,
    monthly_retention_rate_pct,
    monthly_churn_rate_pct,

    ROUND(
        monthly_retention_rate_pct
        + monthly_churn_rate_pct,
        2
    ) AS total_pct

FROM kpi_monthly_retention_rate
ORDER BY month;


-- ============================================================================
-- Validation 5: Average retention rate
-- ============================================================================

SELECT
    ROUND(AVG(monthly_retention_rate_pct), 2)
        AS avg_retention_rate_pct
FROM kpi_monthly_retention_rate
WHERE is_reliable = TRUE;


-- ============================================================================
-- Validation 6: Highest retention months
-- ============================================================================

SELECT *
FROM kpi_monthly_retention_rate
WHERE is_reliable = TRUE
ORDER BY monthly_retention_rate_pct DESC
LIMIT 5;


-- ============================================================================
-- Validation 7: Lowest retention months
-- ============================================================================

SELECT *
FROM kpi_monthly_retention_rate
WHERE is_reliable = TRUE
ORDER BY monthly_retention_rate_pct ASC
LIMIT 5;


-- ============================================================================
-- Validation 8: Month-over-month retention change
-- ============================================================================

SELECT
    curr.month,

    curr.monthly_retention_rate_pct AS current_retention_rate,
    prev.monthly_retention_rate_pct AS previous_retention_rate,

    ROUND(
        curr.monthly_retention_rate_pct
        - prev.monthly_retention_rate_pct,
        2
    ) AS retention_rate_change_pct

FROM kpi_monthly_retention_rate curr

LEFT JOIN kpi_monthly_retention_rate prev
    ON prev.month = curr.month - INTERVAL '1 month'

ORDER BY curr.month;


-- ============================================================================
-- Validation 9: Reliability distribution
-- ============================================================================

SELECT
    is_reliable,
    COUNT(*) AS total_months
FROM kpi_monthly_retention_rate
GROUP BY is_reliable;


-- ============================================================================
-- Validation 10: Monthly retained account trend
-- ============================================================================

SELECT
    month,
    retained_accounts,
    start_month_active_accounts,
    churned_accounts,
    monthly_retention_rate_pct
FROM kpi_monthly_retention_rate
ORDER BY month;