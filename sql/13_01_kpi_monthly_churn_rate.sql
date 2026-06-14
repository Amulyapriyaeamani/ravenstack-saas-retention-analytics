/*
===============================================================================
FILE: 13_01_kpi_monthly_churn_rate.sql
===============================================================================

PURPOSE
-------------------------------------------------------------------------------
Creates the official monthly customer churn KPI table.

This KPI measures the percentage of customer accounts that churned during a
month relative to the accounts that were active at the START of that month.

This is one of the most important SaaS retention metrics and serves as the
primary indicator of customer loss over time.

USED FOR:
    - SaaS health monitoring
    - Retention analysis
    - Cohort analysis
    - Executive KPI dashboards
    - Revenue forecasting
    - Churn segmentation
    - Customer lifecycle analysis

BUSINESS DEFINITION
-------------------------------------------------------------------------------
Monthly Churn Rate measures:

    "Of all accounts active at the beginning of month M,
     what percentage churned during month M?"

FORMULA
-------------------------------------------------------------------------------
Churn Rate % =
(
    Churned Accounts During Month M
    /
    Accounts Active At Start Of Month M
) * 100

NUMERATOR
-------------------------------------------------------------------------------
COUNT(DISTINCT account_id)
FROM base_churn_monthly

WHERE:
    churn occurred during month M

NOTES:
    - Churn deduplication already handled in base_churn_monthly
    - One account counted once per month
    - Trial + paid accounts both included
    - Churn measured at account level (NOT subscription level)

DENOMINATOR
-------------------------------------------------------------------------------
COUNT(DISTINCT account_id)
FROM subscriptions

WHERE:
    account had at least one subscription active on the
    FIRST DAY of month M

Active definition:
    start_date <= first_day_of_month
    AND (
        end_date IS NULL
        OR end_date >= first_day_of_month
    )

IMPORTANT:
    This is intentionally DIFFERENT from base_active_monthly.

    base_active_monthly =
        active ANYTIME during month

    churn denominator =
        active at START of month only

WHY START-OF-MONTH DENOMINATOR?
-------------------------------------------------------------------------------
Using active-anytime accounts would incorrectly include:
    - newly created accounts later in month
    - accounts never exposed to full churn risk

This artificially lowers churn rate.

Correct SaaS churn logic always measures churn against:
    "population at risk at start of period"

TIME LOGIC
-------------------------------------------------------------------------------
Numerator:
    churn_date falls within month M

Denominator:
    active on first day of month M

OUTPUT
-------------------------------------------------------------------------------
month                           → month being measured
start_month_active_accounts     → active accounts at month start
churned_accounts                → accounts churned during month
monthly_churn_rate_pct          → churn %

EXAMPLE
-------------------------------------------------------------------------------
month      | start_active | churned | churn_rate
------------+--------------+----------+------------
2024-01-01 |     200      |    10    |    5.0%

INTERPRETATION:
    5% of accounts active at the beginning of January
    churned during January.

TECHNICAL NOTES
-------------------------------------------------------------------------------
- COUNT(DISTINCT account_id) prevents multi-subscription double counting
- LEFT JOIN preserves months with zero churn
- NULLIF prevents divide-by-zero errors
- ROUND(..., 2) standardizes KPI formatting
- Uses month spine derived from subscriptions table
===============================================================================
*/

DROP VIEW IF EXISTS kpi_monthly_churn_rate;

CREATE VIEW kpi_monthly_churn_rate AS

WITH month_spine AS (

    /*
    ---------------------------------------------------------------------------
    Step 1: Generate complete monthly timeline
    ---------------------------------------------------------------------------
    Creates one row per month across the dataset range.

    Uses subscriptions because:
        - subscriptions define business lifecycle timeline
        - ensures all operational months included
    ---------------------------------------------------------------------------
    */

    SELECT generate_series(
        DATE_TRUNC('month', (SELECT MIN(start_date) FROM subscriptions)),
        DATE_TRUNC('month', (SELECT MAX(start_date) FROM subscriptions)),
        INTERVAL '1 month'
    ) AS month_start
),

