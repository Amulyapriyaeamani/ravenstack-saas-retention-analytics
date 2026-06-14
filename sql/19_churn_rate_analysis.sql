/*
===============================================================================
FILE: 19_churn_rate_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Deep dive into churn rate patterns beyond the KPI layer.

kpi_monthly_churn_rate already provides monthly churn rates.
This step adds:
    - Overall churn picture with business context
    - Churn acceleration point identification
    - Paid vs trial churn comparison
    - Churn rate trend with phase classification
    - Pre-launch churn trajectory assessment

SOURCE
------------------------------------------------------------------------------
Primary sources:
    kpi_monthly_churn_rate       → monthly churn rates (already built)
    kpi_monthly_retention_rate   → retention complement
    base_churn_monthly           → account-level churn events
    base_active_monthly          → active account population
    cohort_base                  → account behavioral attributes
    subscriptions                → trial vs paid classification

HYPOTHESES
------------------------------------------------------------------------------
H1: Churn acceleration began in June 2024 and represents a
    structural shift, not random noise.
    (Early signal from KPI layer: crossed 10% and never recovered)

H2: Trial accounts churn at significantly higher rates than paid accounts.
    Trials are feature experimentation tools — they may exit more freely.

H3: The 5.13% September 2023 retention peak represents
    the product's natural healthy state when acquisition
    and product quality aligned.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 3 — Churn Analysis

    analysis_churn_rate_trend      → churn rate line chart with phases
    analysis_churn_paid_vs_trial   → paid vs trial churn comparison

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: OVERALL CHURN PICTURE
-- ============================================================================
/*
Purpose:
    Establish the full churn picture with context.
    Overall lifetime churn vs monthly churn distinction.
    Paid accounts at risk at any given point.
*/

SELECT
    -- Lifetime picture
    (SELECT COUNT(DISTINCT account_id)
     FROM churn_events)                            AS total_ever_churned,

    (SELECT COUNT(*) FROM accounts)                AS total_accounts,

    ROUND(
        (SELECT COUNT(DISTINCT account_id)
         FROM churn_events)::NUMERIC
        / (SELECT COUNT(*) FROM accounts)
        * 100, 1
    )                                              AS lifetime_churn_rate_pct,

    -- Currently at risk
    (SELECT COUNT(DISTINCT account_id)
     FROM base_active_monthly
     WHERE month = '2024-12-01'
       AND account_type IN ('paid', 'mixed'))      AS active_paid_accounts_dec,

    -- Permanently lost
    (SELECT COUNT(*)
     FROM cohort_base
     WHERE ever_churned = TRUE
       AND ever_reactivated = FALSE)               AS permanently_lost,

    -- Reactivated
    (SELECT COUNT(*)
     FROM cohort_base
     WHERE ever_reactivated = TRUE)                AS reactivated_accounts,

    -- Average churn events per churned account
    ROUND(
        (SELECT COUNT(*) FROM churn_events)::NUMERIC
        / NULLIF(
            (SELECT COUNT(DISTINCT account_id)
             FROM churn_events), 0
        ), 2
    )                                              AS avg_churn_events_per_account;


-- ============================================================================
-- EXPLORATORY 2: CHURN ACCELERATION ANALYSIS
-- ============================================================================
/*
Purpose:
    Identify exactly when churn acceleration began.
    Classify each month by churn severity level.
    Measure the gap between actual churn and industry benchmark.

Hypothesis:
    June 2024 is the structural inflection point —
    churn crossed 10% and never recovered.
    This is not noise — it is a regime change.
*/

WITH churn_with_benchmark AS (
    SELECT
        month,
        start_month_active_accounts,
        churned_accounts,
        monthly_churn_rate_pct,
        is_reliable,

        -- Industry benchmark gap
        ROUND(monthly_churn_rate_pct - 5.0, 2)     AS gap_above_benchmark,

        -- MoM change
        ROUND(
            monthly_churn_rate_pct
            - LAG(monthly_churn_rate_pct) OVER (
                ORDER BY month
            ), 2
        )                                           AS mom_churn_change,

        -- Rolling 3-month avg for trend smoothing
        ROUND(
            AVG(monthly_churn_rate_pct) OVER (
                ORDER BY month
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ), 2
        )                                           AS rolling_3m_avg_churn,

        -- Severity classification
        CASE
            WHEN monthly_churn_rate_pct >= 15   THEN 'crisis'
            WHEN monthly_churn_rate_pct >= 10   THEN 'high'
            WHEN monthly_churn_rate_pct >= 5    THEN 'elevated'
            WHEN monthly_churn_rate_pct > 0
             AND is_reliable = TRUE              THEN 'benchmark range'
            ELSE                                     'unreliable/zero'
        END                                         AS churn_severity

    FROM kpi_monthly_churn_rate
    WHERE is_reliable = TRUE
)

