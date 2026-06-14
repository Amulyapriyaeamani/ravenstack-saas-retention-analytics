/*
===============================================================================
FILE: 27_cohort_retention_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Deep dive into cohort retention patterns beyond the base cohort layer.

cohort_retention_matrix and cohort_survival_curve are already built.
This step adds:
    - Month 1 and Month 2 retention deep dive
    - Drop-off patterns by cohort
    - 2023 vs 2024 cohort comparison
    - Segmented retention by plan tier, industry, country, referral source
    - Survival curve segmentation
    - Reactivation gap quantification per cohort

SOURCE
------------------------------------------------------------------------------
Primary sources (all already built and validated):
    cohort_retention_matrix    → retention_rate_pct per cohort per month
    cohort_survival_curve      → survival_rate_pct per cohort per month
    cohort_base                → segmentation dimensions

cohort_retention_matrix columns:
    cohort_month, cohort_size, months_since_signup,
    activity_month, active_accounts, retention_rate_pct

cohort_survival_curve columns:
    cohort_month, cohort_size, months_since_signup,
    surviving_accounts, survival_rate_pct,
    churned_by_month_n, cumulative_churn_rate_pct

cohort_base columns used:
    cohort_month, account_id, plan_tier, industry,
    country, referral_source, ever_churned,
    ever_reactivated, months_to_first_churn, churn_count

NO raw table joins needed for core analysis.
All segmentation routes through cohort_base.

HYPOTHESES
------------------------------------------------------------------------------
H1: Month 1 retention is the single most critical drop-off point.
    The gap between Month 0 (100%) and Month 1 is larger than
    any subsequent monthly drop.

H2: 2024 cohorts show higher Month 1 retention than 2023 cohorts
    in the retention matrix — but lower Month 1 survival in the
    survival curve. Both true simultaneously (reactivation masking).

H3: Ads channel cohorts retain significantly better at Month 3
    than organic or partner channel cohorts.

H4: Enterprise entry plan cohorts show longer survival than
    Basic or Pro entry plan cohorts.

H5: The reactivation gap (retention minus survival) widens
    through Month 6 and stabilizes after Month 9.
    This quantifies the reactivation dependency.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 7 — Cohort Retention

    analysis_cohort_month1_deep_dive     → Month 1 retention breakdown
    analysis_cohort_year_comparison      → 2023 vs 2024 comparison
    analysis_cohort_survival_segmented   → survival by segment

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: MONTH 1 RETENTION DEEP DIVE
-- ============================================================================
/*
Purpose:
    Month 1 is where the steepest average drop occurs.
    Quantify exactly how large the Month 0 → Month 1 drop is
    for every cohort and identify which cohorts
    had the best and worst Month 1 retention.

Hypothesis H1:
    Month 0 → Month 1 drop is larger than any subsequent monthly drop.
*/

WITH monthly_drops AS (
    SELECT
        crm.cohort_month,
        crm.cohort_size,
        crm.months_since_signup,
        crm.retention_rate_pct,
        LAG(crm.retention_rate_pct) OVER (
            PARTITION BY crm.cohort_month
            ORDER BY crm.months_since_signup
        )                                           AS prev_month_retention,
        crm.retention_rate_pct
            - LAG(crm.retention_rate_pct) OVER (
                PARTITION BY crm.cohort_month
                ORDER BY crm.months_since_signup
            )                                       AS month_over_month_change
    FROM cohort_retention_matrix crm
)

SELECT
    cohort_month,
    cohort_size,
    months_since_signup,
    retention_rate_pct,
    prev_month_retention,
    ROUND(month_over_month_change, 2)               AS retention_drop,
    ABS(ROUND(month_over_month_change, 2))          AS abs_drop,
    CASE
        WHEN months_since_signup = 1                THEN 'month 1 drop'
        WHEN months_since_signup = 2                THEN 'month 2 drop'
        WHEN months_since_signup = 3                THEN 'month 3 drop'
        ELSE                                             'later drop'
    END                                             AS drop_period
FROM monthly_drops
WHERE month_over_month_change IS NOT NULL
  AND month_over_month_change < 0
ORDER BY cohort_month, months_since_signup;


