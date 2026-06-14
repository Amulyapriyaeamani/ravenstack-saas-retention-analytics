/*
===============================================================================
FILE: 28_beta_feature_impact.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Analyzes whether beta feature adoption correlates with retention.

Covers:
    - Churn rate: beta users vs non-beta users
    - Does beta adoption improve retention?
    - Which specific beta features correlate with better retention?
    - Beta adoption trend over time
    - Beta adoption depth vs churn outcome

SOURCE
------------------------------------------------------------------------------
Primary sources:
    base_feature_usage_monthly   → is_beta_feature, feature_name,
                                   total_usage_count, account_id, month
    cohort_base                  → ever_churned, ever_reactivated,
                                   months_to_first_churn, churn_count,
                                   plan_tier, referral_source, cohort_month
    base_churn_monthly           → churn events for monthly cross-reference

base_feature_usage_monthly columns used:
    month, account_id, feature_name, is_beta_feature,
    total_usage_count, total_usage_events, total_errors

cohort_base columns used:
    account_id, ever_churned, ever_reactivated,
    months_to_first_churn, churn_count, plan_tier,
    referral_source, cohort_month

NO raw table joins needed.
All analysis routes through base layer views.

HYPOTHESES
------------------------------------------------------------------------------
H1: Beta users churn at lower rates than non-beta users.
    Early adopters self-select for higher product engagement —
    the type of user who tries beta features is more invested
    in the product's success.

H2: Beta adoption depth (number of distinct beta features used)
    correlates negatively with churn rate.
    Accounts using more beta features churn less.

H3: Specific beta features correlate with significantly better
    retention than others — not all beta features are equal.
    Some beta features attract power users; others attract
    casual experimenters.

H4: Beta adoption rate has grown over time —
    the product is successfully expanding its early adopter base.

H5: Given Step 23 finding (usage does not predict churn),
    H1-H3 will likely be refuted. Beta adoption,
    like overall usage, may not meaningfully differentiate
    churned from retained accounts.

NOTE ON STEP 23 CONTEXT
------------------------------------------------------------------------------
Step 23 proved that overall feature usage does not predict churn
in this dataset. Step 28 tests whether BETA feature usage specifically
is different — beta users may self-select differently than general users.
Document clearly whether Step 28 confirms or refutes the Step 23 finding.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 4 — Feature Usage

    analysis_beta_vs_nonbeta_churn       → churn comparison bar chart
    analysis_beta_feature_retention      → per-feature retention table

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: BETA USER CLASSIFICATION
-- ============================================================================
/*
Purpose:
    Classify every account as beta user or non-beta user.
    Beta user = used at least one beta feature at any point.
    Show distribution before diving into churn comparison.
*/

WITH beta_usage AS (
    SELECT
        account_id,
        BOOL_OR(is_beta_feature = TRUE)             AS is_beta_user,
        COUNT(DISTINCT feature_name)
            FILTER (WHERE is_beta_feature = TRUE)   AS distinct_beta_features,
        COUNT(DISTINCT feature_name)
            FILTER (WHERE is_beta_feature = FALSE)  AS distinct_ga_features,
        SUM(total_usage_count)
            FILTER (WHERE is_beta_feature = TRUE)   AS beta_usage_count,
        SUM(total_usage_count)
            FILTER (WHERE is_beta_feature = FALSE)  AS ga_usage_count,
        SUM(total_usage_count)                      AS total_usage_count
    FROM base_feature_usage_monthly
    GROUP BY account_id
)

SELECT
    CASE
        WHEN bu.is_beta_user = TRUE                 THEN 'beta user'
        WHEN bu.account_id IS NULL                  THEN 'no feature usage'
        ELSE                                             'ga only user'
    END                                             AS user_type,
    COUNT(cb.account_id)                            AS total_accounts,
    ROUND(
        COUNT(cb.account_id)::NUMERIC
        / 500 * 100, 1
    )                                               AS pct_of_total,
    ROUND(AVG(bu.distinct_beta_features), 1)        AS avg_distinct_beta_features,
    ROUND(AVG(bu.distinct_ga_features), 1)          AS avg_distinct_ga_features,
    ROUND(AVG(bu.beta_usage_count), 1)              AS avg_beta_usage_count,
    ROUND(AVG(bu.ga_usage_count), 1)                AS avg_ga_usage_count
