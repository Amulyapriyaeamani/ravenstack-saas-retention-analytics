/*
===============================================================================
FILE: 23_usage_vs_churn.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
The most important analysis in Phase 3.

Connects product engagement behavior to churn outcome.
Answers the critical question: does how much a customer uses
the product predict whether they stay or leave?

Covers:
    - Churn rate by usage intensity bucket
    - Usage threshold — at what point does usage predict retention?
    - Zero-usage account churn rate vs average
    - Monthly usage in period before churn vs retained accounts
    - Feature-level usage vs churn (which features protect against churn?)

SOURCE
------------------------------------------------------------------------------
Primary sources:
    base_feature_usage_monthly  → per-account monthly usage data
    base_churn_monthly          → churn events
    base_active_monthly         → active account population
    cohort_base                 → account behavioral attributes

This is the critical cross-table join:
    base_feature_usage_monthly + base_churn_monthly
    connected through account_id and month

HYPOTHESES
------------------------------------------------------------------------------
H1: High-usage accounts churn significantly less than low-usage accounts.
    Usage intensity is the strongest single predictor of retention.
    (Supporting signal: 12 zero-usage accounts, 7 of 12 churned)

H2: There is a usage threshold — accounts above it have dramatically
    lower churn rates. Accounts below it are effectively pre-churned.
    This threshold becomes the CS intervention trigger.

H3: Usage in the 30 days before a churn event is significantly
    lower than usage for retained accounts in the same period.
    Usage drop is a leading indicator, not a lagging one.

H4: Accounts using more diverse features (breadth) churn less
    than accounts using only one or two features.
    Feature diversity = product dependency = retention anchor.

H5: The first month usage level is the single most predictive
    period — accounts that engage immediately in Month 0/1
    have dramatically better long-term survival.

DESIGN NOTE
------------------------------------------------------------------------------
Usage intensity is measured using total_usage_count
(SUM of usage_count from source) not total_usage_events (row count).
Reason: 10x difference confirmed in base layer validation.
total_usage_count reflects actual engagement frequency.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 4 — Feature Usage

    analysis_usage_vs_churn_buckets      → churn rate by usage bucket bar chart
    analysis_usage_30d_before_churn      → pre-churn usage line chart

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: USAGE INTENSITY DISTRIBUTION ACROSS ALL ACCOUNTS
-- ============================================================================
/*
Purpose:
    Understand the distribution of usage intensity before bucketing.
    Identify percentile thresholds for bucket definitions.
*/

WITH account_total_usage AS (
    SELECT
        account_id,
        SUM(total_usage_count)                      AS lifetime_usage_count,
        COUNT(DISTINCT feature_name)                AS distinct_features_used,
        COUNT(DISTINCT month)                       AS active_usage_months
    FROM base_feature_usage_monthly
    GROUP BY account_id
),

all_accounts AS (
    -- Include zero-usage accounts (not in base_feature_usage_monthly)
    SELECT
        a.account_id,
        COALESCE(u.lifetime_usage_count, 0)         AS lifetime_usage_count,
        COALESCE(u.distinct_features_used, 0)       AS distinct_features_used,
        COALESCE(u.active_usage_months, 0)          AS active_usage_months
    FROM (SELECT DISTINCT account_id FROM cohort_base) a
    LEFT JOIN account_total_usage u
        ON a.account_id = u.account_id
)

SELECT
    COUNT(*)                                        AS total_accounts,
    COUNT(*) FILTER (WHERE lifetime_usage_count = 0)
                                                    AS zero_usage_accounts,
    ROUND(AVG(lifetime_usage_count), 1)             AS avg_usage_count,
    PERCENTILE_CONT(0.25) WITHIN GROUP (
        ORDER BY lifetime_usage_count
    )                                               AS p25_usage,
    PERCENTILE_CONT(0.50) WITHIN GROUP (
        ORDER BY lifetime_usage_count
    )                                               AS p50_usage,
    PERCENTILE_CONT(0.75) WITHIN GROUP (
        ORDER BY lifetime_usage_count
    )                                               AS p75_usage,
    PERCENTILE_CONT(0.90) WITHIN GROUP (
        ORDER BY lifetime_usage_count
    )                                               AS p90_usage,
    MAX(lifetime_usage_count)                       AS max_usage,
    MIN(lifetime_usage_count)                       AS min_usage
