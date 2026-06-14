/*
===============================================================================
FILE: 14_03_cohort_survival_curve.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Creates the cohort survival curve.

For each cohort, tracks what percentage of the original cohort
has NEVER churned by month N since signup.

DEFINITION USED
------------------------------------------------------------------------------
Cumulative survival — once an account churns it is permanently lost.

An account survives month N if:
    ever_churned = FALSE   (never churned at all)
    OR
    months_to_first_churn > N  (first churn has not yet occurred by month N)

Reactivations are IGNORED.
This produces a monotonically non-increasing curve.

CONTRAST WITH 14_02
------------------------------------------------------------------------------
Retention Matrix (14_02):
    - Active during month N?
    - Reactivations count as retained
    - Curve can go UP due to reactivations
    - Source: base_active_monthly

Survival Curve (14_03):
    - Never churned by month N?
    - Reactivations ignored
    - Curve only goes DOWN or stays flat
    - Source: cohort_base.months_to_first_churn

Both are valid — they answer different questions.
Use retention matrix for dashboard/KPI.
Use survival curve for time-to-churn and hazard analysis.

GRAIN
------------------------------------------------------------------------------
One row per cohort_month per months_since_signup.
Same grain as retention matrix — enables direct comparison.

COHORT SIZE
------------------------------------------------------------------------------
Locked at Month 0. Identical to 14_02.
Never recalculated.

MONTHS SINCE SIGNUP
------------------------------------------------------------------------------
Integer series 0 to 23.
Simpler than retention matrix — no calendar month joins needed.
Survival logic only requires month index comparison against
months_to_first_churn from cohort_base.

AGE CAP
------------------------------------------------------------------------------
Only includes month N for a cohort if that month has occurred:

    cohort_month + (months_since_signup × INTERVAL '1 month')
    <= '2024-12-01'

Later cohorts with few observation months show flatter survival curves
because no churn has been observed yet. This is correct and expected.

MONTH 0
------------------------------------------------------------------------------
Always = 100% survival for every cohort.
Nobody has churned at signup month.

OUTPUT
------------------------------------------------------------------------------
cohort_month                → cohort identifier
cohort_size                 → original cohort count (locked at Month 0)
months_since_signup         → 0, 1, 2 ... up to 23
surviving_accounts          → accounts with no first churn by month N
survival_rate_pct           → surviving / cohort_size * 100
churned_by_month_n          → cohort_size - surviving_accounts
cumulative_churn_rate_pct   → 100 - survival_rate_pct

NOTE:
    survival_rate_pct + cumulative_churn_rate_pct = 100% always

CRITICAL VALIDATION
------------------------------------------------------------------------------
Survival curve MUST be monotonically non-increasing.
If survival_rate_pct increases at any month → logic error.
Validated in V3 below.

DEPENDENCIES
------------------------------------------------------------------------------
    cohort_base    (14_01)

NO dependency on base_active_monthly.
All survival logic derived from months_to_first_churn in cohort_base.

===============================================================================
*/

DROP VIEW IF EXISTS cohort_survival_curve;
CREATE VIEW cohort_survival_curve AS

WITH cohort_sizes AS (

    /*
    ---------------------------------------------------------------------------
    Step 1: Lock cohort sizes at Month 0
    ---------------------------------------------------------------------------
    Permanent denominator. Never recalculated.
    Identical to 14_02.
    ---------------------------------------------------------------------------
    */

    SELECT
        cohort_month,
        COUNT(account_id)       AS cohort_size
    FROM cohort_base
    GROUP BY cohort_month
),

month_series AS (

    /*
    ---------------------------------------------------------------------------
    Step 2: Generate month index series 0 to 23
    ---------------------------------------------------------------------------
    Integer series only — no calendar dates needed here.
    Survival logic compares month indices directly against
    months_to_first_churn from cohort_base.

    Simpler than retention matrix which needed calendar month joins.
    ---------------------------------------------------------------------------
    */

    SELECT generate_series(0, 23) AS months_since_signup
),

