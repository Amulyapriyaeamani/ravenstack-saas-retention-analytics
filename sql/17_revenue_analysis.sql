/*
===============================================================================
FILE: 17_revenue_analysis.sql
===============================================================================

PURPOSE
------------------------------------------------------------------------------
Analyzes revenue patterns across the 24-month dataset.

Covers:
    - MRR trend and growth phases
    - Plan-wise revenue breakdown and evolution
    - Revenue concentration risk
    - ARPU growth analysis

SOURCE
------------------------------------------------------------------------------
Primary sources:
    kpi_monthly_mrr_growth    → MRR, growth rates, plan breakdown, ARPU
    base_mrr_monthly          → paid account counts, account-level MRR
    cohort_base               → plan tier segmentation
    subscriptions             → account-level MRR for concentration analysis

kpi_monthly_mrr_growth already contains:
    total_mrr, prev_month_mrr, mrr_change, mrr_growth_pct
    arpu, mrr_basic, mrr_pro, mrr_enterprise
    paid_active_accounts

This step adds:
    - Growth phase classification
    - Plan revenue trend and contribution %
    - Revenue concentration risk quantification
    - ARPU by plan tier

HYPOTHESES
------------------------------------------------------------------------------
H1: Revenue growth is driven by ARPU expansion, not account growth.
    Account count grew 250x but MRR grew 2,291x → ARPU growing 9.2x.

H2: Enterprise dominance accelerated after mid-2023.
    Basic and Pro are dying in absolute terms, not just relative.

H3: Revenue concentration risk is extreme.
    A small number of Enterprise accounts likely drive the majority of MRR.
    Loss of top 10% of accounts would cause significant MRR impact.

DASHBOARD
------------------------------------------------------------------------------
Feeds: Page 2 — Revenue & Growth

    analysis_revenue_mrr_trend        → MRR line chart
    analysis_revenue_plan_breakdown   → plan mix stacked chart
    analysis_revenue_concentration    → concentration risk table

===============================================================================
*/


-- ============================================================================
-- EXPLORATORY 1: MRR TREND & GROWTH PHASES
-- ============================================================================
/*
Purpose:
    Classify MRR growth into distinct business phases.
    Identify when growth slowed and when revenue composition shifted.

Hypothesis:
    Three phases: hypergrowth (2023 Q1), stabilization (2023 Q2-2024 Q1),
    mature growth (2024 Q2-Q4).
*/

SELECT
    m.month,
    m.paid_active_accounts,
    m.total_mrr,
    m.prev_month_mrr,
    m.mrr_change,
    m.mrr_growth_pct,
    m.arpu,

    -- Growth phase classification
    CASE
        WHEN m.mrr_growth_pct >= 100  THEN 'hypergrowth'
        WHEN m.mrr_growth_pct >= 20   THEN 'strong growth'
        WHEN m.mrr_growth_pct >= 10   THEN 'moderate growth'
        WHEN m.mrr_growth_pct >= 0    THEN 'slow growth'
        WHEN m.mrr_growth_pct IS NULL THEN 'first month'
        ELSE                               'decline'
    END                                         AS growth_phase,

    -- Revenue scale milestone
    CASE
        WHEN m.total_mrr >= 10000000 THEN '$10M+ MRR'
        WHEN m.total_mrr >=  5000000 THEN '$5M+ MRR'
        WHEN m.total_mrr >=  1000000 THEN '$1M+ MRR'
        WHEN m.total_mrr >=   500000 THEN '$500K+ MRR'
        WHEN m.total_mrr >=   100000 THEN '$100K+ MRR'
        ELSE                               'sub $100K MRR'
    END                                         AS mrr_milestone

FROM kpi_monthly_mrr_growth m
ORDER BY m.month;


-- ============================================================================
-- EXPLORATORY 2: PLAN-WISE REVENUE EVOLUTION
-- ============================================================================
/*
Purpose:
    Track how Basic, Pro, and Enterprise revenue evolved month by month.
    Identify when Enterprise started dominating.
    Check if Pro/Basic are declining in absolute terms.

Hypothesis:
    Enterprise dominance accelerated from mid-2023.
    Basic absolute revenue peaked and is now declining.
    Pro absolute revenue peaked in Nov 2024 and is now declining.
*/

