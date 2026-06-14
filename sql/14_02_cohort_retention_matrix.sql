/*
===============================================================================
FILE: 14_02_cohort_retention_matrix.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Creates the monthly cohort retention matrix.

For each cohort, tracks what percentage of the original cohort
remains active at each month since signup.

DEFINITION USED
------------------------------------------------------------------------------
Point-in-time active retention:

    An account is retained at month N if it has at least one
    active subscription during that month.

    Source: base_active_monthly

Reactivations count as retained.
Retention CAN increase in later months due to reactivations.
This is intentional and documented.

For monotonically decreasing survival analysis → see 14_03.

GRAIN
------------------------------------------------------------------------------
One row per cohort_month per months_since_signup.
Maximum 576 rows (24 cohorts × 24 months).
Actual rows fewer due to age cap on later cohorts.

COHORT SIZE
------------------------------------------------------------------------------
Locked at Month 0 — never recalculated.
Always = COUNT(account_id) from cohort_base for that cohort.

This is the permanent denominator for ALL retention calculations.

MONTHS SINCE SIGNUP
------------------------------------------------------------------------------
Uses calendar month arithmetic (identical to 14_01):

    months_since_signup =
        (YEAR(activity_month) × 12 + MONTH(activity_month))
        −
        (YEAR(cohort_month)   × 12 + MONTH(cohort_month))

Must match 14_01 months_to_first_churn arithmetic exactly.
This ensures retention matrix and survival curve align perfectly.

AGE CAP
------------------------------------------------------------------------------
Only includes month N for a cohort if that month has occurred:

    activity_month <= '2024-12-01' (dataset end)

Without this:
    Later cohorts appear to have perfect retention at future months.

With this:
    Dec 2024 cohort → Month 0 only
    Nov 2024 cohort → Months 0-1 only
    Jan 2023 cohort → Months 0-23 (full observation window)

MONTH 0
------------------------------------------------------------------------------
Always = 100% for every cohort.
Every account was active in their signup month by definition.

OUTPUT
------------------------------------------------------------------------------
cohort_month            → cohort identifier
cohort_size             → original cohort count (locked at Month 0)
months_since_signup     → 0, 1, 2 ... up to 23
activity_month          → actual calendar month (for time-series charts)
active_accounts         → accounts from cohort active at month N
retention_rate_pct      → active_accounts / cohort_size * 100

DEPENDENCIES
------------------------------------------------------------------------------
    cohort_base             (14_01)
    base_active_monthly     (Step 12)

===============================================================================
*/

DROP VIEW IF EXISTS cohort_retention_matrix;
CREATE VIEW cohort_retention_matrix AS

WITH cohort_sizes AS (

    /*
    ---------------------------------------------------------------------------
    Step 1: Lock cohort sizes at Month 0
    ---------------------------------------------------------------------------
    Permanent denominator for all retention calculations.
    Never recalculated at later months.
    ---------------------------------------------------------------------------
    */

    SELECT
        cohort_month,
        COUNT(account_id)       AS cohort_size
    FROM cohort_base
    GROUP BY cohort_month
),

cohort_month_spine AS (

    /*
    ---------------------------------------------------------------------------
    Step 2: Generate all valid cohort × activity month combinations
    ---------------------------------------------------------------------------
    For each cohort, generates every month from signup through
    dataset end date.

    AGE CAP:
        activity_month <= '2024-12-01'
        ensures no future months are included.

    LOWER BOUND:
        activity_month >= cohort_month
        ensures no months before cohort signup are included.

    Calendar month arithmetic applied here for months_since_signup.
    Must match 14_01 months_to_first_churn arithmetic exactly.
    ---------------------------------------------------------------------------
    */

    SELECT
        cs.cohort_month,
        cs.cohort_size,
        m.month_start                                       AS activity_month,
        (
            EXTRACT(YEAR  FROM m.month_start)::INTEGER * 12
            + EXTRACT(MONTH FROM m.month_start)::INTEGER
        )
        -
        (
            EXTRACT(YEAR  FROM cs.cohort_month)::INTEGER * 12
            + EXTRACT(MONTH FROM cs.cohort_month)::INTEGER
        )                                                   AS months_since_signup

    FROM cohort_sizes cs

    -- Cross join with all months in dataset
    CROSS JOIN (
        SELECT generate_series(
            (SELECT MIN(cohort_month) FROM cohort_sizes),
            '2024-12-01'::DATE,
            INTERVAL '1 month'
        )::DATE AS month_start
    ) m

    -- Age cap: only months the cohort has actually lived through
    WHERE m.month_start >= cs.cohort_month
      AND m.month_start <= '2024-12-01'::DATE
),


    /*
    ---------------------------------------------------------------------------
    Step 3: Count active accounts per cohort per activity month
    ---------------------------------------------------------------------------
    Joins:
        cohort_month_spine  → valid cohort × month combinations
        cohort_base         → which cohort each account belongs to
        base_active_monthly → was each account active in that month

    LEFT JOIN on base_active_monthly:
        Preserves months where a cohort had zero active accounts.
        These appear as NULL → converted to 0 via COALESCE in Step 4.

    INNER JOIN on cohort_base:
        Only accounts belonging to that cohort counted.
    ---------------------------------------------------------------------------
    */