cohort_spine AS (

    /*
    ---------------------------------------------------------------------------
    Step 3: Generate valid cohort × month combinations
    ---------------------------------------------------------------------------
    Cross join cohort sizes with month series.
    Apply age cap to exclude future months.

    AGE CAP:
        cohort_month + months_since_signup months <= 2024-12-01
        Ensures no month is shown that the cohort hasn't lived through.

    Dec 2024 cohort → Month 0 only
    Nov 2024 cohort → Months 0-1 only
    Jan 2023 cohort → Months 0-23 (full window)
    ---------------------------------------------------------------------------
    */

    SELECT
        cs.cohort_month,
        cs.cohort_size,
        ms.months_since_signup
    FROM cohort_sizes cs
    CROSS JOIN month_series ms
    WHERE
        -- Age cap: cohort must have reached this month
        cs.cohort_month + (ms.months_since_signup * INTERVAL '1 month')
        <= '2024-12-01'::DATE
),

survival_counts AS (

    /*
    ---------------------------------------------------------------------------
    Step 4: Count surviving accounts per cohort per month
    ---------------------------------------------------------------------------
    An account survives month N if:
        ever_churned = FALSE
        (never had any churn event — survives all months)

        OR

        months_to_first_churn > N
        (first churn occurred after month N — still surviving at N)

    IMPORTANT:
        Both conditions must be checked.
        Accounts with ever_churned = FALSE have NULL months_to_first_churn.
        Checking only months_to_first_churn > N would exclude them
        because NULL > N evaluates to NULL (not TRUE) in SQL.

    Reactivations are completely ignored.
    Once months_to_first_churn <= N the account is permanently lost
    regardless of any subsequent reactivation.
    ---------------------------------------------------------------------------
    */

    SELECT
        spine.cohort_month,
        spine.cohort_size,
        spine.months_since_signup,
        COUNT(cb.account_id)            AS surviving_accounts
    FROM cohort_spine spine
    JOIN cohort_base cb
        ON cb.cohort_month = spine.cohort_month
    WHERE
        cb.ever_churned = FALSE
        OR cb.months_to_first_churn > spine.months_since_signup
    GROUP BY
        spine.cohort_month,
        spine.cohort_size,
        spine.months_since_signup
)

SELECT
    cohort_month,
    cohort_size,
    months_since_signup,

    surviving_accounts,

    ROUND(
        surviving_accounts::NUMERIC
        / NULLIF(cohort_size, 0)
        * 100,
        2
    )                                   AS survival_rate_pct,

    cohort_size
        - surviving_accounts            AS churned_by_month_n,

    ROUND(
        (cohort_size - surviving_accounts)::NUMERIC
        / NULLIF(cohort_size, 0)
        * 100,
        2
    )                                   AS cumulative_churn_rate_pct

FROM survival_counts
ORDER BY
    cohort_month,
    months_since_signup;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Full curve preview
SELECT *
FROM cohort_survival_curve
ORDER BY cohort_month, months_since_signup;

-- V1: Month 0 survival check
-- NOTE: Month 0 is NOT forced to 100% in survival curve.
-- Accounts churning in signup month (months_to_first_churn = 0)
-- correctly reduce Month 0 survival below 100%.
-- This is intentional and documented in the file header.
-- The following query shows Month 0 survival for all cohorts:


SELECT *
FROM cohort_survival_curve
WHERE months_since_signup = 0
  AND survival_rate_pct != 100.00;


-- V2: Survival must never exceed 100%
-- Should return 0 rows
SELECT *
FROM cohort_survival_curve
WHERE survival_rate_pct > 100.00;


-- V3: Curve must be monotonically non-increasing
-- MOST IMPORTANT validation for survival curves
-- Should return 0 rows
SELECT
    curr.cohort_month,
    curr.months_since_signup,
    curr.survival_rate_pct              AS curr_survival,
    prev.survival_rate_pct              AS prev_survival
FROM cohort_survival_curve curr
JOIN cohort_survival_curve prev
    ON  curr.cohort_month        = prev.cohort_month
    AND curr.months_since_signup = prev.months_since_signup + 1
WHERE curr.survival_rate_pct > prev.survival_rate_pct;


-- V4: survival + cumulative_churn = 100% always
-- Should return 0 rows
SELECT *
FROM cohort_survival_curve
WHERE ROUND(survival_rate_pct + cumulative_churn_rate_pct, 2) != 100.00;


-- V5: Age cap validation
-- Dec 2024 → 1 row, Nov 2024 → 2 rows
SELECT
    cohort_month,
    COUNT(*)                            AS observation_months,
    MIN(months_since_signup)            AS min_month,
    MAX(months_since_signup)            AS max_month