SELECT
    month,
    start_month_active_accounts,
    churned_accounts,
    monthly_churn_rate_pct,
    gap_above_benchmark,
    mom_churn_change,
    rolling_3m_avg_churn,
    churn_severity,

    -- Acceleration flag
    CASE
        WHEN mom_churn_change > 2.0             THEN 'accelerating'
        WHEN mom_churn_change < -2.0            THEN 'decelerating'
        ELSE                                         'stable'
    END                                         AS acceleration_status,

    -- Consecutive months above 10%
    SUM(CASE WHEN monthly_churn_rate_pct >= 10
             THEN 1 ELSE 0 END) OVER (
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                           AS cumulative_high_churn_months

FROM churn_with_benchmark
ORDER BY month;


-- ============================================================================
-- EXPLORATORY 3: CHURN SEVERITY DISTRIBUTION
-- ============================================================================
/*
Purpose:
    Summarize how many months fall into each severity tier.
    Quantify how much time the product spent above vs within benchmark.
*/

SELECT
    CASE
        WHEN monthly_churn_rate_pct >= 15   THEN '4. crisis (>=15%)'
        WHEN monthly_churn_rate_pct >= 10   THEN '3. high (10-15%)'
        WHEN monthly_churn_rate_pct >= 5    THEN '2. elevated (5-10%)'
        WHEN is_reliable = TRUE             THEN '1. benchmark range (<5%)'
        ELSE                                     '0. unreliable'
    END                                         AS severity_tier,
    COUNT(*)                                    AS month_count,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER ()
        * 100, 1
    )                                           AS pct_of_months,
    ROUND(AVG(monthly_churn_rate_pct), 2)       AS avg_churn_rate_in_tier,
    MIN(month)                                  AS first_occurrence,
    MAX(month)                                  AS last_occurrence
FROM kpi_monthly_churn_rate
WHERE is_reliable = TRUE
GROUP BY
    CASE
        WHEN monthly_churn_rate_pct >= 15   THEN '4. crisis (>=15%)'
        WHEN monthly_churn_rate_pct >= 10   THEN '3. high (10-15%)'
        WHEN monthly_churn_rate_pct >= 5    THEN '2. elevated (5-10%)'
        WHEN is_reliable = TRUE             THEN '1. benchmark range (<5%)'
        ELSE                                     '0. unreliable'
    END
ORDER BY severity_tier;


-- ============================================================================
-- EXPLORATORY 4: PAID VS TRIAL CHURN COMPARISON
-- ============================================================================
/*
Purpose:
    Compare churn behavior between paid and trial accounts.
    Trial accounts = feature experimentation based on dataset findings.
    Do they churn more freely than paid accounts?

Hypothesis:
    Trial churn rate > paid churn rate because trials
    carry less financial commitment.

Logic:
    Use base_active_monthly account_type to separate populations.
    Join to base_churn_monthly for churn events per type.
    Denominator: accounts active at start of each month per type.

NOTE:
    base_active_monthly uses active-anytime.
    For rate calculation, approximate with start-of-month logic
    using account_type from base_active_monthly as type proxy.
*/

WITH monthly_active_by_type AS (
    SELECT
        month,
        COUNT(*) FILTER (WHERE account_type IN ('paid', 'mixed'))
                                                AS paid_accounts,
        COUNT(*) FILTER (WHERE account_type = 'trial')
                                                AS trial_accounts,
        COUNT(*)                                AS total_accounts
    FROM base_active_monthly
    GROUP BY month
),