start_month_active_accounts AS (

    /*
    ---------------------------------------------------------------------------
    Step 2: Identify accounts active at START of each month
    ---------------------------------------------------------------------------
    An account is considered active at month start if it has
    at least one subscription active on the first day of month M.

    IMPORTANT:
        This is stricter than active-anytime logic.

    Deduplication:
        COUNT DISTINCT handled downstream.
    ---------------------------------------------------------------------------
    */

    SELECT
        m.month_start AS month,
        s.account_id
    FROM month_spine m
    JOIN subscriptions s
        ON s.start_date <= m.month_start
       AND (
            s.end_date IS NULL
            OR s.end_date >= m.month_start
       )
),

monthly_active_base AS (

    /*
    ---------------------------------------------------------------------------
    Step 3: Aggregate denominator
    ---------------------------------------------------------------------------
    Produces:
        one row per month
        with total active accounts at month start
    ---------------------------------------------------------------------------
    */

    SELECT
        month,
        COUNT(DISTINCT account_id) AS start_month_active_accounts
    FROM start_month_active_accounts
    GROUP BY month
),

monthly_churned_accounts AS (

    /*
    ---------------------------------------------------------------------------
    Step 4: Aggregate churn numerator
    ---------------------------------------------------------------------------
    Uses base_churn_monthly because:
        - churn already deduplicated
        - one row per account per month guaranteed
    ---------------------------------------------------------------------------
    */

    SELECT
        month,
        COUNT(DISTINCT account_id) AS churned_accounts
    FROM base_churn_monthly
    GROUP BY month
)

SELECT
    a.month,

    a.start_month_active_accounts,

    COALESCE(c.churned_accounts, 0) AS churned_accounts,

    ROUND(
        COALESCE(c.churned_accounts, 0)::NUMERIC
        /
        NULLIF(a.start_month_active_accounts, 0)
        * 100,
        2
    ) AS monthly_churn_rate_pct,
    /*
Small denominators create statistically unstable churn rates.
Threshold chosen to flag early-stage months with insufficient population size.
*/
CASE
    WHEN a.start_month_active_accounts < 20 THEN FALSE
    ELSE TRUE
END AS is_reliable
	
FROM monthly_active_base a

LEFT JOIN monthly_churned_accounts c
    ON a.month = c.month

ORDER BY a.month;



-- =============================================================================
-- VALIDATION QUERIES
-- =============================================================================

-- Full KPI preview
SELECT *
FROM kpi_monthly_churn_rate
ORDER BY month;


-- Validation 1:
-- Churn count should NEVER exceed active base
SELECT *
FROM kpi_monthly_churn_rate
WHERE churned_accounts > start_month_active_accounts;


-- Validation 2:
-- Churn rate must remain between 0 and 100
SELECT *
FROM kpi_monthly_churn_rate
WHERE monthly_churn_rate_pct < 0
   OR monthly_churn_rate_pct > 100;


-- Validation 3:
-- Average churn rate across all months
SELECT
    ROUND(
        AVG(monthly_churn_rate_pct),
        2
    ) AS avg_monthly_churn_rate
FROM kpi_monthly_churn_rate;


-- Validation 4:
-- Highest churn months
SELECT *
FROM kpi_monthly_churn_rate
ORDER BY monthly_churn_rate_pct DESC;


-- Validation 5:
-- Lowest churn months
SELECT *
FROM kpi_monthly_churn_rate
ORDER BY monthly_churn_rate_pct ASC;


-- Validation 6:
-- Month-over-month churn change
SELECT
    curr.month,
    curr.monthly_churn_rate_pct,
    prev.monthly_churn_rate_pct AS prev_month_churn_rate,

    ROUND(
        curr.monthly_churn_rate_pct
        - prev.monthly_churn_rate_pct,
        2
    ) AS churn_rate_change_pct

FROM kpi_monthly_churn_rate curr

LEFT JOIN kpi_monthly_churn_rate prev
    ON prev.month = curr.month - INTERVAL '1 month'

ORDER BY curr.month;


-- Validation 7:
-- Denominator trend check
SELECT
    month,
    start_month_active_accounts
FROM kpi_monthly_churn_rate
ORDER BY month;


-- Validation 8:
-- Numerator trend check
SELECT
    month,
    churned_accounts
FROM kpi_monthly_churn_rate
ORDER BY month;