-- ============================================================
-- FILE: 15_kpi_validation.sql
-- PURPOSE: Cross-validation of all analytical layers
-- Confirms base layer, KPI layer, and cohort layer
-- are internally consistent as a system.
-- ============================================================


-- ============================================================
-- CHECK 1: Churn Numbers Reconcile
-- All three sources must report 352 distinct churned accounts
-- ============================================================

SELECT
    'churn_events (raw)'            AS source,
    COUNT(DISTINCT account_id)      AS distinct_churned_accounts
FROM churn_events

UNION ALL

SELECT
    'base_churn_monthly'            AS source,
    COUNT(DISTINCT account_id)      AS distinct_churned_accounts
FROM base_churn_monthly

UNION ALL

SELECT
    'cohort_base'                   AS source,
    COUNT(*)                        AS distinct_churned_accounts
FROM cohort_base
WHERE ever_churned = TRUE;


-- ============================================================
-- CHECK 2: MRR Reconciles Across Layers
-- base_mrr_monthly and kpi_monthly_mrr_growth must match
-- Should return 0 rows
-- ============================================================

SELECT
    b.month,
    b.total_mrr                     AS base_mrr,
    k.total_mrr                     AS kpi_mrr,
    ROUND(b.total_mrr
        - k.total_mrr, 2)           AS difference
FROM base_mrr_monthly b
JOIN kpi_monthly_mrr_growth k
    ON b.month = k.month
WHERE ROUND(b.total_mrr - k.total_mrr, 2) != 0;


-- ============================================================
-- CHECK 3: Active Account Definitions Documented
-- base_active_monthly (anytime) vs kpi_monthly_churn_rate
-- (start-of-month) — different by design, document the gap
-- ============================================================

SELECT
    bam.month,
    COUNT(DISTINCT bam.account_id)          AS base_active_anytime,
    cr.start_month_active_accounts          AS kpi_start_of_month,
    COUNT(DISTINCT bam.account_id)
        - cr.start_month_active_accounts    AS difference
FROM base_active_monthly bam
JOIN kpi_monthly_churn_rate cr
    ON bam.month = cr.month
GROUP BY
    bam.month,
    cr.start_month_active_accounts
ORDER BY bam.month;


-- ============================================================
-- CHECK 4: Cohort Sizes Reconcile With accounts Table
-- Should return 0 rows
-- ============================================================

SELECT
    cb.cohort_month,
    COUNT(cb.account_id)            AS cohort_base_size,
    ac.account_count                AS accounts_table_count,
    COUNT(cb.account_id)
        - ac.account_count          AS difference
FROM cohort_base cb
JOIN (
    SELECT
        DATE_TRUNC('month', signup_date)::DATE  AS cohort_month,
        COUNT(*)                                AS account_count
    FROM accounts
    GROUP BY DATE_TRUNC('month', signup_date)
) ac ON cb.cohort_month = ac.cohort_month
GROUP BY
    cb.cohort_month,
    ac.account_count
HAVING COUNT(cb.account_id) != ac.account_count;


-- ============================================================
-- CHECK 5: Feature Usage Reconciles With Raw Table
-- Difference expected due to active subscription filter
-- Document and explain the gap
-- ============================================================

SELECT
    SUM(f.total_usage_count)                AS base_layer_total,
    (SELECT SUM(usage_count)
     FROM feature_usage)                    AS raw_table_total,
    SUM(f.total_usage_count)
        - (SELECT SUM(usage_count)
           FROM feature_usage)              AS difference,
    ROUND(
        SUM(f.total_usage_count)::NUMERIC
        / NULLIF(
            (SELECT SUM(usage_count) FROM feature_usage),
            0
        ) * 100,
        2
    )                                       AS base_as_pct_of_raw
FROM base_feature_usage_monthly f;

