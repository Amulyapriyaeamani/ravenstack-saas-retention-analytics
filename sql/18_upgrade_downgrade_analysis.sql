/*
===============================================================================
FILE: 18_upgrade_downgrade_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Analyzes plan movement patterns and their revenue impact.

Covers:
    - Monthly upgrade and downgrade rates
    - Revenue impact of upgrades vs downgrades
    - Net expansion trend
    - Which months had most plan movement
    - Movement type vs churn rate

SOURCE
------------------------------------------------------------------------------
Primary sources:
    kpi_monthly_upgrade_downgrade  → upgrade/downgrade rates (already built)
    subscriptions                  → plan movement MRR details
    cohort_base                    → account segmentation + churn behavior
    base_churn_monthly             → preceding downgrade flag

kpi_monthly_upgrade_downgrade contains:
    month
    paid_active_accounts
    upgraded_accounts
    downgraded_accounts
    monthly_upgrade_rate_pct
    monthly_downgrade_rate_pct

This step adds:
    - net upgrade accounts and rate (computed here)
    - MRR impact of upgrades vs downgrades
    - Net revenue expansion per month
    - Plan movement intensity per account
    - Movement type vs churn rate analysis

HYPOTHESES
------------------------------------------------------------------------------
H1: Upgrade MRR consistently exceeds downgrade MRR until H2 2024
    when downgrade pressure compresses net expansion.

H2: December 2024 has highest absolute plan movement
    (most upgrades AND most downgrades simultaneously).

H3: Accounts that downgrade are significantly more likely to churn
    within the next 3 months.

DATASET LIMITATION
------------------------------------------------------------------------------
No dedicated plan-change event timestamp.
Upgrade/downgrade timing approximated using subscription start_date.
Documented in kpi_monthly_upgrade_downgrade.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 2 — Revenue & Growth

    analysis_upgrade_downgrade_trend   → rate trend line chart
    analysis_upgrade_downgrade_revenue → MRR impact bar chart

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: UPGRADE/DOWNGRADE RATE TREND WITH NET EXPANSION
-- ============================================================================
/*
Purpose:
    Full rate picture including net accounts and expansion classification.
    kpi_monthly_upgrade_downgrade has rates but not net — compute here.

Hypothesis:
    Downgrade rate accelerating in H2 2024.
    Net expansion compressing toward end of dataset.
*/

SELECT
    month,
    paid_active_accounts,
    upgraded_accounts,
    downgraded_accounts,
    monthly_upgrade_rate_pct,
    monthly_downgrade_rate_pct,

    -- Net upgrade accounts (computed — not in base KPI view)
    upgraded_accounts
        - downgraded_accounts                   AS net_upgrade_accounts,

    -- Net upgrade rate
    ROUND(
        (upgraded_accounts - downgraded_accounts)::NUMERIC
        / NULLIF(paid_active_accounts, 0)
        * 100, 2
    )                                           AS net_upgrade_rate_pct,

    -- Total plan movement intensity
    upgraded_accounts
        + downgraded_accounts                   AS total_plan_changes,

    -- MoM upgrade rate change
    ROUND(
        monthly_upgrade_rate_pct
        - LAG(monthly_upgrade_rate_pct) OVER (
            ORDER BY month
        ), 2
    )                                           AS upgrade_rate_mom_change,

    -- MoM downgrade rate change
    ROUND(
        monthly_downgrade_rate_pct
        - LAG(monthly_downgrade_rate_pct) OVER (
            ORDER BY month
        ), 2
    )                                           AS downgrade_rate_mom_change,

    -- Net expansion classification
    CASE
        WHEN (upgraded_accounts - downgraded_accounts)::NUMERIC
             / NULLIF(paid_active_accounts, 0) * 100 > 5
                                                THEN 'strong expansion'
        WHEN upgraded_accounts > downgraded_accounts
                                                THEN 'mild expansion'
        WHEN upgraded_accounts = downgraded_accounts
                                                THEN 'neutral'
        ELSE                                         'contraction'
    END                                         AS expansion_classification

FROM kpi_monthly_upgrade_downgrade
ORDER BY month;


-- ============================================================================
-- EXPLORATORY 2: REVENUE IMPACT OF PLAN MOVEMENT
-- ============================================================================
/*
Purpose:
    MRR added by upgrades and lost by downgrades each month.
    Net revenue expansion from plan movement.

Hypothesis:
    Upgrade MRR > downgrade MRR most months.
    July 2024 only month where downgrade MRR > upgrade MRR.
*/