FROM all_accounts;


-- ============================================================================
-- EXPLORATORY 2: CHURN RATE BY USAGE INTENSITY BUCKET
-- ============================================================================
/*
Purpose:
    Core analysis. Segment accounts by usage intensity.
    Compare churn rates across buckets.
    Identify the threshold below which churn becomes near-certain.

Buckets defined by percentile rank:
    zero:   no feature usage at all
    low:    bottom 25% of non-zero users
    medium: 25th-75th percentile
    high:   top 25% of non-zero users

Hypothesis H1:
    High-usage bucket churn rate dramatically lower than low/zero.
    A clear step-down pattern should be visible.
*/

WITH account_usage AS (
    SELECT
        account_id,
        SUM(total_usage_count)                      AS lifetime_usage_count
    FROM base_feature_usage_monthly
    GROUP BY account_id
),

all_accounts_usage AS (
    SELECT
        cb.account_id,
        COALESCE(u.lifetime_usage_count, 0)         AS lifetime_usage_count,
        cb.ever_churned,
        cb.churn_count,
        cb.months_to_first_churn
    FROM cohort_base cb
    LEFT JOIN account_usage u
        ON cb.account_id = u.account_id
),

usage_percentiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY lifetime_usage_count
        ) FILTER (WHERE lifetime_usage_count > 0)   AS p25,
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY lifetime_usage_count
        ) FILTER (WHERE lifetime_usage_count > 0)   AS p75
    FROM all_accounts_usage
),

bucketed AS (
    SELECT
        a.account_id,
        a.lifetime_usage_count,
        a.ever_churned,
        a.churn_count,
        a.months_to_first_churn,
        CASE
            WHEN a.lifetime_usage_count = 0
                                            THEN '1. zero usage'
            WHEN a.lifetime_usage_count <= p.p25
                                            THEN '2. low usage'
            WHEN a.lifetime_usage_count <= p.p75
                                            THEN '3. medium usage'
            ELSE                                 '4. high usage'
        END                                         AS usage_bucket
    FROM all_accounts_usage a
    CROSS JOIN usage_percentiles p
)

SELECT
    usage_bucket,
    COUNT(*)                                        AS total_accounts,
    COUNT(*) FILTER (WHERE ever_churned = TRUE)     AS churned_accounts,
    ROUND(
        COUNT(*) FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(*) FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(lifetime_usage_count), 1)             AS avg_usage_count,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    MIN(lifetime_usage_count)                       AS min_usage_in_bucket,
    MAX(lifetime_usage_count)                       AS max_usage_in_bucket
FROM bucketed
GROUP BY usage_bucket
ORDER BY usage_bucket;


-- ============================================================================
-- EXPLORATORY 3: USAGE THRESHOLD IDENTIFICATION
-- ============================================================================
/*
Purpose:
    Find the specific usage count threshold below which
    churn rate is unacceptably high.

    Method: step through usage thresholds in increments.
    For each threshold: what is the churn rate for accounts
    above vs below?

    The threshold where the gap is largest = the CS intervention trigger.

Hypothesis H2:
    A clear threshold exists.
    Accounts above it: churn rate significantly below average (70.4%).
    Accounts below it: churn rate significantly above average.
*/

WITH usage_totals AS (
    SELECT
        account_id,
        SUM(total_usage_count) AS lifetime_usage_count
    FROM base_feature_usage_monthly
    GROUP BY account_id
),

account_usage AS (
    SELECT
        cb.account_id,
        COALESCE(ut.lifetime_usage_count, 0) AS lifetime_usage_count,
        cb.ever_churned
    FROM cohort_base cb
    LEFT JOIN usage_totals ut
        ON cb.account_id = ut.account_id
),

