/*
================================================================================
FILE: 02_base_active_monthly.sql
PURPOSE:
    Creates a monthly base table of active accounts.
DEFINITION:
    An account is considered ACTIVE in a given month if it has at least one
    subscription (trial or paid) that overlaps with that month.
LOGIC:
    - Generate a month spine from earliest to latest subscription start_date
    - Join subscriptions to each month using active window logic:
        start_date <= month_end
        AND (end_date IS NULL OR end_date >= month_start)
    - Classify each account per month as: paid / trial / mixed
    - One row per account per month guaranteed
OUTPUT:
    month           → month start date (time dimension)
    account_id      → unique account active in that month
    account_type    → 'paid' / 'trial' / 'mixed'
    signup_date     → account creation date (for cohort analysis)
IMPORTANT NOTES:
    - One account can have multiple subscriptions, but is counted once per month
    - account_type classification:
        mixed  = has both paid AND trial subscription active in same month
        paid   = has only paid subscription(s) active
        trial  = has only trial subscription(s) active
    - mixed is checked FIRST in CASE to prevent silent misclassification
    - signup_date added for cohort and retention analysis (Steps 14 and 27)
    - This table acts as the PRIMARY DENOMINATOR for:
        • Churn Rate
        • Retention Rate
        • Feature Adoption Rate
        • Active Users
        • ARPU (filtered to paid + mixed)
        • Cohort Analysis
ASSUMPTIONS:
    - NULL end_date = still active
    - Month-level granularity is sufficient (no day-level overlap enforced)
USAGE:
    - All active accounts:       SELECT * FROM base_active_monthly
    - Paid accounts only:        WHERE account_type IN ('paid', 'mixed')
    - Trial only accounts:       WHERE account_type = 'trial'
    - Mixed accounts only:       WHERE account_type = 'mixed'
    - Cohort grouping:           DATE_TRUNC('month', signup_date)
================================================================================
*/

DROP VIEW IF EXISTS base_active_monthly;
CREATE VIEW base_active_monthly AS

WITH month_spine AS (
    /*
    --------------------------------------------------------
    Step 1: Generate complete month spine
    --------------------------------------------------------
    Covers full dataset range from first to last
    subscription start_date.
    Ensures no months are skipped even if no new
    subscriptions started in that month.
    --------------------------------------------------------
    */
    SELECT generate_series(
        DATE_TRUNC('month', (SELECT MIN(start_date) FROM subscriptions)),
        DATE_TRUNC('month', (SELECT MAX(start_date) FROM subscriptions)),
        INTERVAL '1 month'
    ) AS month_start
),

subscription_activity AS (
    /*
    --------------------------------------------------------
    Step 2: Find all active subscriptions per month
    --------------------------------------------------------
    A subscription is active in month M if:
        start_date <= last day of month M
        AND (end_date IS NULL OR end_date >= first day of M)
    Also joins accounts to bring in signup_date
    for cohort analysis.
    --------------------------------------------------------
    */
    SELECT
        m.month_start,
        s.account_id,
        s.is_trial,
        a.signup_date
    FROM month_spine m
    JOIN subscriptions s
        ON s.start_date <= (m.month_start + INTERVAL '1 month' - INTERVAL '1 day')
       AND (s.end_date IS NULL OR s.end_date >= m.month_start)
    JOIN accounts a
        ON s.account_id = a.account_id
),

account_classification AS (
    /*
    --------------------------------------------------------
    Step 3: Classify each account per month
    --------------------------------------------------------
    Guarantees ONE ROW per account per month.

    Classification logic:
        mixed  → has both paid AND trial active this month
        paid   → has only paid subscription(s) active
        trial  → has only trial subscription(s) active

    IMPORTANT: mixed is evaluated FIRST.
    If paid is checked first, mixed accounts silently
    become 'paid' and the signal is lost.

    signup_date is stable per account — MIN() used
    to collapse across multiple subscription rows
    while keeping GROUP BY clean.
    --------------------------------------------------------
    */
    SELECT
        month_start                                             AS month,
        account_id,
        CASE
            WHEN BOOL_OR(is_trial = FALSE)
             AND BOOL_OR(is_trial = TRUE)  THEN 'mixed'
            WHEN BOOL_OR(is_trial = FALSE) THEN 'paid'
            ELSE                                'trial'
        END                                                     AS account_type,
        MIN(signup_date)                                        AS signup_date
    FROM subscription_activity
    GROUP BY month_start, account_id
)

SELECT *
FROM account_classification
ORDER BY month, account_id;


-- =====================================================================
-- VALIDATION QUERIES
-- =====================================================================

-- Full table preview
SELECT * FROM base_active_monthly;

-- Account type distribution
SELECT
    account_type,
    COUNT(DISTINCT account_id)  AS distinct_accounts,
    COUNT(*)                    AS total_rows
FROM base_active_monthly
GROUP BY account_type
ORDER BY account_type;

-- Total distinct accounts (should = 500)
SELECT COUNT(DISTINCT account_id) AS total_distinct_accounts
FROM base_active_monthly;

-- Monthly active account counts by type
SELECT
    month,
    COUNT(*) FILTER (WHERE account_type IN ('paid', 'mixed')) AS paid_accounts,
    COUNT(*) FILTER (WHERE account_type = 'trial')            AS trial_accounts,
    COUNT(*) FILTER (WHERE account_type = 'mixed')            AS mixed_accounts,
    COUNT(*)                                                   AS total_accounts
FROM base_active_monthly
GROUP BY month
ORDER BY month;

-- Cohort distribution (signup month)
SELECT
    DATE_TRUNC('month', signup_date)    AS signup_cohort,
    COUNT(DISTINCT account_id)          AS accounts_in_cohort
FROM base_active_monthly
GROUP BY signup_cohort
ORDER BY signup_cohort;