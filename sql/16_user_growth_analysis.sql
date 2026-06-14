/*
===============================================================================
FILE: 16_user_growth_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Analyzes user growth patterns across the 24-month dataset.

Covers:
    - Monthly signup trend and MoM growth rate
    - Referral source volume (which channels bring most signups)
    - Referral source quality (which channels bring best customers)
    - Monthly signup trend by referral source (channel mix over time)

SOURCE
------------------------------------------------------------------------------
Primary source: cohort_base (14_01)

cohort_base already contains:
    - cohort_month      → signup month
    - signup_date       → exact signup date
    - referral_source   → acquisition channel
    - ever_churned      → churn flag
    - ever_reactivated  → reactivation flag
    - churn_count       → total churn events
    - months_to_first_churn → time to first churn
    - plan_tier         → entry plan at signup

No additional joins needed for this analysis.

HYPOTHESES
------------------------------------------------------------------------------
H1: Organic and partner channels bring the most signups by volume
    but ads brings the highest quality customers
    (early signal: ads 60.2% vs partner 75.3% churn rate)

H2: Monthly signup growth accelerated in H2 2024
    (consistent with MRR growth acceleration from Step 13)

H3: Channel mix has shifted over time — check if ads proportion
    grows in later cohorts (which may explain 2024 retention improvement)

VIEW NAMING CONVENTION
------------------------------------------------------------------------------
analysis_[module]_[description]

Exploratory queries → SELECT only (run, read, document findings)
Dashboard views     → CREATE OR REPLACE VIEW (Power BI connection)

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 2 — Revenue & Growth

    analysis_user_growth_monthly      → signup trend line chart
    analysis_user_growth_by_channel   → channel quality table
    analysis_user_growth_channel_mix  → channel mix over time chart

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: MONTHLY SIGNUP TREND
-- ============================================================================
/*
Purpose:
    Understand signup volume and growth rate per month.
    Identify acceleration, slowdown, or decline periods.

Hypothesis:
    Growth accelerated in H2 2024.
    Early months show high MoM % growth from small base.
    Later months show larger absolute growth but lower %.
*/

WITH monthly_signups AS (
    SELECT
        cohort_month,
        COUNT(account_id)                       AS new_accounts
    FROM cohort_base
    GROUP BY cohort_month
)

SELECT
    cohort_month,
    new_accounts,
    SUM(new_accounts) OVER (
        ORDER BY cohort_month
    )                                           AS cumulative_accounts,
    LAG(new_accounts) OVER (
        ORDER BY cohort_month
    )                                           AS prev_month_signups,
    ROUND(
        (new_accounts
            - LAG(new_accounts) OVER (ORDER BY cohort_month)
        )::NUMERIC
        / NULLIF(
            LAG(new_accounts) OVER (ORDER BY cohort_month),
            0
        ) * 100,
        2
    )                                           AS mom_growth_pct,
    CASE
        WHEN LAG(new_accounts) OVER (
            ORDER BY cohort_month
        ) IS NULL                               THEN 'first month'
        WHEN new_accounts > LAG(new_accounts) OVER (
            ORDER BY cohort_month
        ) * 1.20                                THEN 'high growth'
        WHEN new_accounts >= LAG(new_accounts) OVER (
            ORDER BY cohort_month
        )                                       THEN 'moderate growth'
        ELSE                                         'decline'
    END                                         AS growth_classification
FROM monthly_signups
ORDER BY cohort_month;


-- ============================================================================
-- EXPLORATORY 2: REFERRAL SOURCE VOLUME
-- ============================================================================
/*
Purpose:
    Understand which channels bring the most signups.
    Context before quality analysis.

Hypothesis:
    Organic brings most signups by volume.
*/

SELECT
    referral_source,
    COUNT(account_id)                           AS total_accounts,
    ROUND(
        COUNT(account_id)::NUMERIC
        / SUM(COUNT(account_id)) OVER ()
        * 100, 1
    )                                           AS pct_of_total,
    MIN(cohort_month)                           AS first_signup_month,
    MAX(cohort_month)                           AS last_signup_month
