/*
===============================================================================
FILE: 26_lifecycle_journey_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Maps the complete customer lifecycle journey for every account.

Tracks the full sequence of events from signup to churn:
    Signup → First Subscription → First Feature Use →
    First Support Ticket → First Churn Event

For each stage transition:
    - How long does it take?
    - How many accounts reach each stage?
    - Where does the journey break down most?
    - Does faster progression predict better retention?

This is the only analysis in the project that uses all 5 base tables
joined together through a single account_id spine.

SOURCE
------------------------------------------------------------------------------
All 5 raw tables + base/cohort layer:
    accounts            → signup_date (journey start)
    subscriptions       → first subscription date
    feature_usage       → first feature use date
    support_tickets     → first support ticket date
    churn_events        → first churn date
    cohort_base         → behavioral attributes + churn outcome

STAGE DEFINITIONS
------------------------------------------------------------------------------
Stage 0 — Signup:
    accounts.signup_date
    All 500 accounts. Entry point.

Stage 1 — First Subscription:
    MIN(subscriptions.start_date) per account
    Expected: all 500 — every account has at least one subscription.

Stage 2 — First Feature Use:
    MIN(feature_usage.usage_date) per account
    Not all accounts reach this — 12 accounts have zero usage.

Stage 3 — First Support Ticket:
    MIN(support_tickets.created_at) per account
    Not all accounts raise tickets — optional stage.

Stage 4 — First Churn Event:
    MIN(churn_events.churn_date) per account
    Only accounts that churned (352 of 500).

HYPOTHESES
------------------------------------------------------------------------------
H1: The longest average gap in the journey is between
    First Subscription and First Feature Use.
    Accounts that take >7 days to use a feature for the first time
    are significantly more likely to churn in Month 0-1.

H2: Accounts that reach the support stage before churning
    have shorter survival times than accounts that churn
    without ever raising a ticket.
    Support contact before churn = frustration signal.

H3: Accounts that skip the feature use stage entirely
    (no feature usage) churn fastest — confirming Step 23.

H4: Journey completion rate improves in 2024 cohorts —
    more accounts reach feature use stage despite faster churn.
    Onboarding improved but did not prevent churn.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 6 — Risk Intelligence

    analysis_lifecycle_journey      → funnel + stage-time chart
    analysis_lifecycle_stages       → stage completion summary

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: BUILD FULL LIFECYCLE TIMELINE PER ACCOUNT
-- ============================================================================
/*
Purpose:
    One row per account with key dates for each lifecycle stage.
    Foundation for all downstream journey analysis.
*/

WITH stage_dates AS (
    SELECT
        a.account_id,
        a.signup_date                               AS signup_date,

        -- Stage 1: First subscription
        MIN(s.start_date)                           AS first_sub_date,

        -- Stage 2: First feature use
        MIN(f.usage_date)                           AS first_usage_date,

        -- Stage 3: First support ticket
        MIN(st.submitted_at::DATE)                    AS first_ticket_date,

        -- Stage 4: First churn
        MIN(ce.churn_date)                          AS first_churn_date

    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage f
        ON s.subscription_id = f.subscription_id
    LEFT JOIN support_tickets st
        ON a.account_id = st.account_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id, a.signup_date
)