FROM cohort_base cb
LEFT JOIN beta_usage bu
    ON cb.account_id = bu.account_id
GROUP BY
    CASE
        WHEN bu.is_beta_user = TRUE                 THEN 'beta user'
        WHEN bu.account_id IS NULL                  THEN 'no feature usage'
        ELSE                                             'ga only user'
    END
ORDER BY total_accounts DESC;


-- ============================================================================
-- EXPLORATORY 2: BETA USERS VS NON-BETA USERS CHURN COMPARISON
-- ============================================================================
/*
Purpose:
    Core analysis. Compare churn rate between beta users and non-beta users.
    Hypothesis H1 test.

    Beta user    = used at least one beta feature
    Non-beta user = used features but none were beta
    No usage     = never used any feature
*/

WITH feature_summary AS (
    SELECT
        f.account_id,

        -- Did account ever use a beta feature?
        BOOL_OR(f.is_beta_feature = TRUE)           AS used_beta_feature,

        -- Any feature usage at all?
        COUNT(*)                                    AS total_feature_rows,

        -- Distinct beta features used
        COUNT(DISTINCT f.feature_name)
            FILTER (
                WHERE f.is_beta_feature = TRUE
            )                                       AS distinct_beta_features,

        -- Total beta usage
        SUM(f.total_usage_count)
            FILTER (
                WHERE f.is_beta_feature = TRUE
            )                                       AS beta_usage_count

    FROM base_feature_usage_monthly f
    GROUP BY f.account_id
),

beta_classification AS (
    SELECT
        cb.account_id,
        cb.ever_churned,
        cb.ever_reactivated,
        cb.months_to_first_churn,
        cb.churn_count,
        cb.plan_tier,
        cb.cohort_month,

        CASE
            WHEN fs.used_beta_feature = TRUE
                THEN 'beta user'

            WHEN fs.total_feature_rows IS NULL
                THEN 'no feature usage'

            ELSE 'ga only user'
        END                                         AS user_type,

        fs.distinct_beta_features,
        fs.beta_usage_count

    FROM cohort_base cb
    LEFT JOIN feature_summary fs
        ON cb.account_id = fs.account_id
)

SELECT
    user_type,

    COUNT(*)                                        AS total_accounts,

    COUNT(*) FILTER (
        WHERE ever_churned = TRUE
    )                                               AS churned_accounts,

    COUNT(*) FILTER (
        WHERE ever_churned = FALSE
    )                                               AS never_churned_accounts,

    ROUND(
        COUNT(*) FILTER (
            WHERE ever_churned = TRUE
        )::NUMERIC
        / NULLIF(COUNT(*), 0) * 100,
        1
    )                                               AS churn_rate_pct,

    ROUND(
        COUNT(*) FILTER (
            WHERE ever_churned = FALSE
        )::NUMERIC
        / NULLIF(COUNT(*), 0) * 100,
        1
    )                                               AS never_churned_pct,

    ROUND(
        COUNT(*) FILTER (
            WHERE ever_reactivated = TRUE
        )::NUMERIC
        / NULLIF(
            COUNT(*) FILTER (
                WHERE ever_churned = TRUE
            ),
            0
        ) * 100,
        1
    )                                               AS reactivation_rate_pct,

    ROUND(
        AVG(months_to_first_churn),
        1
    )                                               AS avg_months_to_first_churn,

    ROUND(
        AVG(churn_count),
        2
    )                                               AS avg_churn_events,

    ROUND(
        AVG(distinct_beta_features),
        1
    )                                               AS avg_distinct_beta_features,

    ROUND(
        AVG(beta_usage_count),
        1
    )                                               AS avg_beta_usage_count,

    -- Gap vs overall average churn rate
    ROUND(
        COUNT(*) FILTER (
            WHERE ever_churned = TRUE
        )::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
        - 70.4,
        1
    )                                               AS gap_vs_overall_avg

