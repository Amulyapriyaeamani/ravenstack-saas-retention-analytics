/*
===========================================================
FILE: 05_base_feature_usage_monthly.sql
===========================================================
PURPOSE:
Creates a reusable monthly feature usage base table.

Each row represents:
1 account using 1 feature in 1 month.

USED FOR:
    - Feature Adoption Rate
    - Active Users
    - Usage vs Churn Analysis
    - Beta Feature Impact Analysis
    - Multi-Factor Churn Model
    - Lifecycle Journey Analysis
    - Feature Engagement Analysis
    - Error vs Churn Analysis

BUSINESS LOGIC:
    - Feature usage is tied to subscriptions
    - Subscription must be active during the same month
      as the usage event
    - Exact day-level overlap is NOT enforced
      (monthly approximation chosen intentionally)

MONTHLY APPROXIMATION DECISION:
    Usage and subscription activity are aligned at the
    monthly level rather than exact timestamp overlap.

    Reason:
    - Project focuses on monthly SaaS KPIs
    - Dataset granularity does not require event-level
      precision
    - Simplifies reusable analytics architecture
    - Keeps logic consistent across all engagement KPIs

GRAIN:
    One row per:
    month + account_id + feature_name + is_beta_feature

    IMPORTANT:
    A feature may appear as both beta and non-beta
    across different months if rollout status changed over time.

    Therefore:
    feature_name + is_beta_feature is treated as the
    analytical feature state grain.

    This is intentional — it enables:
        - Beta vs GA transition analysis
        - Feature adoption curve tracking
        - Beta impact comparison (Step 28)

OUTPUT COLUMNS:
    month                       → month of usage
    account_id                  → account dimension
    feature_name                → feature dimension
    is_beta_feature             → beta flag
    total_usage_events          → COUNT(*) of raw rows
    total_usage_count           → SUM(usage_count) from source
    total_usage_duration_secs   → total time spent
    avg_usage_duration_secs     → avg time per session
    total_errors                → total errors encountered

DIFFERENCE: total_usage_events vs total_usage_count
    total_usage_events:
        COUNT(*) of rows in feature_usage table
        = number of usage records in that month
    total_usage_count:
        SUM(usage_count) from source column
        = actual event frequency as recorded in system
        USE THIS for usage intensity analysis (Step 23)
        USE total_usage_events for record-level aggregation

IMPORTANT:
    This is a reusable BASE TABLE, NOT a KPI table.
    Downstream KPIs should aggregate from this view.

===========================================================
*/

DROP VIEW IF EXISTS base_feature_usage_monthly;
CREATE VIEW base_feature_usage_monthly AS

WITH feature_activity AS (
    /*
    -------------------------------------------------------
    Step 1: Identify valid feature usage activity
    -------------------------------------------------------
    Conditions:
    - Usage event occurred in a given month
    - Subscription was active during that same month

    Join path:
    feature_usage → subscriptions → (account_id resolved)

    NOTE: feature_usage has no direct account_id.
    Must join through subscriptions to get account_id.
    Direct join to accounts is NOT possible from this table.
    -------------------------------------------------------
    */
    SELECT
        DATE_TRUNC('month', f.usage_date)   AS month,
        s.account_id,
        f.feature_name,
        f.is_beta_feature,
        f.usage_count,
        f.usage_duration_secs,
        f.error_count
    FROM feature_usage f
    JOIN subscriptions s
        ON f.subscription_id = s.subscription_id
    WHERE
        -- Subscription active before end of usage month
        s.start_date <= (
            DATE_TRUNC('month', f.usage_date)
            + INTERVAL '1 month'
            - INTERVAL '1 day'
        )
        AND (
            -- Subscription still active at start of usage month
            s.end_date IS NULL
            OR
            s.end_date >= DATE_TRUNC('month', f.usage_date)
        )
),

feature_aggregated AS (
    /*
    -------------------------------------------------------
    Step 2: Aggregate to monthly grain
    -------------------------------------------------------
    One row per:
    month + account_id + feature_name + is_beta_feature

    Two usage volume metrics kept intentionally:
        total_usage_events → row count (records)
        total_usage_count  → SUM(usage_count) from source
                             USE for intensity analysis
    -------------------------------------------------------
    */
    SELECT
        month,
        account_id,
        feature_name,
        is_beta_feature,
        COUNT(*)                        AS total_usage_events,
        SUM(usage_count)                AS total_usage_count,
        SUM(usage_duration_secs)        AS total_usage_duration_secs,
        ROUND(
            AVG(usage_duration_secs), 2
        )                               AS avg_usage_duration_secs,
        SUM(error_count)                AS total_errors
    FROM feature_activity
    GROUP BY
        month,
        account_id,
        feature_name,
        is_beta_feature
)

SELECT *
FROM feature_aggregated
ORDER BY
    month,
    account_id,
    feature_name;


-- =====================================================================
-- VALIDATION QUERIES
-- =====================================================================

-- Full table preview
SELECT * FROM base_feature_usage_monthly;

-- Overall sanity check
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT account_id)      AS distinct_accounts,
    COUNT(DISTINCT feature_name)    AS distinct_features,
    COUNT(DISTINCT month)           AS total_months,
    SUM(total_usage_events)         AS total_usage_events,
    SUM(total_usage_count)          AS total_usage_count,
    SUM(total_errors)               AS total_errors,
    MIN(month)                      AS first_month,
    MAX(month)                      AS last_month
FROM base_feature_usage_monthly;

-- Beta vs non-beta distribution
SELECT
    is_beta_feature,
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT account_id)      AS distinct_accounts,
    COUNT(DISTINCT feature_name)    AS distinct_features,
    SUM(total_usage_count)          AS total_usage_count,
    SUM(total_errors)               AS total_errors
FROM base_feature_usage_monthly
GROUP BY is_beta_feature
ORDER BY is_beta_feature;

-- Top 10 features by usage count
SELECT
    feature_name,
    is_beta_feature,
    SUM(total_usage_count)                  AS total_usage_count,
    SUM(total_usage_events)                 AS total_usage_events,
    COUNT(DISTINCT account_id)              AS distinct_accounts,
    ROUND(
        SUM(total_usage_duration_secs)::NUMERIC
        / NULLIF(SUM(total_usage_events), 0),
    2)                                      AS avg_duration_secs,
    SUM(total_errors)                       AS total_errors
FROM base_feature_usage_monthly
GROUP BY feature_name, is_beta_feature
ORDER BY total_usage_count DESC
LIMIT 10;

-- Monthly usage trend
SELECT
    month,
    COUNT(DISTINCT account_id)      AS active_accounts,
    SUM(total_usage_count)          AS total_usage_count,
    SUM(total_usage_events)         AS total_usage_events,
    SUM(total_errors)               AS total_errors,
    ROUND(
        SUM(total_usage_count)::NUMERIC
        / NULLIF(COUNT(DISTINCT account_id), 0)
    , 2)                            AS avg_usage_per_account
FROM base_feature_usage_monthly
GROUP BY month
ORDER BY month;