thresholds AS (
    SELECT generate_series(0, 200, 10) AS threshold
)

SELECT
    t.threshold,

    COUNT(*) FILTER (
        WHERE a.lifetime_usage_count <= t.threshold
    ) AS accounts_below,

    ROUND(
        COUNT(*) FILTER (
            WHERE a.lifetime_usage_count <= t.threshold
            AND a.ever_churned = TRUE
        )::NUMERIC
        /
        NULLIF(
            COUNT(*) FILTER (
                WHERE a.lifetime_usage_count <= t.threshold
            ),
            0
        ) * 100,
        1
    ) AS churn_rate_below_pct,

    COUNT(*) FILTER (
        WHERE a.lifetime_usage_count > t.threshold
    ) AS accounts_above,

    ROUND(
        COUNT(*) FILTER (
            WHERE a.lifetime_usage_count > t.threshold
            AND a.ever_churned = TRUE
        )::NUMERIC
        /
        NULLIF(
            COUNT(*) FILTER (
                WHERE a.lifetime_usage_count > t.threshold
            ),
            0
        ) * 100,
        1
    ) AS churn_rate_above_pct,

    ROUND(
        (
            COUNT(*) FILTER (
                WHERE a.lifetime_usage_count <= t.threshold
                AND a.ever_churned = TRUE
            )::NUMERIC
            /
            NULLIF(
                COUNT(*) FILTER (
                    WHERE a.lifetime_usage_count <= t.threshold
                ),
                0
            ) * 100
        )
        -
        (
            COUNT(*) FILTER (
                WHERE a.lifetime_usage_count > t.threshold
                AND a.ever_churned = TRUE
            )::NUMERIC
            /
            NULLIF(
                COUNT(*) FILTER (
                    WHERE a.lifetime_usage_count > t.threshold
                ),
                0
            ) * 100
        ),
        1
    ) AS churn_rate_gap_pct

FROM thresholds t
CROSS JOIN account_usage a
GROUP BY t.threshold
ORDER BY t.threshold;


-- ============================================================================
-- EXPLORATORY 4: MONTHLY USAGE BEFORE CHURN
-- ============================================================================
/*
Purpose:
    Compare usage levels in the month of churn vs retained accounts.
    Does usage drop before churn? Is it a leading indicator?

    For each month:
    - Average usage of accounts that churned that month
    - Average usage of accounts that did NOT churn that month

Hypothesis H3:
    Churned accounts show significantly lower usage in churn month
    than retained accounts show in the same month.
    Usage decline precedes churn — detectable before it happens.
*/

WITH monthly_account_usage AS (
    SELECT
        month,
        account_id,
        SUM(total_usage_count)                      AS monthly_usage
    FROM base_feature_usage_monthly
    GROUP BY month, account_id
),

churned_this_month AS (
    SELECT DISTINCT month, account_id
    FROM base_churn_monthly
)

SELECT
    mau.month,

    -- Churned accounts usage
    ROUND(
        AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NOT NULL),
        1
    )                                               AS avg_usage_churned_accounts,

    -- Retained accounts usage
    ROUND(
        AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NULL),
        1
    )                                               AS avg_usage_retained_accounts,

    COUNT(DISTINCT mau.account_id)
        FILTER (WHERE ctm.account_id IS NOT NULL)   AS churned_account_count,

    COUNT(DISTINCT mau.account_id)
        FILTER (WHERE ctm.account_id IS NULL)       AS retained_account_count,

    -- Usage gap (retained - churned)
    ROUND(
        AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NULL)
        - AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NOT NULL),
        1
    )                                               AS usage_gap

FROM monthly_account_usage mau
LEFT JOIN churned_this_month ctm
    ON  mau.account_id  = ctm.account_id
    AND mau.month       = ctm.month
GROUP BY mau.month
HAVING COUNT(DISTINCT mau.account_id) > 5
ORDER BY mau.month;


