# KPI Layer Documentation
## RavenStack SaaS Pre-Launch Analysis
**Project:** RavenStack Pre-Launch Performance Analysis
**Role:** Product Analyst
**Step:** 13 — KPI Layer (Monthly Business Metrics)
**Status:** Complete & Validated
**Last Updated:** 2026-04-28

---

## Table of Contents
1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Design Principles](#3-design-principles)
4. [KPI Views Reference](#4-kpi-views-reference)
   - [13.1 — kpi_monthly_churn_rate](#41-kpi_monthly_churn_rate)
   - [13.2 — kpi_monthly_retention_rate](#42-kpi_monthly_retention_rate)
   - [13.3 — kpi_monthly_mrr_growth](#43-kpi_monthly_mrr_growth)
   - [13.4 — kpi_monthly_active_users](#44-kpi_monthly_active_users)
   - [13.5 — kpi_monthly_feature_adoption](#45-kpi_monthly_feature_adoption)
   - [13.6 — kpi_monthly_revenue_churn_rate](#46-kpi_monthly_revenue_churn_rate)
   - [13.7 — kpi_monthly_upgrade_downgrade](#47-kpi_monthly_upgrade_downgrade)
   - [13.8 — kpi_monthly_support_metrics](#48-kpi_monthly_support_metrics)
5. [Validation Summary](#5-validation-summary)
6. [Key Decisions & Rationale](#6-key-decisions--rationale)
7. [Known Limitations](#7-known-limitations)
8. [Cross-KPI Relationships](#8-cross-kpi-relationships)
9. [KPI Findings Summary](#9-kpi-findings-summary)
10. [Pre-Launch Risk Assessment](#10-pre-launch-risk-assessment)

---

## 1. Overview

The KPI layer transforms the base layer into **business metrics**.

It sits between the base layer and analysis/dashboard:

```
Raw Tables
    ↓
Base Layer     (Step 12 — complete)
    ↓
KPI Layer      ← YOU ARE HERE
    ↓
Core Analysis  (Steps 16–23)
Advanced Analysis (Steps 24–28)
Dashboard      (Phase 6)
```

### Purpose

- Compute all monthly SaaS KPIs from validated base views
- Produce dashboard-ready output columns
- Enable cross-KPI comparison and reconciliation
- Surface pre-launch business health signals

### Core Principle

> KPI views should USE base views.
> They should NOT rebuild base logic.
> Every KPI should be short, readable, and dashboard-ready.

---

## 2. Architecture

### File Structure

```
📁 sql/
├── 13_01_kpi_monthly_churn_rate.sql
├── 13_02_kpi_monthly_retention_rate.sql
├── 13_03_kpi_monthly_mrr_growth.sql
├── 13_04_kpi_monthly_active_users.sql
├── 13_05_kpi_monthly_feature_adoption.sql
├── 13_06_kpi_monthly_revenue_churn_rate.sql
├── 13_07_kpi_monthly_upgrade_downgrade.sql
└── 13_08_kpi_monthly_support_metrics.sql
```

### Dependency Map

```
base_active_monthly ──────────────────────────────→ kpi_monthly_churn_rate
                                                          ↓
base_churn_monthly ──────────────────────────────→ kpi_monthly_churn_rate
                                                          ↓
                                              kpi_monthly_retention_rate (depends on churn)

base_mrr_monthly ────────────────────────────────→ kpi_monthly_mrr_growth

base_active_monthly ──────────────────────────────→ kpi_monthly_active_users
base_feature_usage_monthly ───────────────────────→ kpi_monthly_active_users

base_active_monthly ──────────────────────────────→ kpi_monthly_feature_adoption
base_feature_usage_monthly ───────────────────────→ kpi_monthly_feature_adoption

subscriptions (raw) ──────────────────────────────→ kpi_monthly_revenue_churn_rate
base_churn_monthly ───────────────────────────────→ kpi_monthly_revenue_churn_rate

subscriptions (raw) ──────────────────────────────→ kpi_monthly_upgrade_downgrade

support_tickets (raw) ────────────────────────────→ kpi_monthly_support_metrics
```

### KPI Categories

| Category | KPIs |
|---|---|
| 🔴 Churn & Retention | churn_rate, retention_rate |
| 🟢 Revenue | mrr_growth, revenue_churn_rate, upgrade_downgrade |
| 🟣 Engagement | active_users, feature_adoption |
| 🟡 Support | support_metrics |

---

## 3. Design Principles

### 3.1 Use Base Views — Never Rebuild Logic

KPI views delegate to base layer instead of rebuilding from raw tables.

```sql
-- WRONG: rebuilds churn deduplication logic
SELECT DISTINCT DATE_TRUNC('month', churn_date), account_id
FROM churn_events

-- RIGHT: delegates to base layer
SELECT month, COUNT(*) AS churned_accounts
FROM base_churn_monthly
GROUP BY month
```

**Exception:** When KPI logic requires a stricter definition than the base layer provides (e.g. start-of-month active accounts for churn denominator), a helper CTE using raw tables is acceptable and documented.

### 3.2 Start-of-Month vs Active-Anytime

This is the most important distinction in the KPI layer:

| Context | Active Definition | Used For |
|---|---|---|
| base_active_monthly | Active ANYTIME during month | Feature adoption denominator, active users |
| Churn/Retention denominator | Active on FIRST DAY of month | Churn rate, retention rate, revenue churn |

**Why the distinction matters:**

Using active-anytime for churn rate would include accounts that joined mid-month — they were never exposed to full churn risk for the period. This artificially lowers the churn rate.

Correct SaaS practice: churn denominator = population at risk at start of period.

### 3.3 NULLIF on All Divisions

Every ratio calculation uses `NULLIF` to prevent division-by-zero errors:

```sql
ROUND(numerator::NUMERIC / NULLIF(denominator, 0) * 100, 2)
```

### 3.4 is_reliable Flag

Early months with small denominators produce statistically unreliable percentages. Every rate KPI includes `is_reliable = FALSE` when the denominator is below threshold.

| KPI | Reliability Threshold |
|---|---|
| churn_rate | start_month_active_accounts < 10 |
| retention_rate | Inherited from churn_rate |
| mrr_growth | prev_month_mrr IS NULL (first month) |
| revenue_churn_rate | start_month_paid_accounts < 10 |

### 3.5 COALESCE for Zero Months

LEFT JOINs preserve months with no activity. `COALESCE(..., 0)` ensures these appear as 0 rather than NULL:

```sql
COALESCE(c.churned_accounts, 0) AS churned_accounts
```

### 3.6 KPI Reconciliation

Churn and retention are independently defined but reconciled:

```
Retention Rate + Churn Rate = 100%
```

Validated across all 24 months — confirmed ✅.

---

## 4. KPI Views Reference

---

### 4.1 kpi_monthly_churn_rate

**File:** `13_01_kpi_monthly_churn_rate.sql`
**Purpose:** Primary customer churn metric
**Grain:** One row per month

#### Business Definition

> Of all accounts active at the beginning of month M,
> what percentage churned during month M?

#### Formula

```
Monthly Churn Rate % =
    COUNT(DISTINCT churned accounts during M)
    ─────────────────────────────────────────
    COUNT(DISTINCT accounts active on day 1 of M)
    × 100
```

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| start_month_active_accounts | integer | Accounts active on first day of month |
| churned_accounts | integer | Distinct accounts that churned |
| monthly_churn_rate_pct | numeric | Churn percentage |
| is_reliable | boolean | FALSE when denominator < 10 |

#### Denominator Logic (Important)

The denominator uses a helper CTE against raw `subscriptions`, not `base_active_monthly`:

```sql
ON s.start_date <= m.month_start
AND (s.end_date IS NULL OR s.end_date >= m.month_start)
```

This is **stricter** than `base_active_monthly` (active-anytime). Only accounts present on the first day qualify.

#### Validated Output

```
Reliable months           22/23
Average churn rate        11.41%
Best month                Sep 2023    5.13%
Worst month               Dec 2024   20.17%
Industry benchmark        2-5% monthly
Gap to benchmark          2-4x above healthy range
```

#### Monthly Results

| Month | Active | Churned | Churn Rate |
|---|---|---|---|
| 2023-09 | 117 | 6 | 5.13% ← best |
| 2024-02 | 216 | 10 | 4.63% |
| 2024-06 | 313 | 38 | 12.14% |
| 2024-10 | 415 | 60 | 14.46% |
| 2024-12 | 476 | 96 | 20.17% ← worst |

#### Key Insight

Churn crossed 10% threshold in June 2024 and never recovered. December 2024 at 20.17% is a pre-launch crisis signal — nearly 1 in 5 accounts lost in a single month.

---

### 4.2 kpi_monthly_retention_rate

**File:** `13_02_kpi_monthly_retention_rate.sql`
**Purpose:** Customer retention complement to churn rate
**Grain:** One row per month
**Depends on:** kpi_monthly_churn_rate

#### Business Definition

> Of all accounts active at the beginning of month M,
> what percentage remained active throughout that month?

#### Formula

```
Monthly Retention Rate % =
    (start_month_active_accounts − churned_accounts)
    ─────────────────────────────────────────────────
    start_month_active_accounts
    × 100
```

#### Design Decision — Independent Calculation

Retention is mathematically equivalent to `100 − churn_rate` but is **defined independently** by depending on `kpi_monthly_churn_rate` directly.

This approach:
- Guarantees denominator consistency (both KPIs share exactly the same denominator)
- Prevents KPI drift if churn logic changes
- Follows DRY principle — no duplicated CTE logic
- Makes reconciliation trivial

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| start_month_active_accounts | integer | Denominator |
| churned_accounts | integer | From churn rate view |
| retained_accounts | integer | active − churned |
| monthly_churn_rate_pct | numeric | Included for reconciliation |
| monthly_retention_rate_pct | numeric | Primary KPI |
| is_reliable | boolean | Inherited from churn rate |

#### Reconciliation Validated

```
Retention Rate + Churn Rate = 100.00%
Verified across all 24 months ✅
```

#### Validated Output

```
Average retention rate    88.08%  (reliable months only)
Best month                Feb 2024    95.37%
Worst month               Dec 2024    79.83%
Industry benchmark        95%+ monthly
Gap to benchmark          ~7 percentage points on average
```

#### Feb–Mar 2024 Anomaly

```
Feb 2024    95.37%  (+4.79pp — best reliable month)
Mar 2024    89.79%  (-5.58pp — sharpest single drop)
```

Pattern suggests delayed churns in February caught up in March — not genuine retention improvement. Cross-check with support and feature usage in Phase 3.

---

### 4.3 kpi_monthly_mrr_growth

**File:** `13_03_kpi_monthly_mrr_growth.sql`
**Purpose:** Monthly recurring revenue and growth trends
**Grain:** One row per month
**Depends on:** base_mrr_monthly

#### Business Definition

MRR Growth Rate measures how much monthly recurring revenue changed compared to the previous month.

#### Formula

```
MRR Growth Rate % =
    (current_month_mrr − previous_month_mrr)
    ─────────────────────────────────────────
    previous_month_mrr
    × 100
```

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| paid_active_accounts | integer | Paying accounts |
| total_mrr | numeric | Monthly recurring revenue |
| prev_month_mrr | numeric | Previous month MRR |
| mrr_change | numeric | Absolute MRR change |
| mrr_growth_pct | numeric | MoM growth percentage |
| arpu | numeric | Average revenue per account |
| mrr_basic | numeric | Basic plan revenue |
| mrr_pro | numeric | Pro plan revenue |
| mrr_enterprise | numeric | Enterprise plan revenue |
| is_reliable | boolean | FALSE for first month |

#### Technical Pattern — LAG()

```sql
LAG(total_mrr) OVER (ORDER BY month) AS prev_month_mrr
```

LAG() window function is more efficient than self-join for previous month lookup. First month returns NULL — expected and documented.

#### Plan Reconstruction Validated

```
mrr_basic + mrr_pro + mrr_enterprise = total_mrr
Difference = 0.00 across all 24 months ✅
```

#### Validated Output

```
Total MRR growth          $4,684 → $10,734,251  (2,291x in 24 months)
ARPU growth               $2,342 → $21,469       (9.2x)
Avg monthly growth rate   46.72%
Min monthly growth        13.66%  (Aug 2024)
Max monthly growth        236.53% (Feb 2023 — early hypergrowth)
```

#### Plan Concentration

| Month | Basic % | Pro % | Enterprise % |
|---|---|---|---|
| 2023-01 | 0.0% | 19.9% | 80.1% |
| 2023-06 | 4.6% | 17.9% | 77.5% |
| 2024-06 | 0.4% | 5.5% | 94.1% |
| 2024-12 | 0.0% | 1.7% | 98.2% |

Enterprise consuming nearly all revenue by end of dataset. Basic plan essentially dead. Pro declining sharply in December 2024.

#### Key Insight

December 2024: +24.13% MRR growth AND 20.17% churn rate simultaneously. Revenue masking account instability. Large Enterprise deals offsetting mass smaller-account churn.

---

### 4.4 kpi_monthly_active_users

**File:** `13_04_kpi_monthly_active_users.sql`
**Purpose:** Monthly Active Users (MAU) and engagement rate
**Grain:** One row per month
**Depends on:** base_active_monthly, base_feature_usage_monthly

#### Business Definition

An active user is an account with:
1. At least one active subscription during the month
2. At least one feature usage event during the same month

This measures **product engagement**, not just subscription activity.

#### Formula

```
Monthly Active Users =
    COUNT(DISTINCT account_id)
    with active subscription AND feature usage in month M

Engagement Rate % =
    monthly_active_users
    ─────────────────────
    total_active_accounts
    × 100
```

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| monthly_active_users | integer | Engaged active accounts |
| total_active_accounts | integer | All active accounts |
| engagement_rate_pct | numeric | % of accounts that used product |

#### LEFT JOIN Design Decision

LEFT JOIN (not INNER JOIN) is used intentionally:

```sql
FROM active_accounts a
LEFT JOIN engaged_accounts e ON a.month = e.month AND a.account_id = e.account_id
```

INNER JOIN would silently drop months where accounts exist but no usage happened — overstating engagement rate. LEFT JOIN preserves dormant account signal.

#### Validated Output

```
MAU growth              1 → 417  (417x over 24 months)
Engagement rate growth  50% → 83.40%
Year-over-year          ~35% (2023) → ~65% (2024)
```

#### Dormant Account Risk

| Month | Active | MAU | Not Engaged |
|---|---|---|---|
| 2023-06 | 71 | 17 | 54 (76%) |
| 2024-01 | 217 | 92 | 125 (58%) |
| 2024-12 | 500 | 417 | 83 (17%) |

83 accounts paying but not engaging in December 2024 — high churn risk. Likely overlaps significantly with the 96 churned accounts that month.

#### Key Anomaly — May 2023

```
Apr 2023    16 MAU    +166.67%
May 2023    13 MAU    -18.75%   ← only negative MAU growth month
Jun 2023    17 MAU    +30.77%
```

Only month with MAU decline. Consistent with churn spike in same period.

---

### 4.5 kpi_monthly_feature_adoption

**File:** `13_05_kpi_monthly_feature_adoption.sql`
**Purpose:** Per-feature monthly adoption rates
**Grain:** One row per month per feature per beta status
**Depends on:** base_feature_usage_monthly, base_active_monthly

#### Business Definition

Feature Adoption Rate measures what percentage of active accounts used a specific feature during a given month.

#### Formula

```
Feature Adoption Rate % =
    COUNT(DISTINCT accounts using feature F in month M)
    ───────────────────────────────────────────────────
    COUNT(DISTINCT active accounts in month M)
    × 100
```

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| feature_name | varchar | Feature dimension |
| is_beta_feature | boolean | Beta status |
| adopted_accounts | integer | Accounts using feature |
| total_active_accounts | integer | Active account denominator |
| feature_adoption_rate_pct | numeric | Adoption percentage |
| total_usage_count | integer | Total usage volume |
| avg_usage_per_adopter | numeric | Depth of engagement |

#### Denominator Note

Denominator uses `base_active_monthly` (active-anytime). Numerator uses `base_feature_usage_monthly` (tied to active subscription during usage). Minor population difference is acceptable at monthly grain — documented in KPI definitions Step 11.

#### Feature State Grain

`feature_name + is_beta_feature` is the grain. Same feature can appear twice if beta status changed over time. This is intentional — enables beta→GA transition analysis.

#### Validated Output

```
Total rows              1,069
Distinct features          40  ✅
Total months               24  ✅
Total usage count      61,306  ✅ matches base layer exactly
Min adoption rate        0.20%
Max adoption rate       50.00%
```

#### Top Features by Adoption

| Feature | Avg Adoption | Usage Count | Avg/Adopter |
|---|---|---|---|
| feature_35 | 5.05% | 1,513 | 9.91 |
| feature_39 | 2.92% | 1,470 | 9.68 |
| feature_38 | 2.87% | 1,597 | 10.39 |

#### Beta vs Non-Beta

| Type | Avg Adoption | Avg Usage/Adopter |
|---|---|---|
| Non-beta | 2.51% | 10.05 |
| Beta | 0.58% | 9.97 |

Beta adoption 4.3x lower than GA but usage intensity nearly identical. Discoverability problem, not quality problem.

#### Key Insight — Feature Sprawl

Average adoption rate collapsed from 50% (1 feature, Jan 2023) to ~1.36% (40 features, 2024). More features competing for attention, none reaching critical adoption mass. Industry healthy core feature adoption: 20-40%+ monthly.

---

### 4.6 kpi_monthly_revenue_churn_rate

**File:** `13_06_kpi_monthly_revenue_churn_rate.sql`
**Purpose:** Revenue lost from churned accounts as % of starting MRR
**Grain:** One row per month
**Depends on:** subscriptions (raw), base_churn_monthly

#### Business Definition

Revenue Churn Rate measures what percentage of monthly recurring revenue was lost from accounts that churned during the month.

Unlike customer churn — this is revenue-weighted. Losing a large Enterprise account impacts this metric far more than losing a Basic account.

#### Formula

```
Revenue Churn Rate % =
    SUM(account MRR at start of M for accounts that churned during M)
    ──────────────────────────────────────────────────────────────────
    Total MRR from all active paid subscriptions on day 1 of M
    × 100
```

#### Critical Design — Start-of-Month MRR

MRR must be measured **before** churn occurs. Post-churn MRR from churned accounts = 0 — making the metric meaningless.

#### Aggregation Order

```
Step 1: subscription → account level MRR (SUM per account per month)
Step 2: filter to churned accounts only
Step 3: sum across all churned accounts
Step 4: divide by total starting MRR
```

This prevents double-counting accounts with multiple paid subscriptions.

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| start_month_paid_accounts | integer | Paid accounts on first day |
| start_month_mrr | numeric | Total MRR at month start |
| churned_paid_accounts | integer | Paid accounts that churned |
| churned_mrr | numeric | MRR lost from churned accounts |
| revenue_churn_rate_pct | numeric | % of MRR lost |
| is_reliable | boolean | FALSE when paid accounts < 10 |

#### Validated Output

```
Revenue churn range     0.00% – 13.73%  (reliable months)
Average                 ~6.5%
Best month              Aug 2023    2.06%
Worst month             Dec 2024   13.73%
Industry benchmark      < 1% monthly
```

#### Revenue vs Customer Churn Comparison

```
Month          Revenue Churn    Customer Churn    Gap
2023-08        2.06%            6.67%            -4.61  (small accounts leaving)
2024-02        4.66%            4.63%            +0.03  (balanced)
2024-08        11.01%           10.93%           +0.08  (slight high-value loss)
2024-12        13.73%           20.17%           -6.44  (small accounts leaving again)
```

Revenue churn consistently **lower** than customer churn across most months — smaller, lower-value accounts churning disproportionately. High-value Enterprise accounts are retained.

Only two months where revenue churn slightly exceeded customer churn (Jun 2023, Aug 2024) — both borderline.

#### Key Insight

Business is naturally self-selecting toward Enterprise but this is not a stable pre-launch strategy. Basic and Pro pipelines dying while Enterprise dependency grows to 98.2% of MRR.

---

### 4.7 kpi_monthly_upgrade_downgrade

**File:** `13_07_kpi_monthly_upgrade_downgrade.sql`
**Purpose:** Plan movement rates and expansion/contraction analysis
**Grain:** One row per month
**Depends on:** subscriptions (raw)

#### Business Definitions

**Upgrade Rate:** % of active paid accounts that upgraded during month M.

**Downgrade Rate:** % of active paid accounts that downgraded during month M.

#### Formulas

```
Upgrade Rate % =
    COUNT(DISTINCT accounts where upgrade_flag = TRUE in month M)
    ─────────────────────────────────────────────────────────────
    COUNT(DISTINCT active paid accounts in month M)
    × 100

Downgrade Rate % = same with downgrade_flag
```

#### Dataset Limitation

No dedicated plan-change event timestamp exists. `upgrade_flag` and `downgrade_flag` timing is **approximated using subscription start_date**.

This means a new subscription row marked as upgrade/downgrade is treated as occurring in that month. Rates may slightly overstate movement in months with new subscriptions.

**This limitation is documented in the view header and acceptable for project-level analysis.**

#### Stock vs Flow Distinction

Upgrade/downgrade rates measure **new plan changes occurring in each month** — not the stock of upgraded accounts. An account that upgraded in January only appears in January's numerator, even if their upgraded subscription spans multiple months.

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| paid_active_accounts | integer | Active paid account denominator |
| upgraded_accounts | integer | Accounts with upgrade this month |
| downgraded_accounts | integer | Accounts with downgrade this month |
| monthly_upgrade_rate_pct | numeric | Upgrade rate |
| monthly_downgrade_rate_pct | numeric | Downgrade rate |
| net_upgrade_accounts | integer | Upgraded minus downgraded |
| net_upgrade_rate_pct | numeric | Net expansion rate |

#### Validated Output

```
Avg upgrade rate      10.00%
Avg downgrade rate     3.97%
Net expansion         positive throughout
```

#### MRR Impact

| Month | Upgrade MRR | Downgrade MRR | Net |
|---|---|---|---|
| 2023-12 | $42,839 | $190 | +$42,649 |
| 2024-04 | $97,594 | $16,874 | +$80,720 |
| 2024-07 | $45,770 | $46,467 | -$697 ← only negative |
| 2024-12 | $160,180 | $133,955 | +$26,225 ← thinnest margin |

July 2024: only month where downgrade MRR exceeded upgrade MRR. Pre-launch contraction pressure signal.

December 2024: highest upgrade count ever (51 accounts) but downgrade MRR nearly cancels it. Net expansion compressed to thinnest margin in 18 months.

#### Key Insight

Downgrade rate tripling from January 2024 (2.42%) to December 2024 (6.60%). Average downgrading account MRR in December ($4,059) exceeds upgrading account ($3,141) — high-value accounts moving down, not just small accounts.

---

### 4.8 kpi_monthly_support_metrics

**File:** `13_08_kpi_monthly_support_metrics.sql`
**Purpose:** Monthly customer support operational KPIs
**Grain:** One row per month
**Depends on:** support_tickets (raw)

#### Business Definitions

**Average Resolution Time:** Average hours to close support tickets (closed tickets only).

**Median Resolution Time:** Median hours to close — more robust than average for skewed distributions.

**CSAT Score:** Average customer satisfaction score (1-5) for tickets with responses.

**CSAT Response Rate:** % of closed tickets that received a satisfaction response.

**Escalation Rate:** % of closed tickets that were escalated.

#### Time Attribution

Metrics attributed using `DATE_TRUNC('month', closed_at)` — ticket assigned to the month it was **resolved**, not submitted. This reflects support team performance by month.

#### NULL CSAT Handling

`NULL satisfaction_score` represents customer non-response, not missing data (confirmed in Step 10). PostgreSQL `AVG()` and `COUNT(column)` automatically exclude NULLs — intentional behavior, not a bug.

#### Output Schema

| Column | Type | Description |
|---|---|---|
| month | date | Reporting month |
| closed_tickets | integer | Resolved tickets |
| urgent_tickets | integer | Urgent priority count |
| high_tickets | integer | High priority count |
| medium_tickets | integer | Medium priority count |
| low_tickets | integer | Low priority count |
| avg_resolution_time_hours | numeric | Average resolution time |
| median_resolution_time_hours | numeric | Median resolution time |
| avg_first_response_time_mins | numeric | Average first response |
| avg_csat_score | numeric | Average CSAT (NULLs excluded) |
| avg_csat_escalated | numeric | CSAT for escalated tickets only |
| tickets_with_csat | integer | Count of CSAT responses |
| csat_response_rate_pct | numeric | % tickets with CSAT response |
| escalated_tickets | integer | Escalated ticket count |
| escalation_rate_pct | numeric | Escalation percentage |

#### Technical Note — PERCENTILE_CONT

```sql
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resolution_time_hours)
```

Resolution time distributions are typically right-skewed — a few very long tickets inflate the average. Median provides a more honest picture of typical customer experience. This is a production analytics pattern.

#### Validated Output

```
Total closed tickets          2,000  ✅
Monthly ticket aggregation    2,000  ✅ (no gaps)
Total CSAT responses          1,175
Overall CSAT response rate    58.75%
Total escalations             95
Negative resolution times     0  ✅
Negative first response       0  ✅
CSAT range                    3.0 – 5.0  ✅ (valid 1-5 scale)
```

#### Key Metrics Summary

```
Avg resolution time     33-40 hours    (benchmark: <24 hours)
CSAT score range        3.71 – 4.33    (benchmark: 4.5+)
CSAT response rate      55-65%
Escalation rate         1-8%
Avg first response      78-98 minutes  (benchmark: <60 minutes)
```

#### Escalated Ticket CSAT Finding

Escalated CSAT sometimes higher than overall CSAT (e.g. Feb 2024: 5.00 vs 4.04). Counterintuitive but explainable — escalated tickets receive dedicated handling, resulting in better resolution despite initial frustration.

Three months show NULL escalated CSAT — escalated tickets with no customer response. These are the most at-risk silent dissatisfied customers.

---

## 5. Validation Summary

### 5.1 Logic Bounds — All Pass

| KPI | Check | Result |
|---|---|---|
| churn_rate | churned never > active | ✅ 0 violations |
| churn_rate | rate between 0-100% | ✅ 0 violations |
| retention_rate | retained never > active | ✅ 0 violations |
| retention_rate | rate between 0-100% | ✅ 0 violations |
| retention_rate | retention + churn = 100% | ✅ all 24 months |
| mrr_growth | revenue never negative | ✅ 0 violations |
| mrr_growth | plan MRR reconstruction | ✅ 0.00 difference all months |
| active_users | MAU never > active accounts | ✅ 0 violations |
| feature_adoption | adopted never > active | ✅ 0 violations |
| revenue_churn | revenue churn never > 100% | ✅ 0 violations |
| revenue_churn | churned MRR never > starting | ✅ 0 violations |
| upgrade_downgrade | upgrades/downgrades never > paid | ✅ 0 violations |
| support_metrics | V2 = V3 (2,000 = 2,000) | ✅ perfect match |
| support_metrics | negative resolution times | ✅ 0 violations |
| support_metrics | CSAT range 1-5 | ✅ 3.0–5.0 confirmed |

### 5.2 Cross-KPI Reconciliation

| Check | Result |
|---|---|
| Retention + Churn = 100% (all months) | ✅ verified |
| feature adoption usage_count = base layer | ✅ 61,306 = 61,306 |
| support closed tickets = sum of monthly | ✅ 2,000 = 2,000 |
| MRR basic + pro + enterprise = total | ✅ 0.00 difference |

### 5.3 Reliability Flags

| KPI | Unreliable Months | Reason |
|---|---|---|
| churn_rate | 1 (Feb 2023) | denominator = 2 |
| retention_rate | 1 (Feb 2023) | inherited from churn |
| mrr_growth | 1 (Jan 2023) | no previous month |
| revenue_churn | 2 (Feb-Mar 2023) | paid accounts < 10 |

---

## 6. Key Decisions & Rationale

| Decision | What | Why |
|---|---|---|
| Start-of-month denominator for churn | Stricter active definition | Only accounts exposed to full churn risk qualify |
| Retention depends on churn rate view | DRY principle | Guarantees denominator consistency, prevents KPI drift |
| LAG() for MRR growth | Window function over self-join | More efficient, cleaner syntax |
| LEFT JOIN for active users | Preserves dormant account months | INNER JOIN would overstate engagement rate |
| is_reliable flag | Statistical caution | Small denominators produce misleading percentages |
| PERCENTILE_CONT for support | Median vs average | Resolution time distributions are right-skewed |
| avg_csat_escalated separate column | Escalated vs overall CSAT | Escalated tickets behave differently |
| Two usage metrics in feature adoption | COUNT(*) and SUM(usage_count) | 10x difference — intensity vs record count |
| Revenue churn uses start-of-month MRR | MRR before churn | Post-churn MRR = 0, metric becomes meaningless |
| Account-level MRR aggregation first | Two-step aggregation | Prevents double-counting multi-subscription accounts |
| COALESCE on all LEFT JOIN results | Null to zero | Months with no activity show 0, not NULL |
| NULLIF on all denominators | Division by zero protection | Defensive pattern for edge case months |

---

## 7. Known Limitations

### 7.1 Upgrade/Downgrade Timing Approximation

No dedicated plan-change event timestamp. Timing approximated using subscription `start_date`. Rates may slightly overstate movement. Documented in view header.

### 7.2 Feature Adoption Denominator Mismatch

Numerator uses `base_feature_usage_monthly` (tied to active subscription during usage). Denominator uses `base_active_monthly` (active-anytime). Minor population difference acceptable at monthly grain — documented in KPI definitions.

### 7.3 CSAT Response Rate Bias

58.75% of tickets have CSAT responses. Remaining 41.25% are non-responses — these may disproportionately represent dissatisfied customers who chose not to respond. CSAT score may be slightly inflated.

### 7.4 Churn Rate Includes Reactivations

An account that churned in January, reactivated in February, and churned again in March appears in both January and March numerators. This is correct business behavior — each churn event is a real loss. `COUNT(DISTINCT account_id)` within each month prevents double-counting within a single month.

### 7.5 Revenue Churn Excludes Trial Accounts

Revenue churn denominator only includes paid accounts (`is_trial = FALSE`). Trial accounts contribute zero MRR so exclusion is correct. However, trial churns that convert to paid and then churn may not be fully captured in revenue churn metrics.

### 7.6 Support Metrics Attribution

Tickets attributed to resolution month (`closed_at`), not submission month (`submitted_at`). A ticket submitted in December but resolved in January appears in January's metrics. This reflects team performance by month, not customer experience by submission month.

---

## 8. Cross-KPI Relationships

### 8.1 Churn and Revenue

```
High churn rate  →  check revenue churn rate
If revenue churn < customer churn  →  smaller accounts leaving
If revenue churn > customer churn  →  larger accounts leaving
```

### 8.2 Churn and Engagement

```
High churn + low MAU  →  engagement driving churn (validate Step 23)
High churn + high MAU →  engaged accounts still churning (pricing/support issue)
```

### 8.3 Revenue and Upgrades

```
MRR growth > account growth  →  ARPU expansion driving revenue
Downgrade MRR rising  →  contraction pressure building
Net upgrade MRR compressing  →  expansion engine weakening
```

### 8.4 Support and Churn

```
Rising escalation rate + rising churn  →  support quality driving churn
Poor CSAT months + high churn months   →  satisfaction → retention correlation
```

Cross-validate formally in Step 24 (Support Impact Analysis).

---

## 9. KPI Findings Summary

### 9.1 Churn & Retention

```
Average monthly churn rate        11.41%   (benchmark: 2-5%)
Average monthly retention rate    88.08%   (benchmark: 95%+)
Best retention month              Feb 2024   95.37%
Worst retention month             Dec 2024   79.83%
Churn trend                       Deteriorating since Jun 2024
Pre-launch state                  Crisis level — 20.17% in Dec 2024
```

### 9.2 Revenue

```
MRR growth                        $4,684 → $10,734,251  (2,291x)
ARPU growth                       $2,342 → $21,469       (9.2x)
Enterprise MRR share              80% → 98.2%
Basic MRR share                   Near zero by Dec 2024
Revenue churn rate                2-14% (above 1% benchmark)
Avg upgrade rate                  10.00%
Avg downgrade rate                3.97%
```

### 9.3 Engagement

```
MAU growth                        1 → 417
Engagement rate                   50% → 83.40%
Dormant accounts (Dec 2024)       83 out of 500
Feature adoption (top feature)    5.05% avg  (benchmark: 20-40%)
Feature sprawl                    40 features, avg 1.36-2.66% adoption
Beta adoption                     61.7% of active accounts
```

### 9.4 Support

```
Avg resolution time               33-40 hours  (benchmark: <24)
CSAT score                        3.71-4.33    (benchmark: 4.5+)
CSAT response rate                58.75%
Escalation rate                   1-8%
First response time               78-98 mins   (benchmark: <60)
Total closed tickets              2,000
```

---

## 10. Pre-Launch Risk Assessment

### Critical Risks

**Risk 1 — Churn Acceleration**
December 2024 churn rate of 20.17% is unsustainable for a public launch. Losing 1 in 5 customers monthly will erode even strong new customer acquisition.

**Risk 2 — Enterprise Concentration**
98.2% of MRR from Enterprise accounts. Losing a single large Enterprise customer could cause a significant MRR drop. No revenue diversification buffer.

**Risk 3 — Revenue Masking Account Instability**
MRR growing while account base deteriorating. Vanity metric risk — the business looks healthy on revenue but is hollow underneath.

**Risk 4 — Feature Adoption Below Benchmark**
Top feature at 5.05% monthly adoption vs 20-40% benchmark. Low product stickiness means low switching cost for churning customers.

### Moderate Risks

**Risk 5 — Support Below Benchmark**
Resolution time and CSAT both below industry benchmark. Support quality correlates with retention. Escalation rate spiking in H2 2024.

**Risk 6 — Downgrade Pressure Growing**
Downgrade rate tripling in 2024. High-value accounts moving down in December. Expansion engine compressing.

**Risk 7 — 83 Dormant Accounts**
Paying but not engaging accounts are pre-churned customers. High overlap likely with December churn cohort.

### Positive Signals

**Signal 1 — Strong ARPU Expansion**
ARPU growing 9.2x — accounts that stay are buying more. Upsell motion working.

**Signal 2 — Engagement Rate Improving**
83.40% engagement rate in December 2024 vs 50% in January 2023. Product getting stickier.

**Signal 3 — High Reactivation Rate**
79.3% of churned accounts reactivated at least once. Product value recognized even after churn.

**Signal 4 — Beta Quality**
Beta features on par with GA quality. Feature experimentation culture emerging — 61.7% of accounts using beta features.

---

## Document History

| Date | Step | Change |
|---|---|---|
| 2026-04-28 | Step 13.1 | kpi_monthly_churn_rate built and validated |
| 2026-04-28 | Step 13.2 | kpi_monthly_retention_rate built and validated |
| 2026-04-28 | Step 13.3 | kpi_monthly_mrr_growth built and validated |
| 2026-04-28 | Step 13.4 | kpi_monthly_active_users built and validated |
| 2026-04-28 | Step 13.5 | kpi_monthly_feature_adoption built and validated |
| 2026-04-28 | Step 13.6 | kpi_monthly_revenue_churn_rate built and validated |
| 2026-04-28 | Step 13.7 | kpi_monthly_upgrade_downgrade built and validated |
| 2026-04-28 | Step 13.8 | kpi_monthly_support_metrics built and validated |
| 2026-04-28 | Step 13 | Documentation finalized |

---

*This document is the authoritative reference for the RavenStack KPI layer. All analysis modules in Phase 3–4 and dashboard sections in Phase 6 should reference the KPI definitions and findings documented here.*