-- ============================================================================
-- EXPLORATORY 2: MONTH 1 RETENTION RANKED — ALL COHORTS
-- ============================================================================
/*
Purpose:
    Rank all cohorts by Month 1 retention rate.
    Identify best and worst cohorts.
    Check if 2024 cohorts dominate the top of the ranking.
*/

WITH month1_retention AS (
    SELECT
        crm.cohort_month,
        crm.cohort_size,
        crm.retention_rate_pct                      AS month1_retention_pct,
        css.survival_rate_pct                       AS month1_survival_pct,
        ROUND(
            crm.retention_rate_pct
            - css.survival_rate_pct, 1
        )                                           AS month1_reactivation_gap
    FROM cohort_retention_matrix crm
    JOIN cohort_survival_curve css
        ON  crm.cohort_month        = css.cohort_month
        AND crm.months_since_signup = css.months_since_signup
    WHERE crm.months_since_signup = 1
)

SELECT
    mr.cohort_month,
    mr.cohort_size,
    mr.month1_retention_pct,
    mr.month1_survival_pct,
    mr.month1_reactivation_gap,
    CASE
        WHEN EXTRACT(YEAR FROM mr.cohort_month) = 2023
                                                    THEN '2023'
        ELSE                                             '2024'
    END                                             AS cohort_year,
    RANK() OVER (
        ORDER BY mr.month1_retention_pct DESC
    )                                               AS retention_rank,
    RANK() OVER (
        ORDER BY mr.month1_survival_pct DESC
    )                                               AS survival_rank
FROM month1_retention mr
ORDER BY mr.month1_retention_pct DESC;


-- ============================================================================
-- EXPLORATORY 3: MONTH 2 RETENTION AND DROP-OFF PATTERNS
-- ============================================================================
/*
Purpose:
    Is Month 2 the second biggest drop-off point?
    Compare Month 1 drop vs Month 2 drop for each cohort.
    Identify cohorts with recovery between Month 1 and Month 2.
*/

WITH pivoted AS (
    SELECT
        cohort_month,
        cohort_size,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 0)  AS m0_retention,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 1)  AS m1_retention,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 2)  AS m2_retention,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 3)  AS m3_retention,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 6)  AS m6_retention,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 12) AS m12_retention
    FROM cohort_retention_matrix
    GROUP BY cohort_month, cohort_size
)

SELECT
    cohort_month,
    cohort_size,
    ROUND(m0_retention, 1)                          AS m0_retention_pct,
    ROUND(m1_retention, 1)                          AS m1_retention_pct,
    ROUND(m2_retention, 1)                          AS m2_retention_pct,
    ROUND(m3_retention, 1)                          AS m3_retention_pct,
    ROUND(m6_retention, 1)                          AS m6_retention_pct,
    ROUND(m12_retention, 1)                         AS m12_retention_pct,

    -- Month 0 → 1 drop
    ROUND(m0_retention - m1_retention, 1)           AS m0_to_m1_drop,

    -- Month 1 → 2 change (can be positive = recovery)
    ROUND(m2_retention - m1_retention, 1)           AS m1_to_m2_change,

    -- Month 2 → 3 change
    ROUND(m3_retention - m2_retention, 1)           AS m2_to_m3_change,

    -- Overall Month 0 → 3 drop
    ROUND(m0_retention - m3_retention, 1)           AS m0_to_m3_total_drop,

    -- Recovery flag: retention goes up from M1 to M2
    CASE
        WHEN m2_retention > m1_retention            THEN TRUE
        ELSE                                             FALSE
    END                                             AS m1_to_m2_recovery

FROM pivoted
WHERE m1_retention IS NOT NULL
ORDER BY cohort_month;


-- ============================================================================
-- EXPLORATORY 4: 2023 vs 2024 COHORT COMPARISON
-- ============================================================================
/*
Purpose:
    Side-by-side retention and survival comparison by cohort year.
    Confirm H2: retention matrix shows 2024 improving while
    survival curve shows 2024 worsening.

    Only use months where both years have data:
    Month 0, 1, 2, 3 (2024 cohorts have limited observation)
*/

WITH retention_by_year AS (
    SELECT
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END                                         AS cohort_year,
        months_since_signup,
        COUNT(DISTINCT cohort_month)                AS cohort_count,
        ROUND(AVG(retention_rate_pct), 1)           AS avg_retention_pct,
        ROUND(MIN(retention_rate_pct), 1)           AS min_retention_pct,
        ROUND(MAX(retention_rate_pct), 1)           AS max_retention_pct
    FROM cohort_retention_matrix
    GROUP BY
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END,
        months_since_signup
),

