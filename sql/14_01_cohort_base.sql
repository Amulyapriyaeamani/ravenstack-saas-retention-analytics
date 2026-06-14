/*
===============================================================================
FILE: 14_01_cohort_base.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Creates the master cohort dimension table.

Every account is assigned to exactly ONE cohort based on their signup month.
This table is the permanent reference for all cohort analysis in Steps 14,
20, 24, and 27.

GRAIN
------------------------------------------------------------------------------
One row per account.
500 rows total.
Never changes — cohort assignment is fixed at signup.

COHORT ASSIGNMENT
------------------------------------------------------------------------------
cohort_month = DATE_TRUNC('month', signup_date)

All accounts signing up in the same calendar month
belong to the same cohort regardless of exact signup date.

This assignment is permanent — upgrades, downgrades, churns,
and reactivations do NOT change cohort membership.

COLUMN GROUPS
------------------------------------------------------------------------------
1. Identity & Cohort Assignment
   cohort_month, account_id, signup_date

2. Segmentation Dimensions
   plan_tier (ENTRY plan — not current plan)
   industry, country, referral_source, seats, is_trial

3. Churn Behavior
   ever_churned, ever_reactivated, churn_count
   first_churn_date, last_churn_date, months_to_first_churn

4. Current Status
   is_currently_active (as of dataset end: 2024-12-31)

IMPORTANT DESIGN DECISIONS
------------------------------------------------------------------------------
plan_tier:
    Uses accounts.plan_tier = ENTRY plan at signup.
    NOT subscriptions.plan_tier which changes over time.
    Cohort segmentation by entry plan — not current plan.

ever_reactivated:
    TRUE only when:
        ever_churned = TRUE
        AND account has a paid subscription starting AFTER first_churn_date
    An account that never churned CANNOT be reactivated.

months_to_first_churn:
    Based on MIN(churn_date) only.
    Used directly in survival curve (14_03) to determine
    whether account was alive at month N.

is_currently_active:
    Based on base_active_monthly for December 2024.
    NOT CURRENT_DATE (dataset is historical — ends 2024-12-31).

MULTI-CHURN HANDLING
------------------------------------------------------------------------------
Accounts that churned multiple times:
    first_churn_date    = MIN(churn_date) → survival endpoint
    last_churn_date     = MAX(churn_date) → most recent loss
    churn_count         = COUNT(churn_event_id) → instability measure

Survival curve uses first_churn_date as the survival endpoint.
Reactivations and re-churns captured via churn_count and last_churn_date.

DEPENDENCIES
------------------------------------------------------------------------------
    accounts
    churn_events
    subscriptions       (for reactivation check)
    base_active_monthly (for current status)

USED BY
------------------------------------------------------------------------------
    14_02_cohort_retention_matrix.sql
    14_03_cohort_survival_curve.sql
    Step 20 — Churn Segmentation
    Step 24 — Support Impact Analysis
    Step 27 — Cohort Retention Analysis

===============================================================================
*/

DROP VIEW IF EXISTS cohort_base;
CREATE VIEW cohort_base AS

WITH cohort_assignment AS (

    /*
    -----------------------------------------------------------------------
    Step 1: Assign every account to a cohort
    -----------------------------------------------------------------------
    One row per account.
    Brings in all identity and segmentation columns from accounts table.

    cohort_month = first day of the month the account signed up.
    -----------------------------------------------------------------------
    */

    SELECT
        DATE_TRUNC('month', a.signup_date)::DATE    AS cohort_month,
        a.account_id,
        a.signup_date,

        -- Segmentation dimensions
        a.plan_tier,
        a.industry,
        a.country,
        a.referral_source,
        a.seats,
        a.is_trial

    FROM accounts a
),

churn_summary AS (

    /*
    -----------------------------------------------------------------------
    Step 2: Aggregate churn behavior per account
    -----------------------------------------------------------------------
    LEFT JOIN ensures accounts with zero churn events are included.
    They receive: ever_churned = FALSE, churn_count = 0, NULL dates.

    Multi-churn accounts:
        first_churn_date = MIN → survival endpoint
        last_churn_date  = MAX → most recent churn
        churn_count      = COUNT → instability indicator
    -----------------------------------------------------------------------
    */

    SELECT
        account_id,
        COUNT(churn_event_id)               AS churn_count,
        MIN(churn_date)                     AS first_churn_date,
        MAX(churn_date)                     AS last_churn_date
    FROM churn_events
    GROUP BY account_id
),

