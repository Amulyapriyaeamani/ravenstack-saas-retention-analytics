/*
===============================================================================
FILE: 20_churn_segmentation.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Segments churn across four business dimensions:
    - Plan tier (Basic vs Pro vs Enterprise)
    - Industry (which verticals churn most)
    - Country (geographic patterns)
    - Referral source (channel quality — cross-validates Step 16)

SOURCE
------------------------------------------------------------------------------
Primary sources:
    cohort_base          → segmentation dimensions + churn behavior
    base_churn_monthly   → monthly churn events with reason_code
    base_active_monthly  → active account population for denominators
    kpi_monthly_churn_rate → overall churn baseline for comparison

cohort_base already contains:
    plan_tier, industry, country, referral_source
    ever_churned, churn_count, months_to_first_churn

No complex joins needed — cohort_base is the segmentation spine.

HYPOTHESES
------------------------------------------------------------------------------
H1: Enterprise accounts churn less than Basic and Pro.
    Higher financial commitment = stronger retention motivation.
    Enterprise also has dedicated onboarding in most SaaS products.

H2: Certain industries (e.g. EdTech, early-stage startups)
    show significantly higher churn than others (e.g. FinTech, DevTools).

H3: Churn rates vary meaningfully by country —
    geographic markets have different product-market fit levels.

H4: Referral source churn segmentation confirms Step 16 findings:
    ads best quality, partner worst quality.
    (This is a cross-validation check, not a new hypothesis.)

DESIGN NOTE
------------------------------------------------------------------------------
Every segmentation section follows the same pattern:
    1. Churn rate for that dimension
    2. Average months to first churn (survival quality)
    3. Churn count distribution (instability measure)
    4. Never-churned proportion (loyal base per segment)

This consistency makes the sections directly comparable.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 3 — Churn Analysis

    analysis_churn_by_plan       → plan tier churn bar chart
    analysis_churn_by_industry   → industry churn ranked chart
    analysis_churn_by_country    → country churn map/bar chart

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: CHURN BY PLAN TIER
-- ============================================================================
/*
Purpose:
    Does entry plan tier predict churn behavior?
    Enterprise expected to churn less due to higher commitment.
    Basic expected to churn most due to lower cost and commitment.

Note:
    plan_tier = ENTRY plan from accounts table.
    Not current plan — accounts may have changed plans since signup.
    This measures whether starting plan predicts long-term retention.
*/

SELECT
    plan_tier,
    COUNT(account_id)                               AS total_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = TRUE)          AS churned_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = FALSE)         AS never_churned_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    COUNT(account_id)
        FILTER (WHERE ever_reactivated = TRUE)      AS reactivated_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_reactivated = TRUE)::NUMERIC
        / NULLIF(
            COUNT(account_id)
                FILTER (WHERE ever_churned = TRUE),
            0
        ) * 100, 1
    )                                               AS reactivation_rate_pct
FROM cohort_base
GROUP BY plan_tier
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- EXPLORATORY 2: PLAN TIER CHURN TREND OVER TIME
-- ============================================================================
/*
Purpose:
    Is plan tier churn stable or has the relative ranking shifted?
    Did Enterprise churn rate worsen in H2 2024 matching overall trend?
*/

SELECT
    DATE_TRUNC('month', bcm.churn_date)::DATE       AS churn_month,
    cb.plan_tier,
    COUNT(DISTINCT bcm.account_id)                  AS churned_accounts
FROM base_churn_monthly bcm
JOIN cohort_base cb
    ON bcm.account_id = cb.account_id
GROUP BY
    DATE_TRUNC('month', bcm.churn_date)::DATE,
    cb.plan_tier
ORDER BY churn_month, plan_tier;


-- ============================================================================
-- EXPLORATORY 3: CHURN BY INDUSTRY
-- ============================================================================
/*
Purpose:
    Which SaaS verticals churn most?
    Are certain industries structurally better fits for the product?

Hypothesis:
    Industries with longer sales cycles or higher switching costs
    (FinTech, Healthcare) may show better retention.
    Fast-moving verticals (EdTech, early-stage) may show higher churn.
*/