FROM cohort_base
GROUP BY referral_source
ORDER BY total_accounts DESC;


-- ============================================================================
-- EXPLORATORY 3: REFERRAL SOURCE QUALITY (DETAILED)
-- ============================================================================
/*
Purpose:
    Deep dive into channel quality before creating the dashboard view.
    Validate hypothesis before committing to a view structure.

Hypothesis:
    Ads has lowest churn rate and longest time to first churn.
    Partner has highest churn rate and shortest time to first churn.
*/

SELECT
    referral_source,
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
    )                                               AS reactivation_rate_pct,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    COUNT(account_id)
        FILTER (WHERE plan_tier = 'Basic')          AS basic_signups,
    COUNT(account_id)
        FILTER (WHERE plan_tier = 'Pro')            AS pro_signups,
    COUNT(account_id)
        FILTER (WHERE plan_tier = 'Enterprise')     AS enterprise_signups
FROM cohort_base
GROUP BY referral_source
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_user_growth_monthly
-- ============================================================================
/*
Purpose:
    Monthly signup trend for dashboard line chart.
    Shows new signups, cumulative growth, and MoM growth rate.

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Line chart — monthly signups + cumulative accounts
*/

DROP VIEW IF EXISTS analysis_user_growth_monthly;
CREATE VIEW analysis_user_growth_monthly AS

WITH monthly_signups AS (
    SELECT
        cohort_month,
        COUNT(account_id)                       AS new_accounts
    FROM cohort_base
    GROUP BY cohort_month
)

SELECT
    cohort_month,
    new_accounts,
    SUM(new_accounts) OVER (
        ORDER BY cohort_month
    )                                           AS cumulative_accounts,
    LAG(new_accounts) OVER (
        ORDER BY cohort_month
    )                                           AS prev_month_signups,
    ROUND(
        (new_accounts
            - LAG(new_accounts) OVER (ORDER BY cohort_month)
        )::NUMERIC
        / NULLIF(
            LAG(new_accounts) OVER (ORDER BY cohort_month),
            0
        ) * 100,
        2
    )                                           AS mom_growth_pct,
    CASE
        WHEN LAG(new_accounts) OVER (
            ORDER BY cohort_month
        ) IS NULL                               THEN 'first month'
        WHEN new_accounts > LAG(new_accounts) OVER (
            ORDER BY cohort_month
        ) * 1.20                                THEN 'high growth'
        WHEN new_accounts >= LAG(new_accounts) OVER (
            ORDER BY cohort_month
        )                                       THEN 'moderate growth'
        ELSE                                         'decline'
    END                                         AS growth_classification
FROM monthly_signups
ORDER BY cohort_month;

select * from analysis_user_growth_monthly;
-- ============================================================================
-- DASHBOARD VIEW 2: analysis_user_growth_by_channel
-- ============================================================================
/*
Purpose:
    Channel quality comparison for dashboard table.
    Combines volume + quality + ranking in one view.
    Best channel = low churn + good volume + long time to first churn.

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Table — channel performance ranked by quality
*/

DROP VIEW IF EXISTS analysis_user_growth_by_channel;
CREATE VIEW analysis_user_growth_by_channel AS

WITH channel_metrics AS (
    SELECT
        referral_source,
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
        ROUND(
            COUNT(account_id)
                FILTER (WHERE ever_reactivated = TRUE)::NUMERIC
            / NULLIF(
                COUNT(account_id)
                    FILTER (WHERE ever_churned = TRUE),
                0
            ) * 100, 1
        )                                               AS reactivation_rate_pct,
        ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
        ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
        ROUND(
            COUNT(account_id)::NUMERIC
            / SUM(COUNT(account_id)) OVER ()
            * 100, 1
        )                                               AS pct_of_total_signups
    FROM cohort_base
    GROUP BY referral_source
)

