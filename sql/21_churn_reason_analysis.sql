/*
===============================================================================
FILE: 21_churn_reason_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Analyzes why accounts churn across five dimensions:
    - Overall reason distribution
    - Reason by plan tier (does reason vary by plan?)
    - Reason by cohort month (does reason shift over time?)
    - Unknown churn behavioral pattern (silent churners)
    - Reason vs time to churn (do some reasons churn faster?)

SOURCE
------------------------------------------------------------------------------
Primary sources:
    base_churn_monthly   → reason_code, preceding_downgrade_flag, churn_date
    cohort_base          → plan_tier, industry, months_to_first_churn,
                           ever_reactivated, churn_count
    kpi_monthly_churn_rate → monthly churn context

base_churn_monthly already contains reason_code.
No complex joins needed for core analysis.

HYPOTHESES
------------------------------------------------------------------------------
H1: Features is the top churn reason reflecting product gaps.
    (Early signal from base layer: features = 19.2% — slight lead)

H2: Churn reason varies significantly by plan tier.
    Basic may cite budget/pricing more.
    Enterprise may cite competitor or features more.

H3: Support-related churn concentrates in months with poor CSAT.
    Temporal pattern should align with kpi_monthly_support_metrics.

H4: Unknown churns (15.2%) represent silent disengaged customers
    who leave without explanation — likely low feature usage accounts.

H5: Accounts churning due to support survive fewer months
    before their first churn than accounts churning for other reasons.

DESIGN NOTE
------------------------------------------------------------------------------
reason_code values in dataset:
    features, support, budget, pricing, competitor, unknown

base_churn_monthly has one row per account per month.
Multiple churn events per account use the most recent reason_code
(as designed in 04_base_churn_monthly.sql via DISTINCT ON).

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 3 — Churn Analysis

    analysis_churn_reason_distribution → donut/bar chart
    analysis_churn_reason_by_plan      → matrix heatmap
    analysis_churn_reason_trend        → line chart over time

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: OVERALL CHURN REASON DISTRIBUTION
-- ============================================================================
/*
Purpose:
    Full picture of why accounts churn.
    Confirm the even distribution finding from base layer validation.

Hypothesis:
    Features leads at 19.2% but all reasons within 4pp of each other.
    No silver bullet — multi-front problem.
*/

SELECT
    reason_code,
    COUNT(*)                                        AS churn_events,
    COUNT(DISTINCT account_id)                      AS distinct_accounts,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER ()
        * 100, 1
    )                                               AS pct_of_total_events,
    ROUND(
        COUNT(DISTINCT account_id)::NUMERIC
        / SUM(COUNT(DISTINCT account_id)) OVER ()
        * 100, 1
    )                                               AS pct_of_distinct_accounts,

    -- Avg months to first churn for this reason
    ROUND(
        AVG(
            (SELECT cb.months_to_first_churn
             FROM cohort_base cb
             WHERE cb.account_id = bcm.account_id)
        ), 1
    )                                               AS avg_months_to_first_churn,

    -- Preceding downgrade rate for this reason
    ROUND(
        COUNT(*) FILTER (WHERE preceding_downgrade_flag = TRUE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS pct_preceded_by_downgrade,

    -- Reactivation rate for this reason
    ROUND(
        COUNT(DISTINCT account_id) FILTER (
            WHERE account_id IN (
                SELECT account_id FROM cohort_base
                WHERE ever_reactivated = TRUE
            )
        )::NUMERIC
        / NULLIF(COUNT(DISTINCT account_id), 0)
        * 100, 1
    )                                               AS reactivation_rate_pct

FROM base_churn_monthly bcm
GROUP BY reason_code
ORDER BY churn_events DESC;


-- ============================================================================
-- EXPLORATORY 2: CHURN REASON BY PLAN TIER
-- ============================================================================
/*
Purpose:
    Does churn reason vary by entry plan tier?
    Enterprise may cite competitor or features.
    Basic may cite budget or pricing.
    This determines whether interventions should be plan-specific.

Hypothesis:
    Budget and pricing disproportionate in Basic.
    Competitor and features disproportionate in Enterprise.
*/

SELECT
    cb.plan_tier,
    bcm.reason_code,
    COUNT(*)                                        AS churn_events,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER (
            PARTITION BY cb.plan_tier
        ) * 100, 1
    )                                               AS pct_within_plan,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER ()
        * 100, 1
    )                                               AS pct_of_all_churns