SELECT
    sd.account_id,
    sd.signup_date,
    sd.first_sub_date,
    sd.first_usage_date,
    sd.first_ticket_date,
    sd.first_churn_date,

    -- Days between each stage transition
    sd.first_sub_date
        - sd.signup_date                            AS days_signup_to_sub,

    sd.first_usage_date
        - sd.signup_date                            AS days_signup_to_usage,

    sd.first_usage_date
        - sd.first_sub_date                         AS days_sub_to_usage,

    sd.first_ticket_date
        - sd.signup_date                            AS days_signup_to_ticket,

    sd.first_churn_date
        - sd.signup_date                            AS days_signup_to_churn,

    sd.first_churn_date
        - sd.first_usage_date                       AS days_usage_to_churn,

    sd.first_churn_date
        - sd.first_ticket_date                      AS days_ticket_to_churn,

    -- Stage reached flags
    CASE WHEN sd.first_sub_date IS NOT NULL
        THEN TRUE ELSE FALSE END                    AS reached_subscription,
    CASE WHEN sd.first_usage_date IS NOT NULL
        THEN TRUE ELSE FALSE END                    AS reached_usage,
    CASE WHEN sd.first_ticket_date IS NOT NULL
        THEN TRUE ELSE FALSE END                    AS reached_support,
    CASE WHEN sd.first_churn_date IS NOT NULL
        THEN TRUE ELSE FALSE END                    AS reached_churn,

    -- Journey completeness
    CASE
        WHEN sd.first_churn_date IS NOT NULL
         AND sd.first_ticket_date IS NOT NULL
         AND sd.first_usage_date IS NOT NULL        THEN 'full journey'
        WHEN sd.first_churn_date IS NOT NULL
         AND sd.first_usage_date IS NOT NULL        THEN 'no support'
        WHEN sd.first_churn_date IS NOT NULL        THEN 'no usage no support'
        WHEN sd.first_usage_date IS NOT NULL
         AND sd.first_ticket_date IS NOT NULL       THEN 'retained with support'
        WHEN sd.first_usage_date IS NOT NULL        THEN 'retained no support'
        ELSE                                             'minimal journey'
    END                                             AS journey_type,

    -- Cohort attributes from cohort_base
    cb.plan_tier,
    cb.referral_source,
    cb.industry,
    cb.ever_churned,
    cb.churn_count,
    cb.months_to_first_churn

FROM stage_dates sd
JOIN cohort_base cb
    ON sd.account_id = cb.account_id
ORDER BY sd.signup_date;


-- ============================================================================
-- EXPLORATORY 2: STAGE COMPLETION FUNNEL
-- ============================================================================
/*
Purpose:
    How many accounts reach each stage?
    Classic funnel analysis — where does the biggest drop-off occur?

Hypothesis H1:
    Feature use stage has the first meaningful drop-off.
    12 accounts never used any feature.
*/

WITH stage_dates AS ( SELECT a.account_id, a.signup_date, MIN(s.start_date) AS first_sub_date, MIN(f.usage_date) AS first_usage_date, MIN(st.submitted_at::DATE) AS first_ticket_date, MIN(ce.churn_date) AS first_churn_date FROM accounts a LEFT JOIN subscriptions s ON a.account_id = s.account_id LEFT JOIN feature_usage f ON s.subscription_id = f.subscription_id LEFT JOIN support_tickets st ON a.account_id = st.account_id LEFT JOIN churn_events ce ON a.account_id = ce.account_id GROUP BY a.account_id, a.signup_date ) SELECT 'Stage 0 — Signup' AS stage, COUNT(*) AS accounts_reached, 100.0 AS pct_of_total, NULL::NUMERIC AS drop_off_pct FROM stage_dates UNION ALL SELECT 'Stage 1 — First Subscription', COUNT(*) FILTER (WHERE first_sub_date IS NOT NULL), ROUND( COUNT(*) FILTER (WHERE first_sub_date IS NOT NULL) ::NUMERIC / 500 * 100, 1 ), ROUND( (500 - COUNT(*) FILTER (WHERE first_sub_date IS NOT NULL)) ::NUMERIC / 500 * 100, 1 ) FROM stage_dates UNION ALL SELECT 'Stage 2 — First Feature Use', COUNT(*) FILTER (WHERE first_usage_date IS NOT NULL), ROUND( COUNT(*) FILTER (WHERE first_usage_date IS NOT NULL) ::NUMERIC / 500 * 100, 1 ), ROUND( (COUNT(*) FILTER (WHERE first_sub_date IS NOT NULL) - COUNT(*) FILTER (WHERE first_usage_date IS NOT NULL)) ::NUMERIC / 500 * 100, 1 ) FROM stage_dates UNION ALL SELECT 'Stage 3 — First Support Ticket', COUNT(*) FILTER (WHERE first_ticket_date IS NOT NULL), ROUND( COUNT(*) FILTER (WHERE first_ticket_date IS NOT NULL) ::NUMERIC / 500 * 100, 1 ), NULL FROM stage_dates UNION ALL SELECT 'Stage 4 — First Churn Event', COUNT(*) FILTER (WHERE first_churn_date IS NOT NULL), ROUND( COUNT(*) FILTER (WHERE first_churn_date IS NOT NULL) ::NUMERIC / 500 * 100, 1 ), ROUND( (500 - COUNT(*) FILTER (WHERE first_churn_date IS NOT NULL)) ::NUMERIC / 500 * 100, 1 ) FROM stage_dates ORDER BY stage;


