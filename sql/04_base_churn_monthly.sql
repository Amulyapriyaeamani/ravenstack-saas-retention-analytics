/*
===============================================================================
FILE: 04_base_churn_monthly.sql
===============================================================================
PURPOSE
------------------------------------------------------------------------------
Creates a reusable monthly churn base table at the ACCOUNT level.
This is the master churn numerator table used for:
    - Monthly Churn Rate
    - Monthly Retention Rate
    - Revenue Churn Rate
    - Churn Segmentation (plan, industry, country)
    - Churn Reason Analysis
    - Usage vs Churn Analysis
    - Support vs Churn Analysis
    - Multi-Factor Churn Model
    - Cohort Retention Analysis

BUSINESS LOGIC
------------------------------------------------------------------------------
A churned account is defined as:
    - An account with at least one churn_event during a given month

Rules:
    - Accounts are counted ONCE per month
    - Multiple churn events within same month are deduplicated
    - Churn is measured at account level, NOT subscription level
    - Trial + paid churn both included in base
    - Paid-only filtering applied downstream if needed
    - Most recent churn event selected when duplicates exist in same month

WHY DEDUPLICATION MATTERS
------------------------------------------------------------------------------
An account may:
    - churn
    - reactivate
    - churn again
within the same month.

Without deduplication:
    - churn counts become inflated
    - churn rate becomes inaccurate
    - reason_code and flags become ambiguous

This base prevents double-counting by ensuring:
    ONE ROW = ONE ACCOUNT = ONE MONTH

When duplicates exist in same month:
    Most recent churn event is selected (ORDER BY churn_date DESC)
    This captures the final churn state for that month.

REASON CODE LOGIC
------------------------------------------------------------------------------
reason_code is included directly in this base table because:
    - Churn reason analysis (Step 21) is a core module
    - Avoids repeated joins to churn_events in every downstream query
    - reason_code is stable at event level (not derived)

DOWNGRADE FLAG LOGIC
------------------------------------------------------------------------------
preceding_downgrade_flag is included because:
    - Downgrade before churn is a strong pre-churn signal
    - Used in Multi-Factor Churn Model (Step 25)
    - Avoids repeated joins to churn_events downstream

OUTPUT
------------------------------------------------------------------------------
month                       → month of churn (DATE_TRUNC to month)
account_id                  → churned account
reason_code                 → primary churn reason
preceding_downgrade_flag    → TRUE if account downgraded before churning

Example:
2024-03-01 | A-101 | pricing       | false
2024-03-01 | A-245 | support       | true
2024-03-01 | A-389 | features      | false

TECHNICAL NOTES
------------------------------------------------------------------------------
- DISTINCT ON (month, account_id) guarantees one row per account per month
- ORDER BY churn_date DESC selects most recent event when duplicates exist
- DATE_TRUNC('month', churn_date) standardizes to monthly granularity
- Output is intentionally minimal and reusable
- Additional dimensions (plan, industry, country) joined downstream
- churn_events is the confirmed source of truth (Step 7 decision)
===============================================================================
*/

DROP VIEW IF EXISTS base_churn_monthly;
CREATE VIEW base_churn_monthly AS

WITH churned_accounts AS (
    /*
    --------------------------------------------------------
    Step 1: Deduplicate churn events
    --------------------------------------------------------
    Selects ONE ROW per account per month.

    If an account has multiple churn events in the same
    month (reactivation cycle within month), the most
    recent event is selected using:
        DISTINCT ON (month, account_id)
        ORDER BY month, account_id, churn_date DESC

    This captures the final churn state for that month
    including the most recent reason_code, flags,
    and exact churn_date.

    churn_date retained for:
        - Time-to-churn analysis
        - Cohort survival curves
        - Downgrade-to-churn gap analysis
        - Churn lag analysis
        - Retention curve precision
    --------------------------------------------------------
    */
    SELECT DISTINCT ON (
        DATE_TRUNC('month', churn_date),
        account_id
    )
        DATE_TRUNC('month', churn_date)     AS month,
        account_id,
        churn_date,                          -- exact churn date retained
        reason_code,
        preceding_downgrade_flag
    FROM churn_events
    WHERE churn_date IS NOT NULL
    ORDER BY
        DATE_TRUNC('month', churn_date),
        account_id,
        churn_date DESC                      -- most recent event selected
)

SELECT *
FROM churned_accounts
ORDER BY month, account_id;


-- =====================================================================
-- VALIDATION QUERIES
-- =====================================================================

-- Full table preview
SELECT * FROM base_churn_monthly;

-- Monthly churn counts
SELECT
    month,
    COUNT(*)                                                    AS churned_accounts,
    COUNT(*) FILTER (WHERE preceding_downgrade_flag = TRUE)    AS churned_after_downgrade,
    COUNT(*) FILTER (WHERE preceding_downgrade_flag = FALSE)   AS churned_without_downgrade
FROM base_churn_monthly
GROUP BY month
ORDER BY month;

-- Churn reason distribution
SELECT
    reason_code,
    COUNT(*)                                AS total_churns,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM base_churn_monthly
GROUP BY reason_code
ORDER BY total_churns DESC;

-- Deduplication check: should return 0 rows
SELECT
    month,
    account_id,
    COUNT(*) AS appearances
FROM base_churn_monthly
GROUP BY month, account_id
HAVING COUNT(*) > 1;

-- Total distinct churned accounts (should = 352)
SELECT COUNT(DISTINCT account_id) AS total_churned_accounts
FROM base_churn_monthly;