SELECT
    industry,
    COUNT(account_id)                               AS total_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = TRUE)          AS churned_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = FALSE)         AS never_churned_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_reactivated = TRUE)::NUMERIC
        / NULLIF(
            COUNT(account_id)
                FILTER (WHERE ever_churned = TRUE),
            0
        ) * 100, 1
    )                                               AS reactivation_rate_pct,
    -- Plan mix within industry
    COUNT(account_id)
        FILTER (WHERE plan_tier = 'Basic')          AS basic_accounts,
    COUNT(account_id)
        FILTER (WHERE plan_tier = 'Pro')            AS pro_accounts,
    COUNT(account_id)
        FILTER (WHERE plan_tier = 'Enterprise')     AS enterprise_accounts
FROM cohort_base
GROUP BY industry
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- EXPLORATORY 4: CHURN BY COUNTRY
-- ============================================================================
/*
Purpose:
    Geographic churn distribution.
    High churn in specific countries may indicate:
        - Language/localization gaps
        - Payment method issues
        - Support timezone mismatch
        - Weaker product-market fit in that market

Show only countries with >= 5 accounts
for statistical stability.
*/

SELECT
    country,
    COUNT(account_id)                               AS total_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = TRUE)          AS churned_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = FALSE)         AS never_churned_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn
FROM cohort_base
GROUP BY country
HAVING COUNT(account_id) >= 5
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- EXPLORATORY 5: CHURN BY REFERRAL SOURCE
-- ============================================================================
/*
Purpose:
    Cross-validate Step 16 channel quality findings using
    a different analytical lens.
    Step 16 used cohort_base directly.
    This step uses monthly churn events to add temporal context.

Hypothesis:
    Ads has lowest churn rate (already confirmed in Step 16 = 60.2%).
    Partner has highest churn rate (already confirmed = 75.3%).
    No new hypothesis — this is a cross-validation check.
*/

SELECT
    referral_source,
    COUNT(account_id)                               AS total_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = TRUE)          AS churned_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    -- Overall rank (lower churn = rank 1)
    RANK() OVER (
        ORDER BY
            COUNT(account_id)
                FILTER (WHERE ever_churned = TRUE)::NUMERIC
            / NULLIF(COUNT(account_id), 0)
    )                                               AS quality_rank
FROM cohort_base
GROUP BY referral_source
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- EXPLORATORY 6: CROSS-DIMENSION CHURN MATRIX
-- ============================================================================
/*
Purpose:
    Plan tier × industry interaction.
    Which plan + industry combinations churn most?
    This is the Level 4 cross-dimensional insight.

    Example: Enterprise accounts in one industry may churn at 90%
    while Enterprise accounts in another churn at 30%.
    Summary statistics would hide this difference.
*/

SELECT
    plan_tier,
    industry,
    COUNT(account_id)                               AS total_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn
FROM cohort_base
GROUP BY plan_tier, industry
HAVING COUNT(account_id) >= 3
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_churn_by_plan
-- ============================================================================
/*
Purpose:
    Plan tier churn comparison for dashboard bar chart.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Horizontal bar chart — churn rate by plan tier
*/

DROP VIEW IF EXISTS analysis_churn_by_plan;
CREATE VIEW analysis_churn_by_plan AS

SELECT
    plan_tier,
    COUNT(account_id)                               AS total_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = TRUE)          AS churned_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = FALSE)         AS never_churned_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_reactivated = TRUE)::NUMERIC
        / NULLIF(
            COUNT(account_id)
                FILTER (WHERE ever_churned = TRUE),
            0
        ) * 100, 1
    )                                               AS reactivation_rate_pct,
    -- Benchmark gap
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100
        - 70.4,
        1
    )                                               AS gap_vs_overall_avg