FROM base_churn_monthly bcm
JOIN cohort_base cb
    ON bcm.account_id = cb.account_id
GROUP BY
    cb.plan_tier,
    bcm.reason_code
ORDER BY
    cb.plan_tier,
    churn_events DESC;


-- ============================================================================
-- EXPLORATORY 3: CHURN REASON TREND OVER TIME
-- ============================================================================
/*
Purpose:
    Has the dominant churn reason shifted over time?
    If support-related churn spikes in certain months —
    cross-validate with kpi_monthly_support_metrics CSAT.

Hypothesis:
    Support-related churn concentrates in H2 2024
    when CSAT was at its lowest and escalation rate highest.
*/

WITH monthly_reason_counts AS (
    SELECT
        DATE_TRUNC('month', bcm.churn_date)::DATE AS churn_month,
        bcm.reason_code,
        COUNT(*) AS churn_events
    FROM base_churn_monthly bcm
    GROUP BY
        DATE_TRUNC('month', bcm.churn_date)::DATE,
        bcm.reason_code
)

SELECT
    churn_month,
    reason_code,
    churn_events,
    ROUND(
        churn_events::NUMERIC
        / SUM(churn_events) OVER (PARTITION BY churn_month) * 100,
        1
    ) AS pct_within_month
FROM monthly_reason_counts
ORDER BY
    churn_month,
    churn_events DESC;


-- ============================================================================
-- EXPLORATORY 4: UNKNOWN CHURN BEHAVIORAL PATTERN
-- ============================================================================
/*
Purpose:
    Who are the silent churners — accounts with reason_code = 'unknown'?
    Hypothesis H4: they are low-feature-usage accounts.
    If true → usage is a proxy for churn risk identification.

    Compare unknown churners to known-reason churners across:
        - months_to_first_churn
        - churn_count
        - plan_tier distribution
        - ever_reactivated rate
*/

WITH churned_by_reason_type AS (
    SELECT
        bcm.account_id,
        CASE
            WHEN bcm.reason_code = 'unknown' THEN 'unknown'
            ELSE 'known reason'
        END AS reason_type
    FROM base_churn_monthly bcm
)

SELECT
    crt.reason_type,

    COUNT(DISTINCT crt.account_id) AS distinct_accounts,

    ROUND(
        AVG(cb.months_to_first_churn),
        1
    ) AS avg_months_to_first_churn,

    ROUND(
        AVG(cb.churn_count),
        2
    ) AS avg_churn_events,

    ROUND(
        COUNT(DISTINCT crt.account_id)
            FILTER (WHERE cb.ever_reactivated = TRUE)::NUMERIC
        / NULLIF(COUNT(DISTINCT crt.account_id), 0)
        * 100,
        1
    ) AS reactivation_rate_pct,

    COUNT(DISTINCT crt.account_id)
        FILTER (WHERE cb.plan_tier = 'Basic') AS basic_count,

    COUNT(DISTINCT crt.account_id)
        FILTER (WHERE cb.plan_tier = 'Pro') AS pro_count,

    COUNT(DISTINCT crt.account_id)
        FILTER (WHERE cb.plan_tier = 'Enterprise') AS enterprise_count

FROM churned_by_reason_type crt
JOIN cohort_base cb
    ON crt.account_id = cb.account_id

GROUP BY crt.reason_type

ORDER BY crt.reason_type;