-- ============================================================================
-- EXPLORATORY 5: FEATURE DIVERSITY VS CHURN
-- ============================================================================
/*
Purpose:
    Does using more features protect against churn?
    Accounts using many features have higher product dependency.

    Hypothesis H4:
    Accounts using 5+ distinct features churn less than
    accounts using only 1-2 features.
    Feature diversity = stickiness anchor.
*/

WITH account_feature_diversity AS (
    SELECT
        account_id,
        COUNT(DISTINCT feature_name)                AS distinct_features_used,
        SUM(total_usage_count)                      AS lifetime_usage_count
    FROM base_feature_usage_monthly
    GROUP BY account_id
),

all_accounts_diversity AS (
    SELECT
        cb.account_id,
        COALESCE(d.distinct_features_used, 0)       AS distinct_features_used,
        COALESCE(d.lifetime_usage_count, 0)         AS lifetime_usage_count,
        cb.ever_churned,
        cb.months_to_first_churn,
        cb.churn_count
    FROM cohort_base cb
    LEFT JOIN account_feature_diversity d
        ON cb.account_id = d.account_id
)

SELECT
    CASE
        WHEN distinct_features_used = 0             THEN '0 features'
        WHEN distinct_features_used <= 2            THEN '1-2 features'
        WHEN distinct_features_used <= 5            THEN '3-5 features'
        WHEN distinct_features_used <= 10           THEN '6-10 features'
        ELSE                                             '11+ features'
    END                                             AS feature_diversity_bucket,
    COUNT(*)                                        AS total_accounts,
    ROUND(
        COUNT(*) FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(AVG(distinct_features_used), 1)           AS avg_features_used,
    ROUND(AVG(lifetime_usage_count), 1)             AS avg_usage_count,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events
FROM all_accounts_diversity
GROUP BY
    CASE
        WHEN distinct_features_used = 0             THEN '0 features'
        WHEN distinct_features_used <= 2            THEN '1-2 features'
        WHEN distinct_features_used <= 5            THEN '3-5 features'
        WHEN distinct_features_used <= 10           THEN '6-10 features'
        ELSE                                             '11+ features'
    END
ORDER BY avg_features_used;


-- ============================================================================
-- EXPLORATORY 6: MONTH 0 AND MONTH 1 USAGE IMPACT
-- ============================================================================
/*
Purpose:
    Does early engagement predict long-term retention?
    Compare Month 0 and Month 1 usage levels between
    accounts that survived vs accounts that churned early.

    Hypothesis H5:
    Accounts with high Month 0-1 usage survive significantly longer.
    First-month engagement is the single most predictive period.
*/

WITH early_usage AS (
    SELECT
        f.account_id,
        SUM(f.total_usage_count)
            FILTER (WHERE f.month = cb.cohort_month)
                                                    AS month_0_usage,
        SUM(f.total_usage_count)
            FILTER (
                WHERE f.month = (
                    cb.cohort_month + INTERVAL '1 month'
                )::DATE
            )                                       AS month_1_usage
    FROM base_feature_usage_monthly f
    JOIN cohort_base cb
        ON f.account_id = cb.account_id
    GROUP BY f.account_id
)

SELECT
    CASE
        WHEN COALESCE(eu.month_0_usage, 0)
           + COALESCE(eu.month_1_usage, 0) = 0     THEN 'no early usage'
        WHEN COALESCE(eu.month_0_usage, 0)
           + COALESCE(eu.month_1_usage, 0) <= 5    THEN 'low early usage (1-5)'
        WHEN COALESCE(eu.month_0_usage, 0)
           + COALESCE(eu.month_1_usage, 0) <= 20   THEN 'medium early usage (6-20)'
        ELSE                                             'high early usage (21+)'
    END                                             AS early_usage_bucket,
    COUNT(cb.account_id)                            AS total_accounts,
    ROUND(
        COUNT(cb.account_id)
            FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(cb.account_id), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(AVG(cb.months_to_first_churn), 1)         AS avg_months_to_first_churn,
    ROUND(AVG(cb.churn_count), 2)                   AS avg_churn_events,
    ROUND(
        AVG(
            COALESCE(eu.month_0_usage, 0)
            + COALESCE(eu.month_1_usage, 0)
        ), 1
    )                                               AS avg_early_usage_count
FROM cohort_base cb
LEFT JOIN early_usage eu
    ON cb.account_id = eu.account_id
GROUP BY
    CASE
        WHEN COALESCE(eu.month_0_usage, 0)
           + COALESCE(eu.month_1_usage, 0) = 0     THEN 'no early usage'
        WHEN COALESCE(eu.month_0_usage, 0)
           + COALESCE(eu.month_1_usage, 0) <= 5    THEN 'low early usage (1-5)'
        WHEN COALESCE(eu.month_0_usage, 0)
           + COALESCE(eu.month_1_usage, 0) <= 20   THEN 'medium early usage (6-20)'
        ELSE                                             'high early usage (21+)'
    END
ORDER BY avg_early_usage_count;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_usage_vs_churn_buckets
-- ============================================================================
/*
Purpose:
    Churn rate by usage intensity bucket for dashboard bar chart.
    Primary visual connecting product usage to business outcome.

Dashboard:
    Page 4 — Feature Usage
    Page 6 — Risk Intelligence (CS intervention threshold)
    Visual: Grouped bar chart — churn rate by usage bucket
*/

DROP VIEW IF EXISTS analysis_usage_vs_churn_buckets;
CREATE VIEW analysis_usage_vs_churn_buckets AS

WITH account_usage AS (
    SELECT
        account_id,
        SUM(total_usage_count)                      AS lifetime_usage_count,
        COUNT(DISTINCT feature_name)                AS distinct_features_used
    FROM base_feature_usage_monthly
    GROUP BY account_id
),

all_accounts_usage AS (
    SELECT
        cb.account_id,
        COALESCE(u.lifetime_usage_count, 0)         AS lifetime_usage_count,
        COALESCE(u.distinct_features_used, 0)       AS distinct_features_used,
        cb.ever_churned,
        cb.churn_count,
        cb.months_to_first_churn,
        cb.plan_tier,
        cb.referral_source
    FROM cohort_base cb
    LEFT JOIN account_usage u
        ON cb.account_id = u.account_id
),

usage_percentiles AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY lifetime_usage_count
        ) FILTER (WHERE lifetime_usage_count > 0)   AS p25,
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY lifetime_usage_count
        ) FILTER (WHERE lifetime_usage_count > 0)   AS p75
    FROM all_accounts_usage
),