FROM beta_classification
GROUP BY user_type
ORDER BY churn_rate_pct ASC;

-- ============================================================================
-- EXPLORATORY 3: BETA ADOPTION DEPTH VS CHURN
-- ============================================================================
/*
Purpose:
    Does using MORE beta features protect against churn?
    Hypothesis H2 test.
    Bucket accounts by number of distinct beta features used.
*/

WITH account_beta_usage AS (
    SELECT
        account_id,
        COUNT(DISTINCT feature_name)
            FILTER (WHERE is_beta_feature = TRUE)   AS distinct_beta_features,
        SUM(total_usage_count)
            FILTER (WHERE is_beta_feature = TRUE)   AS beta_usage_count
    FROM base_feature_usage_monthly
    GROUP BY account_id
)

SELECT
    CASE
        WHEN abu.account_id IS NULL
          OR abu.distinct_beta_features = 0         THEN '0 beta features'
        WHEN abu.distinct_beta_features = 1         THEN '1 beta feature'
        WHEN abu.distinct_beta_features <= 3        THEN '2-3 beta features'
        WHEN abu.distinct_beta_features <= 5        THEN '4-5 beta features'
        ELSE                                             '6+ beta features'
    END                                             AS beta_depth_bucket,
    COUNT(cb.account_id)                            AS total_accounts,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(cb.account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE cb.ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(cb.account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(cb.months_to_first_churn), 1)         AS avg_months_to_first_churn,
    ROUND(AVG(cb.churn_count), 2)                   AS avg_churn_events,
    ROUND(AVG(abu.distinct_beta_features), 1)       AS avg_distinct_beta_features,
    ROUND(AVG(abu.beta_usage_count), 1)             AS avg_beta_usage_count
FROM cohort_base cb
LEFT JOIN account_beta_usage abu
    ON cb.account_id = abu.account_id
GROUP BY
    CASE
        WHEN abu.account_id IS NULL
          OR abu.distinct_beta_features = 0         THEN '0 beta features'
        WHEN abu.distinct_beta_features = 1         THEN '1 beta feature'
        WHEN abu.distinct_beta_features <= 3        THEN '2-3 beta features'
        WHEN abu.distinct_beta_features <= 5        THEN '4-5 beta features'
        ELSE                                             '6+ beta features'
    END
ORDER BY avg_distinct_beta_features;


-- ============================================================================
-- EXPLORATORY 4: PER-BETA-FEATURE CHURN COMPARISON
-- ============================================================================
/*
Purpose:
    For each distinct beta feature — what is the churn rate
    of accounts that used it vs accounts that did not use it?
    Hypothesis H3: some beta features correlate with better retention.

    Method:
    For each beta feature, split accounts into:
        adopters    = used this specific beta feature
        non-adopters = never used this specific beta feature
    Compare churn rates between the two groups.
*/

WITH beta_features AS (
    SELECT DISTINCT feature_name
    FROM base_feature_usage_monthly
    WHERE is_beta_feature = TRUE
),

feature_adopters AS (
    SELECT
        f.feature_name,
        f.account_id,
        SUM(f.total_usage_count)                    AS feature_usage_count
    FROM base_feature_usage_monthly f
    WHERE f.is_beta_feature = TRUE
    GROUP BY f.feature_name, f.account_id
)

SELECT
    bf.feature_name,

    -- Adopter metrics
    COUNT(DISTINCT fa.account_id)                   AS adopter_accounts,
    ROUND(
        COUNT(DISTINCT fa.account_id)
            FILTER (
                WHERE cb_a.ever_churned = TRUE
            )::NUMERIC
        / NULLIF(COUNT(DISTINCT fa.account_id), 0)
        * 100, 1
    )                                               AS adopter_churn_rate_pct,
    ROUND(
        AVG(cb_a.months_to_first_churn)
            FILTER (WHERE cb_a.ever_churned = TRUE),
        1
    )                                               AS adopter_avg_months_to_churn,

    -- Non-adopter metrics
    COUNT(DISTINCT cb_na.account_id)                AS non_adopter_accounts,
    ROUND(
        COUNT(DISTINCT cb_na.account_id)
            FILTER (
                WHERE cb_na.ever_churned = TRUE
            )::NUMERIC
        / NULLIF(COUNT(DISTINCT cb_na.account_id), 0)
        * 100, 1
    )                                               AS non_adopter_churn_rate_pct,

    -- Retention lift: negative = adopters churn less (better)
    ROUND(
        COUNT(DISTINCT fa.account_id)
            FILTER (WHERE cb_a.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(DISTINCT fa.account_id), 0) * 100
        -
        COUNT(DISTINCT cb_na.account_id)
            FILTER (WHERE cb_na.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(DISTINCT cb_na.account_id), 0) * 100,
        1
    )                                               AS churn_rate_diff,

    -- Adoption rate
    ROUND(
        COUNT(DISTINCT fa.account_id)::NUMERIC
        / 500 * 100, 2
    )                                               AS adoption_rate_pct,

    -- Avg usage among adopters
    ROUND(AVG(fa.feature_usage_count), 1)           AS avg_usage_per_adopter

FROM beta_features bf
-- Join adopters
LEFT JOIN feature_adopters fa
    ON bf.feature_name = fa.feature_name
LEFT JOIN cohort_base cb_a
    ON fa.account_id = cb_a.account_id
-- Join non-adopters
LEFT JOIN cohort_base cb_na
    ON cb_na.account_id NOT IN (
        SELECT account_id
        FROM feature_adopters
        WHERE feature_name = bf.feature_name
    )
GROUP BY bf.feature_name
ORDER BY churn_rate_diff ASC;


-- ============================================================================
-- EXPLORATORY 5: BETA ADOPTION TREND OVER TIME
-- ============================================================================
/*
Purpose:
    Is beta adoption growing, stable, or declining over 24 months?
    Hypothesis H4: beta adoption rate has grown over time.

    Compare:
    - Monthly beta adopters count
    - Beta adoption rate among active accounts
    - Beta usage volume trend
*/

WITH monthly_beta AS (
    SELECT
        f.month,
        COUNT(DISTINCT f.account_id)
            FILTER (WHERE f.is_beta_feature = TRUE) AS beta_adopters,
        COUNT(DISTINCT f.account_id)                AS total_feature_users,
        SUM(f.total_usage_count)
            FILTER (WHERE f.is_beta_feature = TRUE) AS beta_usage_count,
        SUM(f.total_usage_count)                    AS total_usage_count,
        COUNT(DISTINCT f.feature_name)
            FILTER (WHERE f.is_beta_feature = TRUE) AS distinct_beta_features_used
    FROM base_feature_usage_monthly f
    GROUP BY f.month
),

monthly_active AS (
    SELECT
        month,
        COUNT(DISTINCT account_id)                  AS active_accounts
    FROM base_active_monthly
    GROUP BY month
)

SELECT
    mb.month,
    ma.active_accounts,
    mb.beta_adopters,
    mb.total_feature_users,
    mb.beta_usage_count,
    mb.total_usage_count,
    mb.distinct_beta_features_used,

    -- Beta adoption rate among all active accounts
    ROUND(
        mb.beta_adopters::NUMERIC
        / NULLIF(ma.active_accounts, 0) * 100, 2
    )                                               AS beta_adoption_rate_pct,

    -- Beta share of total usage
    ROUND(
        mb.beta_usage_count::NUMERIC
        / NULLIF(mb.total_usage_count, 0) * 100, 2
    )                                               AS beta_pct_of_total_usage,

    -- MoM change in beta adoption rate
    ROUND(
        mb.beta_adopters::NUMERIC
        / NULLIF(ma.active_accounts, 0) * 100
        - LAG(
            mb.beta_adopters::NUMERIC
            / NULLIF(ma.active_accounts, 0) * 100
        ) OVER (ORDER BY mb.month),
        2
    )                                               AS beta_adoption_rate_mom_change

FROM monthly_beta mb
JOIN monthly_active ma
    ON mb.month = ma.month
ORDER BY mb.month;


-- ============================================================================
-- EXPLORATORY 6: BETA USER PROFILE — WHO USES BETA FEATURES?
-- ============================================================================
/*
Purpose:
    Understand who the beta users are — plan tier, industry,
    channel, cohort year. This reveals whether beta adoption
    is concentrated in a specific segment.
*/

WITH account_beta_flag AS (
    SELECT
        account_id,
        BOOL_OR(is_beta_feature = TRUE)             AS is_beta_user
    FROM base_feature_usage_monthly
    GROUP BY account_id
)

SELECT
    cb.plan_tier,
    cb.referral_source,
    CASE
        WHEN EXTRACT(YEAR FROM cb.cohort_month) = 2023
                                                    THEN '2023'
        ELSE                                             '2024'
    END                                             AS cohort_year,
    COUNT(cb.account_id)                            AS total_accounts,
    COUNT(cb.account_id)
        FILTER (WHERE abf.is_beta_user = TRUE)      AS beta_users,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE abf.is_beta_user = TRUE)::NUMERIC
        / NULLIF(COUNT(cb.account_id), 0) * 100, 1
    )                                               AS beta_adoption_pct,
    ROUND(
        COUNT(cb.account_id)
            FILTER (
                WHERE abf.is_beta_user = TRUE
                  AND cb.ever_churned = TRUE
            )::NUMERIC
        / NULLIF(
            COUNT(cb.account_id)
                FILTER (WHERE abf.is_beta_user = TRUE),
            0
        ) * 100, 1
    )                                               AS beta_user_churn_rate,
    ROUND(
        COUNT(cb.account_id)
            FILTER (
                WHERE (abf.is_beta_user = FALSE
                    OR abf.account_id IS NULL)
                  AND cb.ever_churned = TRUE
            )::NUMERIC
        / NULLIF(
            COUNT(cb.account_id)
                FILTER (
                    WHERE abf.is_beta_user = FALSE
                       OR abf.account_id IS NULL
                ),
            0
        ) * 100, 1
    )                                               AS non_beta_user_churn_rate