-- ============================================================================
-- EXPLORATORY 5: REASON VS TIME TO CHURN
-- ============================================================================
/*
Purpose:
    Do accounts citing certain reasons churn faster?
    Support-related churn may happen quickly after a bad experience.
    Competitor churn may happen slowly as alternatives are evaluated.

Hypothesis H5:
    Support churn = fastest (reactive — triggered by bad experience)
    Competitor churn = slowest (deliberate — requires evaluation period)
*/

SELECT
    bcm.reason_code,
    COUNT(DISTINCT bcm.account_id)              AS accounts,
    ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY cb.months_to_first_churn
    )                                           AS median_months_to_first_churn,
    MIN(cb.months_to_first_churn)               AS min_months,
    MAX(cb.months_to_first_churn)               AS max_months,
    ROUND(AVG(cb.churn_count), 2)               AS avg_churn_events,
    ROUND(
        COUNT(DISTINCT bcm.account_id)
            FILTER (WHERE cb.months_to_first_churn <= 1)::NUMERIC
        / NULLIF(COUNT(DISTINCT bcm.account_id), 0)
        * 100, 1
    )                                           AS pct_churned_by_month_1
FROM base_churn_monthly bcm
JOIN cohort_base cb
    ON bcm.account_id = cb.account_id
WHERE cb.months_to_first_churn IS NOT NULL
GROUP BY bcm.reason_code
ORDER BY avg_months_to_first_churn ASC;


-- ============================================================================
-- EXPLORATORY 6: REASON BY COHORT YEAR
-- ============================================================================
/*
Purpose:
    Does churn reason composition differ between
    2023 cohorts and 2024 cohorts?
    If 2024 cohorts cite features more → product gaps worsening.
    If 2024 cohorts cite support more → support quality declining.
*/

SELECT
    CASE
        WHEN cb.cohort_month < '2024-01-01'     THEN '2023 cohorts'
        ELSE                                         '2024 cohorts'
    END                                         AS cohort_year,
    bcm.reason_code,
    COUNT(*)                                    AS churn_events,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER (
            PARTITION BY
                CASE
                    WHEN cb.cohort_month < '2024-01-01'
                    THEN '2023 cohorts'
                    ELSE '2024 cohorts'
                END
        ) * 100, 1
    )                                           AS pct_within_cohort_year
FROM base_churn_monthly bcm
JOIN cohort_base cb
    ON bcm.account_id = cb.account_id
GROUP BY
    CASE
        WHEN cb.cohort_month < '2024-01-01'     THEN '2023 cohorts'
        ELSE                                         '2024 cohorts'
    END,
    bcm.reason_code
ORDER BY
    cohort_year,
    churn_events DESC;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_churn_reason_distribution
-- ============================================================================
/*
Purpose:
    Overall churn reason breakdown for donut/bar chart.
    Core visual for Page 3 churn reason section.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Donut chart — reason distribution
            Bar chart — reason with avg survival months
*/

DROP VIEW IF EXISTS analysis_churn_reason_distribution;
CREATE VIEW analysis_churn_reason_distribution AS

SELECT
    bcm.reason_code,
    COUNT(*)                                        AS churn_events,
    COUNT(DISTINCT bcm.account_id)                  AS distinct_accounts,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER ()
        * 100, 1
    )                                               AS pct_of_total,
    ROUND(
        AVG(cb.months_to_first_churn), 1
    )                                               AS avg_months_to_first_churn,
    ROUND(
        COUNT(*) FILTER (
            WHERE bcm.preceding_downgrade_flag = TRUE
        )::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS pct_preceded_by_downgrade,
    ROUND(
        COUNT(DISTINCT bcm.account_id) FILTER (
            WHERE cb.ever_reactivated = TRUE
        )::NUMERIC
        / NULLIF(COUNT(DISTINCT bcm.account_id), 0)
        * 100, 1
    )                                               AS reactivation_rate_pct,
    -- Rank by frequency
    RANK() OVER (
        ORDER BY COUNT(*) DESC
    )                                               AS frequency_rank
FROM base_churn_monthly bcm
JOIN cohort_base cb
    ON bcm.account_id = cb.account_id
GROUP BY bcm.reason_code
ORDER BY churn_events DESC;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_churn_reason_by_plan
-- ============================================================================
/*
Purpose:
    Reason × plan tier matrix for heatmap.
    Reveals whether interventions should be plan-specific.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Matrix heatmap — reason rows × plan tier columns
*/

DROP VIEW IF EXISTS analysis_churn_reason_by_plan;
CREATE VIEW analysis_churn_reason_by_plan AS

SELECT
    bcm.reason_code,
    cb.plan_tier,
    COUNT(*)                                        AS churn_events,
    COUNT(DISTINCT bcm.account_id)                  AS distinct_accounts,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER (
            PARTITION BY cb.plan_tier
        ) * 100, 1
    )                                               AS pct_within_plan,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER (
            PARTITION BY bcm.reason_code
        ) * 100, 1
    )                                               AS pct_within_reason,
    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER ()
        * 100, 1
    )                                               AS pct_of_all_churns