survival_by_year AS (
    SELECT
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END                                         AS cohort_year,
        months_since_signup,
        ROUND(AVG(survival_rate_pct), 1)            AS avg_survival_pct,
        ROUND(MIN(survival_rate_pct), 1)            AS min_survival_pct,
        ROUND(MAX(survival_rate_pct), 1)            AS max_survival_pct
    FROM cohort_survival_curve
    GROUP BY
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END,
        months_since_signup
)

SELECT
    r.cohort_year,
    r.months_since_signup,
    r.cohort_count,
    r.avg_retention_pct,
    r.min_retention_pct,
    r.max_retention_pct,
    s.avg_survival_pct,
    s.min_survival_pct,
    s.max_survival_pct,

    -- Reactivation gap = retention - survival
    ROUND(
        r.avg_retention_pct - s.avg_survival_pct, 1
    )                                               AS avg_reactivation_gap

FROM retention_by_year r
JOIN survival_by_year s
    ON  r.cohort_year           = s.cohort_year
    AND r.months_since_signup   = s.months_since_signup
WHERE r.months_since_signup <= 6
ORDER BY r.months_since_signup, r.cohort_year;


-- ============================================================================
-- EXPLORATORY 5: REACTIVATION GAP BY MONTH
-- ============================================================================
/*
Purpose:
    Quantify the reactivation gap at every month across all cohorts.
    Hypothesis H5: gap widens to Month 6 then stabilizes.

    Reactivation gap = retention_rate - survival_rate
    = proportion of active accounts that have churned at least once
*/

SELECT
    crm.months_since_signup,
    COUNT(DISTINCT crm.cohort_month)                AS cohort_count,
    ROUND(AVG(crm.retention_rate_pct), 2)           AS avg_retention_pct,
    ROUND(AVG(css.survival_rate_pct), 2)            AS avg_survival_pct,
    ROUND(
        AVG(crm.retention_rate_pct)
        - AVG(css.survival_rate_pct), 2
    )                                               AS avg_reactivation_gap,
    ROUND(MAX(
        crm.retention_rate_pct - css.survival_rate_pct
    ), 2)                                           AS max_reactivation_gap,
    ROUND(MIN(
        crm.retention_rate_pct - css.survival_rate_pct
    ), 2)                                           AS min_reactivation_gap

FROM cohort_retention_matrix crm
JOIN cohort_survival_curve css
    ON  crm.cohort_month        = css.cohort_month
    AND crm.months_since_signup = css.months_since_signup
GROUP BY crm.months_since_signup
ORDER BY crm.months_since_signup;


-- ============================================================================
-- EXPLORATORY 6: COHORT DROP-OFF PATTERN CLASSIFICATION
-- ============================================================================
/*
Purpose:
    Classify each cohort by its drop-off pattern.
    Some cohorts drop hard at Month 1 and recover.
    Others drop steadily. Others drop hard and never recover.
*/

WITH pivoted AS (
    SELECT
        crm.cohort_month,
        crm.cohort_size,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 1)  AS m1,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 2)  AS m2,
        MAX(retention_rate_pct)
            FILTER (WHERE months_since_signup = 3)  AS m3,
        MAX(survival_rate_pct)
            FILTER (WHERE months_since_signup = 1)  AS m1_survival
    FROM cohort_retention_matrix crm
    LEFT JOIN cohort_survival_curve 
        USING (cohort_month, months_since_signup)
    GROUP BY cohort_month, crm.cohort_size
)

SELECT
    cohort_month,
    cohort_size,
    ROUND(m1, 1)                                    AS m1_retention_pct,
    ROUND(m2, 1)                                    AS m2_retention_pct,
    ROUND(m3, 1)                                    AS m3_retention_pct,
    ROUND(m1_survival, 1)                           AS m1_survival_pct,
    ROUND(m1 - m1_survival, 1)                      AS m1_reactivation_gap,

    -- Drop-off pattern classification
    CASE
        WHEN m1 IS NULL                             THEN 'insufficient data'
        WHEN m1 < 50
         AND m2 IS NOT NULL
         AND m2 > m1                                THEN 'sharp drop + recovery'
        WHEN m1 < 50
         AND (m2 IS NULL OR m2 <= m1)              THEN 'sharp drop + no recovery'
        WHEN m1 >= 80                               THEN 'strong Month 1'
        WHEN m1 >= 60                               THEN 'moderate Month 1'
        ELSE                                             'weak Month 1'
    END                                             AS dropoff_pattern,

    CASE
        WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023'
        ELSE                                             '2024'
    END                                             AS cohort_year