SELECT
    DATE_TRUNC('month', s.start_date)::DATE         AS month,

    COUNT(DISTINCT s.account_id)
        FILTER (WHERE s.upgrade_flag = TRUE
            AND s.is_trial = FALSE)                 AS upgraded_accounts,
    COUNT(DISTINCT s.account_id)
        FILTER (WHERE s.downgrade_flag = TRUE
            AND s.is_trial = FALSE)                 AS downgraded_accounts,

    ROUND(SUM(s.mrr_amount)
        FILTER (WHERE s.upgrade_flag = TRUE
            AND s.is_trial = FALSE), 2)             AS upgrade_mrr,

    ROUND(SUM(s.mrr_amount)
        FILTER (WHERE s.downgrade_flag = TRUE
            AND s.is_trial = FALSE), 2)             AS downgrade_mrr,

    ROUND(
        COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        - COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0),
        2
    )                                               AS net_expansion_mrr,

    ROUND(
        COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        / NULLIF(COUNT(DISTINCT s.account_id)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0),
        2
    )                                               AS avg_upgrade_mrr_per_account,

    ROUND(
        COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        / NULLIF(COUNT(DISTINCT s.account_id)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0),
        2
    )                                               AS avg_downgrade_mrr_per_account

FROM subscriptions s
WHERE s.is_trial = FALSE
  AND s.mrr_amount > 0
  AND (s.upgrade_flag = TRUE OR s.downgrade_flag = TRUE)
GROUP BY DATE_TRUNC('month', s.start_date)::DATE
ORDER BY month;


-- ============================================================================
-- EXPLORATORY 3: MOVEMENT TYPE VS CHURN RATE
-- ============================================================================
/*
Purpose:
    Compare churn rates across movement types.
    Does upgrading protect against churn?
    Does downgrading predict churn?

Hypothesis:
    Downgrade-only accounts churn more than upgrade-only accounts.
    Both-directions accounts most unstable.
*/

WITH account_movement AS (
    SELECT
        s.account_id,
        CASE
            WHEN COUNT(*) FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE) > 0
             AND COUNT(*) FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE) > 0     THEN 'both directions'
            WHEN COUNT(*) FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE) > 0     THEN 'upgrade only'
            WHEN COUNT(*) FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE) > 0     THEN 'downgrade only'
            ELSE                                     'no movement'
        END                                     AS movement_type
    FROM subscriptions s
    GROUP BY s.account_id
)

SELECT
    am.movement_type,
    COUNT(am.account_id)                        AS total_accounts,
    COUNT(am.account_id)
        FILTER (WHERE cb.ever_churned = TRUE)   AS churned_accounts,
    ROUND(
        COUNT(am.account_id)
            FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(am.account_id), 0)
        * 100, 1
    )                                           AS churn_rate_pct,
    ROUND(
        AVG(cb.months_to_first_churn), 1
    )                                           AS avg_months_to_first_churn,
    ROUND(
        AVG(cb.churn_count), 2
    )                                           AS avg_churn_events
FROM account_movement am
JOIN cohort_base cb
    ON am.account_id = cb.account_id
GROUP BY am.movement_type
ORDER BY churn_rate_pct DESC;


-- ============================================================================
-- EXPLORATORY 4: DOWNGRADE-TO-CHURN ANALYSIS
-- ============================================================================
/*
Purpose:
    Do accounts that downgrade before churning survive shorter?
    Uses preceding_downgrade_flag from base_churn_monthly.

Hypothesis:
    Accounts with preceding_downgrade_flag churn sooner.
*/

SELECT
    bcm.preceding_downgrade_flag,
    COUNT(DISTINCT bcm.account_id)              AS churned_accounts,
    ROUND(
        COUNT(DISTINCT bcm.account_id)::NUMERIC
        / SUM(COUNT(DISTINCT bcm.account_id)) OVER ()
        * 100, 1
    )                                           AS pct_of_churns,
    ROUND(
        AVG(cb.months_to_first_churn), 1
    )                                           AS avg_months_to_churn,
    ROUND(
        AVG(cb.churn_count), 2
    )                                           AS avg_churn_events
FROM base_churn_monthly bcm
JOIN cohort_base cb
    ON bcm.account_id = cb.account_id
GROUP BY bcm.preceding_downgrade_flag
ORDER BY bcm.preceding_downgrade_flag;


-- ============================================================================
-- EXPLORATORY 5: HIGHEST PLAN MOVEMENT MONTHS
-- ============================================================================
/*
Purpose:
    Which months had the most total plan changes?
    Identify periods of maximum instability.

Hypothesis:
    December 2024 has highest total plan movement.
*/

SELECT
    month,
    upgraded_accounts,
    downgraded_accounts,
    upgraded_accounts
        + downgraded_accounts                   AS total_plan_changes,
    monthly_upgrade_rate_pct,
    monthly_downgrade_rate_pct,
    ROUND(
        (monthly_upgrade_rate_pct
            + monthly_downgrade_rate_pct), 2
    )                                           AS total_movement_rate_pct
FROM kpi_monthly_upgrade_downgrade
ORDER BY total_plan_changes DESC;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_upgrade_downgrade_trend
-- ============================================================================
/*
Purpose:
    Monthly upgrade/downgrade rates with net expansion.
    Feeds rate trend line chart on dashboard.

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Line chart — upgrade rate vs downgrade rate over time
*/

DROP VIEW IF EXISTS analysis_upgrade_downgrade_trend;
CREATE VIEW analysis_upgrade_downgrade_trend AS

