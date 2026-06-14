-- ============================================================
-- FILE: 01_base_accounts.sql
-- PURPOSE: Snapshot-level account and subscription metrics
-- ============================================================

-- DESCRIPTION:
-- Provides a high-level overview of accounts and subscriptions.
-- Used for sanity checks, dataset understanding, and validation
-- before building time-based KPIs.

-- ============================================================
-- METRICS INCLUDED:
-- - Total accounts
-- - Total subscriptions
-- - Paid vs Trial subscriptions
-- - Active subscriptions (snapshot-based)
-- - Active accounts (distinct)
-- - Active paid vs trial accounts (account-level split)
-- - Active paid vs trial subscriptions (subscription-level split)
-- - Churned accounts (distinct, historical)
-- ============================================================

-- DEFINITIONS:
-- "Active" =
--     start_date <= snapshot_date
--     AND (end_date IS NULL OR end_date >= snapshot_date)

-- ============================================================

-- ⚠️ NOTE:
-- Snapshot date is derived from dataset (not system date)
-- ensuring reproducible and consistent results.

-- SNAPSHOT DATE LOGIC:
-- Defined as MAX(end_date) from closed subscriptions.
-- Represents the latest confirmed event in the dataset.
-- Used instead of CURRENT_DATE because dataset is historical (2023–2024).
-- This ensures reproducible results regardless of query execution date.

-- NOTE: active_accounts = total_accounts (500) is expected.
-- Every account in this dataset has at least one open subscription
-- (end_date IS NULL) as of the dataset end date (2024-12-31).
-- This reflects the dataset design where churn is subscription-level,
-- not account-level permanent departure.
-- For churn analysis, use churn_events as source of truth (Step 7 decision).

-- ============================================================

WITH snapshot_date AS (
    SELECT MAX(end_date) AS snapshot_date
    FROM subscriptions
    WHERE end_date IS NOT NULL
),

total_accounts AS (
    SELECT COUNT(*) AS total_accounts
    FROM accounts
),

total_subscriptions AS (
    SELECT COUNT(*) AS total_subscriptions
    FROM subscriptions
),

subscription_split AS (
    SELECT
        COUNT(*) FILTER (WHERE is_trial = FALSE) AS paid_subscriptions,
        COUNT(*) FILTER (WHERE is_trial = TRUE)  AS trial_subscriptions
    FROM subscriptions
),

active_subscriptions AS (
    SELECT
        s.account_id,
        s.is_trial
    FROM subscriptions s
    CROSS JOIN snapshot_date d
    WHERE s.start_date <= d.snapshot_date
      AND (s.end_date IS NULL OR s.end_date >= d.snapshot_date)
),

active_accounts AS (
    SELECT
        COUNT(DISTINCT account_id) AS active_accounts
    FROM active_subscriptions
),

active_account_split AS (
    SELECT
        COUNT(DISTINCT account_id) FILTER (WHERE is_trial = FALSE) AS active_paid_accounts,
        COUNT(DISTINCT account_id) FILTER (WHERE is_trial = TRUE)  AS active_trial_accounts
    FROM active_subscriptions
),

active_subscription_split AS (
    SELECT
        COUNT(*) FILTER (WHERE is_trial = FALSE) AS active_paid_subscriptions,
        COUNT(*) FILTER (WHERE is_trial = TRUE)  AS active_trial_subscriptions
    FROM active_subscriptions
),

churned_accounts AS (
    SELECT
        COUNT(DISTINCT account_id) AS churned_accounts
    FROM churn_events
)

SELECT
    ta.total_accounts,
    ts.total_subscriptions,

    ss.paid_subscriptions,
    ss.trial_subscriptions,

    aa.active_accounts,

    aas.active_paid_accounts,
    aas.active_trial_accounts,

    ass.active_paid_subscriptions,
    ass.active_trial_subscriptions,

    ca.churned_accounts

FROM total_accounts ta
CROSS JOIN total_subscriptions ts
CROSS JOIN subscription_split ss
CROSS JOIN active_accounts aa
CROSS JOIN active_account_split aas
CROSS JOIN active_subscription_split ass
CROSS JOIN churned_accounts ca;