FROM pivoted
ORDER BY cohort_month;


-- ============================================================================
-- EXPLORATORY 7: RETENTION SEGMENTED BY PLAN TIER
-- ============================================================================
/*
Purpose:
    Do Enterprise entry accounts retain better at Month 1 and Month 3?
    Hypothesis H4: Enterprise plan cohorts show longer survival.

    Method: For each cohort, calculate the proportion of accounts
    by plan_tier from cohort_base, then weight survival accordingly.
    Since retention matrix is at cohort level (not account level),
    we cross-reference cohort_base for the plan split.
*/

WITH cohort_plan_metrics AS (
    SELECT
        cb.cohort_month,
        cb.plan_tier,
        COUNT(cb.account_id)                        AS accounts,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
            / NULLIF(COUNT(cb.account_id), 0) * 100, 1
        )                                           AS churn_rate_pct,
        ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_reactivated = TRUE)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS reactivation_rate_pct
    FROM cohort_base cb
    GROUP BY cb.cohort_month, cb.plan_tier
)

SELECT
    plan_tier,
    COUNT(DISTINCT cohort_month)                    AS cohorts,
    SUM(accounts)                                   AS total_accounts,
    ROUND(AVG(churn_rate_pct), 1)                   AS avg_churn_rate_pct,
    ROUND(AVG(avg_months_to_first_churn), 1)        AS avg_months_to_first_churn,
    ROUND(AVG(reactivation_rate_pct), 1)            AS avg_reactivation_rate_pct,
    ROUND(
        AVG(churn_rate_pct) - 70.4, 1
    )                                               AS gap_vs_overall_avg
FROM cohort_plan_metrics
GROUP BY plan_tier
ORDER BY avg_churn_rate_pct ASC;


-- ============================================================================
-- EXPLORATORY 8: SURVIVAL CURVE SEGMENTED BY REFERRAL SOURCE
-- ============================================================================
/*
Purpose:
    Does ads channel show better cohort survival than organic?
    Hypothesis H3 test — channel quality → cohort retention quality.

    Method: For each cohort, use cohort_base to get referral_source
    composition, then compute survival metrics per source.
*/

WITH source_survival AS (
    SELECT
        cb.referral_source,
        cb.cohort_month,
        COUNT(cb.account_id)                        AS accounts,
        ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_churned = FALSE)::NUMERIC
            / NULLIF(COUNT(cb.account_id), 0) * 100, 1
        )                                           AS never_churned_pct,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 1)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month1,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 3)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month3
    FROM cohort_base cb
    GROUP BY cb.referral_source, cb.cohort_month
)

SELECT
    referral_source,
    COUNT(DISTINCT cohort_month)                    AS cohorts,
    SUM(accounts)                                   AS total_accounts,
    ROUND(AVG(never_churned_pct), 1)                AS avg_never_churned_pct,
    ROUND(AVG(avg_months_to_first_churn), 1)        AS avg_months_to_first_churn,
    ROUND(AVG(pct_churned_by_month1), 1)            AS avg_pct_churned_by_month1,
    ROUND(AVG(pct_churned_by_month3), 1)            AS avg_pct_churned_by_month3,
    RANK() OVER (
        ORDER BY AVG(avg_months_to_first_churn) DESC
    )                                               AS survival_rank
FROM source_survival
GROUP BY referral_source
ORDER BY avg_months_to_first_churn DESC;


-- ============================================================================
-- EXPLORATORY 9: MONTH-BY-MONTH COHORT HEATMAP INPUTS
-- ============================================================================
/*
Purpose:
    Generate the full retention matrix in a format optimized
    for Power BI heatmap rendering.
    One row per cohort × month with both retention and survival.
*/