FROM cohort_base cb
LEFT JOIN account_beta_flag abf
    ON cb.account_id = abf.account_id
GROUP BY
    cb.plan_tier,
    cb.referral_source,
    CASE
        WHEN EXTRACT(YEAR FROM cb.cohort_month) = 2023
                                                    THEN '2023'
        ELSE                                             '2024'
    END
ORDER BY
    cb.plan_tier,
    cb.referral_source,
    cohort_year;


-- ============================================================================
-- EXPLORATORY 7: BETA VS GA USAGE IN PRE-CHURN MONTH
-- ============================================================================
/*
Purpose:
    Do churned accounts show lower beta usage than retained accounts
    in the month of churn?

    Cross-validates Step 23 finding for beta specifically.
    If churned accounts show lower beta usage — beta is a
    churn-protective behavior.
    If gap is near zero — beta adoption does not protect
    against churn (consistent with Step 23).
*/

WITH monthly_beta_usage AS (
    SELECT
        f.month,
        f.account_id,
        SUM(f.total_usage_count)
            FILTER (WHERE f.is_beta_feature = TRUE) AS beta_usage,
        SUM(f.total_usage_count)
            FILTER (WHERE f.is_beta_feature = FALSE) AS ga_usage
    FROM base_feature_usage_monthly f
    GROUP BY f.month, f.account_id
),