-- ============================================================================
-- EXPLORATORY 3: AVERAGE TIME BETWEEN STAGES
-- ============================================================================
/*
Purpose:
    How long does the average account spend between each stage?
    The longest gap = biggest friction point in the journey.

Hypothesis H1:
    Subscription → Feature Use gap is the most critical.
    Long activation lag predicts Month 0-1 churn.
*/

WITH stage_dates AS (
    SELECT
        a.account_id,
        a.signup_date,
        MIN(s.start_date)                           AS first_sub_date,
        MIN(f.usage_date)                           AS first_usage_date,
        MIN(st.submitted_at::DATE)                    AS first_ticket_date,
        MIN(ce.churn_date)                          AS first_churn_date
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage f
        ON s.subscription_id = f.subscription_id
    LEFT JOIN support_tickets st
        ON a.account_id = st.account_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id, a.signup_date
)

SELECT
    -- Signup → First Subscription
    'Signup → First Subscription'                   AS transition,
    COUNT(*) FILTER (
        WHERE first_sub_date IS NOT NULL
    )                                               AS accounts,
    ROUND(AVG(
        first_sub_date - signup_date
    ) FILTER (WHERE first_sub_date IS NOT NULL), 1) AS avg_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY first_sub_date - signup_date
    ) FILTER (WHERE first_sub_date IS NOT NULL)     AS median_days,
    MIN(first_sub_date - signup_date)               AS min_days,
    MAX(first_sub_date - signup_date)               AS max_days

FROM stage_dates

UNION ALL

SELECT
    'Signup → First Feature Use',
    COUNT(*) FILTER (WHERE first_usage_date IS NOT NULL),
    ROUND(AVG(
        first_usage_date - signup_date
    ) FILTER (WHERE first_usage_date IS NOT NULL), 1),
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY first_usage_date - signup_date
    ) FILTER (WHERE first_usage_date IS NOT NULL),
    MIN(first_usage_date - signup_date),
    MAX(first_usage_date - signup_date)
FROM stage_dates

UNION ALL

SELECT
    'First Subscription → First Feature Use',
    COUNT(*) FILTER (
        WHERE first_sub_date IS NOT NULL
          AND first_usage_date IS NOT NULL
    ),
    ROUND(AVG(
        first_usage_date - first_sub_date
    ) FILTER (
        WHERE first_sub_date IS NOT NULL
          AND first_usage_date IS NOT NULL
    ), 1),
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY first_usage_date - first_sub_date
    ) FILTER (
        WHERE first_sub_date IS NOT NULL
          AND first_usage_date IS NOT NULL
    ),
    MIN(first_usage_date - first_sub_date),
    MAX(first_usage_date - first_sub_date)
FROM stage_dates

UNION ALL

SELECT
    'First Feature Use → First Churn',
    COUNT(*) FILTER (
        WHERE first_usage_date IS NOT NULL
          AND first_churn_date IS NOT NULL
    ),
    ROUND(AVG(
        first_churn_date - first_usage_date
    ) FILTER (
        WHERE first_usage_date IS NOT NULL
          AND first_churn_date IS NOT NULL
    ), 1),
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY first_churn_date - first_usage_date
    ) FILTER (
        WHERE first_usage_date IS NOT NULL
          AND first_churn_date IS NOT NULL
    ),
    MIN(first_churn_date - first_usage_date),
    MAX(first_churn_date - first_usage_date)