reactivation_check AS (

    /*
    -----------------------------------------------------------------------
    Step 3: Identify accounts that reactivated after first churn
    -----------------------------------------------------------------------
    An account is reactivated if:
        - They have a churn event (joined via churn_summary)
        - AND they have a paid subscription starting AFTER first_churn_date

    Uses is_trial = FALSE to confirm genuine paid reactivation.
    Trial restarts after churn are NOT counted as reactivation.

    This is a separate CTE because the logic requires joining
    subscriptions to churn_summary — cleaner than embedding inline.
    -----------------------------------------------------------------------
    */

    SELECT DISTINCT
        cs.account_id
    FROM churn_summary cs
    JOIN subscriptions s
        ON  s.account_id  = cs.account_id
        AND s.start_date  > cs.first_churn_date
        AND s.is_trial    = FALSE
),

    /*
    -----------------------------------------------------------------------
    Step 4: Determine if account is currently active
    -----------------------------------------------------------------------
    Checks base_active_monthly for the last month of the dataset.

    Dataset ends 2024-12-31 → check December 2024.

    NOT CURRENT_DATE — dataset is historical.
    CURRENT_DATE would return zero active accounts.
    -----------------------------------------------------------------------
    */

current_status AS (
    SELECT DISTINCT account_id
    FROM subscriptions
    WHERE start_date <= '2024-12-31'::DATE
      AND (
            end_date IS NULL
            OR end_date >= '2024-12-31'::DATE
          )
),

final AS (

    /*
    -----------------------------------------------------------------------
    Step 5: Assemble final cohort base table
    -----------------------------------------------------------------------
    LEFT JOIN all behavioral CTEs onto cohort_assignment.

    COALESCE handles accounts with no churn events:
        ever_churned        → FALSE
        churn_count         → 0
        ever_reactivated    → FALSE
        is_currently_active → FALSE

    months_to_first_churn:
        Calculated as whole months between signup_date and first_churn_date.
        NULL for accounts that never churned.
        Must always be >= 0 (validated below).
    -----------------------------------------------------------------------
    */

    SELECT
        -- ─────────────────────────────────────────
        -- Group 1: Identity & Cohort Assignment
        -- ─────────────────────────────────────────
        ca.cohort_month,
        ca.account_id,
        ca.signup_date,

        -- ─────────────────────────────────────────
        -- Group 2: Segmentation Dimensions
        -- ─────────────────────────────────────────
        ca.plan_tier,
        ca.industry,
        ca.country,
        ca.referral_source,
        ca.seats,
        ca.is_trial,

        -- ─────────────────────────────────────────
        -- Group 3: Churn Behavior
        -- ─────────────────────────────────────────
        CASE
            WHEN cs.churn_count IS NULL THEN FALSE
            ELSE TRUE
        END                                             AS ever_churned,

        CASE
            WHEN rc.account_id IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                             AS ever_reactivated,

        COALESCE(cs.churn_count, 0)                     AS churn_count,

        cs.first_churn_date,
        cs.last_churn_date,

        CASE
    WHEN cs.first_churn_date IS NULL THEN NULL
    ELSE
        (
            EXTRACT(YEAR  FROM cs.first_churn_date)::INTEGER * 12
            + EXTRACT(MONTH FROM cs.first_churn_date)::INTEGER
        )
        -
        (
            EXTRACT(YEAR  FROM ca.signup_date)::INTEGER * 12
            + EXTRACT(MONTH FROM ca.signup_date)::INTEGER
        )
END AS months_to_first_churn,

        -- ─────────────────────────────────────────
        -- Group 4: Current Status
        -- ─────────────────────────────────────────
        CASE
            WHEN cur.account_id IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                             AS is_currently_active

    FROM cohort_assignment ca
    LEFT JOIN churn_summary cs
        ON ca.account_id = cs.account_id
    LEFT JOIN reactivation_check rc
        ON ca.account_id = rc.account_id
    LEFT JOIN current_status cur
        ON ca.account_id = cur.account_id
)