SELECT
    month,
    total_mrr,

    -- Absolute plan revenue
    COALESCE(mrr_basic, 0)                      AS mrr_basic,
    COALESCE(mrr_pro, 0)                        AS mrr_pro,
    COALESCE(mrr_enterprise, 0)                 AS mrr_enterprise,

    -- Plan contribution %
    ROUND(
        COALESCE(mrr_basic, 0)
        / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS basic_pct,
    ROUND(
        COALESCE(mrr_pro, 0)
        / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS pro_pct,
    ROUND(
        COALESCE(mrr_enterprise, 0)
        / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS enterprise_pct,

    -- MoM change per plan
    ROUND(
        COALESCE(mrr_basic, 0)
        - LAG(COALESCE(mrr_basic, 0)) OVER (
            ORDER BY month
        ), 2
    )                                           AS basic_mrr_change,
    ROUND(
        COALESCE(mrr_pro, 0)
        - LAG(COALESCE(mrr_pro, 0)) OVER (
            ORDER BY month
        ), 2
    )                                           AS pro_mrr_change,
    ROUND(
        COALESCE(mrr_enterprise, 0)
        - LAG(COALESCE(mrr_enterprise, 0)) OVER (
            ORDER BY month
        ), 2
    )                                           AS enterprise_mrr_change

FROM kpi_monthly_mrr_growth
ORDER BY month;


-- ============================================================================
-- EXPLORATORY 3: REVENUE CONCENTRATION RISK
-- ============================================================================
/*
Purpose:
    Quantify how dependent the business is on a small number of accounts.
    Understand what happens if top accounts churn.

Hypothesis:
    Top 10% of accounts (50 accounts) drive majority of MRR.
    Loss of any Enterprise account = significant revenue impact.
*/

WITH latest_month AS (
    -- Use most recent month as snapshot
    SELECT MAX(month_start) AS ref_month
    FROM (
        SELECT generate_series(
            DATE_TRUNC('month', (SELECT MIN(start_date) FROM subscriptions)),
            DATE_TRUNC('month', (SELECT MAX(start_date) FROM subscriptions)),
            INTERVAL '1 month'
        ) AS month_start
    ) m
),

account_mrr_snapshot AS (
    -- Account-level MRR at most recent month
    SELECT
        s.account_id,
        SUM(s.mrr_amount)                       AS account_mrr,
        MAX(a.plan_tier)                        AS plan_tier
    FROM subscriptions s
    JOIN accounts a
        ON s.account_id = a.account_id
    CROSS JOIN latest_month lm
    WHERE s.start_date  <= lm.ref_month
      AND (s.end_date IS NULL OR s.end_date >= lm.ref_month)
      AND s.is_trial    = FALSE
      AND s.mrr_amount  > 0
    GROUP BY s.account_id
),

ranked_accounts AS (
    SELECT
        account_id,
        account_mrr,
        plan_tier,
        RANK() OVER (ORDER BY account_mrr DESC)     AS mrr_rank,
        SUM(account_mrr) OVER ()                    AS total_mrr,
        SUM(account_mrr) OVER (
            ORDER BY account_mrr DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        )                                           AS cumulative_mrr,
        COUNT(*) OVER ()                            AS total_accounts
    FROM account_mrr_snapshot
)

SELECT
    mrr_rank,
    account_id,
    plan_tier,
    account_mrr,
    ROUND(
        account_mrr / NULLIF(total_mrr, 0) * 100, 2
    )                                               AS pct_of_total_mrr,
    ROUND(
        cumulative_mrr / NULLIF(total_mrr, 0) * 100, 2
    )                                               AS cumulative_pct_of_mrr,
    total_mrr,
    -- Flag concentration tiers
    CASE
        WHEN mrr_rank <= total_accounts * 0.10 THEN 'top 10%'
        WHEN mrr_rank <= total_accounts * 0.25 THEN 'top 25%'
        WHEN mrr_rank <= total_accounts * 0.50 THEN 'top 50%'
        ELSE                                        'bottom 50%'
    END                                             AS concentration_tier
FROM ranked_accounts
ORDER BY mrr_rank;


-- ============================================================================
-- EXPLORATORY 4: CONCENTRATION SUMMARY
-- ============================================================================
/*
Purpose:
    Summarize concentration risk by tier.
    Single numbers: top 10% of accounts = X% of MRR.
*/

WITH latest_month AS (
    SELECT MAX(month_start) AS ref_month
    FROM (
        SELECT generate_series(
            DATE_TRUNC('month', (SELECT MIN(start_date) FROM subscriptions)),
            DATE_TRUNC('month', (SELECT MAX(start_date) FROM subscriptions)),
            INTERVAL '1 month'
        ) AS month_start
    ) m
),

account_mrr_snapshot AS (
    SELECT
        s.account_id,
        SUM(s.mrr_amount)                       AS account_mrr
    FROM subscriptions s
    CROSS JOIN latest_month lm
    WHERE s.start_date  <= lm.ref_month
      AND (s.end_date IS NULL OR s.end_date >= lm.ref_month)
      AND s.is_trial    = FALSE
      AND s.mrr_amount  > 0
    GROUP BY s.account_id
),

ranked AS (
    SELECT
        account_mrr,
        RANK() OVER (ORDER BY account_mrr DESC) AS mrr_rank,
        COUNT(*) OVER ()                        AS total_accounts,
        SUM(account_mrr) OVER ()                AS total_mrr
    FROM account_mrr_snapshot
),

tiered AS (
    SELECT
        CASE
            WHEN mrr_rank <= total_accounts * 0.10 THEN 'top 10% accounts'
            WHEN mrr_rank <= total_accounts * 0.25 THEN 'top 25% accounts'
            WHEN mrr_rank <= total_accounts * 0.50 THEN 'top 50% accounts'
            ELSE                                        'bottom 50% accounts'
        END                                     AS concentration_tier,
        COUNT(*)                                AS account_count,
        SUM(account_mrr)                        AS tier_mrr,
        MAX(total_mrr)                          AS total_mrr,
        MAX(total_accounts)                     AS total_accounts
    FROM ranked
    GROUP BY
        CASE
            WHEN mrr_rank <= total_accounts * 0.10 THEN 'top 10% accounts'
            WHEN mrr_rank <= total_accounts * 0.25 THEN 'top 25% accounts'
            WHEN mrr_rank <= total_accounts * 0.50 THEN 'top 50% accounts'
            ELSE                                        'bottom 50% accounts'
        END
)

SELECT
    concentration_tier,
    account_count,
    ROUND(
        account_count::NUMERIC
        / NULLIF(total_accounts, 0) * 100, 1
    )                                           AS pct_of_accounts,
    ROUND(tier_mrr, 2)                          AS tier_mrr,
    ROUND(
        tier_mrr / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS pct_of_total_mrr,
    ROUND(tier_mrr / NULLIF(account_count, 0), 2) AS avg_mrr_per_account
FROM tiered
ORDER BY
    CASE concentration_tier
        WHEN 'top 10% accounts'    THEN 1
        WHEN 'top 25% accounts'    THEN 2
        WHEN 'top 50% accounts'    THEN 3
        ELSE                            4
    END;


-- ============================================================================
-- EXPLORATORY 5: ARPU BY PLAN TIER
-- ============================================================================
/*
Purpose:
    Understand ARPU differences across plan tiers.
    Overall ARPU from kpi_monthly_mrr_growth mixes all plans together.
    This breaks it down: which plan drives ARPU growth?

Hypothesis:
    Enterprise ARPU significantly higher than Basic/Pro.
    Enterprise ARPU itself growing over time (seat expansion + upgrades).
*/

WITH monthly_plan_accounts AS (
    SELECT
        DATE_TRUNC('month', s.start_date)::DATE     AS month,
        a.plan_tier,
        COUNT(DISTINCT s.account_id)                AS accounts,
        SUM(s.mrr_amount)                           AS plan_mrr
    FROM subscriptions s
    JOIN accounts a ON s.account_id = a.account_id
    WHERE s.is_trial    = FALSE
      AND s.mrr_amount  > 0
    GROUP BY
        DATE_TRUNC('month', s.start_date)::DATE,
        a.plan_tier
)

SELECT
    month,
    plan_tier,
    accounts,
    ROUND(plan_mrr, 2)                          AS plan_mrr,
    ROUND(
        plan_mrr / NULLIF(accounts, 0), 2
    )                                           AS arpu_by_plan
FROM monthly_plan_accounts
ORDER BY month, plan_tier;


-- ============================================================================
-- DASHBOARD VIEW 1: analysis_revenue_mrr_trend
-- ============================================================================
/*
Purpose:
    Monthly MRR trend with growth phase classification.
    Feeds MRR line chart on dashboard.

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Line chart — MRR over time with phase annotations
*/

DROP VIEW IF EXISTS analysis_revenue_mrr_trend;
CREATE VIEW analysis_revenue_mrr_trend AS

SELECT
    month,
    paid_active_accounts,
    total_mrr,
    COALESCE(prev_month_mrr, 0)                 AS prev_month_mrr,
    COALESCE(mrr_change, 0)                     AS mrr_change,
    mrr_growth_pct,
    arpu,

    CASE
        WHEN mrr_growth_pct >= 100  THEN 'hypergrowth'
        WHEN mrr_growth_pct >= 20   THEN 'strong growth'
        WHEN mrr_growth_pct >= 10   THEN 'moderate growth'
        WHEN mrr_growth_pct >= 0    THEN 'slow growth'
        WHEN mrr_growth_pct IS NULL THEN 'first month'
        ELSE                             'decline'
    END                                         AS growth_phase,

    CASE
        WHEN total_mrr >= 10000000 THEN '$10M+ MRR'
        WHEN total_mrr >=  5000000 THEN '$5M+ MRR'
        WHEN total_mrr >=  1000000 THEN '$1M+ MRR'
        WHEN total_mrr >=   500000 THEN '$500K+ MRR'
        WHEN total_mrr >=   100000 THEN '$100K+ MRR'
        ELSE                            'sub $100K MRR'
    END                                         AS mrr_milestone

FROM kpi_monthly_mrr_growth
ORDER BY month;


-- ============================================================================
-- DASHBOARD VIEW 2: analysis_revenue_plan_breakdown
-- ============================================================================
/*
Purpose:
    Monthly plan-wise MRR breakdown.
    Feeds stacked bar chart showing plan revenue evolution.

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Stacked bar — Basic/Pro/Enterprise MRR per month
*/

DROP VIEW IF EXISTS analysis_revenue_plan_breakdown;
CREATE VIEW analysis_revenue_plan_breakdown AS

SELECT
    month,
    total_mrr,
    COALESCE(mrr_basic, 0)                      AS mrr_basic,
    COALESCE(mrr_pro, 0)                        AS mrr_pro,
    COALESCE(mrr_enterprise, 0)                 AS mrr_enterprise,
    ROUND(
        COALESCE(mrr_basic, 0)
        / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS basic_pct,
    ROUND(
        COALESCE(mrr_pro, 0)
        / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS pro_pct,
    ROUND(
        COALESCE(mrr_enterprise, 0)
        / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS enterprise_pct,
    ROUND(
        COALESCE(mrr_basic, 0)
        - LAG(COALESCE(mrr_basic, 0)) OVER (
            ORDER BY month
        ), 2
    )                                           AS basic_mrr_change,
    ROUND(
        COALESCE(mrr_pro, 0)
        - LAG(COALESCE(mrr_pro, 0)) OVER (
            ORDER BY month
        ), 2
    )                                           AS pro_mrr_change,
    ROUND(
        COALESCE(mrr_enterprise, 0)
        - LAG(COALESCE(mrr_enterprise, 0)) OVER (
            ORDER BY month
        ), 2
    )                                           AS enterprise_mrr_change

FROM kpi_monthly_mrr_growth
ORDER BY month;


-- ============================================================================
-- DASHBOARD VIEW 3: analysis_revenue_concentration
-- ============================================================================
/*
Purpose:
    Revenue concentration risk summary by account tier.
    Shows how dependent the business is on a small number of accounts.

Dashboard:
    Page 2 — Revenue & Growth
    Visual: Table — concentration risk by tier
*/

DROP VIEW IF EXISTS analysis_revenue_concentration;
CREATE VIEW analysis_revenue_concentration AS

WITH latest_month AS (
    SELECT MAX(month_start) AS ref_month
    FROM (
        SELECT generate_series(
            DATE_TRUNC('month', (SELECT MIN(start_date) FROM subscriptions)),
            DATE_TRUNC('month', (SELECT MAX(start_date) FROM subscriptions)),
            INTERVAL '1 month'
        ) AS month_start
    ) m
),

account_mrr_snapshot AS (
    SELECT
        s.account_id,
        SUM(s.mrr_amount)                       AS account_mrr
    FROM subscriptions s
    CROSS JOIN latest_month lm
    WHERE s.start_date  <= lm.ref_month
      AND (s.end_date IS NULL OR s.end_date >= lm.ref_month)
      AND s.is_trial    = FALSE
      AND s.mrr_amount  > 0
    GROUP BY s.account_id
),

ranked AS (
    SELECT
        account_mrr,
        RANK() OVER (ORDER BY account_mrr DESC) AS mrr_rank,
        COUNT(*) OVER ()                        AS total_accounts,
        SUM(account_mrr) OVER ()                AS total_mrr
    FROM account_mrr_snapshot
),

tiered AS (
    SELECT
        CASE
            WHEN mrr_rank <= total_accounts * 0.10 THEN 'top 10% accounts'
            WHEN mrr_rank <= total_accounts * 0.25 THEN 'top 25% accounts'
            WHEN mrr_rank <= total_accounts * 0.50 THEN 'top 50% accounts'
            ELSE                                        'bottom 50% accounts'
        END                                     AS concentration_tier,
        COUNT(*)                                AS account_count,
        SUM(account_mrr)                        AS tier_mrr,
        MAX(total_mrr)                          AS total_mrr,
        MAX(total_accounts)                     AS total_accounts
    FROM ranked
    GROUP BY
        CASE
            WHEN mrr_rank <= total_accounts * 0.10 THEN 'top 10% accounts'
            WHEN mrr_rank <= total_accounts * 0.25 THEN 'top 25% accounts'
            WHEN mrr_rank <= total_accounts * 0.50 THEN 'top 50% accounts'
            ELSE                                        'bottom 50% accounts'
        END
)

SELECT
    concentration_tier,
    account_count,
    ROUND(
        account_count::NUMERIC
        / NULLIF(total_accounts, 0) * 100, 1
    )                                           AS pct_of_accounts,
    ROUND(tier_mrr, 2)                          AS tier_mrr,
    ROUND(
        tier_mrr / NULLIF(total_mrr, 0) * 100, 1
    )                                           AS pct_of_total_mrr,
    ROUND(
        tier_mrr / NULLIF(account_count, 0), 2
    )                                           AS avg_mrr_per_account
FROM tiered
ORDER BY
    CASE concentration_tier
        WHEN 'top 10% accounts'    THEN 1
        WHEN 'top 25% accounts'    THEN 2
        WHEN 'top 50% accounts'    THEN 3
        ELSE                            4
    END;


-- ============================================================================
-- VALIDATION
-- ============================================================================

-- V1: MRR trend view matches kpi_monthly_mrr_growth exactly
SELECT
    t.month,
    t.total_mrr         AS trend_view_mrr,
    k.total_mrr         AS kpi_layer_mrr,
    t.total_mrr
        - k.total_mrr   AS difference
FROM analysis_revenue_mrr_trend t
JOIN kpi_monthly_mrr_growth k
    ON t.month = k.month
WHERE t.total_mrr != k.total_mrr;
-- Should return 0 rows

-- V2: Plan breakdown totals match total_mrr
SELECT
    month,
    total_mrr,
    ROUND(mrr_basic + mrr_pro + mrr_enterprise, 2)  AS reconstructed_mrr,
    ROUND(total_mrr
        - (mrr_basic + mrr_pro + mrr_enterprise), 2) AS difference
FROM analysis_revenue_plan_breakdown
WHERE ROUND(
    total_mrr
    - (mrr_basic + mrr_pro + mrr_enterprise),
    2
) != 0;
-- Should return 0 rows

-- V3: Concentration tiers sum to total accounts
SELECT
    SUM(account_count)  AS total_from_tiers,
    MAX(ROUND(tier_mrr / pct_of_total_mrr * 100, 0))
                        AS implied_total_mrr
FROM analysis_revenue_concentration;

-- V4: Preview all dashboard views
SELECT * FROM analysis_revenue_mrr_trend        ORDER BY month;
SELECT * FROM analysis_revenue_plan_breakdown   ORDER BY month;
SELECT * FROM analysis_revenue_concentration    ORDER BY
    CASE concentration_tier
        WHEN 'top 10% accounts'  THEN 1
        WHEN 'top 25% accounts'  THEN 2
        WHEN 'top 50% accounts'  THEN 3
        ELSE 4
    END;

SELECT
    s.account_id,
    a.plan_tier                         AS entry_plan,
    COUNT(s.subscription_id)            AS total_subscriptions,
    SUM(s.mrr_amount)                   AS total_mrr_all_subs,
    MAX(s.mrr_amount)                   AS max_single_sub_mrr,
    MIN(s.start_date)                   AS first_sub_date,
    MAX(s.start_date)                   AS latest_sub_date
FROM subscriptions s
JOIN accounts a ON s.account_id = a.account_id
WHERE s.account_id IN (
    'A-5b1bcd','A-d4e0d4','A-5a215a',
    'A-1f0636','A-30b4ca'
)
GROUP BY s.account_id, a.plan_tier
ORDER BY total_mrr_all_subs DESC;