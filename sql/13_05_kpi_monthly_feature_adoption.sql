/*
===============================================================================
FILE: 13_05_kpi_monthly_feature_adoption.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Measures monthly feature adoption across active accounts.

This KPI answers:
    - What % of active accounts used a feature?
    - Which features are most widely adopted?
    - Which features are deeply used vs lightly used?
    - How do beta features compare to stable features?

BUSINESS DEFINITION
------------------------------------------------------------------------------
Feature Adoption Rate (%) =
    adopted_accounts / total_active_accounts * 100

Where:
    adopted_accounts =
        distinct accounts that used a feature during month M

    total_active_accounts =
        distinct accounts active during month M

IMPORTANT POPULATION NOTE
------------------------------------------------------------------------------
Denominator:
    base_active_monthly
    → active-anytime-during-month logic

Numerator:
    base_feature_usage_monthly
    → usage tied to subscription active during same month

These populations are slightly different because:
    - numerator validates subscription activity alongside usage
    - denominator only checks monthly activity overlap

This approximation is intentionally accepted because:
    - project operates at monthly SaaS KPI granularity
    - exact timestamp overlap is unnecessary for business analysis
    - logic remains consistent across engagement KPIs

ENGAGEMENT DEPTH METRICS
------------------------------------------------------------------------------
Adoption rate measures breadth of usage.

Additional engagement metrics included:
    total_usage_count
    avg_usage_per_adopter

These help distinguish:
    - widely adopted but shallow features
    - niche but deeply sticky features

GRAIN
------------------------------------------------------------------------------
One row per:
    month + feature_name + is_beta_feature

OUTPUT
------------------------------------------------------------------------------
month
feature_name
is_beta_feature
adopted_accounts
total_active_accounts
feature_adoption_rate_pct
total_usage_count
avg_usage_per_adopter

DEPENDS ON
------------------------------------------------------------------------------
base_feature_usage_monthly
base_active_monthly

===============================================================================
*/

DROP VIEW IF EXISTS kpi_monthly_feature_adoption;

CREATE VIEW kpi_monthly_feature_adoption AS

WITH active_accounts AS (
    /*
    -------------------------------------------------------
    Step 1: Monthly active account denominator
    -------------------------------------------------------
    */
    SELECT
        month,
        COUNT(DISTINCT account_id) AS total_active_accounts
    FROM base_active_monthly
    GROUP BY month
),

feature_users AS (
    /*
    -------------------------------------------------------
    Step 2: Monthly feature users
    -------------------------------------------------------
    Aggregates usage at:
        month + account + feature

    Keeps usage intensity metrics for downstream analysis.
    -------------------------------------------------------
    */
    SELECT
        month,
        account_id,
        feature_name,
        is_beta_feature,
        SUM(total_usage_count) AS account_usage_count
    FROM base_feature_usage_monthly
    GROUP BY
        month,
        account_id,
        feature_name,
        is_beta_feature
),

feature_adoption AS (
    /*
    -------------------------------------------------------
    Step 3: Aggregate to feature-month level
    -------------------------------------------------------
    */
    SELECT
        month,
        feature_name,
        is_beta_feature,
        COUNT(DISTINCT account_id)     AS adopted_accounts,
        SUM(account_usage_count)       AS total_usage_count
    FROM feature_users
    GROUP BY
        month,
        feature_name,
        is_beta_feature
)

SELECT
    f.month,
    f.feature_name,
    f.is_beta_feature,
    f.adopted_accounts,
    a.total_active_accounts,

    ROUND(
        f.adopted_accounts::NUMERIC
        / NULLIF(a.total_active_accounts, 0)
        * 100,
        2
    ) AS feature_adoption_rate_pct,

    f.total_usage_count,

    ROUND(
        f.total_usage_count::NUMERIC
        / NULLIF(f.adopted_accounts, 0),
        2
    ) AS avg_usage_per_adopter

FROM feature_adoption f
JOIN active_accounts a
    ON f.month = a.month

ORDER BY
    f.month,
    feature_adoption_rate_pct DESC,
    f.feature_name;


-- ============================================================================
-- VALIDATION QUERIES
-- ============================================================================

-- Full preview
SELECT *
FROM kpi_monthly_feature_adoption;


-- Overall sanity check
SELECT
    COUNT(*)                                AS total_rows,
    COUNT(DISTINCT feature_name)            AS distinct_features,
    COUNT(DISTINCT month)                   AS total_months,
    MIN(feature_adoption_rate_pct)          AS min_adoption_rate,
    MAX(feature_adoption_rate_pct)          AS max_adoption_rate,
    SUM(total_usage_count)                  AS total_usage_count
FROM kpi_monthly_feature_adoption;


-- Adoption rate should never exceed 100%
SELECT *
FROM kpi_monthly_feature_adoption
WHERE feature_adoption_rate_pct > 100;


-- Top adopted features
SELECT
    feature_name,
    is_beta_feature,
    ROUND(AVG(feature_adoption_rate_pct), 2) AS avg_adoption_rate,
    SUM(total_usage_count)                   AS total_usage_count,
    ROUND(AVG(avg_usage_per_adopter), 2)     AS avg_usage_per_adopter
FROM kpi_monthly_feature_adoption
GROUP BY feature_name, is_beta_feature
ORDER BY avg_adoption_rate DESC
LIMIT 15;


-- Highest engagement depth features
SELECT
    feature_name,
    is_beta_feature,
    ROUND(AVG(avg_usage_per_adopter), 2) AS avg_usage_per_adopter,
    ROUND(AVG(feature_adoption_rate_pct), 2) AS avg_adoption_rate
FROM kpi_monthly_feature_adoption
GROUP BY feature_name, is_beta_feature
ORDER BY avg_usage_per_adopter DESC
LIMIT 15;


-- Beta vs non-beta comparison
SELECT
    is_beta_feature,
    ROUND(AVG(feature_adoption_rate_pct), 2) AS avg_adoption_rate,
    ROUND(AVG(avg_usage_per_adopter), 2)     AS avg_usage_per_adopter,
    SUM(total_usage_count)                   AS total_usage_count
FROM kpi_monthly_feature_adoption
GROUP BY is_beta_feature;


-- Monthly adoption trend
SELECT
    month,
    COUNT(DISTINCT feature_name)             AS active_features,
    ROUND(AVG(feature_adoption_rate_pct), 2) AS avg_feature_adoption_rate,
    SUM(total_usage_count)                   AS total_usage_count
FROM kpi_monthly_feature_adoption
GROUP BY month
ORDER BY month;