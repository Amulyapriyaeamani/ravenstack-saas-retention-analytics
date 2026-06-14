/*
===============================================================================
FILE: 22_feature_adoption_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Analyzes feature adoption patterns across the 40-feature product.

Covers:
    - Most and least adopted features (by adoption rate and intensity)
    - Beta vs GA adoption comparison
    - Feature engagement depth vs breadth
    - Feature sprawl quantification
    - Adoption trend over time per feature

SOURCE
------------------------------------------------------------------------------
Primary sources:
    kpi_monthly_feature_adoption      → per-feature monthly adoption (already built)
    base_feature_usage_monthly        → usage intensity data
    base_active_monthly               → active account denominator

kpi_monthly_feature_adoption already contains:
    month, feature_name, is_beta_feature
    adopted_accounts, total_active_accounts
    feature_adoption_rate_pct
    total_usage_count, avg_usage_per_adopter

This step adds:
    - Cross-month aggregation and feature ranking
    - Depth vs breadth quadrant classification
    - Beta vs GA quality comparison
    - Feature adoption trend direction
    - Underperformer identification

HYPOTHESES
------------------------------------------------------------------------------
H1: No single feature reaches 10% average monthly adoption.
    Feature sprawl is the core engagement problem — 40 features
    competing for attention, none reaching critical mass.
    (Early signal: top feature at 5.05% vs 20-40% benchmark)

H2: Beta features have lower adoption than GA features
    but identical usage intensity once adopted.
    Problem is discoverability, not quality.
    (Confirmed in base layer: 4.3x lower adoption, same intensity)

H3: Features can be classified into four archetypes:
    Core (high breadth + high depth)
    Specialist (low breadth + high depth)
    Awareness (high breadth + low depth)
    Dead (low breadth + low depth)

H4: The bottom 10 features collectively account for
    less than 5% of total usage — candidate for sunset or redesign.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 4 — Feature Usage

    analysis_feature_adoption_ranked    → ranked bar chart
    analysis_feature_breadth_depth      → scatter plot quadrant

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: FEATURE ADOPTION SUMMARY — ALL 40 FEATURES
-- ============================================================================
/*
Purpose:
    Full ranked view of all 40 features by adoption rate.
    Foundation for all downstream analysis.

Hypothesis:
    Top feature below 10% avg adoption.
    Clear spread from top to bottom — no cluster at high adoption.
*/

SELECT
    feature_name,
    is_beta_feature,

    -- Adoption breadth
    ROUND(AVG(feature_adoption_rate_pct), 2)        AS avg_adoption_rate_pct,
    MAX(feature_adoption_rate_pct)                  AS peak_adoption_rate_pct,
    COUNT(DISTINCT month)
        FILTER (WHERE adopted_accounts > 0)         AS months_with_adoption,

    -- Adoption depth (intensity)
    ROUND(AVG(avg_usage_per_adopter), 2)            AS avg_usage_per_adopter,
    SUM(total_usage_count)                          AS total_usage_count,
    ROUND(
        SUM(total_usage_count)::NUMERIC
        / NULLIF(SUM(adopted_accounts), 0), 2
    )                                               AS weighted_avg_usage_per_adopter,

    -- Account reach
    COUNT(DISTINCT month)                           AS total_months_observed,
    MAX(adopted_accounts)                           AS peak_adopted_accounts,

    -- Usage share of total
    ROUND(
        SUM(total_usage_count)::NUMERIC
        / SUM(SUM(total_usage_count)) OVER ()
        * 100, 2
    )                                               AS pct_of_total_usage,

    -- Overall rank by adoption rate
    RANK() OVER (
        ORDER BY AVG(feature_adoption_rate_pct) DESC
    )                                               AS adoption_rank,

    -- Overall rank by usage volume
    RANK() OVER (
        ORDER BY SUM(total_usage_count) DESC
    )                                               AS usage_rank

FROM kpi_monthly_feature_adoption
GROUP BY feature_name, is_beta_feature
ORDER BY avg_adoption_rate_pct DESC;