-- Step 1: How many raw rows pass the active subscription filter?
SELECT COUNT(*) AS rows_with_active_sub
FROM feature_usage f
JOIN subscriptions s ON f.subscription_id = s.subscription_id
WHERE s.start_date <= (
    DATE_TRUNC('month', f.usage_date)
    + INTERVAL '1 month' - INTERVAL '1 day'
)
AND (
    s.end_date IS NULL
    OR s.end_date >= DATE_TRUNC('month', f.usage_date)
);

-- Step 2: What is SUM(usage_count) for those rows?
SELECT SUM(f.usage_count) AS filtered_usage_count
FROM feature_usage f
JOIN subscriptions s ON f.subscription_id = s.subscription_id
WHERE s.start_date <= (
    DATE_TRUNC('month', f.usage_date)
    + INTERVAL '1 month' - INTERVAL '1 day'
)
AND (
    s.end_date IS NULL
    OR s.end_date >= DATE_TRUNC('month', f.usage_date)
);

-- ============================================================
-- CHECK 6: Retention + Churn = 100% System Wide
-- Cross-validates kpi_monthly_churn_rate and
-- kpi_monthly_retention_rate as a system
-- Should return 0 rows
-- ============================================================

SELECT
    month,
    monthly_churn_rate_pct,
    monthly_retention_rate_pct,
    ROUND(
        monthly_churn_rate_pct
        + monthly_retention_rate_pct,
        2
    )                                       AS total_pct
FROM kpi_monthly_retention_rate
WHERE ROUND(
    monthly_churn_rate_pct
    + monthly_retention_rate_pct,
    2
) != 100.00;


-- ============================================================
-- CHECK 7: Cohort Retention Matrix Month 0 = 100%
-- System-level confirmation after fix
-- Should return 0 rows
-- ============================================================

SELECT *
FROM cohort_retention_matrix
WHERE months_since_signup = 0
  AND retention_rate_pct != 100.00;


-- ============================================================
-- CHECK 8: Survival Curve Monotonic System Check
-- Should return 0 rows
-- ============================================================

SELECT
    curr.cohort_month,
    curr.months_since_signup,
    curr.survival_rate_pct          AS curr_survival,
    prev.survival_rate_pct          AS prev_survival
FROM cohort_survival_curve curr
JOIN cohort_survival_curve prev
    ON  curr.cohort_month        = prev.cohort_month
    AND curr.months_since_signup = prev.months_since_signup + 1
WHERE curr.survival_rate_pct > prev.survival_rate_pct;


-- ============================================================
-- CHECK 9: Total Accounts Consistent Across All Layers
-- Every layer must account for all 500 accounts
-- ============================================================

SELECT
    'accounts (raw)'                AS source,
    COUNT(*)                        AS total_accounts
FROM accounts

UNION ALL

SELECT
    'cohort_base'                   AS source,
    COUNT(*)                        AS total_accounts
FROM cohort_base

UNION ALL

SELECT
    'base_active_monthly (distinct)'  AS source,
    COUNT(DISTINCT account_id)        AS total_accounts
FROM base_active_monthly

UNION ALL

SELECT
    'base_mrr_monthly max month'    AS source,
    paid_active_accounts            AS total_accounts
FROM base_mrr_monthly
WHERE month = (SELECT MAX(month) FROM base_mrr_monthly);


-- ============================================================
-- CHECK 10: Revenue Churn Denominator Consistency
-- kpi_monthly_revenue_churn_rate start_month_mrr
-- must be <= base_mrr_monthly total_mrr for same month
-- (start-of-month MRR <= active-anytime MRR)
-- Should return 0 rows where start > active-anytime
-- ============================================================

SELECT
    r.month,
    r.start_month_mrr,
    b.total_mrr                     AS active_anytime_mrr,
    ROUND(r.start_month_mrr
        - b.total_mrr, 2)           AS difference
FROM kpi_monthly_revenue_churn_rate r
JOIN base_mrr_monthly b
    ON r.month = b.month
WHERE r.start_month_mrr > b.total_mrr;