monthly_churned AS (
    SELECT
        bcm.month,
        COUNT(DISTINCT bcm.account_id)          AS total_churned,
        COUNT(DISTINCT bcm.account_id)
            FILTER (
                WHERE bam.account_type IN ('paid', 'mixed')
            )                                   AS paid_churned,
        COUNT(DISTINCT bcm.account_id)
            FILTER (
                WHERE bam.account_type = 'trial'
            )                                   AS trial_churned
    FROM base_churn_monthly bcm
    LEFT JOIN base_active_monthly bam
        ON  bcm.account_id = bam.account_id
        AND bcm.month      = bam.month
    GROUP BY bcm.month
)

SELECT
    a.month,
    a.paid_accounts,
    a.trial_accounts,
    COALESCE(c.paid_churned, 0)                 AS paid_churned,
    COALESCE(c.trial_churned, 0)                AS trial_churned,

    -- Paid churn rate
    ROUND(
        COALESCE(c.paid_churned, 0)::NUMERIC
        / NULLIF(a.paid_accounts, 0)
        * 100, 2
    )                                           AS paid_churn_rate_pct,

    -- Trial churn rate
    ROUND(
        COALESCE(c.trial_churned, 0)::NUMERIC
        / NULLIF(a.trial_accounts, 0)
        * 100, 2
    )                                           AS trial_churn_rate_pct,

    -- Gap between paid and trial churn
    ROUND(
        COALESCE(c.trial_churned, 0)::NUMERIC
            / NULLIF(a.trial_accounts, 0) * 100
        - COALESCE(c.paid_churned, 0)::NUMERIC
            / NULLIF(a.paid_accounts, 0) * 100,
        2
    )                                           AS trial_vs_paid_gap_pct

FROM monthly_active_by_type a
LEFT JOIN monthly_churned c
    ON a.month = c.month
ORDER BY a.month;


-- ============================================================================
-- EXPLORATORY 5: CHURN COHORT COMPARISON — 2023 vs 2024
-- ============================================================================
/*
Purpose:
    Are 2024 accounts churning faster than 2023 accounts?
    Cross-validates cohort_survival_curve finding from Step 14.
*/

SELECT
    CASE
        WHEN cb.cohort_month < '2024-01-01'     THEN '2023 cohorts'
        ELSE                                         '2024 cohorts'
    END                                         AS cohort_year,
    COUNT(DISTINCT cb.account_id)               AS total_accounts,
    COUNT(DISTINCT cb.account_id)
        FILTER (WHERE cb.ever_churned = TRUE)   AS churned_accounts,
    ROUND(
        COUNT(DISTINCT cb.account_id)
            FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(DISTINCT cb.account_id), 0)
        * 100, 1
    )                                           AS churn_rate_pct,
    ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn,
    ROUND(AVG(cb.churn_count), 2)               AS avg_churn_events
FROM cohort_base cb
GROUP BY
    CASE
        WHEN cb.cohort_month < '2024-01-01'     THEN '2023 cohorts'
        ELSE                                         '2024 cohorts'
    END
ORDER BY cohort_year;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_churn_rate_trend
-- ============================================================================
/*
Purpose:
    Monthly churn rate trend with phase classification and benchmark gap.
    Feeds churn rate line chart on dashboard.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Line chart — monthly churn rate with benchmark band
            and phase annotations
*/

DROP VIEW IF EXISTS analysis_churn_rate_trend;
CREATE VIEW analysis_churn_rate_trend AS