-- ============================================================================
-- EXPLORATORY 2: TOP 10 VS BOTTOM 10 FEATURES
-- ============================================================================
/*
Purpose:
    Identify clear top performers and underperformers.
    Bottom features = candidates for sunset, redesign, or consolidation.

Hypothesis H4:
    Bottom 10 features collectively < 5% of total usage.
*/

WITH feature_summary AS (
    SELECT
        feature_name,
        is_beta_feature,
        ROUND(AVG(feature_adoption_rate_pct), 2)    AS avg_adoption_rate_pct,
        SUM(total_usage_count)                      AS total_usage_count,
        ROUND(AVG(avg_usage_per_adopter), 2)        AS avg_usage_per_adopter,
        RANK() OVER (
            ORDER BY AVG(feature_adoption_rate_pct) DESC
        )                                           AS adoption_rank
    FROM kpi_monthly_feature_adoption
    GROUP BY feature_name, is_beta_feature
)

-- Top 10
SELECT
    'top 10'                                        AS feature_tier,
    feature_name,
    is_beta_feature,
    avg_adoption_rate_pct,
    total_usage_count,
    avg_usage_per_adopter,
    adoption_rank
FROM feature_summary
WHERE adoption_rank <= 10

UNION ALL

-- Bottom 10
SELECT
    'bottom 10'                                     AS feature_tier,
    feature_name,
    is_beta_feature,
    avg_adoption_rate_pct,
    total_usage_count,
    avg_usage_per_adopter,
    adoption_rank
FROM feature_summary
WHERE adoption_rank > (
    SELECT MAX(adoption_rank) - 10
    FROM feature_summary
)

ORDER BY feature_tier, adoption_rank;


-- ============================================================================
-- EXPLORATORY 3: DEPTH VS BREADTH CLASSIFICATION
-- ============================================================================
/*
Purpose:
    Classify each feature into one of four archetypes
    based on adoption rate (breadth) and usage intensity (depth).

    Quadrant definitions:
    Core:       breadth >= median AND depth >= median
    Specialist: breadth < median AND depth >= median
    Awareness:  breadth >= median AND depth < median
    Dead:       breadth < median AND depth < median

Hypothesis H3:
    Four distinct archetypes visible.
    Core features are the retention anchors.
    Dead features are sunset candidates.
*/

WITH feature_metrics AS (
    SELECT
        feature_name,
        is_beta_feature,
        ROUND(AVG(feature_adoption_rate_pct), 2)    AS avg_adoption_rate_pct,
        ROUND(
            SUM(total_usage_count)::NUMERIC
            / NULLIF(SUM(adopted_accounts), 0), 2
        )                                           AS weighted_usage_per_adopter,
        SUM(total_usage_count)                      AS total_usage_count
    FROM kpi_monthly_feature_adoption
    GROUP BY feature_name, is_beta_feature
),

medians AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY avg_adoption_rate_pct
        )                                           AS median_adoption,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY weighted_usage_per_adopter
        )                                           AS median_depth
    FROM feature_metrics
)

SELECT
    f.feature_name,
    f.is_beta_feature,
    f.avg_adoption_rate_pct,
    f.weighted_usage_per_adopter,
    f.total_usage_count,
    m.median_adoption,
    m.median_depth,

    -- Quadrant classification
    CASE
        WHEN f.avg_adoption_rate_pct >= m.median_adoption
         AND f.weighted_usage_per_adopter >= m.median_depth
                                                    THEN 'core'
        WHEN f.avg_adoption_rate_pct < m.median_adoption
         AND f.weighted_usage_per_adopter >= m.median_depth
                                                    THEN 'specialist'
        WHEN f.avg_adoption_rate_pct >= m.median_adoption
         AND f.weighted_usage_per_adopter < m.median_depth
                                                    THEN 'awareness'
        ELSE                                             'dead'
    END                                             AS feature_archetype

FROM feature_metrics f
CROSS JOIN medians m
ORDER BY feature_archetype, f.avg_adoption_rate_pct DESC;