FROM stage_dates

UNION ALL

SELECT
    'Signup → First Churn',
    COUNT(*) FILTER (WHERE first_churn_date IS NOT NULL),
    ROUND(AVG(
        first_churn_date - signup_date
    ) FILTER (WHERE first_churn_date IS NOT NULL), 1),
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY first_churn_date - signup_date
    ) FILTER (WHERE first_churn_date IS NOT NULL),
    MIN(first_churn_date - signup_date),
    MAX(first_churn_date - signup_date)
FROM stage_dates

ORDER BY transition;


-- ============================================================================
-- EXPLORATORY 4: ACTIVATION LAG VS CHURN RATE
-- ============================================================================
/*
Purpose:
    Does the gap between subscription and first feature use
    predict churn?

    Accounts that activate quickly (same day) vs
    accounts that take a week or more to activate.

Hypothesis H1 (core test):
    Accounts taking >7 days to first feature use
    churn at significantly higher rates.
*/

WITH stage_dates AS (
    SELECT
        a.account_id,
        MIN(s.start_date)                           AS first_sub_date,
        MIN(f.usage_date)                           AS first_usage_date
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage f
        ON s.subscription_id = f.subscription_id
    GROUP BY a.account_id
),

activation_lag AS (
    SELECT
        sd.account_id,
        CASE
            WHEN sd.first_usage_date IS NULL        THEN 'never activated'
            WHEN sd.first_usage_date
               - sd.first_sub_date = 0             THEN 'same day (0)'
            WHEN sd.first_usage_date
               - sd.first_sub_date <= 3            THEN '1-3 days'
            WHEN sd.first_usage_date
               - sd.first_sub_date <= 7            THEN '4-7 days'
            WHEN sd.first_usage_date
               - sd.first_sub_date <= 30           THEN '8-30 days'
            ELSE                                        '30+ days'
        END                                         AS activation_lag_bucket,
        sd.first_usage_date - sd.first_sub_date     AS activation_lag_days
    FROM stage_dates sd
)