active_per_cohort_month AS (

    -- Month 0: always full cohort (100% by definition)
    SELECT
        spine.cohort_month,
        spine.cohort_size,
        spine.activity_month,
        spine.months_since_signup,
        spine.cohort_size               AS active_accounts
    FROM cohort_month_spine spine
    WHERE spine.months_since_signup = 0

    UNION ALL

    -- Month 1+: actual active count from base_active_monthly
    SELECT
        spine.cohort_month,
        spine.cohort_size,
        spine.activity_month,
        spine.months_since_signup,
        COUNT(DISTINCT bam.account_id)  AS active_accounts
    FROM cohort_month_spine spine
    JOIN cohort_base cb
        ON cb.cohort_month = spine.cohort_month
    LEFT JOIN base_active_monthly bam
        ON  bam.account_id  = cb.account_id
        AND bam.month       = spine.activity_month
    WHERE spine.months_since_signup > 0
    GROUP BY
        spine.cohort_month,
        spine.cohort_size,
        spine.activity_month,
        spine.months_since_signup
)

SELECT
    cohort_month,
    cohort_size,
    months_since_signup,
    activity_month,
    COALESCE(active_accounts, 0)            AS active_accounts,
    ROUND(
        COALESCE(active_accounts, 0)::NUMERIC
        / NULLIF(cohort_size, 0)
        * 100,
        2
    )                                       AS retention_rate_pct

FROM active_per_cohort_month
ORDER BY
    cohort_month,
    months_since_signup;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Full matrix preview
SELECT *
FROM cohort_retention_matrix
ORDER BY cohort_month, months_since_signup;


-- V1: Month 0 must be 100% for ALL cohorts
-- Should return 0 rows
SELECT *
FROM cohort_retention_matrix
WHERE months_since_signup = 0
  AND retention_rate_pct != 100.00;


-- V2: Retention must never exceed 100%
-- Should return 0 rows
SELECT *
FROM cohort_retention_matrix
WHERE retention_rate_pct > 100.00;


-- V3: Age cap validation
-- Dec 2024 cohort → only Month 0
-- Nov 2024 cohort → only Months 0 and 1
SELECT
    cohort_month,
    COUNT(*)                        AS observation_months,
    MIN(months_since_signup)        AS min_month,
    MAX(months_since_signup)        AS max_month
FROM cohort_retention_matrix
GROUP BY cohort_month
ORDER BY cohort_month;


-- V4: Cohort sizes must match cohort_base
-- Should return 0 rows
SELECT
    crm.cohort_month,
    crm.cohort_size                 AS matrix_cohort_size,
    cb.base_cohort_size
FROM (
    SELECT cohort_month, MAX(cohort_size) AS cohort_size
    FROM cohort_retention_matrix
    GROUP BY cohort_month
) crm
JOIN (
    SELECT cohort_month, COUNT(*) AS base_cohort_size
    FROM cohort_base
    GROUP BY cohort_month
) cb ON crm.cohort_month = cb.cohort_month
WHERE crm.cohort_size != cb.base_cohort_size;


-- V5: Month 1 retention by cohort
-- Most important single output in cohort analysis
SELECT
    cohort_month,
    cohort_size,
    active_accounts,
    retention_rate_pct              AS month_1_retention_pct
FROM cohort_retention_matrix
WHERE months_since_signup = 1
ORDER BY cohort_month;


-- V6: Retention at standard SaaS checkpoints
SELECT
    cohort_month,
    cohort_size,
    MAX(retention_rate_pct)
        FILTER (WHERE months_since_signup = 0)      AS month_0_pct,
    MAX(retention_rate_pct)
        FILTER (WHERE months_since_signup = 1)      AS month_1_pct,
    MAX(retention_rate_pct)
        FILTER (WHERE months_since_signup = 3)      AS month_3_pct,
    MAX(retention_rate_pct)
        FILTER (WHERE months_since_signup = 6)      AS month_6_pct,
    MAX(retention_rate_pct)
        FILTER (WHERE months_since_signup = 12)     AS month_12_pct
FROM cohort_retention_matrix
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;


-- V7: Average retention curve across all cohorts
-- Shows typical retention shape by month
SELECT
    months_since_signup,
    COUNT(DISTINCT cohort_month)            AS cohorts_observed,
    ROUND(AVG(retention_rate_pct), 2)       AS avg_retention_pct,
    ROUND(MIN(retention_rate_pct), 2)       AS min_retention_pct,
    ROUND(MAX(retention_rate_pct), 2)       AS max_retention_pct
FROM cohort_retention_matrix
GROUP BY months_since_signup
ORDER BY months_since_signup;


-- V8: Best and worst retaining cohorts at Month 6
SELECT
    cohort_month,
    cohort_size,
    retention_rate_pct              AS month_6_retention_pct
FROM cohort_retention_matrix
WHERE months_since_signup = 6
ORDER BY retention_rate_pct DESC;


-- V9: Best and worst retaining cohorts at Month 12
SELECT
    cohort_month,
    cohort_size,
    retention_rate_pct              AS month_12_retention_pct
FROM cohort_retention_matrix
WHERE months_since_signup = 12
ORDER BY retention_rate_pct DESC;


-- V10: Cohort improvement trend
-- Are newer cohorts retaining better than older ones at Month 3?
SELECT
    cohort_month,
    retention_rate_pct              AS month_3_retention_pct,
    CASE
        WHEN cohort_month < '2024-01-01' THEN '2023 cohort'
        ELSE '2024 cohort'
    END                             AS cohort_year
FROM cohort_retention_matrix
WHERE months_since_signup = 3
ORDER BY cohort_month;


-- V11: Reactivation signal
-- Months where retention INCREASES vs previous month
-- These are months where reactivations outpaced new churns
SELECT
    cohort_month,
    months_since_signup,
    retention_rate_pct,
    LAG(retention_rate_pct) OVER (
        PARTITION BY cohort_month
        ORDER BY months_since_signup
    )                               AS prev_month_retention,
    ROUND(
        retention_rate_pct -
        LAG(retention_rate_pct) OVER (
            PARTITION BY cohort_month
            ORDER BY months_since_signup
        ),
        2
    )                               AS retention_change
FROM cohort_retention_matrix
ORDER BY cohort_month, months_since_signup;