-- ============================================================================
-- EXPLORATORY 4: BETA VS GA DETAILED COMPARISON
-- ============================================================================
/*
Purpose:
    Confirm H2: beta lower adoption but identical intensity.
    Quality is not the problem — discoverability is.

Metrics compared:
    - Average adoption rate
    - Average usage per adopter
    - Total usage count
    - Error rate (errors per usage event)
    - Peak adoption month
*/

SELECT
    is_beta_feature,
    COUNT(DISTINCT feature_name)                    AS distinct_features,
    ROUND(AVG(feature_adoption_rate_pct), 2)        AS avg_adoption_rate_pct,
    ROUND(
        SUM(total_usage_count)::NUMERIC
        / NULLIF(SUM(adopted_accounts), 0), 2
    )                                               AS weighted_avg_usage_per_adopter,
    SUM(total_usage_count)                          AS total_usage_count,
    ROUND(
        SUM(total_usage_count)::NUMERIC
        / NULLIF(
            (SELECT SUM(total_usage_count)
             FROM kpi_monthly_feature_adoption),
            0
        ) * 100, 1
    )                                               AS pct_of_total_usage,
    ROUND(
        AVG(
            (SELECT SUM(f2.total_errors)::NUMERIC
                    / NULLIF(SUM(f2.total_usage_count), 0)
             FROM base_feature_usage_monthly f2
             WHERE f2.feature_name = fa.feature_name
               AND f2.is_beta_feature = fa.is_beta_feature)
        ), 4
    )                                               AS avg_error_rate_per_usage

FROM kpi_monthly_feature_adoption fa
GROUP BY is_beta_feature
ORDER BY is_beta_feature;


-- ============================================================================
-- EXPLORATORY 5: FEATURE ADOPTION TREND DIRECTION
-- ============================================================================
/*
Purpose:
    Is each feature growing or declining in adoption over time?
    Compare H1 2024 adoption vs H2 2024 adoption.
    Features declining in adoption heading into launch need attention.
*/

WITH h1_adoption AS (
    SELECT
        feature_name,
        is_beta_feature,
        ROUND(AVG(feature_adoption_rate_pct), 2)    AS h1_avg_adoption
    FROM kpi_monthly_feature_adoption
    WHERE month BETWEEN '2024-01-01' AND '2024-06-01'
    GROUP BY feature_name, is_beta_feature
),

h2_adoption AS (
    SELECT
        feature_name,
        is_beta_feature,
        ROUND(AVG(feature_adoption_rate_pct), 2)    AS h2_avg_adoption
    FROM kpi_monthly_feature_adoption
    WHERE month BETWEEN '2024-07-01' AND '2024-12-01'
    GROUP BY feature_name, is_beta_feature
)

SELECT
    h1.feature_name,
    h1.is_beta_feature,
    h1.h1_avg_adoption,
    h2.h2_avg_adoption,
    ROUND(h2.h2_avg_adoption - h1.h1_avg_adoption, 2)
                                                    AS adoption_change,
    CASE
        WHEN h2.h2_avg_adoption > h1.h1_avg_adoption * 1.1
                                                    THEN 'growing'
        WHEN h2.h2_avg_adoption < h1.h1_avg_adoption * 0.9
                                                    THEN 'declining'
        ELSE                                             'stable'
    END                                             AS trend_direction
FROM h1_adoption h1
JOIN h2_adoption h2
    ON  h1.feature_name     = h2.feature_name
    AND h1.is_beta_feature  = h2.is_beta_feature
ORDER BY adoption_change DESC;


-- ============================================================================
-- EXPLORATORY 6: FEATURE SPRAWL QUANTIFICATION
-- ============================================================================
/*
Purpose:
    Quantify the feature sprawl problem with hard numbers.
    How concentrated is usage across features?
    What % of usage comes from top 10 features?

Hypothesis H1:
    Top 10 features drive majority of usage
    while bottom 20 features are nearly invisible.
*/