churned_this_month AS (
    SELECT DISTINCT month, account_id
    FROM base_churn_monthly
)

SELECT
    mbu.month,
    ROUND(
        AVG(mbu.beta_usage)
            FILTER (WHERE ctm.account_id IS NOT NULL),
        2
    )                                               AS churned_avg_beta_usage,
    ROUND(
        AVG(mbu.beta_usage)
            FILTER (WHERE ctm.account_id IS NULL),
        2
    )                                               AS retained_avg_beta_usage,
    ROUND(
        AVG(mbu.ga_usage)
            FILTER (WHERE ctm.account_id IS NOT NULL),
        2
    )                                               AS churned_avg_ga_usage,
    ROUND(
        AVG(mbu.ga_usage)
            FILTER (WHERE ctm.account_id IS NULL),
        2
    )                                               AS retained_avg_ga_usage,
    COUNT(DISTINCT mbu.account_id)
        FILTER (WHERE ctm.account_id IS NOT NULL)   AS churned_with_usage,
    COUNT(DISTINCT mbu.account_id)
        FILTER (WHERE ctm.account_id IS NULL)       AS retained_with_usage,

    -- Beta usage gap (retained - churned)
    ROUND(
        AVG(mbu.beta_usage)
            FILTER (WHERE ctm.account_id IS NULL)
        - AVG(mbu.beta_usage)
            FILTER (WHERE ctm.account_id IS NOT NULL),
        2
    )                                               AS beta_usage_gap

