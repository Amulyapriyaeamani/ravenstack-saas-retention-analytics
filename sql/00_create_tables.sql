-- =========================================
-- RAVENSTACK DATABASE SCHEMA
-- =========================================

-- =========================================
-- ACCOUNTS TABLE
-- =========================================

CREATE TABLE accounts (
    account_id TEXT PRIMARY KEY,
    account_name TEXT,
    industry TEXT,
    country TEXT,
    signup_date DATE,
    referral_source TEXT,
    plan_tier TEXT,
    seats INT,
    is_trial BOOLEAN,
    churn_flag BOOLEAN
);

-- =========================================
-- SUBSCRIPTIONS TABLE
-- =========================================

CREATE TABLE subscriptions (
    subscription_id TEXT PRIMARY KEY,
    account_id TEXT,
    start_date DATE,
    end_date DATE,
    plan_tier TEXT,
    seats INT,
    mrr_amount NUMERIC,
    arr_amount NUMERIC,
    is_trial BOOLEAN,
    upgrade_flag BOOLEAN,
    downgrade_flag BOOLEAN,
    churn_flag BOOLEAN,
    billing_frequency TEXT,
    auto_renew_flag BOOLEAN
);

-- =========================================
-- FEATURE USAGE TABLE
-- =========================================

CREATE TABLE feature_usage (
    usage_id TEXT PRIMARY KEY,
    subscription_id TEXT,
    usage_date DATE,
    feature_name TEXT,
    usage_count INT,
    usage_duration_secs INT,
    error_count INT,
    is_beta_feature BOOLEAN
);

-- =========================================
-- SUPPORT TICKETS TABLE
-- =========================================

CREATE TABLE support_tickets (
    ticket_id TEXT PRIMARY KEY,
    account_id TEXT,
    submitted_at TIMESTAMP,
    closed_at TIMESTAMP,
    resolution_time_hours NUMERIC,
    priority TEXT,
    first_response_time_minutes INT,
    satisfaction_score INT,
    escalation_flag BOOLEAN
);

-- =========================================
-- CHURN EVENTS TABLE
-- =========================================

CREATE TABLE churn_events (
    churn_event_id TEXT PRIMARY KEY,
    account_id TEXT,
    churn_date DATE,
    reason_code TEXT,
    refund_amount_usd NUMERIC,
    preceding_upgrade_flag BOOLEAN,
    preceding_downgrade_flag BOOLEAN,
    is_reactivation BOOLEAN,
    feedback_text TEXT
);