SELECT
    crm.cohort_month,
    crm.cohort_size,
    crm.months_since_signup,
    crm.activity_month,
    crm.active_accounts,
    crm.retention_rate_pct,
    css.surviving_accounts,
    css.survival_rate_pct,
    css.churned_by_month_n,
    css.cumulative_churn_rate_pct,

    -- Reactivation gap at this month
    ROUND(
        crm.retention_rate_pct
        - css.survival_rate_pct, 1
    )                                               AS reactivation_gap,

    -- Cohort year label
    CASE
        WHEN EXTRACT(YEAR FROM crm.cohort_month) = 2023
                                                    THEN '2023'
        ELSE                                             '2024'
    END                                             AS cohort_year,

    -- Retention severity
    CASE
        WHEN crm.retention_rate_pct >= 90          THEN 'excellent'
        WHEN crm.retention_rate_pct >= 70          THEN 'good'
        WHEN crm.retention_rate_pct >= 50          THEN 'moderate'
        WHEN crm.retention_rate_pct >= 30          THEN 'poor'
        ELSE                                             'critical'
    END                                             AS retention_tier,

    -- Survival severity
    CASE
        WHEN css.survival_rate_pct >= 80           THEN 'excellent'
        WHEN css.survival_rate_pct >= 60           THEN 'good'
        WHEN css.survival_rate_pct >= 40           THEN 'moderate'
        WHEN css.survival_rate_pct >= 20           THEN 'poor'
        ELSE                                             'critical'
    END                                             AS survival_tier

FROM cohort_retention_matrix crm
JOIN cohort_survival_curve css
    ON  crm.cohort_month        = css.cohort_month
    AND crm.months_since_signup = css.months_since_signup
ORDER BY crm.cohort_month, crm.months_since_signup;


-- ============================================================================
-- EXPLORATORY 10: MEDIAN SURVIVAL MONTH PER COHORT
-- ============================================================================
/*
Purpose:
    At what month does each cohort cross 50% survival?
    Identifies the median customer lifetime per cohort.
    Confirms deterioration trend across 2023 → 2024.
*/

WITH survival_with_lag AS (
    SELECT
        cohort_month,
        cohort_size,
        months_since_signup,
        survival_rate_pct,
        LAG(survival_rate_pct) OVER (
            PARTITION BY cohort_month
            ORDER BY months_since_signup
        )                                           AS prev_survival_rate
    FROM cohort_survival_curve
)

SELECT
    cohort_month,
    cohort_size,
    MIN(months_since_signup)                        AS median_survival_month,
    MAX(survival_rate_pct)
        FILTER (
            WHERE survival_rate_pct >= 50
        )                                           AS last_survival_above_50,
    MIN(survival_rate_pct)
        FILTER (
            WHERE survival_rate_pct < 50
        )                                           AS first_survival_below_50,
    CASE
        WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023'
        ELSE                                             '2024'
    END                                             AS cohort_year
FROM survival_with_lag
WHERE survival_rate_pct < 50
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_cohort_month1_deep_dive
-- ============================================================================
/*
Purpose:
    Month 1 retention and survival for every cohort.
    The most important single-month comparison in cohort analysis.
    Shows both retention matrix (reactivation-inclusive) and
    survival curve (first-churn-inclusive) side by side.

Dashboard:
    Page 7 — Cohort Retention
    Visual: Bar chart — Month 1 retention vs survival per cohort
*/

DROP VIEW IF EXISTS analysis_cohort_month1_deep_dive;
CREATE VIEW analysis_cohort_month1_deep_dive AS