FROM base_churn_monthly bcm
JOIN cohort_base cb
    ON bcm.account_id = cb.account_id
GROUP BY
    bcm.reason_code,
    cb.plan_tier
ORDER BY
    bcm.reason_code,
    cb.plan_tier;


-- ============================================================================
-- DASHBOARD VIEW 3: analysis_churn_reason_trend
-- ============================================================================
/*
Purpose:
    Monthly churn reason trend for line chart.
    Reveals whether reason mix shifts over time.
    Cross-validate with support metrics for H3.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Multi-line chart — one line per reason over 24 months
*/

DROP VIEW IF EXISTS analysis_churn_reason_trend;
CREATE VIEW analysis_churn_reason_trend AS

WITH monthly_reason_counts AS (
    SELECT
        DATE_TRUNC('month', bcm.churn_date)::DATE AS churn_month,
        bcm.reason_code,
        COUNT(*) AS churn_events
    FROM base_churn_monthly bcm
    GROUP BY
        DATE_TRUNC('month', bcm.churn_date)::DATE,
        bcm.reason_code
)

SELECT
    churn_month,
    reason_code,
    churn_events,
    ROUND(
        churn_events::NUMERIC
        / SUM(churn_events) OVER (PARTITION BY churn_month) * 100,
        1
    ) AS pct_within_month
FROM monthly_reason_counts
ORDER BY
    churn_month,
    churn_events DESC;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: All reason codes covered — should be 6
SELECT
    COUNT(DISTINCT reason_code) AS distinct_reason_codes
FROM analysis_churn_reason_distribution;
-- Expected: 6

-- V2: Percentages sum to 100%
SELECT
    ROUND(SUM(pct_of_total), 1) AS total_pct
FROM analysis_churn_reason_distribution;
-- Expected: 100.0

-- V3: Plan × reason totals must match overall churns
SELECT
    SUM(churn_events)           AS total_from_plan_reason,
    (SELECT SUM(churn_events)
     FROM analysis_churn_reason_distribution)
                                AS total_from_distribution
FROM analysis_churn_reason_by_plan;
-- Should be equal

-- V4: Trend view monthly totals must match base_churn_monthly
SELECT
    t.churn_month,
    SUM(t.churn_events)         AS trend_total,
    b.churned_count             AS base_total
FROM analysis_churn_reason_trend t
JOIN (
    SELECT
        month,
        COUNT(*) AS churned_count
    FROM base_churn_monthly
    GROUP BY month
) b ON t.churn_month = b.month
GROUP BY t.churn_month, b.churned_count
HAVING SUM(t.churn_events) != b.churned_count;
-- Should return 0 rows

-- V5: Preview all dashboard views
SELECT * FROM analysis_churn_reason_distribution ORDER BY frequency_rank;
SELECT * FROM analysis_churn_reason_by_plan       ORDER BY reason_code, plan_tier;
SELECT * FROM analysis_churn_reason_trend         ORDER BY churn_month, churn_events DESC;