SELECT
    month,
    paid_active_accounts,
    upgraded_accounts,
    downgraded_accounts,
    monthly_upgrade_rate_pct,
    monthly_downgrade_rate_pct,

    upgraded_accounts
        - downgraded_accounts                   AS net_upgrade_accounts,

    ROUND(
        (upgraded_accounts - downgraded_accounts)::NUMERIC
        / NULLIF(paid_active_accounts, 0)
        * 100, 2
    )                                           AS net_upgrade_rate_pct,

    upgraded_accounts
        + downgraded_accounts                   AS total_plan_changes,

    CASE
        WHEN (upgraded_accounts - downgraded_accounts)::NUMERIC
             / NULLIF(paid_active_accounts, 0) * 100 > 5
                                                THEN 'strong expansion'
        WHEN upgraded_accounts > downgraded_accounts
                                                THEN 'mild expansion'
        WHEN upgraded_accounts = downgraded_accounts
                                                THEN 'neutral'
        ELSE                                         'contraction'
    END                                         AS expansion_classification

FROM kpi_monthly_upgrade_downgrade
ORDER BY month;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_upgrade_downgrade_revenue
-- ============================================================================
/*
Purpose:
    Monthly MRR impact of plan movement.
    Feeds revenue expansion bar chart on dashboard.

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Bar chart — upgrade MRR vs downgrade MRR per month
*/

DROP VIEW IF EXISTS analysis_upgrade_downgrade_revenue;
CREATE VIEW analysis_upgrade_downgrade_revenue AS

SELECT
    DATE_TRUNC('month', s.start_date)::DATE     AS month,

    COUNT(DISTINCT s.account_id)
        FILTER (WHERE s.upgrade_flag = TRUE
            AND s.is_trial = FALSE)             AS upgraded_accounts,
    COUNT(DISTINCT s.account_id)
        FILTER (WHERE s.downgrade_flag = TRUE
            AND s.is_trial = FALSE)             AS downgraded_accounts,

    ROUND(COALESCE(SUM(s.mrr_amount)
        FILTER (WHERE s.upgrade_flag = TRUE
            AND s.is_trial = FALSE), 0), 2)     AS upgrade_mrr,

    ROUND(COALESCE(SUM(s.mrr_amount)
        FILTER (WHERE s.downgrade_flag = TRUE
            AND s.is_trial = FALSE), 0), 2)     AS downgrade_mrr,

    ROUND(
        COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        - COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0),
        2
    )                                           AS net_expansion_mrr,

    ROUND(
        COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        / NULLIF(COUNT(DISTINCT s.account_id)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0),
        2
    )                                           AS avg_upgrade_mrr,

    ROUND(
        COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        / NULLIF(COUNT(DISTINCT s.account_id)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0),
        2
    )                                           AS avg_downgrade_mrr,

    CASE
        WHEN COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        > COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)     THEN 'net positive'
        WHEN COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.upgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)
        < COALESCE(SUM(s.mrr_amount)
            FILTER (WHERE s.downgrade_flag = TRUE
                AND s.is_trial = FALSE), 0)     THEN 'net negative'
        ELSE                                         'neutral'
    END                                         AS revenue_expansion_status

FROM subscriptions s
WHERE s.is_trial = FALSE
  AND s.mrr_amount > 0
  AND (s.upgrade_flag = TRUE OR s.downgrade_flag = TRUE)
GROUP BY DATE_TRUNC('month', s.start_date)::DATE
ORDER BY month;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: Upgraded accounts match kpi layer exactly
SELECT
    t.month,
    t.upgraded_accounts         AS trend_view,
    k.upgraded_accounts         AS kpi_layer,
    t.upgraded_accounts
        - k.upgraded_accounts   AS difference
FROM analysis_upgrade_downgrade_trend t
JOIN kpi_monthly_upgrade_downgrade k
    ON t.month = k.month
WHERE t.upgraded_accounts != k.upgraded_accounts;
-- Should return 0 rows

-- V2: Downgraded accounts match kpi layer exactly
SELECT
    t.month,
    t.downgraded_accounts       AS trend_view,
    k.downgraded_accounts       AS kpi_layer,
    t.downgraded_accounts
        - k.downgraded_accounts AS difference
FROM analysis_upgrade_downgrade_trend t
JOIN kpi_monthly_upgrade_downgrade k
    ON t.month = k.month
WHERE t.downgraded_accounts != k.downgraded_accounts;
-- Should return 0 rows

-- V3: Net expansion MRR sign check
-- Negative net = downgrade MRR exceeded upgrade MRR
SELECT
    month,
    upgrade_mrr,
    downgrade_mrr,
    net_expansion_mrr,
    revenue_expansion_status
FROM analysis_upgrade_downgrade_revenue
ORDER BY net_expansion_mrr ASC;

-- V4: Preview all dashboard views
SELECT * FROM analysis_upgrade_downgrade_trend   ORDER BY month;
SELECT * FROM analysis_upgrade_downgrade_revenue ORDER BY month;