SELECT
    crm.cohort_month,
    crm.cohort_size,
    crm.active_accounts                             AS m1_active_accounts,
    crm.retention_rate_pct                          AS m1_retention_pct,
    css.surviving_accounts                          AS m1_surviving_accounts,
    css.survival_rate_pct                           AS m1_survival_pct,
    css.churned_by_month_n                          AS m1_churned_accounts,
    css.cumulative_churn_rate_pct                   AS m1_cumulative_churn_pct,

    -- Reactivation gap at Month 1
    ROUND(
        crm.retention_rate_pct
        - css.survival_rate_pct, 1
    )                                               AS m1_reactivation_gap,

    -- Cohort year
    CASE
        WHEN EXTRACT(YEAR FROM crm.cohort_month) = 2023
                                                    THEN '2023'
        ELSE                                             '2024'
    END                                             AS cohort_year,

    -- Month 1 retention tier
    CASE
        WHEN crm.retention_rate_pct >= 90           THEN 'excellent (90%+)'
        WHEN crm.retention_rate_pct >= 70           THEN 'good (70-90%)'
        WHEN crm.retention_rate_pct >= 50           THEN 'moderate (50-70%)'
        ELSE                                             'poor (<50%)'
    END                                             AS m1_retention_tier,

    -- Month 1 survival tier
    CASE
        WHEN css.survival_rate_pct >= 90            THEN 'excellent (90%+)'
        WHEN css.survival_rate_pct >= 70            THEN 'good (70-90%)'
        WHEN css.survival_rate_pct >= 50            THEN 'moderate (50-70%)'
        ELSE                                             'poor (<50%)'
    END                                             AS m1_survival_tier,

    -- Rank by retention
    RANK() OVER (
        ORDER BY crm.retention_rate_pct DESC
    )                                               AS retention_rank,

    -- Rank by survival
    RANK() OVER (
        ORDER BY css.survival_rate_pct DESC
    )                                               AS survival_rank

FROM cohort_retention_matrix crm
JOIN cohort_survival_curve css
    ON  crm.cohort_month        = css.cohort_month
    AND crm.months_since_signup = css.months_since_signup
WHERE crm.months_since_signup = 1
ORDER BY crm.cohort_month;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_cohort_year_comparison
-- ============================================================================
/*
Purpose:
    2023 vs 2024 cohort comparison on retention and survival
    at months 0, 1, 2, 3, 6 (only where both years have data).

Dashboard:
    Page 7 — Cohort Retention
    Visual: Grouped bar — 2023 vs 2024 retention + survival by month N
*/

DROP VIEW IF EXISTS analysis_cohort_year_comparison;
CREATE VIEW analysis_cohort_year_comparison AS

WITH retention_agg AS (
    SELECT
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END                                         AS cohort_year,
        months_since_signup,
        COUNT(DISTINCT cohort_month)                AS cohort_count,
        SUM(cohort_size)                            AS total_accounts,
        ROUND(AVG(retention_rate_pct), 1)           AS avg_retention_pct,
        ROUND(MIN(retention_rate_pct), 1)           AS min_retention_pct,
        ROUND(MAX(retention_rate_pct), 1)           AS max_retention_pct
    FROM cohort_retention_matrix
    GROUP BY
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END,
        months_since_signup
),

survival_agg AS (
    SELECT
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END                                         AS cohort_year,
        months_since_signup,
        ROUND(AVG(survival_rate_pct), 1)            AS avg_survival_pct,
        ROUND(MIN(survival_rate_pct), 1)            AS min_survival_pct,
        ROUND(MAX(survival_rate_pct), 1)            AS max_survival_pct,
        ROUND(AVG(cumulative_churn_rate_pct), 1)    AS avg_cumulative_churn_pct
    FROM cohort_survival_curve
    GROUP BY
        CASE
            WHEN EXTRACT(YEAR FROM cohort_month) = 2023
                                                    THEN '2023 cohorts'
            ELSE                                         '2024 cohorts'
        END,
        months_since_signup
)

SELECT
    r.cohort_year,
    r.months_since_signup,
    r.cohort_count,
    r.total_accounts,
    r.avg_retention_pct,
    r.min_retention_pct,
    r.max_retention_pct,
    s.avg_survival_pct,
    s.min_survival_pct,
    s.max_survival_pct,
    s.avg_cumulative_churn_pct,
    ROUND(
        r.avg_retention_pct - s.avg_survival_pct, 1
    )                                               AS avg_reactivation_gap
FROM retention_agg r
JOIN survival_agg s
    ON  r.cohort_year           = s.cohort_year
    AND r.months_since_signup   = s.months_since_signup
WHERE r.months_since_signup IN (0, 1, 2, 3, 6, 9, 12)
ORDER BY r.months_since_signup, r.cohort_year;


-- ============================================================================
-- DASHBOARD VIEW 3: analysis_cohort_survival_segmented
-- ============================================================================
/*
Purpose:
    Cohort survival metrics segmented by key dimensions.
    Feeds segmented survival comparison on dashboard.

Dashboard:
    Page 7 — Cohort Retention
    Visual: Grouped bar — survival metrics by plan/channel/industry
*/

DROP VIEW IF EXISTS analysis_cohort_survival_segmented;
CREATE VIEW analysis_cohort_survival_segmented AS

