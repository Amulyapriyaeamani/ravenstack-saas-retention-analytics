/*
================================================================================
FILE: 03_base_mrr_monthly.sql
PURPOSE:
    Creates a monthly revenue base (MRR) for all active paid subscriptions.
DEFINITION:
    MRR = sum of mrr_amount from all ACTIVE PAID subscriptions in a given month
LOGIC:
    - Generate a month spine from earliest to latest subscription start_date
    - Filter:
        • is_trial = FALSE (exclude trial users)
        • mrr_amount > 0 (defensive check; validated in Step 10)
    - Apply active subscription logic:
        start_date <= month_end
        AND (end_date IS NULL OR end_date >= month_start)
    - Aggregate MRR first at account level (prevents double counting)
    - Then aggregate to monthly level
OUTPUT:
    month                → month start date (time dimension)
    paid_active_accounts → distinct paying customers that month
    total_mrr            → total monthly recurring revenue
    arpu                 → average revenue per account
    mrr_basic            → MRR from Basic plan accounts
    mrr_pro              → MRR from Pro plan accounts
    mrr_enterprise       → MRR from Enterprise plan accounts
IMPORTANT NOTES:
    - MRR is aggregated at ACCOUNT level first, then summed
      Reason: prevents double counting for accounts with
      multiple active paid subscriptions in same month
    - COUNT(DISTINCT account_id) counts each account once
      SUM(account_mrr) sums full revenue including multi-sub accounts
      This is intentional — both are correct for their purpose
    - Trial users excluded completely (is_trial = FALSE)
    - mrr_amount > 0 is a defensive filter (zero MRR = trial,
      already validated in Step 10)
    - plan_tier added for plan-wise revenue analysis (Step 17)
    - NULL end_date = still active
    - mrr_amount is monthly normalized (even for annual billing)
THIS TABLE IS USED FOR:
    • MRR trend analysis
    • ARPU calculation and trends
    • Plan-wise revenue breakdown (Steps 17)
    • Revenue Churn Rate denominator
    • Business growth analysis
    • Upgrade/downgrade revenue impact
USAGE:
    - Overall MRR:        SELECT month, total_mrr FROM base_mrr_monthly
    - ARPU trend:         SELECT month, arpu FROM base_mrr_monthly
    - Plan MRR:           SELECT month, mrr_basic, mrr_pro, mrr_enterprise
    - Revenue growth:     Self-join on month and month - 1 month
================================================================================
*/

DROP VIEW IF EXISTS base_mrr_monthly;
CREATE VIEW base_mrr_monthly AS

WITH month_spine AS (
    /*
    --------------------------------------------------------
    Step 1: Generate complete month spine
    --------------------------------------------------------
    Covers full dataset range from first to last
    subscription start_date.
    --------------------------------------------------------
    */
    SELECT generate_series(
        DATE_TRUNC('month', (SELECT MIN(start_date) FROM subscriptions)),
        DATE_TRUNC('month', (SELECT MAX(start_date) FROM subscriptions)),
        INTERVAL '1 month'
    ) AS month_start
),

active_paid_subscriptions AS (
    /*
    --------------------------------------------------------
    Step 2: Identify all active paid subscriptions per month
    --------------------------------------------------------
    Conditions:
    - is_trial = FALSE (paid only)
    - mrr_amount > 0 (defensive filter)
    - subscription active during month M:
        start_date <= last day of M
        AND (end_date IS NULL OR end_date >= first day of M)
    --------------------------------------------------------
    */
    SELECT
        m.month_start,
        s.account_id,
        s.subscription_id,
        s.mrr_amount,
        s.plan_tier
    FROM month_spine m
    JOIN subscriptions s
        ON s.start_date <= (m.month_start + INTERVAL '1 month' - INTERVAL '1 day')
       AND (s.end_date IS NULL OR s.end_date >= m.month_start)
    WHERE s.is_trial = FALSE
      AND s.mrr_amount > 0
),

