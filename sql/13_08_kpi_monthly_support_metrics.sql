-- ============================================
-- FILE: 13_08_kpi_monthly_support_metrics.sql
-- PURPOSE:
-- Monthly customer support KPI layer for:
-- - resolution efficiency
-- - customer satisfaction
-- - escalation tracking
-- - support workload distribution
-- - operational performance monitoring
--
-- BUSINESS RULES:
-- 1. Only closed tickets are included
--    because open tickets do not have
--    finalized resolution metrics.
--
-- 2. Metrics are attributed using closed_at
--    (resolution month), not created_at.
--
-- 3. NULL satisfaction_score represents
--    customer non-response, NOT missing data.
--    AVG() and COUNT(column) intentionally
--    exclude NULL values.
--  This behavior is intentional because NULL CSAT values
-- represent customers who did not submit feedback.
-- ============================================

DROP VIEW IF EXISTS kpi_monthly_support_metrics;

CREATE VIEW kpi_monthly_support_metrics AS

WITH resolved_tickets AS (

    SELECT
        DATE_TRUNC('month', closed_at)::DATE      AS month,
        ticket_id,
        resolution_time_hours,
        first_response_time_minutes,
        satisfaction_score,
        priority,
        escalation_flag

    FROM support_tickets

    WHERE closed_at IS NOT NULL
),

monthly_support_metrics AS (

    SELECT
        month,

        -- =========================
        -- Ticket Volume Metrics
        -- =========================
        COUNT(ticket_id) AS closed_tickets,

        COUNT(ticket_id)
            FILTER (WHERE priority = 'urgent')
            AS urgent_tickets,

        COUNT(ticket_id)
            FILTER (WHERE priority = 'high')
            AS high_tickets,

        COUNT(ticket_id)
            FILTER (WHERE priority = 'medium')
            AS medium_tickets,

        COUNT(ticket_id)
            FILTER (WHERE priority = 'low')
            AS low_tickets,

        -- =========================
        -- Resolution Metrics
        -- =========================
        ROUND(
            AVG(resolution_time_hours)::NUMERIC,
            2
        ) AS avg_resolution_time_hours,

        ROUND(
            PERCENTILE_CONT(0.5)
            WITHIN GROUP (
                ORDER BY resolution_time_hours
            )::NUMERIC,
            2
        ) AS median_resolution_time_hours,

        ROUND(
            AVG(first_response_time_minutes)::NUMERIC,
            2
        ) AS avg_first_response_time_mins,

        -- =========================
        -- CSAT Metrics
        -- =========================
        ROUND(
            AVG(satisfaction_score)::NUMERIC,
            2
        ) AS avg_csat_score,

        ROUND(
            AVG(satisfaction_score)
                FILTER (WHERE escalation_flag = TRUE)::NUMERIC,
            2
        ) AS avg_csat_escalated,

        COUNT(satisfaction_score)
            AS tickets_with_csat,

        ROUND(
            COUNT(satisfaction_score)::NUMERIC
            / NULLIF(COUNT(ticket_id), 0) * 100,
            2
        ) AS csat_response_rate_pct,

        -- =========================
        -- Escalation Metrics
        -- =========================
        COUNT(ticket_id)
            FILTER (WHERE escalation_flag = TRUE)
            AS escalated_tickets,

        ROUND(
            COUNT(ticket_id)
                FILTER (WHERE escalation_flag = TRUE)::NUMERIC
            / NULLIF(COUNT(ticket_id), 0) * 100,
            2
        ) AS escalation_rate_pct

    FROM resolved_tickets

    GROUP BY month
)

SELECT *
FROM monthly_support_metrics
ORDER BY month;


-- ============================================
-- VALIDATION QUERIES
-- ============================================

-- 1. Monthly KPI Output Check
SELECT *
FROM kpi_monthly_support_metrics
ORDER BY month;


-- 2. Check Total Closed Tickets
SELECT
    COUNT(*) AS total_closed_tickets
FROM support_tickets
WHERE closed_at IS NOT NULL;


-- 3. Validate Monthly Ticket Totals
SELECT
    SUM(closed_tickets) AS aggregated_closed_tickets
FROM kpi_monthly_support_metrics;


-- 4. Validate CSAT Non-NULL Count
SELECT
    COUNT(satisfaction_score) AS total_csat_responses
FROM support_tickets
WHERE closed_at IS NOT NULL;


-- 5. Validate Escalation Count
SELECT
    COUNT(*) AS total_escalated_tickets
FROM support_tickets
WHERE closed_at IS NOT NULL
  AND escalation_flag = TRUE;


-- 6. Data Quality Checks
SELECT
    COUNT(*) AS negative_resolution_times
FROM support_tickets
WHERE resolution_time_hours < 0;


SELECT
    COUNT(*) AS negative_first_response_times
FROM support_tickets
WHERE first_response_time_minutes < 0;


SELECT
    MIN(satisfaction_score) AS min_csat,
    MAX(satisfaction_score) AS max_csat
FROM support_tickets
WHERE satisfaction_score IS NOT NULL;