bucketed AS (
    SELECT
        a.*,
        CASE
            WHEN a.lifetime_usage_count = 0         THEN '1. zero usage'
            WHEN a.lifetime_usage_count <= p.p25    THEN '2. low usage'
            WHEN a.lifetime_usage_count <= p.p75    THEN '3. medium usage'
            ELSE                                         '4. high usage'
        END                                         AS usage_bucket,
        p.p25                                       AS p25_threshold,
        p.p75                                       AS p75_threshold
    FROM all_accounts_usage a
    CROSS JOIN usage_percentiles p
)

SELECT
    usage_bucket,
    COUNT(*)                                        AS total_accounts,
    COUNT(*) FILTER (WHERE ever_churned = TRUE)     AS churned_accounts,
    COUNT(*) FILTER (WHERE ever_churned = FALSE)    AS never_churned_accounts,
    ROUND(
        COUNT(*) FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(
        COUNT(*) FILTER (WHERE ever_churned = FALSE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS never_churned_pct,
    ROUND(AVG(lifetime_usage_count), 1)             AS avg_usage_count,
    ROUND(AVG(distinct_features_used), 1)           AS avg_features_used,
    ROUND(AVG(months_to_first_churn), 1)            AS avg_months_to_first_churn,
    ROUND(AVG(churn_count), 2)                      AS avg_churn_events,
    MIN(lifetime_usage_count)                       AS bucket_usage_min,
    MAX(lifetime_usage_count)                       AS bucket_usage_max,
    MAX(p25_threshold)                              AS p25_threshold,
    MAX(p75_threshold)                              AS p75_threshold,
    -- Gap vs overall average churn (70.4%)
    ROUND(
        COUNT(*) FILTER (WHERE ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100
        - 70.4,
        1
    )                                               AS gap_vs_overall_avg
FROM bucketed
GROUP BY usage_bucket
ORDER BY usage_bucket;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_usage_30d_before_churn
-- ============================================================================
/*
Purpose:
    Monthly comparison of usage between churned and retained accounts.
    Shows whether usage is a leading indicator of churn.

Dashboard:
    Page 4 — Feature Usage
    Visual: Dual-line chart — churned vs retained avg monthly usage
*/

DROP VIEW IF EXISTS analysis_usage_30d_before_churn;
CREATE VIEW analysis_usage_30d_before_churn AS

WITH monthly_account_usage AS (
    SELECT
        month,
        account_id,
        SUM(total_usage_count)                      AS monthly_usage
    FROM base_feature_usage_monthly
    GROUP BY month, account_id
),

churned_this_month AS (
    SELECT DISTINCT month, account_id
    FROM base_churn_monthly
)

SELECT
    mau.month,

    ROUND(
        AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NOT NULL),
        2
    )                                               AS avg_usage_churned,

    ROUND(
        AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NULL),
        2
    )                                               AS avg_usage_retained,

    COUNT(DISTINCT mau.account_id)
        FILTER (WHERE ctm.account_id IS NOT NULL)   AS churned_with_usage,

    COUNT(DISTINCT mau.account_id)
        FILTER (WHERE ctm.account_id IS NULL)       AS retained_with_usage,

    ROUND(
        AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NULL)
        - AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NOT NULL),
        2
    )                                               AS usage_gap,

    -- Ratio: how many times more do retained accounts use vs churned?
    ROUND(
        AVG(mau.monthly_usage)
            FILTER (WHERE ctm.account_id IS NULL)
        / NULLIF(
            AVG(mau.monthly_usage)
                FILTER (WHERE ctm.account_id IS NOT NULL),
            0
        ),
        2
    )                                               AS retained_vs_churned_ratio