FROM monthly_beta_usage mbu
LEFT JOIN churned_this_month ctm
    ON  mbu.account_id = ctm.account_id
    AND mbu.month      = ctm.month
GROUP BY mbu.month
HAVING COUNT(DISTINCT mbu.account_id) > 5
ORDER BY mbu.month;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_beta_vs_nonbeta_churn
-- ============================================================================
/*
Purpose:
    Beta user vs non-beta user churn comparison.
    Primary visual for Page 4 beta section.

Dashboard:
    Page 4 — Feature Usage
    Visual: Grouped bar — churn rate by user type
*/

DROP VIEW IF EXISTS analysis_beta_vs_nonbeta_churn;
CREATE VIEW analysis_beta_vs_nonbeta_churn AS

WITH account_beta_metrics AS (
    SELECT
        account_id,
        BOOL_OR(is_beta_feature = TRUE)             AS is_beta_user,
        COUNT(DISTINCT feature_name)
            FILTER (WHERE is_beta_feature = TRUE)   AS distinct_beta_features,
        COUNT(DISTINCT feature_name)
            FILTER (WHERE is_beta_feature = FALSE)  AS distinct_ga_features,
        SUM(total_usage_count)
            FILTER (WHERE is_beta_feature = TRUE)   AS beta_usage_count,
        SUM(total_usage_count)
            FILTER (WHERE is_beta_feature = FALSE)  AS ga_usage_count
    FROM base_feature_usage_monthly
    GROUP BY account_id
)