SELECT *
FROM final
ORDER BY cohort_month, account_id;

select * from cohort_base;

-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- V1: Total rows and distinct accounts (both must = 500)
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT account_id)      AS distinct_accounts,
    COUNT(DISTINCT cohort_month)    AS distinct_cohorts,
    MIN(cohort_month)               AS first_cohort,
    MAX(cohort_month)               AS last_cohort
FROM cohort_base;


-- V2: Churn flag reconciliation
-- ever_churned = TRUE must match distinct accounts in churn_events (352)
SELECT
    ever_churned,
    COUNT(*)                        AS account_count
FROM cohort_base
GROUP BY ever_churned
ORDER BY ever_churned;


-- V3: Reactivation consistency check
-- ever_reactivated = TRUE must only exist when ever_churned = TRUE
-- Should return 0 rows
SELECT *
FROM cohort_base
WHERE ever_reactivated = TRUE
  AND ever_churned     = FALSE;


-- V4: months_to_first_churn must always be >= 0
-- Negative values = data integrity issue
-- Should return 0 rows
SELECT *
FROM cohort_base
WHERE months_to_first_churn < 0;


-- V5: churn_count must be 0 when ever_churned = FALSE
-- Should return 0 rows
SELECT *
FROM cohort_base
WHERE ever_churned = FALSE
  AND churn_count  > 0;


-- V6: Cohort size distribution
-- Should match base_active_monthly cohort query
SELECT
    cohort_month,
    COUNT(*)                        AS cohort_size
FROM cohort_base
GROUP BY cohort_month
ORDER BY cohort_month;


-- V7: Churn behavior distribution
SELECT
    ever_churned,
    ever_reactivated,
    COUNT(*)                        AS accounts,
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        1
    )                               AS pct_of_total
FROM cohort_base
GROUP BY ever_churned, ever_reactivated
ORDER BY ever_churned, ever_reactivated;


-- V8: churn_count distribution
SELECT
    churn_count,
    COUNT(*)                        AS accounts
FROM cohort_base
GROUP BY churn_count
ORDER BY churn_count;


-- V9: months_to_first_churn distribution
-- Shows how quickly accounts churn after signup
SELECT
    months_to_first_churn,
    COUNT(*)                        AS accounts
FROM cohort_base
WHERE months_to_first_churn IS NOT NULL
GROUP BY months_to_first_churn
ORDER BY months_to_first_churn;


-- V10: Segmentation distribution
-- Plan tier breakdown per cohort
SELECT
    cohort_month,
    plan_tier,
    COUNT(*)                        AS accounts
FROM cohort_base
GROUP BY cohort_month, plan_tier
ORDER BY cohort_month, plan_tier;


-- V11: Current active status reconciliation
-- is_currently_active = TRUE count should match
-- COUNT(DISTINCT account_id) from base_active_monthly WHERE month = '2024-12-01'
SELECT
    is_currently_active,
    COUNT(*)                        AS accounts
FROM cohort_base
GROUP BY is_currently_active;


-- V12: Referral source distribution
SELECT
    referral_source,
    COUNT(*)                        AS accounts,
    ROUND(
        AVG(CASE WHEN ever_churned THEN 1.0 ELSE 0.0 END) * 100,
        1
    )                               AS churn_rate_pct
FROM cohort_base
GROUP BY referral_source
ORDER BY accounts DESC;

-- V13: Validate months_to_first_churn alignment with calendar months
-- signup in Jan, churn in Feb should = 1 (not 0)
SELECT
    account_id,
    signup_date,
    first_churn_date,
    months_to_first_churn,
    EXTRACT(MONTH FROM first_churn_date) - EXTRACT(MONTH FROM signup_date)
        AS naive_month_diff
FROM cohort_base
WHERE first_churn_date IS NOT NULL
  AND EXTRACT(YEAR FROM first_churn_date) = EXTRACT(YEAR FROM signup_date)
ORDER BY signup_date
LIMIT 20;