WITH feature_totals AS (
    SELECT
        feature_name,
        is_beta_feature,
        SUM(total_usage_count)                      AS total_usage,
        ROUND(AVG(feature_adoption_rate_pct), 2)    AS avg_adoption,
        RANK() OVER (
            ORDER BY SUM(total_usage_count) DESC
        )                                           AS usage_rank,
        SUM(SUM(total_usage_count)) OVER ()         AS grand_total_usage
    FROM kpi_monthly_feature_adoption
    GROUP BY feature_name, is_beta_feature
)

SELECT
    feature_name,
    is_beta_feature,
    total_usage,
    avg_adoption,
    usage_rank,
    ROUND(
        total_usage::NUMERIC / grand_total_usage * 100, 2
    )                                               AS pct_of_total_usage,
    ROUND(
        SUM(total_usage::NUMERIC / grand_total_usage * 100)
        OVER (ORDER BY usage_rank
              ROWS BETWEEN UNBOUNDED PRECEDING
              AND CURRENT ROW),
        2
    )                                               AS cumulative_pct,
    CASE
        WHEN usage_rank <= 10                       THEN 'top 10'
        WHEN usage_rank <= 20                       THEN 'top 20'
        WHEN usage_rank <= 30                       THEN 'top 30'
        ELSE                                             'bottom 10'
    END                                             AS usage_tier
FROM feature_totals
ORDER BY usage_rank;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_feature_adoption_ranked
-- ============================================================================
/*
Purpose:
    Ranked feature adoption for dashboard bar chart.
    Shows all 40 features sorted by adoption rate.
    Benchmark reference at 20% (industry lower bound).

Dashboard:
    Page 4 — Feature Usage
    Visual: Ranked horizontal bar chart — all 40 features
*/

DROP VIEW IF EXISTS analysis_feature_adoption_ranked;
CREATE VIEW analysis_feature_adoption_ranked AS

WITH feature_metrics AS (
    SELECT
        feature_name,
        is_beta_feature,
        ROUND(AVG(feature_adoption_rate_pct), 2)    AS avg_adoption_rate_pct,
        MAX(feature_adoption_rate_pct)              AS peak_adoption_rate_pct,
        ROUND(
            SUM(total_usage_count)::NUMERIC
            / NULLIF(SUM(adopted_accounts), 0), 2
        )                                           AS weighted_usage_per_adopter,
        SUM(total_usage_count)                      AS total_usage_count,
        ROUND(
            SUM(total_usage_count)::NUMERIC
            / SUM(SUM(total_usage_count)) OVER ()
            * 100, 2
        )                                           AS pct_of_total_usage
    FROM kpi_monthly_feature_adoption
    GROUP BY feature_name, is_beta_feature
)

SELECT
    feature_name,
    is_beta_feature,
    avg_adoption_rate_pct,
    peak_adoption_rate_pct,
    weighted_usage_per_adopter,
    total_usage_count,
    pct_of_total_usage,

    -- Benchmark gap
    ROUND(20.0 - avg_adoption_rate_pct, 2)          AS gap_to_benchmark,

    -- Adoption tier
    CASE
        WHEN avg_adoption_rate_pct >= 10            THEN 'strong (>=10%)'
        WHEN avg_adoption_rate_pct >= 5             THEN 'moderate (5-10%)'
        WHEN avg_adoption_rate_pct >= 2             THEN 'low (2-5%)'
        ELSE                                             'critical (<2%)'
    END                                             AS adoption_tier,

    RANK() OVER (
        ORDER BY avg_adoption_rate_pct DESC
    )                                               AS adoption_rank

FROM feature_metrics
ORDER BY adoption_rank;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_feature_breadth_depth
-- ============================================================================
/*
Purpose:
    Breadth vs depth quadrant for scatter plot.
    Each dot = one feature.
    Quadrant reveals feature archetype.

Dashboard:
    Page 4 — Feature Usage
    Visual: Scatter plot — adoption rate (x) vs usage intensity (y)
*/

DROP VIEW IF EXISTS analysis_feature_breadth_depth;
CREATE VIEW analysis_feature_breadth_depth AS

