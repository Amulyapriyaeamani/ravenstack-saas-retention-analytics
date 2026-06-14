/*
===============================================================================
FILE: 13_04_kpi_monthly_active_users.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Creates the Monthly Active Users (MAU) KPI table.

DEFINITION
------------------------------------------------------------------------------
An ACTIVE USER is defined as:

    An account that:
    1. Had at least one active subscription during the month
    2. Had at least one feature usage event during the same month

This measures PRODUCT ENGAGEMENT, not just subscription activity.

BUSINESS LOGIC
------------------------------------------------------------------------------
- base_active_monthly provides the active subscription population
- base_feature_usage_monthly provides actual product usage activity
- Users are counted ONCE per month
- Multiple feature usage rows within a month are deduplicated

FORMULA
------------------------------------------------------------------------------
Monthly Active Users =
COUNT(DISTINCT account_id)
with:
    active subscription during month
    AND
    at least one feature usage event during month

DEPENDS ON
------------------------------------------------------------------------------
- base_active_monthly
- base_feature_usage_monthly

OUTPUT
------------------------------------------------------------------------------
month                   → reporting month
monthly_active_users    → engaged active accounts
total_active_accounts   → all active accounts
engagement_rate_pct     → % of active accounts that used product

IMPORTANT NOTES
------------------------------------------------------------------------------
- This KPI is DIFFERENT from active subscriptions
- An account can be active but not engaged
- Engagement Rate helps identify dormant customers
- COUNT(DISTINCT account_id) prevents double counting
  from multiple feature usage records

===============================================================================
*/

DROP VIEW IF EXISTS kpi_monthly_active_users;

CREATE VIEW kpi_monthly_active_users AS

WITH active_accounts AS (
    /*
    --------------------------------------------------------------------------
    Step 1: Monthly active account population
    --------------------------------------------------------------------------
    One row per:
        month + account_id
    */
    SELECT DISTINCT
        month,
        account_id
    FROM base_active_monthly
),

engaged_accounts AS (
    /*
    --------------------------------------------------------------------------
    Step 2: Accounts with at least one feature usage event
    --------------------------------------------------------------------------
    base_feature_usage_monthly already guarantees:
    - valid active subscription overlap
    - monthly aggregation

    DISTINCT ensures:
    one account counted once per month.
    --------------------------------------------------------------------------
    */
    SELECT DISTINCT
        month,
        account_id
    FROM base_feature_usage_monthly
),

monthly_active_users AS (
    /*
    --------------------------------------------------------------------------
    Step 3: Combine active accounts + engaged accounts
    --------------------------------------------------------------------------
    INNER JOIN ensures:
    account must satisfy BOTH conditions.
    --------------------------------------------------------------------------
    */
    SELECT
        a.month,
        COUNT(DISTINCT e.account_id)     AS monthly_active_users,
        COUNT(DISTINCT a.account_id)     AS total_active_accounts
    FROM active_accounts a
    LEFT JOIN engaged_accounts e
        ON a.month = e.month
       AND a.account_id = e.account_id
    GROUP BY a.month
)

SELECT
    month,
    monthly_active_users,
    total_active_accounts,
    ROUND(
        monthly_active_users::NUMERIC
        / NULLIF(total_active_accounts, 0)
        * 100,
        2
    ) AS engagement_rate_pct
FROM monthly_active_users
ORDER BY month;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Full KPI preview
SELECT *
FROM kpi_monthly_active_users;


-- Validation 1: MAU should never exceed active accounts
SELECT *
FROM kpi_monthly_active_users
WHERE monthly_active_users > total_active_accounts;


-- Validation 2: Engagement rate bounds check
SELECT
    MIN(engagement_rate_pct) AS min_engagement_rate,
    MAX(engagement_rate_pct) AS max_engagement_rate
FROM kpi_monthly_active_users;


-- Validation 3: Monthly trend
SELECT
    month,
    monthly_active_users,
    total_active_accounts,
    engagement_rate_pct
FROM kpi_monthly_active_users
ORDER BY month;


-- Validation 4: MoM MAU growth
SELECT
    curr.month,
    curr.monthly_active_users,
    prev.monthly_active_users                     AS prev_month_mau,
    curr.monthly_active_users
        - prev.monthly_active_users               AS mau_change,
    ROUND(
        (
            curr.monthly_active_users
            - prev.monthly_active_users
        )::NUMERIC
        / NULLIF(prev.monthly_active_users, 0)
        * 100,
        2
    )                                             AS mau_growth_pct
FROM kpi_monthly_active_users curr
LEFT JOIN kpi_monthly_active_users prev
    ON curr.month = prev.month + INTERVAL '1 month'
ORDER BY curr.month;