WITH plan_segment AS (
    SELECT
        'plan_tier'                                 AS segment_type,
        cb.plan_tier                                AS segment_value,
        COUNT(cb.account_id)                        AS total_accounts,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_churned = FALSE)::NUMERIC
            / NULLIF(COUNT(cb.account_id), 0) * 100, 1
        )                                           AS never_churned_pct,
        ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 1)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month1,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 3)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month3,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_reactivated = TRUE)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS reactivation_rate_pct
    FROM cohort_base cb
    GROUP BY cb.plan_tier
),

channel_segment AS (
    SELECT
        'referral_source'                           AS segment_type,
        cb.referral_source                          AS segment_value,
        COUNT(cb.account_id)                        AS total_accounts,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_churned = FALSE)::NUMERIC
            / NULLIF(COUNT(cb.account_id), 0) * 100, 1
        )                                           AS never_churned_pct,
        ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 1)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month1,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 3)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month3,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_reactivated = TRUE)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS reactivation_rate_pct
    FROM cohort_base cb
    GROUP BY cb.referral_source
),

industry_segment AS (
    SELECT
        'industry'                                  AS segment_type,
        cb.industry                                 AS segment_value,
        COUNT(cb.account_id)                        AS total_accounts,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_churned = FALSE)::NUMERIC
            / NULLIF(COUNT(cb.account_id), 0) * 100, 1
        )                                           AS never_churned_pct,
        ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 1)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month1,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.months_to_first_churn <= 3)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS pct_churned_by_month3,
        ROUND(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_reactivated = TRUE)::NUMERIC
            / NULLIF(
                COUNT(cb.account_id)
                    FILTER (WHERE cb.ever_churned = TRUE),
                0
            ) * 100, 1
        )                                           AS reactivation_rate_pct
    FROM cohort_base cb
    GROUP BY cb.industry
)

SELECT * FROM plan_segment
UNION ALL
SELECT * FROM channel_segment
UNION ALL
SELECT * FROM industry_segment
ORDER BY segment_type, never_churned_pct DESC;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: Month 1 deep dive covers all cohorts with Month 1 data
SELECT
    COUNT(DISTINCT cohort_month)        AS cohorts_with_month1,
    MIN(cohort_month)                   AS earliest_cohort,
    MAX(cohort_month)                   AS latest_cohort
FROM analysis_cohort_month1_deep_dive;
-- Dec 2024 cohort should NOT appear (no Month 1 data yet)

-- V2: Retention rank and survival rank should not always match
-- Confirms the retention/survival paradox
SELECT
    cohort_month,
    m1_retention_pct,
    m1_survival_pct,
    retention_rank,
    survival_rank,
    ABS(retention_rank - survival_rank) AS rank_divergence
FROM analysis_cohort_month1_deep_dive
ORDER BY rank_divergence DESC
LIMIT 10;
-- Cohorts where retention rank != survival rank = reactivation masking

-- V3: Year comparison — 2023 should have more Month 6+ data than 2024
SELECT
    cohort_year,
    months_since_signup,
    cohort_count
FROM analysis_cohort_year_comparison
ORDER BY months_since_signup, cohort_year;

-- V4: Segmented survival totals = 500 per segment type
SELECT
    segment_type,
    SUM(total_accounts)                 AS total
FROM analysis_cohort_survival_segmented
GROUP BY segment_type;
-- Each segment_type should sum to 500

-- V5: Reactivation gap always positive (retention >= survival)
SELECT *
FROM (
    SELECT
        cohort_month,
        months_since_signup,
        retention_rate_pct,
        survival_rate_pct,
        ROUND(retention_rate_pct - survival_rate_pct, 1) AS gap
    FROM cohort_retention_matrix crm
    JOIN cohort_survival_curve css
        USING (cohort_month, months_since_signup)
) g
WHERE gap < -1.0;
-- Should return 0 rows (rounding tolerance of -1.0)

-- V6: Preview all dashboard views
SELECT * FROM analysis_cohort_month1_deep_dive
    ORDER BY cohort_month;
SELECT * FROM analysis_cohort_year_comparison
    ORDER BY months_since_signup, cohort_year;
SELECT * FROM analysis_cohort_survival_segmented
    ORDER BY segment_type, never_churned_pct DESC;