SELECT
    CASE
        WHEN abm.is_beta_user = TRUE                THEN 'beta user'
        WHEN abm.account_id IS NULL                 THEN 'no feature usage'
        ELSE                                             'ga only user'
    END                                             AS user_type,

    COUNT(cb.account_id)                            AS total_accounts,
    ROUND(
        COUNT(cb.account_id)::NUMERIC / 500 * 100, 1
    )                                               AS pct_of_total,

    -- Churn metrics
    COUNT(cb.account_id)
        FILTER (WHERE cb.ever_churned = TRUE)       AS churned_accounts,
    COUNT(cb.account_id)
        FILTER (WHERE cb.ever_churned = FALSE)      AS never_churned_accounts,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(cb.account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE cb.ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(cb.account_id), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE cb.ever_reactivated = TRUE)::NUMERIC
        / NULLIF(
            COUNT(cb.account_id)
                FILTER (WHERE cb.ever_churned = TRUE),
            0
        ) * 100, 1
    )                                               AS reactivation_rate_pct,
    ROUND(AVG(cb.months_to_first_churn), 1)         AS avg_months_to_first_churn,
    ROUND(AVG(cb.churn_count), 2)                   AS avg_churn_events,

    -- Usage metrics
    ROUND(AVG(abm.distinct_beta_features), 1)       AS avg_distinct_beta_features,
    ROUND(AVG(abm.distinct_ga_features), 1)         AS avg_distinct_ga_features,
    ROUND(AVG(abm.beta_usage_count), 1)             AS avg_beta_usage_count,

    -- Benchmark comparison
    5.0                                             AS benchmark_lower,
    70.4                                            AS overall_avg_churn,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(cb.account_id), 0) * 100
        - 70.4, 1
    )                                               AS gap_vs_overall_avg

FROM cohort_base cb
LEFT JOIN account_beta_metrics abm
    ON cb.account_id = abm.account_id
GROUP BY
    CASE
        WHEN abm.is_beta_user = TRUE                THEN 'beta user'
        WHEN abm.account_id IS NULL                 THEN 'no feature usage'
        ELSE                                             'ga only user'
    END
ORDER BY churn_rate_pct ASC;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_beta_feature_retention
-- ============================================================================
/*
Purpose:
    Per-beta-feature retention comparison.
    Shows adoption rate and churn rate for each beta feature.
    Ranked by retention lift (negative = better than average).

Dashboard:
    Page 4 — Feature Usage
    Visual: Ranked table — beta features by retention impact
*/

DROP VIEW IF EXISTS analysis_beta_feature_retention;
CREATE VIEW analysis_beta_feature_retention AS

WITH beta_feature_list AS (
    SELECT DISTINCT feature_name
    FROM base_feature_usage_monthly
    WHERE is_beta_feature = TRUE
),

feature_adopters AS (
    SELECT
        feature_name,
        account_id,
        SUM(total_usage_count)                      AS feature_usage_count,
        COUNT(DISTINCT month)                       AS active_months
    FROM base_feature_usage_monthly
    WHERE is_beta_feature = TRUE
    GROUP BY feature_name, account_id
),

adopter_churn AS (
    SELECT
        fa.feature_name,
        COUNT(DISTINCT fa.account_id)               AS adopter_count,
        ROUND(
            COUNT(DISTINCT fa.account_id)::NUMERIC
            / 500 * 100, 2
        )                                           AS adoption_rate_pct,
        ROUND(
            COUNT(DISTINCT fa.account_id)
                FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
            / NULLIF(COUNT(DISTINCT fa.account_id), 0) * 100, 1
        )                                           AS adopter_churn_rate_pct,
        ROUND(
            COUNT(DISTINCT fa.account_id)
                FILTER (WHERE cb.ever_churned = FALSE)::NUMERIC
            / NULLIF(COUNT(DISTINCT fa.account_id), 0) * 100, 1
        )                                           AS adopter_never_churned_pct,
        ROUND(AVG(fa.feature_usage_count), 1)       AS avg_usage_per_adopter,
        ROUND(AVG(fa.active_months), 1)             AS avg_months_used,
        ROUND(AVG(cb.months_to_first_churn), 1)     AS avg_months_to_first_churn
    FROM feature_adopters fa
    JOIN cohort_base cb
        ON fa.account_id = cb.account_id
    GROUP BY fa.feature_name
)