SELECT
    al.activation_lag_bucket,
    COUNT(*)                                        AS total_accounts,
    ROUND(
        COUNT(*) FILTER (WHERE cb.ever_churned = TRUE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS churn_rate_pct,
    ROUND(AVG(cb.months_to_first_churn), 1)         AS avg_months_to_first_churn,
    ROUND(AVG(cb.churn_count), 2)                   AS avg_churn_events,
    ROUND(AVG(al.activation_lag_days), 1)           AS avg_activation_lag_days
FROM activation_lag al
JOIN cohort_base cb
    ON al.account_id = cb.account_id
GROUP BY al.activation_lag_bucket
ORDER BY avg_activation_lag_days NULLS LAST;


-- ============================================================================
-- EXPLORATORY 5: JOURNEY TYPE VS CHURN OUTCOME
-- ============================================================================
/*
Purpose:
    Does the pattern of stages an account passes through
    predict churn outcome?

    Full journey accounts vs accounts that skip stages.
*/

WITH stage_dates AS (
    SELECT
        a.account_id,
        MIN(s.start_date)                           AS first_sub_date,
        MIN(f.usage_date)                           AS first_usage_date,
        MIN(st.submitted_at::DATE)                    AS first_ticket_date,
        MIN(ce.churn_date)                          AS first_churn_date
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage f
        ON s.subscription_id = f.subscription_id
    LEFT JOIN support_tickets st
        ON a.account_id = st.account_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id
),

journey_typed AS (
    SELECT
        sd.account_id,
        CASE
            WHEN sd.first_churn_date IS NOT NULL
             AND sd.first_ticket_date IS NOT NULL
             AND sd.first_usage_date IS NOT NULL    THEN 'churned: full journey'
            WHEN sd.first_churn_date IS NOT NULL
             AND sd.first_usage_date IS NOT NULL    THEN 'churned: no support'
            WHEN sd.first_churn_date IS NOT NULL    THEN 'churned: minimal'
            WHEN sd.first_ticket_date IS NOT NULL
             AND sd.first_usage_date IS NOT NULL    THEN 'retained: with support'
            WHEN sd.first_usage_date IS NOT NULL    THEN 'retained: no support'
            ELSE                                         'retained: minimal'
        END                                         AS journey_type
    FROM stage_dates sd
)

SELECT
    jt.journey_type,
    COUNT(*)                                        AS total_accounts,
    ROUND(
        COUNT(*)::NUMERIC / 500 * 100, 1
    )                                               AS pct_of_total,
    ROUND(AVG(cb.months_to_first_churn), 1)         AS avg_months_to_first_churn,
    ROUND(AVG(cb.churn_count), 2)                   AS avg_churn_events,
    ROUND(
        COUNT(*) FILTER (WHERE cb.ever_reactivated = TRUE)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100, 1
    )                                               AS reactivation_rate_pct
FROM journey_typed jt
JOIN cohort_base cb
    ON jt.account_id = cb.account_id
GROUP BY jt.journey_type
ORDER BY avg_months_to_first_churn ASC NULLS LAST;


-- ============================================================================
-- EXPLORATORY 6: SUPPORT-BEFORE-CHURN ANALYSIS
-- ============================================================================
/*
Purpose:
    For churned accounts — did they raise a support ticket
    BEFORE churning? And how much time between their
    last ticket and churn event?

Hypothesis H2:
    Accounts that raised a ticket before churning had
    shorter survival times — support contact = frustration signal.
*/

WITH first_churn AS (
    SELECT
        ce.account_id,
        MIN(ce.churn_date) AS first_churn_date
    FROM churn_events ce
    GROUP BY ce.account_id
),

pre_churn_support AS (
    SELECT
        fc.account_id,
        fc.first_churn_date,

        MAX(st.submitted_at::DATE)
            FILTER (
                WHERE st.submitted_at::DATE < fc.first_churn_date
            ) AS last_ticket_before_churn,

        COUNT(st.ticket_id)
            FILTER (
                WHERE st.submitted_at::DATE < fc.first_churn_date
            ) AS tickets_before_churn

    FROM first_churn fc
    LEFT JOIN support_tickets st
        ON fc.account_id = st.account_id
    GROUP BY
        fc.account_id,
        fc.first_churn_date
)

SELECT
    CASE
        WHEN pcs.tickets_before_churn = 0
          OR pcs.tickets_before_churn IS NULL
            THEN 'no ticket before churn'

        WHEN pcs.last_ticket_before_churn
            >= pcs.first_churn_date - 7
            THEN 'ticket within 7 days'

        WHEN pcs.last_ticket_before_churn
            >= pcs.first_churn_date - 30
            THEN 'ticket within 30 days'

        ELSE 'ticket 30+ days before'
    END AS pre_churn_support_pattern,

    COUNT(*) AS churned_accounts,

    ROUND(
        COUNT(*)::NUMERIC
        / SUM(COUNT(*)) OVER () * 100,
        1
    ) AS pct_of_churns,

    ROUND(AVG(cb.months_to_first_churn), 1)
        AS avg_months_to_first_churn,

    ROUND(AVG(pcs.tickets_before_churn), 1)
        AS avg_tickets_before_churn,

    ROUND(AVG(cb.churn_count), 2)
        AS avg_total_churn_events

FROM pre_churn_support pcs
JOIN cohort_base cb
    ON pcs.account_id = cb.account_id

GROUP BY
    CASE
        WHEN pcs.tickets_before_churn = 0
          OR pcs.tickets_before_churn IS NULL
            THEN 'no ticket before churn'

        WHEN pcs.last_ticket_before_churn
            >= pcs.first_churn_date - 7
            THEN 'ticket within 7 days'

        WHEN pcs.last_ticket_before_churn
            >= pcs.first_churn_date - 30
            THEN 'ticket within 30 days'

        ELSE 'ticket 30+ days before'
    END

ORDER BY avg_months_to_first_churn ASC;


-- ============================================================================
-- EXPLORATORY 7: 2023 vs 2024 COHORT JOURNEY COMPARISON
-- ============================================================================
/*
Purpose:
    Hypothesis H4 — did 2024 cohorts improve on journey completion
    despite faster churn?

    Compare stage completion rates and transition times
    between 2023 and 2024 cohort groups.
*/

WITH stage_dates AS (
    SELECT
        a.account_id,
        a.signup_date,
        MIN(s.start_date)                           AS first_sub_date,
        MIN(f.usage_date)                           AS first_usage_date,
        MIN(st.submitted_at::DATE)                    AS first_ticket_date,
        MIN(ce.churn_date)                          AS first_churn_date
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage f
        ON s.subscription_id = f.subscription_id
    LEFT JOIN support_tickets st
        ON a.account_id = st.account_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id, a.signup_date
)

SELECT
    CASE
        WHEN DATE_TRUNC('year', sd.signup_date)
            = '2023-01-01'                          THEN '2023 cohorts'
        ELSE                                             '2024 cohorts'
    END                                             AS cohort_year,

    COUNT(*)                                        AS total_accounts,

    -- Stage completion rates
    ROUND(
        COUNT(*) FILTER (
            WHERE sd.first_usage_date IS NOT NULL
        )::NUMERIC / COUNT(*) * 100, 1
    )                                               AS pct_reached_feature_use,
    ROUND(
        COUNT(*) FILTER (
            WHERE sd.first_ticket_date IS NOT NULL
        )::NUMERIC / COUNT(*) * 100, 1
    )                                               AS pct_reached_support,
    ROUND(
        COUNT(*) FILTER (
            WHERE sd.first_churn_date IS NOT NULL
        )::NUMERIC / COUNT(*) * 100, 1
    )                                               AS pct_reached_churn,

    -- Avg transition times
    ROUND(AVG(
        sd.first_usage_date - sd.first_sub_date
    ) FILTER (
        WHERE sd.first_sub_date IS NOT NULL
          AND sd.first_usage_date IS NOT NULL
    ), 1)                                           AS avg_days_sub_to_usage,
    ROUND(AVG(
        sd.first_churn_date - sd.signup_date
    ) FILTER (
        WHERE sd.first_churn_date IS NOT NULL
    ), 1)                                           AS avg_days_to_first_churn

FROM stage_dates sd
GROUP BY
    CASE
        WHEN DATE_TRUNC('year', sd.signup_date)
            = '2023-01-01'                          THEN '2023 cohorts'
        ELSE                                             '2024 cohorts'
    END
ORDER BY cohort_year;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_lifecycle_journey
-- ============================================================================
/*
Purpose:
    Full per-account lifecycle journey with stage dates,
    transition times, and journey classification.
    Feeds funnel chart and stage-time bars on dashboard.

Dashboard:
    Page 6 — Risk Intelligence
    Visual: Horizontal funnel + stage time bar chart
*/

DROP VIEW IF EXISTS analysis_lifecycle_journey;
CREATE VIEW analysis_lifecycle_journey AS

WITH stage_dates AS (
    SELECT
        a.account_id,
        a.signup_date,
        MIN(s.start_date)                           AS first_sub_date,
        MIN(f.usage_date)                           AS first_usage_date,
        MIN(st.submitted_at::DATE)                    AS first_ticket_date,
        MIN(ce.churn_date)                          AS first_churn_date
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage f
        ON s.subscription_id = f.subscription_id
    LEFT JOIN support_tickets st
        ON a.account_id = st.account_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id, a.signup_date
)

SELECT
    sd.account_id,
    cb.plan_tier,
    cb.referral_source,
    cb.industry,
    cb.cohort_month,
    cb.ever_churned,
    cb.churn_count,
    cb.months_to_first_churn,

    -- Stage dates
    sd.signup_date,
    sd.first_sub_date,
    sd.first_usage_date,
    sd.first_ticket_date,
    sd.first_churn_date,

    -- Transition times (days)
    sd.first_sub_date
        - sd.signup_date                            AS days_signup_to_sub,
    sd.first_usage_date
        - sd.first_sub_date                         AS days_sub_to_usage,
    sd.first_ticket_date
        - sd.signup_date                            AS days_signup_to_ticket,
    sd.first_churn_date
        - sd.signup_date                            AS days_signup_to_churn,
    sd.first_churn_date
        - sd.first_usage_date                       AS days_usage_to_churn,

    -- Stage flags
    sd.first_sub_date IS NOT NULL                   AS reached_subscription,
    sd.first_usage_date IS NOT NULL                 AS reached_usage,
    sd.first_ticket_date IS NOT NULL                AS reached_support,
    sd.first_churn_date IS NOT NULL                 AS reached_churn,

    -- Stages reached count (0-4)
    (CASE WHEN sd.first_sub_date IS NOT NULL
        THEN 1 ELSE 0 END
    + CASE WHEN sd.first_usage_date IS NOT NULL
        THEN 1 ELSE 0 END
    + CASE WHEN sd.first_ticket_date IS NOT NULL
        THEN 1 ELSE 0 END
    + CASE WHEN sd.first_churn_date IS NOT NULL
        THEN 1 ELSE 0 END)                          AS stages_reached,

    -- Activation lag bucket
    CASE
        WHEN sd.first_usage_date IS NULL            THEN 'never activated'
        WHEN sd.first_usage_date
           - sd.first_sub_date = 0                 THEN 'same day'
        WHEN sd.first_usage_date
           - sd.first_sub_date <= 7                THEN 'within 7 days'
        WHEN sd.first_usage_date
           - sd.first_sub_date <= 30               THEN '8-30 days'
        ELSE                                             '30+ days'
    END                                             AS activation_speed,

    -- Journey type
    CASE
        WHEN sd.first_churn_date IS NOT NULL
         AND sd.first_ticket_date IS NOT NULL
         AND sd.first_usage_date IS NOT NULL        THEN 'churned: full journey'
        WHEN sd.first_churn_date IS NOT NULL
         AND sd.first_usage_date IS NOT NULL        THEN 'churned: no support'
        WHEN sd.first_churn_date IS NOT NULL        THEN 'churned: minimal'
        WHEN sd.first_ticket_date IS NOT NULL
         AND sd.first_usage_date IS NOT NULL        THEN 'retained: with support'
        WHEN sd.first_usage_date IS NOT NULL        THEN 'retained: no support'
        ELSE                                             'retained: minimal'
    END                                             AS journey_type

FROM stage_dates sd
JOIN cohort_base cb
    ON sd.account_id = cb.account_id
ORDER BY sd.signup_date;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_lifecycle_stages
-- ============================================================================
/*
Purpose:
    Stage-level summary for funnel visualization.
    Shows completion rate, avg days to reach each stage,
    and churn rate for accounts that reached each stage.

Dashboard:
    Page 6 — Risk Intelligence
    Visual: Funnel chart + average days bar chart
*/

DROP VIEW IF EXISTS analysis_lifecycle_stages;
CREATE VIEW analysis_lifecycle_stages AS

WITH stage_dates AS (
    SELECT
        a.account_id,
        a.signup_date,
        MIN(s.start_date)                           AS first_sub_date,
        MIN(f.usage_date)                           AS first_usage_date,
        MIN(st.submitted_at::DATE)                    AS first_ticket_date,
        MIN(ce.churn_date)                          AS first_churn_date
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
    LEFT JOIN feature_usage f
        ON s.subscription_id = f.subscription_id
    LEFT JOIN support_tickets st
        ON a.account_id = st.account_id
    LEFT JOIN churn_events ce
        ON a.account_id = ce.account_id
    GROUP BY a.account_id, a.signup_date
),

stage_summary AS (
    SELECT
        'Signup'                                    AS stage_name,
        0                                           AS stage_order,
        COUNT(*)                                    AS accounts_reached,
        0.0                                         AS avg_days_from_signup,
        NULL::NUMERIC                               AS churn_rate_at_stage
    FROM stage_dates

    UNION ALL

    SELECT
        'First Subscription',
        1,
        COUNT(*) FILTER (WHERE first_sub_date IS NOT NULL),
        ROUND(AVG(first_sub_date - signup_date)
            FILTER (WHERE first_sub_date IS NOT NULL), 1),
        NULL
    FROM stage_dates

    UNION ALL

    SELECT
        'First Feature Use',
        2,
        COUNT(*) FILTER (WHERE first_usage_date IS NOT NULL),
        ROUND(AVG(first_usage_date - signup_date)
            FILTER (WHERE first_usage_date IS NOT NULL), 1),
        ROUND(
            COUNT(*) FILTER (
                WHERE first_usage_date IS NOT NULL
                  AND first_churn_date IS NOT NULL
            )::NUMERIC
            / NULLIF(COUNT(*) FILTER (
                WHERE first_usage_date IS NOT NULL
            ), 0) * 100, 1
        )
    FROM stage_dates

    UNION ALL

    SELECT
        'First Support Ticket',
        3,
        COUNT(*) FILTER (WHERE first_ticket_date IS NOT NULL),
        ROUND(AVG(first_ticket_date - signup_date)
            FILTER (WHERE first_ticket_date IS NOT NULL), 1),
        ROUND(
            COUNT(*) FILTER (
                WHERE first_ticket_date IS NOT NULL
                  AND first_churn_date IS NOT NULL
            )::NUMERIC
            / NULLIF(COUNT(*) FILTER (
                WHERE first_ticket_date IS NOT NULL
            ), 0) * 100, 1
        )
    FROM stage_dates

    UNION ALL

    SELECT
        'First Churn Event',
        4,
        COUNT(*) FILTER (WHERE first_churn_date IS NOT NULL),
        ROUND(AVG(first_churn_date - signup_date)
            FILTER (WHERE first_churn_date IS NOT NULL), 1),
        100.0
    FROM stage_dates
)

SELECT
    stage_name,
    stage_order,
    accounts_reached,
    ROUND(
        accounts_reached::NUMERIC / 500 * 100, 1
    )                                               AS pct_of_total,
    avg_days_from_signup,
    churn_rate_at_stage,
    -- Drop from previous stage
    LAG(accounts_reached) OVER (
        ORDER BY stage_order
    ) - accounts_reached                           AS drop_from_prev_stage

FROM stage_summary
ORDER BY stage_order;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: All 500 accounts in lifecycle journey view
SELECT
    COUNT(*)                        AS total_accounts,
    500                             AS expected
FROM analysis_lifecycle_journey;

-- V2: Stage completion counts match expected values
-- Subscription: 500, Feature use: 488 (500-12 zero usage), Churn: 352
SELECT
    COUNT(*) FILTER (WHERE reached_subscription)   AS subscribed,
    COUNT(*) FILTER (WHERE reached_usage)          AS used_feature,
    COUNT(*) FILTER (WHERE reached_support)        AS raised_ticket,
    COUNT(*) FILTER (WHERE reached_churn)          AS churned
FROM analysis_lifecycle_journey;

-- V3: Days between stages — no negative transitions
-- Feature use should happen AFTER subscription
SELECT *
FROM analysis_lifecycle_journey
WHERE days_sub_to_usage < 0;
-- Should return 0 rows

-- V4: Funnel view stage order complete
SELECT
    stage_name,
    stage_order,
    accounts_reached,
    pct_of_total,
    avg_days_from_signup,
    drop_from_prev_stage
FROM analysis_lifecycle_stages
ORDER BY stage_order;

-- V5: Activation speed distribution
SELECT
    activation_speed,
    COUNT(*)                        AS accounts,
    ROUND(
        COUNT(*)::NUMERIC / 500 * 100, 1
    )                               AS pct_of_total
FROM analysis_lifecycle_journey
GROUP BY activation_speed
ORDER BY accounts DESC;

-- V6: Preview dashboard views
SELECT * FROM analysis_lifecycle_journey    ORDER BY signup_date LIMIT 20;
SELECT * FROM analysis_lifecycle_stages     ORDER BY stage_order;