WITH feature_metrics AS (
    SELECT
        feature_name,
        is_beta_feature,
        ROUND(AVG(feature_adoption_rate_pct), 2)    AS avg_adoption_rate_pct,
        ROUND(
            SUM(total_usage_count)::NUMERIC
            / NULLIF(SUM(adopted_accounts), 0), 2
        )                                           AS weighted_usage_per_adopter,
        SUM(total_usage_count)                      AS total_usage_count,
        ROUND(
            SUM(total_usage_count)::NUMERIC
            / SUM(SUM(total_usage_count)) OVER ()
            * 100, 2
        )                                           AS pct_of_total_usage
    FROM kpi_monthly_feature_adoption
    GROUP BY feature_name, is_beta_feature
),

medians AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY avg_adoption_rate_pct
        )                                           AS median_adoption,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY weighted_usage_per_adopter
        )                                           AS median_depth
    FROM feature_metrics
)

SELECT
    f.feature_name,
    f.is_beta_feature,
    f.avg_adoption_rate_pct,
    f.weighted_usage_per_adopter,
    f.total_usage_count,
    f.pct_of_total_usage,
    ROUND(m.median_adoption::NUMERIC, 2)            AS median_adoption_reference,
    ROUND(m.median_depth::NUMERIC, 2)               AS median_depth_reference,

    CASE
        WHEN f.avg_adoption_rate_pct >= m.median_adoption
         AND f.weighted_usage_per_adopter >= m.median_depth
                                                    THEN 'core'
        WHEN f.avg_adoption_rate_pct < m.median_adoption
         AND f.weighted_usage_per_adopter >= m.median_depth
                                                    THEN 'specialist'
        WHEN f.avg_adoption_rate_pct >= m.median_adoption
         AND f.weighted_usage_per_adopter < m.median_depth
                                                    THEN 'awareness'
        ELSE                                             'dead'
    END                                             AS feature_archetype,

    RANK() OVER (
        ORDER BY f.avg_adoption_rate_pct DESC
    )                                               AS adoption_rank

FROM feature_metrics f
CROSS JOIN medians m
ORDER BY feature_archetype, f.avg_adoption_rate_pct DESC;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: All 40 features present in ranked view
SELECT
    COUNT(DISTINCT feature_name)            AS distinct_features,
    40                                      AS expected
FROM analysis_feature_adoption_ranked;

-- V2: Total usage count matches base layer
SELECT
    SUM(total_usage_count)                  AS ranked_view_total,
    (SELECT SUM(total_usage_count)
     FROM base_feature_usage_monthly)       AS base_layer_total
FROM analysis_feature_adoption_ranked;
-- Should be equal: both = 61,306

-- V3: Quadrant distribution — all 40 features classified
SELECT
    feature_archetype,
    COUNT(*)                                AS feature_count,
    ROUND(AVG(avg_adoption_rate_pct), 2)    AS avg_adoption,
    ROUND(AVG(weighted_usage_per_adopter), 2) AS avg_depth,
    SUM(total_usage_count)                  AS total_usage
FROM analysis_feature_breadth_depth
GROUP BY feature_archetype
ORDER BY feature_archetype;

-- V4: Beta vs GA split in ranked view
SELECT
    is_beta_feature,
    COUNT(DISTINCT feature_name)            AS feature_count,
    ROUND(AVG(avg_adoption_rate_pct), 2)    AS avg_adoption_rate,
    SUM(total_usage_count)                  AS total_usage
FROM analysis_feature_adoption_ranked
GROUP BY is_beta_feature;

-- V5: Top 10 cumulative usage % (sprawl check)
SELECT
    SUM(pct_of_total_usage)                 AS top_10_usage_pct
FROM analysis_feature_adoption_ranked
WHERE adoption_rank <= 10;

-- V6: Preview dashboard views
SELECT * FROM analysis_feature_adoption_ranked  ORDER BY adoption_rank;
SELECT * FROM analysis_feature_breadth_depth    ORDER BY feature_archetype, adoption_rank;