account_level_mrr AS (
    /*
    --------------------------------------------------------
    Step 3: Aggregate MRR at account level first
    --------------------------------------------------------
    CRITICAL STEP — prevents double counting.

    An account with multiple active paid subscriptions
    in the same month must be counted ONCE as an account
    but contribute FULL revenue to MRR.

    plan_tier is kept here using the highest value plan
    when an account has multiple subscriptions.
    Priority: Enterprise > Pro > Basic

    This ensures one row per account per month
    for clean downstream aggregation.
    --------------------------------------------------------
    */
    SELECT
    month_start,
    account_id,
    SUM(mrr_amount) AS account_mrr,

    CASE
        WHEN BOOL_OR(plan_tier = 'Enterprise') THEN 'Enterprise'
        WHEN BOOL_OR(plan_tier = 'Pro') THEN 'Pro'
        ELSE 'Basic'
    END AS plan_tier

FROM active_paid_subscriptions
GROUP BY month_start, account_id
        -- MAX on plan_tier: Enterprise > Pro > Basic alphabetically
        -- Not perfect but acceptable for dataset structure
        -- In production: use explicit CASE WHEN priority ranking
    
),

mrr_aggregated AS (
    /*
    --------------------------------------------------------
    Step 4: Aggregate to monthly level
    --------------------------------------------------------
    Produces final monthly metrics including:
    - Total MRR
    - Paid active accounts
    - ARPU
    - Plan-wise MRR breakdown
    --------------------------------------------------------
    */
    SELECT
        month_start                                                     AS month,
        COUNT(DISTINCT account_id)                                      AS paid_active_accounts,
        SUM(account_mrr)                                                AS total_mrr,
        ROUND(
            SUM(account_mrr) / NULLIF(COUNT(DISTINCT account_id), 0),
            2
        )                                                               AS arpu,
        COALESCE(ROUND(SUM(account_mrr) FILTER (WHERE plan_tier = 'Basic'), 2), 0)  AS mrr_basic,
COALESCE(ROUND(SUM(account_mrr) FILTER (WHERE plan_tier = 'Pro'), 2), 0)    AS mrr_pro,
COALESCE(ROUND(SUM(account_mrr) FILTER (WHERE plan_tier = 'Enterprise'), 2), 0) AS mrr_enterprise
    FROM account_level_mrr
    GROUP BY month_start
)
-- Plan-wise MRR is allocated using the account's
-- highest active plan tier for the month.
--
-- Example:
-- If an account has both Basic and Pro subscriptions,
-- all account revenue is attributed to Pro.
--
-- This creates mutually exclusive customer segments
-- and prevents revenue double counting across plans.
SELECT *
FROM mrr_aggregated
ORDER BY month;


-- =====================================================================
-- VALIDATION QUERIES
-- =====================================================================

-- Full table preview
SELECT * FROM base_mrr_monthly;

-- Sanity check: total MRR range
SELECT
    MIN(total_mrr)          AS min_mrr,
    MAX(total_mrr)          AS max_mrr,
    MIN(arpu)               AS min_arpu,
    MAX(arpu)               AS max_arpu,
    MIN(paid_active_accounts) AS min_accounts,
    MAX(paid_active_accounts) AS max_accounts
FROM base_mrr_monthly;

-- Plan-wise MRR distribution
SELECT
    month,
    total_mrr,
    mrr_basic,
    mrr_pro,
    mrr_enterprise,
    ROUND(mrr_basic      / NULLIF(total_mrr, 0) * 100, 1) AS pct_basic,
    ROUND(mrr_pro        / NULLIF(total_mrr, 0) * 100, 1) AS pct_pro,
    ROUND(mrr_enterprise / NULLIF(total_mrr, 0) * 100, 1) AS pct_enterprise
FROM base_mrr_monthly
ORDER BY month;

-- MRR growth month over month
SELECT
    curr.month,
    curr.total_mrr,
    prev.total_mrr                                      AS prev_mrr,
    ROUND(curr.total_mrr - prev.total_mrr, 2)           AS mrr_change,
    ROUND(
        (curr.total_mrr - prev.total_mrr)
        / NULLIF(prev.total_mrr, 0) * 100,
        1
    )                                                   AS mrr_growth_pct
FROM base_mrr_monthly curr
LEFT JOIN base_mrr_monthly prev
    ON prev.month = curr.month - INTERVAL '1 month'
ORDER BY curr.month;