SELECT
    month,
    start_month_active_accounts,
    churned_accounts,
    monthly_churn_rate_pct,
    monthly_retention_rate_pct,
    is_reliable,

    -- Benchmark reference (industry standard: 2-5%)
    2.0                                         AS benchmark_lower,
    5.0                                         AS benchmark_upper,

    -- Gap above upper benchmark
    ROUND(
        GREATEST(monthly_churn_rate_pct - 5.0, 0),
        2
    )                                           AS gap_above_benchmark,

    -- Severity tier
    CASE
        WHEN monthly_churn_rate_pct >= 15       THEN 'crisis'
        WHEN monthly_churn_rate_pct >= 10       THEN 'high'
        WHEN monthly_churn_rate_pct >= 5        THEN 'elevated'
        WHEN is_reliable = TRUE                 THEN 'benchmark range'
        ELSE                                         'unreliable'
    END                                         AS churn_severity,

    -- Phase classification
    CASE
        WHEN month < '2023-06-01'               THEN 'early stage'
        WHEN month < '2024-06-01'               THEN 'stabilization'
        ELSE                                         'acceleration'
    END                                         AS churn_phase,

    -- Rolling 3-month average for trend line
    ROUND(
        AVG(monthly_churn_rate_pct) OVER (
            ORDER BY month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    )                                           AS rolling_3m_avg

FROM kpi_monthly_retention_rate
ORDER BY month;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_churn_paid_vs_trial
-- ============================================================================
/*
Purpose:
    Monthly paid vs trial churn comparison.
    Feeds segmented churn chart on dashboard.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Dual-line chart — paid churn rate vs trial churn rate
*/

DROP VIEW IF EXISTS analysis_churn_paid_vs_trial;
CREATE VIEW analysis_churn_paid_vs_trial AS

WITH monthly_active_by_type AS (
    SELECT
        month,
        COUNT(*) FILTER (WHERE account_type IN ('paid', 'mixed'))
                                                AS paid_accounts,
        COUNT(*) FILTER (WHERE account_type = 'trial')
                                                AS trial_accounts
    FROM base_active_monthly
    GROUP BY month
),

monthly_churned AS (
    SELECT
        bcm.month,
        COUNT(DISTINCT bcm.account_id)
            FILTER (
                WHERE bam.account_type IN ('paid', 'mixed')
            )                                   AS paid_churned,
        COUNT(DISTINCT bcm.account_id)
            FILTER (
                WHERE bam.account_type = 'trial'
            )                                   AS trial_churned
    FROM base_churn_monthly bcm
    LEFT JOIN base_active_monthly bam
        ON  bcm.account_id = bam.account_id
        AND bcm.month      = bam.month
    GROUP BY bcm.month
)

SELECT
    a.month,
    a.paid_accounts,
    a.trial_accounts,
    COALESCE(c.paid_churned, 0)                 AS paid_churned,
    COALESCE(c.trial_churned, 0)                AS trial_churned,
    ROUND(
        COALESCE(c.paid_churned, 0)::NUMERIC
        / NULLIF(a.paid_accounts, 0) * 100, 2
    )                                           AS paid_churn_rate_pct,
    ROUND(
        COALESCE(c.trial_churned, 0)::NUMERIC
        / NULLIF(a.trial_accounts, 0) * 100, 2
    )                                           AS trial_churn_rate_pct,
    ROUND(
        COALESCE(c.trial_churned, 0)::NUMERIC
            / NULLIF(a.trial_accounts, 0) * 100
        - COALESCE(c.paid_churned, 0)::NUMERIC
            / NULLIF(a.paid_accounts, 0) * 100,
        2
    )                                           AS trial_vs_paid_gap_pct

FROM monthly_active_by_type a
LEFT JOIN monthly_churned c
    ON a.month = c.month
ORDER BY a.month;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: Dashboard view monthly churn rate matches KPI layer exactly
SELECT
    t.month,
    t.monthly_churn_rate_pct        AS trend_view,
    k.monthly_churn_rate_pct        AS kpi_layer,
    t.monthly_churn_rate_pct
        - k.monthly_churn_rate_pct  AS difference
FROM analysis_churn_rate_trend t
JOIN kpi_monthly_churn_rate k
    ON t.month = k.month
WHERE t.monthly_churn_rate_pct != k.monthly_churn_rate_pct;
-- Should return 0 rows

-- V2: Paid + trial churned should not exceed total churned per month
SELECT
    month,
    paid_churned + trial_churned    AS sum_by_type,
    (SELECT churned_accounts
     FROM kpi_monthly_churn_rate cr
     WHERE cr.month = pv.month)     AS total_churned_kpi
FROM analysis_churn_paid_vs_trial pv
WHERE paid_churned + trial_churned >
    (SELECT churned_accounts
     FROM kpi_monthly_churn_rate cr
     WHERE cr.month = pv.month);
-- Should return 0 rows

-- V3: Severity distribution summary
SELECT
    churn_severity,
    COUNT(*)                        AS month_count,
    MIN(month)                      AS first_month,
    MAX(month)                      AS last_month
FROM analysis_churn_rate_trend
WHERE is_reliable = TRUE
GROUP BY churn_severity
ORDER BY churn_severity;

-- V4: 2023 vs 2024 cohort comparison
-- (Exploratory 5 output)

-- V5: Preview all dashboard views
SELECT * FROM analysis_churn_rate_trend     ORDER BY month;
SELECT * FROM analysis_churn_paid_vs_trial  ORDER BY month;