FROM cohort_base
GROUP BY plan_tier
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_churn_by_industry
-- ============================================================================
/*
Purpose:
    Industry churn ranking for dashboard chart.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Ranked horizontal bar chart — churn rate by industry
*/

DROP VIEW IF EXISTS analysis_churn_by_industry;
CREATE VIEW analysis_churn_by_industry AS

SELECT
    industry,
    COUNT(account_id)                               AS total_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = TRUE)          AS churned_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = FALSE)         AS never_churned_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    -- Distance from overall average
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100
        - 70.4,
        1
    )                                               AS gap_vs_overall_avg,
    -- Industry rank (lower churn = rank 1)
    RANK() OVER (
        ORDER BY
            COUNT(account_id)
                FILTER (WHERE ever_churned = TRUE)::NUMERIC
            / NULLIF(COUNT(account_id), 0)
    )                                               AS industry_rank
FROM cohort_base
GROUP BY industry
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- DASHBOARD VIEW 3: analysis_churn_by_country
-- ============================================================================
/*
Purpose:
    Country-level churn for geographic analysis.
    Only countries with >= 5 accounts for statistical stability.

Dashboard:
    Page 3 — Churn Analysis
    Visual: Map or ranked bar — churn rate by country
*/

DROP VIEW IF EXISTS analysis_churn_by_country;
CREATE VIEW analysis_churn_by_country AS

SELECT
    country,
    COUNT(account_id)                               AS total_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = TRUE)          AS churned_accounts,
    COUNT(account_id)
        FILTER (WHERE ever_churned = FALSE)         AS never_churned_accounts,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    -- Distance from overall average
    ROUND(
        COUNT(account_id)
            FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100
        - 70.4,
        1
    )                                               AS gap_vs_overall_avg,
    RANK() OVER (
        ORDER BY
            COUNT(account_id)
                FILTER (WHERE ever_churned = TRUE)::NUMERIC
            / NULLIF(COUNT(account_id), 0)
    )                                               AS country_rank
FROM cohort_base
GROUP BY country
HAVING COUNT(account_id) >= 5
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: Plan tier totals must sum to 500
SELECT
    SUM(total_accounts)     AS total_from_plans,
    500                     AS expected
FROM analysis_churn_by_plan;

-- V2: churned_accounts per plan must sum to 352
SELECT
    SUM(churned_accounts)   AS total_churned_from_plans,
    352                     AS expected
FROM analysis_churn_by_plan;

-- V3: Industry totals must sum to 500
SELECT
    SUM(total_accounts)     AS total_from_industries
FROM analysis_churn_by_industry;

-- V4: Country view — confirm only countries with >= 5 accounts
SELECT *
FROM analysis_churn_by_country
WHERE total_accounts < 5;
-- Should return 0 rows

-- V5: Cross-validation against Step 16 referral source quality
-- ads churn rate should = 60.2%, partner = 75.3%
SELECT
    referral_source,
    churn_rate_pct,
    quality_rank
FROM (
    SELECT
        referral_source,
        ROUND(
            COUNT(account_id)
                FILTER (WHERE ever_churned = TRUE)::NUMERIC
            / NULLIF(COUNT(account_id), 0) * 100, 1
        )                               AS churn_rate_pct,
        RANK() OVER (
            ORDER BY
                COUNT(account_id)
                    FILTER (WHERE ever_churned = TRUE)::NUMERIC
                / NULLIF(COUNT(account_id), 0)
        )                               AS quality_rank
    FROM cohort_base
    GROUP BY referral_source
) r
ORDER BY quality_rank;
-- ads must rank 1, partner must rank 5

-- V6: Preview all dashboard views
SELECT * FROM analysis_churn_by_plan        ORDER BY churn_rate_pct;
SELECT * FROM analysis_churn_by_industry    ORDER BY churn_rate_pct;
SELECT * FROM analysis_churn_by_country     ORDER BY churn_rate_pct;