FROM monthly_account_usage mau
LEFT JOIN churned_this_month ctm
    ON  mau.account_id  = ctm.account_id
    AND mau.month       = ctm.month
GROUP BY mau.month
HAVING COUNT(DISTINCT mau.account_id) > 5
ORDER BY mau.month;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: Usage bucket totals = 500 accounts
SELECT
    SUM(total_accounts)                     AS total_from_buckets,
    500                                     AS expected
FROM analysis_usage_vs_churn_buckets;

-- V2: Churned account total across buckets = 352
SELECT
    SUM(churned_accounts)                   AS total_churned_from_buckets,
    352                                     AS expected
FROM analysis_usage_vs_churn_buckets;

-- V3: Zero usage bucket matches known zero-usage count (12)
SELECT
    total_accounts                          AS zero_usage_accounts,
    churned_accounts                        AS zero_usage_churned,
    churn_rate_pct
FROM analysis_usage_vs_churn_buckets
WHERE usage_bucket = '1. zero usage';
-- Expected: 12 total, 7 churned, 58.3% churn rate

-- V4: Usage gap direction — retained should always use MORE than churned
SELECT *
FROM analysis_usage_30d_before_churn
WHERE usage_gap < 0;
-- Should return 0 rows if H3 confirmed
-- If rows returned: churned accounts used MORE than retained — unexpected

-- V5: Monthly view coverage — should cover full 24 months
SELECT
    COUNT(DISTINCT month)                   AS months_covered,
    MIN(month)                              AS first_month,
    MAX(month)                              AS last_month
FROM analysis_usage_30d_before_churn;

-- V6: Preview all dashboard views
SELECT * FROM analysis_usage_vs_churn_buckets       ORDER BY usage_bucket;
SELECT * FROM analysis_usage_30d_before_churn       ORDER BY month;