SELECT
    referral_source,
    total_accounts,
    pct_of_total_signups,
    churned_accounts,
    never_churned_accounts,
    churn_rate_pct,
    never_churned_pct,
    reactivation_rate_pct,
    avg_churn_events,
    avg_months_to_first_churn,

    -- Quality rank (lower churn = rank 1)
    RANK() OVER (
        ORDER BY churn_rate_pct ASC
    )                                                   AS quality_rank,

    -- Volume rank (more signups = rank 1)
    RANK() OVER (
        ORDER BY total_accounts DESC
    )                                                   AS volume_rank,

    -- Combined rank (lower = better overall channel)
    RANK() OVER (ORDER BY churn_rate_pct ASC)
        + RANK() OVER (ORDER BY total_accounts DESC)    AS combined_score

FROM channel_metrics
ORDER BY quality_rank;

select * from analysis_user_growth_by_channel;
-- ============================================================================
-- DASHBOARD VIEW 3: analysis_user_growth_channel_mix
-- ============================================================================
/*
Purpose:
    Monthly channel mix breakdown for dashboard stacked bar chart.
    Shows how acquisition channel composition changed over time.
    Key question: is ads proportion growing in later cohorts?

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Stacked bar chart — channel mix per month
*/

DROP VIEW IF EXISTS analysis_user_growth_channel_mix;
CREATE VIEW analysis_user_growth_channel_mix AS

SELECT
    cohort_month,
    COUNT(account_id)                               AS total_signups,

    -- Absolute counts per channel
    COUNT(account_id)
        FILTER (WHERE referral_source = 'organic')  AS organic,
    COUNT(account_id)
        FILTER (WHERE referral_source = 'ads')      AS ads,
    COUNT(account_id)
        FILTER (WHERE referral_source = 'event')    AS event,
    COUNT(account_id)
        FILTER (WHERE referral_source = 'partner')  AS partner,
    COUNT(account_id)
        FILTER (WHERE referral_source = 'other')    AS other,

    -- Percentage mix per channel
    ROUND(
        COUNT(account_id)
            FILTER (WHERE referral_source = 'organic')::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS organic_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE referral_source = 'ads')::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS ads_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE referral_source = 'event')::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS event_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE referral_source = 'partner')::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS partner_pct,
    ROUND(
        COUNT(account_id)
            FILTER (WHERE referral_source = 'other')::NUMERIC
        / NULLIF(COUNT(account_id), 0) * 100, 1
    )                                               AS other_pct

FROM cohort_base
GROUP BY cohort_month
ORDER BY cohort_month;

select * from analysis_user_growth_channel_mix;
-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: Total signups must equal 500
SELECT
    SUM(new_accounts)           AS total_signups_monthly_view,
    (SELECT COUNT(*) FROM cohort_base) AS total_accounts_cohort_base
FROM analysis_user_growth_monthly;

-- V2: Channel totals must sum to 500
SELECT
    SUM(total_accounts)         AS total_from_channels,
    (SELECT COUNT(*) FROM cohort_base) AS total_accounts_cohort_base
FROM analysis_user_growth_by_channel;

-- V3: Monthly channel mix totals must match monthly signup counts
SELECT
    cm.cohort_month,
    cm.total_signups            AS channel_mix_total,
    gm.new_accounts             AS growth_monthly_total,
    cm.total_signups
        - gm.new_accounts       AS difference
FROM analysis_user_growth_channel_mix cm
JOIN analysis_user_growth_monthly gm
    ON cm.cohort_month = gm.cohort_month
WHERE cm.total_signups != gm.new_accounts;
-- Should return 0 rows

-- V4: Preview all three dashboard views
SELECT * FROM analysis_user_growth_monthly       ORDER BY cohort_month;
SELECT * FROM analysis_user_growth_by_channel    ORDER BY quality_rank;
SELECT * FROM analysis_user_growth_channel_mix   ORDER BY cohort_month;