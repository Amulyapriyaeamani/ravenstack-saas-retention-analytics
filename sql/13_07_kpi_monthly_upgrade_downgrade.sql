/*
===============================================================================
FILE: 13_07_kpi_monthly_upgrade_downgrade.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Tracks monthly upgrade and downgrade behavior for paid accounts.

This KPI measures:
    - % of paid active accounts that upgraded in a month
    - % of paid active accounts that downgraded in a month

Used for:
    - Plan migration analysis
    - Revenue expansion/contraction analysis
    - Customer lifecycle analysis
    - Churn risk analysis
    - Product-market fit analysis

BUSINESS DEFINITIONS
------------------------------------------------------------------------------
Upgrade Rate:
    % of paid active accounts that initiated an upgraded subscription
    during month M.

Downgrade Rate:
    % of paid active accounts that initiated a downgraded subscription
    during month M.

FORMULAS
------------------------------------------------------------------------------
Upgrade Rate % =
    upgraded_accounts / paid_active_accounts * 100

Downgrade Rate % =
    downgraded_accounts / paid_active_accounts * 100

NUMERATOR LOGIC
------------------------------------------------------------------------------
Upgrade numerator:
    COUNT(DISTINCT account_id)
    WHERE:
        upgrade_flag = TRUE
        AND start_date falls in month M
        AND is_trial = FALSE

Downgrade numerator:
    COUNT(DISTINCT account_id)
    WHERE:
        downgrade_flag = TRUE
        AND start_date falls in month M
        AND is_trial = FALSE

DENOMINATOR LOGIC
------------------------------------------------------------------------------
Paid active accounts during month M:
    Accounts with at least one active PAID subscription
    overlapping month M.

Logic:
    start_date <= month_end
    AND (
        end_date IS NULL
        OR end_date >= month_start
    )

IMPORTANT NOTE
------------------------------------------------------------------------------
Upgrade/downgrade rates measure NEW plan changes occurring
during each month — NOT the stock of upgraded accounts.

Example:
    An account upgrades in January and remains on that plan
    through June.

    → Appears in numerator ONLY in January
    → Still appears in denominator Jan–Jun

This is intentional and reflects event-based upgrade behavior.

DEDUPLICATION
------------------------------------------------------------------------------
Accounts may have multiple upgrade/downgrade subscriptions
starting in the same month.

COUNT(DISTINCT account_id) ensures:
    One account counted ONCE per month.

OUTPUT
------------------------------------------------------------------------------
month
paid_active_accounts
upgraded_accounts
downgraded_accounts
monthly_upgrade_rate_pct
monthly_downgrade_rate_pct

DEPENDENCIES
------------------------------------------------------------------------------
Raw tables:
    subscriptions

Base views:
    base_active_monthly

===============================================================================
*/

DROP VIEW IF EXISTS kpi_monthly_upgrade_downgrade;

CREATE VIEW kpi_monthly_upgrade_downgrade AS

WITH paid_active_accounts AS (
    /*
    ------------------------------------------------------------------------
    Step 1: Paid active denominator
    ------------------------------------------------------------------------
    Paid accounts active anytime during month M.
    Uses base_active_monthly for consistency.
    ------------------------------------------------------------------------
    */
    SELECT
        month,
        COUNT(DISTINCT account_id) AS paid_active_accounts
    FROM base_active_monthly
    WHERE account_type IN ('paid', 'mixed')
    GROUP BY month
),

monthly_upgrade_accounts AS (
    /*
    ------------------------------------------------------------------------
    Step 2: Monthly upgraded accounts
    ------------------------------------------------------------------------
    Accounts with upgrade_flag = TRUE
    where subscription started in month M.
    ------------------------------------------------------------------------
    */
    SELECT
        DATE_TRUNC('month', start_date) AS month,
        COUNT(DISTINCT account_id)      AS upgraded_accounts
    FROM subscriptions
    WHERE upgrade_flag = TRUE
      AND is_trial = FALSE
    GROUP BY DATE_TRUNC('month', start_date)
),

monthly_downgrade_accounts AS (
    /*
    ------------------------------------------------------------------------
    Step 3: Monthly downgraded accounts
    ------------------------------------------------------------------------
    Accounts with downgrade_flag = TRUE
    where subscription started in month M.
    ------------------------------------------------------------------------
    */
    SELECT
        DATE_TRUNC('month', start_date) AS month,
        COUNT(DISTINCT account_id)      AS downgraded_accounts
    FROM subscriptions
    WHERE downgrade_flag = TRUE
      AND is_trial = FALSE
    GROUP BY DATE_TRUNC('month', start_date)
)

SELECT
    p.month,
    p.paid_active_accounts,

    COALESCE(u.upgraded_accounts, 0)
        AS upgraded_accounts,

    COALESCE(d.downgraded_accounts, 0)
        AS downgraded_accounts,

    ROUND(
        COALESCE(u.upgraded_accounts, 0)::NUMERIC
        / NULLIF(p.paid_active_accounts, 0)
        * 100,
        2
    ) AS monthly_upgrade_rate_pct,

    ROUND(
        COALESCE(d.downgraded_accounts, 0)::NUMERIC
        / NULLIF(p.paid_active_accounts, 0)
        * 100,
        2
    ) AS monthly_downgrade_rate_pct

FROM paid_active_accounts p

LEFT JOIN monthly_upgrade_accounts u
    ON p.month = u.month

LEFT JOIN monthly_downgrade_accounts d
    ON p.month = d.month

ORDER BY p.month;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Full table preview
SELECT *
FROM kpi_monthly_upgrade_downgrade;


-- Monthly trend check
SELECT
    month,
    paid_active_accounts,
    upgraded_accounts,
    downgraded_accounts,
    monthly_upgrade_rate_pct,
    monthly_downgrade_rate_pct
FROM kpi_monthly_upgrade_downgrade
ORDER BY month;


-- Highest upgrade months
SELECT
    month,
    upgraded_accounts,
    monthly_upgrade_rate_pct
FROM kpi_monthly_upgrade_downgrade
ORDER BY monthly_upgrade_rate_pct DESC
LIMIT 5;


-- Highest downgrade months
SELECT
    month,
    downgraded_accounts,
    monthly_downgrade_rate_pct
FROM kpi_monthly_upgrade_downgrade
ORDER BY monthly_downgrade_rate_pct DESC
LIMIT 5;


-- Sanity check:
-- upgrade/downgrade counts should never exceed denominator
SELECT
    month,
    paid_active_accounts,
    upgraded_accounts,
    downgraded_accounts
FROM kpi_monthly_upgrade_downgrade
WHERE upgraded_accounts > paid_active_accounts
   OR downgraded_accounts > paid_active_accounts;


-- Average monthly rates
SELECT
    ROUND(AVG(monthly_upgrade_rate_pct), 2)
        AS avg_upgrade_rate_pct,

    ROUND(AVG(monthly_downgrade_rate_pct), 2)
        AS avg_downgrade_rate_pct
FROM kpi_monthly_upgrade_downgrade;


-- MRR associated with upgrade/downgrade accounts
-- Provides revenue context for account movement
SELECT
    DATE_TRUNC('month', s.start_date) AS month,

    SUM(s.mrr_amount)
        FILTER (WHERE s.upgrade_flag = TRUE)
        AS upgrade_mrr,

    SUM(s.mrr_amount)
        FILTER (WHERE s.downgrade_flag = TRUE)
        AS downgrade_mrr

FROM subscriptions s
WHERE s.is_trial = FALSE
GROUP BY DATE_TRUNC('month', s.start_date)
ORDER BY month;