SELECT
    ac.feature_name,
    ac.adopter_count,
    ac.adoption_rate_pct,
    ac.adopter_churn_rate_pct,
    ac.adopter_never_churned_pct,
    ac.avg_usage_per_adopter,
    ac.avg_months_used,
    ac.avg_months_to_first_churn,

    -- Gap vs overall churn average (70.4%)
    ROUND(ac.adopter_churn_rate_pct - 70.4, 1)     AS gap_vs_overall_avg,

    -- Retention lift classification
    CASE
        WHEN ac.adopter_churn_rate_pct < 65         THEN 'strong retention signal'
        WHEN ac.adopter_churn_rate_pct < 70         THEN 'moderate retention signal'
        WHEN ac.adopter_churn_rate_pct <= 72        THEN 'neutral'
        ELSE                                             'no retention signal'
    END                                             AS retention_signal,

    -- Rank by adopter churn rate (lower = better)
    RANK() OVER (
        ORDER BY ac.adopter_churn_rate_pct ASC
    )                                               AS retention_rank,

    -- Rank by adoption rate (higher = better)
    RANK() OVER (
        ORDER BY ac.adoption_rate_pct DESC
    )                                               AS adoption_rank

FROM adopter_churn ac
ORDER BY adopter_churn_rate_pct ASC;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: Beta vs non-beta accounts sum to 500
SELECT
    SUM(total_accounts)             AS total_from_view,
    500                             AS expected
FROM analysis_beta_vs_nonbeta_churn;

-- V2: Beta feature retention view covers all beta features
SELECT
    COUNT(DISTINCT feature_name)    AS beta_features_in_view
FROM analysis_beta_feature_retention;
-- Should match distinct beta features in base_feature_usage_monthly

-- V3: Beta user count consistency check
SELECT
    COUNT(DISTINCT account_id)      AS accounts_with_any_beta_usage
FROM base_feature_usage_monthly
WHERE is_beta_feature = TRUE;
-- Cross-check with beta user count in analysis_beta_vs_nonbeta_churn

-- V4: Step 23 cross-validation check
-- Beta usage gap direction — should be near zero if H1 refuted
-- V4: Step 23 cross-validation check (corrected)
-- Beta usage gap direction — near zero if consistent with Step 23

WITH beta_gap_check AS (
    SELECT
        mbu.month,
        ROUND(
            AVG(mbu.beta_usage)
                FILTER (WHERE ctm.account_id IS NULL)
            - AVG(mbu.beta_usage)
                FILTER (WHERE ctm.account_id IS NOT NULL),
            2
        )                                           AS beta_usage_gap
    FROM (
        SELECT
            f.month,
            f.account_id,
            SUM(f.total_usage_count)
                FILTER (WHERE f.is_beta_feature = TRUE) AS beta_usage
        FROM base_feature_usage_monthly f
        GROUP BY f.month, f.account_id
    ) mbu
    LEFT JOIN (
        SELECT DISTINCT month, account_id
        FROM base_churn_monthly
    ) ctm
        ON  mbu.account_id = ctm.account_id
        AND mbu.month      = ctm.month
    GROUP BY mbu.month
    HAVING COUNT(DISTINCT mbu.account_id) > 5
)

SELECT
    COUNT(*) FILTER (WHERE beta_usage_gap > 2)      AS months_retained_use_more,
    COUNT(*) FILTER (WHERE beta_usage_gap < -2)     AS months_churned_use_more,
    COUNT(*) FILTER (
        WHERE beta_usage_gap BETWEEN -2 AND 2
    )                                               AS months_near_zero_gap,
    ROUND(AVG(beta_usage_gap), 2)                   AS avg_beta_usage_gap
FROM beta_gap_check;
-- Most months near zero = Step 23 finding holds for beta usage too
-- Most months should show near-zero gap if consistent with Step 23

-- V5: All user types present in beta churn view
SELECT
    user_type,
    total_accounts,
    churn_rate_pct
FROM analysis_beta_vs_nonbeta_churn
ORDER BY total_accounts DESC;

-- V6: Preview all dashboard views
SELECT * FROM analysis_beta_vs_nonbeta_churn
    ORDER BY churn_rate_pct ASC;
SELECT * FROM analysis_beta_feature_retention
    ORDER BY retention_rank;