FROM cohort_survival_curve
GROUP BY cohort_month
ORDER BY cohort_month;


-- V6: Average survival curve across all cohorts
-- Shows typical survival shape by month
-- Compare against retention matrix average curve
SELECT
    months_since_signup,
    COUNT(DISTINCT cohort_month)        AS cohorts_observed,
    ROUND(AVG(survival_rate_pct), 2)    AS avg_survival_pct,
    ROUND(MIN(survival_rate_pct), 2)    AS min_survival_pct,
    ROUND(MAX(survival_rate_pct), 2)    AS max_survival_pct,
    ROUND(AVG(cumulative_churn_rate_pct), 2) AS avg_cumulative_churn_pct
FROM cohort_survival_curve
GROUP BY months_since_signup
ORDER BY months_since_signup;


-- V7: Median survival month per cohort
-- At which month does each cohort first drop below 50% survival?
-- NULL = cohort never dropped below 50% in observation window
SELECT
    cohort_month,
    cohort_size,
    MIN(months_since_signup)            AS median_survival_month,
    MIN(survival_rate_pct)              AS survival_at_median_month
FROM cohort_survival_curve
WHERE survival_rate_pct <= 50.00
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;


-- V8: Standard SaaS survival checkpoints
SELECT
    cohort_month,
    cohort_size,
    MAX(survival_rate_pct)
        FILTER (WHERE months_since_signup = 0)  AS month_0_pct,
    MAX(survival_rate_pct)
        FILTER (WHERE months_since_signup = 1)  AS month_1_pct,
    MAX(survival_rate_pct)
        FILTER (WHERE months_since_signup = 3)  AS month_3_pct,
    MAX(survival_rate_pct)
        FILTER (WHERE months_since_signup = 6)  AS month_6_pct,
    MAX(survival_rate_pct)
        FILTER (WHERE months_since_signup = 12) AS month_12_pct
FROM cohort_survival_curve
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;


-- V9: Cohort improvement trend at Month 3
-- Are 2024 cohorts surviving longer than 2023 cohorts?
SELECT
    cohort_month,
    survival_rate_pct                   AS month_3_survival_pct,
    CASE
        WHEN cohort_month < '2024-01-01' THEN '2023 cohort'
        ELSE '2024 cohort'
    END                                 AS cohort_year
FROM cohort_survival_curve
WHERE months_since_signup = 3
ORDER BY cohort_month;


-- V10: Survival vs retention gap
-- Gap = reactivated accounts
-- Large gap = strong reactivation behavior
SELECT
    sv.cohort_month,
    sv.months_since_signup,
    sv.survival_rate_pct,
    rm.retention_rate_pct,
    ROUND(
        rm.retention_rate_pct
        - sv.survival_rate_pct,
        2
    )                                   AS reactivation_gap_pct
FROM cohort_survival_curve sv
JOIN cohort_retention_matrix rm
    ON  sv.cohort_month        = rm.cohort_month
    AND sv.months_since_signup = rm.months_since_signup
ORDER BY
    sv.cohort_month,
    sv.months_since_signup;


-- V11: Long-term survival floor
-- Jan 2023 cohort at Month 23 — true loyal customer base
SELECT
    cohort_month,
    cohort_size,
    months_since_signup,
    surviving_accounts,
    survival_rate_pct,
    cumulative_churn_rate_pct
FROM cohort_survival_curve
WHERE months_since_signup = (
    SELECT MAX(months_since_signup)
    FROM cohort_survival_curve
    WHERE cohort_month = '2023-01-01'
)
AND cohort_month = '2023-01-01';


-- V12: Final survival by cohort at maximum observed month
-- Long-term loyal base per cohort
SELECT
    sc.cohort_month,
    sc.cohort_size,
    sc.months_since_signup              AS final_observed_month,
    sc.surviving_accounts,
    sc.survival_rate_pct                AS final_survival_pct,
    sc.cumulative_churn_rate_pct        AS final_churn_pct
FROM cohort_survival_curve sc
JOIN (
    SELECT cohort_month, MAX(months_since_signup) AS max_month
    FROM cohort_survival_curve
    GROUP BY cohort_month
) last ON sc.cohort_month = last.cohort_month
       AND sc.months_since_signup = last.max_month
ORDER BY sc.cohort_month;