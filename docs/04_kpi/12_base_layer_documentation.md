# Base Layer Documentation

## RavenStack SaaS Pre-Launch Analysis

**Project:** RavenStack Pre-Launch Performance Analysis
**Role:** Product Analyst
**Step:** 12 — Base Layer (SQL Foundation)
**Status:** Complete \& Validated
**Last Updated:** 2026-04-28

\---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Design Principles](#3-design-principles)
4. [Base Views Reference](#4-base-views-reference)

   * [01 — base\_accounts](#41-base_accounts)
   * [02 — base\_active\_monthly](#42-base_active_monthly)
   * [03 — base\_mrr\_monthly](#43-base_mrr_monthly)
   * [04 — base\_churn\_monthly](#44-base_churn_monthly)
   * [05 — base\_feature\_usage\_monthly](#45-base_feature_usage_monthly)
5. [Validation Results](#5-validation-results)
6. [Key Decisions \& Rationale](#6-key-decisions--rationale)
7. [Known Limitations](#7-known-limitations)
8. [Cross-Table Relationships](#8-cross-table-relationships)
9. [Usage Guide](#9-usage-guide)
10. [Early Analytical Signals](#10-early-analytical-signals)

\---

## 1\. Overview

The base layer is the **analytical foundation** of the RavenStack project.

It sits between raw source tables and the KPI layer:

```
Raw Tables
    ↓
Base Layer    ← YOU ARE HERE
    ↓
KPI Layer
    ↓
Analysis \& Dashboard
```

### Purpose

* Centralize all business logic in one place
* Prevent logic duplication across KPI queries
* Ensure consistent definitions across all metrics
* Create reusable, validated building blocks

### Core Principle

> Raw Tables → Base Tables → KPIs → Dashboard
>
> If base tables are correct → everything is correct.
> If base tables are wrong → everything breaks.

\---

## 2\. Architecture

### Layer Structure

```
📁 sql/
├── 01\_base\_accounts.sql              → Snapshot dimension
├── 02\_base\_active\_monthly.sql        → Activity denominator
├── 03\_base\_mrr\_monthly.sql           → Revenue fact
├── 04\_base\_churn\_monthly.sql         → Churn fact
└── 05\_base\_feature\_usage\_monthly.sql → Engagement fact
```

### Data Flow

```
accounts
subscriptions    ──→  base\_accounts              (snapshot)
                 ──→  base\_active\_monthly         (denominator)
                 ──→  base\_mrr\_monthly            (revenue)

churn\_events     ──→  base\_churn\_monthly          (churn numerator)

feature\_usage
subscriptions    ──→  base\_feature\_usage\_monthly  (engagement)
```

### Schema Type

The dataset follows a **hybrid star schema** with event-driven fact tables:

|Table|Role|
|-|-|
|accounts|Central dimension (customer entity)|
|subscriptions|Revenue fact|
|feature\_usage|Engagement fact|
|support\_tickets|Experience fact|
|churn\_events|Outcome fact (source of truth)|

\---

## 3\. Design Principles

### 3.1 One Row = One Business Entity

Every base view guarantees a clean grain:

|View|Grain|
|-|-|
|base\_accounts|One row (snapshot)|
|base\_active\_monthly|One row per account per month|
|base\_mrr\_monthly|One row per month|
|base\_churn\_monthly|One row per account per month|
|base\_feature\_usage\_monthly|One row per account per feature per month|

### 3.2 Always Use COUNT(DISTINCT account\_id)

Accounts can have multiple subscriptions. Raw row counts overstate customer counts. All downstream KPIs must use `COUNT(DISTINCT account\_id)` unless explicitly aggregating at subscription level.

### 3.3 Source of Truth Decisions

|Metric|Source of Truth|Reason|
|-|-|-|
|Churn|churn\_events|accounts.churn\_flag only 21% accurate|
|Active subscriptions|end\_date IS NULL or end\_date >= reference|NULL = still active|
|MRR|subscriptions.mrr\_amount|Already monthly-normalized|
|Feature usage|feature\_usage via subscriptions|No direct account\_id in feature\_usage|

### 3.4 Raw Data Preserved

No raw tables were modified. All business logic is applied through views and CTEs. This ensures:

* Reproducibility
* Auditability
* Safe re-analysis if logic changes

### 3.5 Monthly Granularity

All time-series views use `DATE\_TRUNC('month', ...)` for consistency. Day-level precision is not enforced — monthly approximation is sufficient for SaaS KPI analysis at this scale.

\---

## 4\. Base Views Reference

\---

### 4.1 base\_accounts

**File:** `01\_base\_accounts.sql`
**Type:** Snapshot — single row output
**Purpose:** Dataset-level sanity check and baseline metrics

#### Output Schema

|Column|Type|Description|
|-|-|-|
|total\_accounts|integer|All accounts in dataset|
|total\_subscriptions|integer|All subscription records|
|paid\_subscriptions|integer|Subscriptions with is\_trial = FALSE|
|trial\_subscriptions|integer|Subscriptions with is\_trial = TRUE|
|active\_accounts|integer|Accounts with active subscription at snapshot date|
|active\_paid\_accounts|integer|Accounts with at least one paid subscription active|
|active\_trial\_accounts|integer|Accounts with at least one trial subscription active|
|active\_paid\_subscriptions|integer|Paid subscription records active at snapshot|
|active\_trial\_subscriptions|integer|Trial subscription records active at snapshot|
|churned\_accounts|integer|Distinct accounts with at least one churn event|

#### Snapshot Date Logic

```sql
-- Defined as MAX(end\_date) from closed subscriptions
-- = 2024-12-31 for this dataset
-- Used instead of CURRENT\_DATE (dataset is historical 2023-2024)
-- Ensures reproducible results regardless of query execution date
```

#### Validated Output

```
total\_accounts              500
total\_subscriptions        5000
paid\_subscriptions         4222
trial\_subscriptions         778
active\_accounts             500  ← expected (all accounts have open subs)
active\_paid\_accounts        500
active\_trial\_accounts       385
active\_paid\_subscriptions  3836
active\_trial\_subscriptions  702
churned\_accounts            352
```

#### Important Note

`active\_accounts = total\_accounts (500)` is **expected behavior**, not a data quality issue.

Every account has at least one subscription with `end\_date IS NULL` as of the dataset end date. This reflects the dataset design where churn is subscription-level, not account-level permanent departure.

For churn analysis, use `churn\_events` as source of truth (Step 7 decision).

\---

### 4.2 base\_active\_monthly

**File:** `02\_base\_active\_monthly.sql`
**Type:** Monthly activity dimension
**Purpose:** Primary denominator for all monthly KPIs
**Rows:** 5,257

#### Output Schema

|Column|Type|Description|
|-|-|-|
|month|date|Month start date (first day of month)|
|account\_id|varchar|Active account|
|account\_type|varchar|'paid', 'trial', or 'mixed'|
|signup\_date|date|Account creation date (for cohort analysis)|

#### Active Definition

An account is active in month M if it has at least one subscription satisfying:

```sql
start\_date <= last\_day\_of\_month\_M
AND (end\_date IS NULL OR end\_date >= first\_day\_of\_month\_M)
```

#### Account Type Classification

```sql
CASE
    WHEN BOOL\_OR(is\_trial = FALSE) AND BOOL\_OR(is\_trial = TRUE) THEN 'mixed'
    WHEN BOOL\_OR(is\_trial = FALSE) THEN 'paid'
    ELSE 'trial'
END AS account\_type
```

**Classification logic:**

* `mixed` = account has BOTH paid AND trial subscriptions active in same month
* `paid` = account has only paid subscription(s) active
* `trial` = account has only trial subscription(s) active

**IMPORTANT:** `mixed` is checked FIRST. If `paid` were checked first, mixed accounts would silently become 'paid' and the signal would be lost.

#### Why signup\_date is Included

Added for cohort analysis (Steps 14 and 27). Without it, every cohort query would require joining back to `accounts`. Including it here centralizes the logic.

#### Validated Output

```
account\_type    distinct\_accounts    total\_rows
mixed           403                  2,890
paid            371                  2,229
trial            61                    138
Total distinct accounts: 500 ✅
```

#### Downstream Usage

```sql
-- All active accounts (churn denominator)
WHERE account\_type IN ('paid', 'trial', 'mixed')

-- Paid accounts (revenue denominator)
WHERE account\_type IN ('paid', 'mixed')

-- Trial only
WHERE account\_type = 'trial'

-- Cohort grouping
DATE\_TRUNC('month', signup\_date) AS cohort\_month
```

\---

### 4.3 base\_mrr\_monthly

**File:** `03\_base\_mrr\_monthly.sql`
**Type:** Monthly revenue fact
**Purpose:** Revenue base for MRR, ARPU, and revenue churn
**Rows:** 24 (one per month)

#### Output Schema

|Column|Type|Description|
|-|-|-|
|month|date|Month start date|
|paid\_active\_accounts|integer|Distinct paying accounts active during month|
|total\_mrr|numeric|Total monthly recurring revenue|
|arpu|numeric|Average revenue per paid account|
|mrr\_basic|numeric|MRR from Basic plan accounts|
|mrr\_pro|numeric|MRR from Pro plan accounts|
|mrr\_enterprise|numeric|MRR from Enterprise plan accounts|

#### Active Definition (Revenue)

A paid subscription is active during month M if:

```sql
start\_date <= last\_day\_of\_month\_M
AND (end\_date IS NULL OR end\_date >= first\_day\_of\_month\_M)
AND is\_trial = FALSE
AND mrr\_amount > 0
```

#### Critical Aggregation Pattern

MRR is aggregated in two steps to prevent double-counting:

```
Step 1: subscription → account level (SUM per account)
Step 2: account level → monthly level (SUM across accounts)
```

An account with 3 active paid subscriptions contributes:

* Once to `paid\_active\_accounts` (COUNT DISTINCT)
* Full combined revenue to `total\_mrr` (SUM)

#### Plan Tier Classification

When an account has multiple subscriptions with different plan tiers in the same month, `MAX(plan\_tier)` is used (Enterprise > Pro > Basic alphabetically).

**Limitation:** This is an approximation. In production, a dedicated plan hierarchy ranking would be used.

#### Validated Output

```
Month          Paid Accounts    Total MRR       ARPU
2023-01        2                $4,684          $2,342
2024-12        500              $10,734,251     $21,469
Growth         250x             2,291x          9.2x
```

\---

### 4.4 base\_churn\_monthly

**File:** `04\_base\_churn\_monthly.sql`
**Type:** Monthly churn fact (source of truth)
**Purpose:** Master churn numerator for all churn KPIs
**Rows:** 547

#### Output Schema

|Column|Type|Description|
|-|-|-|
|month|date|Month of churn (truncated to month start)|
|account\_id|varchar|Churned account|
|churn\_date|date|Exact churn date within month|
|reason\_code|varchar|Primary churn reason|
|preceding\_downgrade\_flag|boolean|TRUE if account downgraded before churning|

#### Deduplication Logic

```sql
SELECT DISTINCT ON (
    DATE\_TRUNC('month', churn\_date),
    account\_id
)
ORDER BY
    DATE\_TRUNC('month', churn\_date),
    account\_id,
    churn\_date DESC  -- most recent event selected
```

**Why DISTINCT ON instead of DISTINCT:**

An account may churn, reactivate, and churn again within the same month. `DISTINCT ON` with `ORDER BY churn\_date DESC` selects the **most recent** churn event per account per month — capturing the final churn state including the most recent reason\_code and flags.

**Without this:** churn counts inflate, rates become inaccurate, reason\_code becomes ambiguous.

#### Why churn\_events is Source of Truth

During Step 7 validation:

* `accounts.churn\_flag` accuracy: **21%** (severely under-reports churn)
* `subscriptions.churn\_flag`: partially reliable, inconsistent with account-level
* `churn\_events`: event-level granularity, contains timing, reason, and financial impact

#### Why reason\_code and preceding\_downgrade\_flag are Included

Including these columns directly prevents repeated joins to `churn\_events` in every downstream query:

* `reason\_code` → churn reason analysis (Step 21)
* `preceding\_downgrade\_flag` → multi-factor churn model (Step 25)

#### Validated Output

```
total\_rows                          547
total\_distinct\_churned\_accounts     352
deduplication\_check                 0 rows (no duplicates) ✅
first\_churn\_month                   2023-01
last\_churn\_month                    2024-12
```

**Churn reason distribution:**

|Reason|Count|%|
|-|-|-|
|features|105|19.2%|
|support|97|17.7%|
|budget|91|16.6%|
|pricing|86|15.7%|
|competitor|85|15.5%|
|unknown|83|15.2%|

Remarkably even distribution — no single dominant reason.

\---

### 4.5 base\_feature\_usage\_monthly

**File:** `05\_base\_feature\_usage\_monthly.sql`
**Type:** Monthly engagement fact
**Purpose:** Product usage base for feature adoption, active users, usage vs churn
**Rows:** 6,040

#### Output Schema

|Column|Type|Description|
|-|-|-|
|month|date|Month of usage|
|account\_id|varchar|Account dimension|
|feature\_name|varchar|Feature dimension|
|is\_beta\_feature|boolean|Beta feature flag|
|total\_usage\_events|integer|COUNT(\*) of raw usage rows|
|total\_usage\_count|integer|SUM(usage\_count) from source — USE FOR INTENSITY|
|total\_usage\_duration\_secs|integer|Total time spent on feature|
|avg\_usage\_duration\_secs|numeric|Average time per usage session|
|total\_errors|integer|Total errors encountered|

#### Important: Two Usage Volume Metrics

```
total\_usage\_events:
    COUNT(\*) of rows in feature\_usage table
    = number of usage records in that month
    USE FOR: record-level aggregation

total\_usage\_count:
    SUM(usage\_count) from source column
    = actual event frequency as recorded in system
    USE FOR: usage intensity analysis (Step 23)
    RATIO: 61,306 / 6,127 = \~10x difference
```

**Always use `total\_usage\_count` for engagement intensity metrics.**

#### Join Path

```sql
feature\_usage → subscriptions → (account\_id resolved)
```

`feature\_usage` has no direct `account\_id`. Must join through `subscriptions`. Direct join to `accounts` is not possible from this table.

#### Active Subscription Validation

Usage events are only included when the associated subscription was active during the same month:

```sql
s.start\_date <= last\_day\_of\_usage\_month
AND (s.end\_date IS NULL OR s.end\_date >= first\_day\_of\_usage\_month)
```

#### Feature State Grain

A feature may appear as both `is\_beta\_feature = TRUE` and `is\_beta\_feature = FALSE` across different months if its rollout status changed over time.

`feature\_name + is\_beta\_feature` is therefore treated as the analytical feature state grain.

This enables:

* Beta vs GA transition analysis
* Feature adoption curve tracking
* Beta impact comparison (Step 28)

#### Validated Output

```
total\_rows              6,040
distinct\_accounts         488  (12 accounts never used any feature)
distinct\_features          40  ✅ matches dataset readme
total\_months               24  ✅ Jan 2023 – Dec 2024
total\_usage\_events        6,127
total\_usage\_count        61,306
total\_errors              3,290
```

**Beta vs Non-Beta:**

|Type|Rows|Accounts|Usage Count|Error Rate|
|-|-|-|-|-|
|Non-beta|5,454|484|55,443|0.054/usage|
|Beta|586|301|5,863|0.052/usage|

Beta error rate nearly identical to non-beta — quality is on par.

\---

## 5\. Validation Results

### 5.1 Row Count Validation

|Table|Expected|Actual|Status|
|-|-|-|-|
|accounts|500|500|✅ PASS|
|subscriptions|5,000|5,000|✅ PASS|
|feature\_usage|25,000|25,000|✅ PASS|
|support\_tickets|2,000|2,000|✅ PASS|
|churn\_events|600|600|✅ PASS|

### 5.2 Referential Integrity

|Relationship|Result|
|-|-|
|subscriptions → accounts|✅ PASS — no orphan records|
|feature\_usage → subscriptions|✅ PASS — no orphan records|
|support\_tickets → accounts|✅ PASS — no orphan records|
|churn\_events → accounts|✅ PASS — no orphan records|

### 5.3 Primary Key Validation

|Table|Column|Status|
|-|-|-|
|accounts|account\_id|✅ Unique, non-null|
|subscriptions|subscription\_id|✅ Unique, non-null|
|feature\_usage|usage\_id|⚠️ 21 duplicate IDs — not used for aggregation|
|support\_tickets|ticket\_id|✅ Unique, non-null|
|churn\_events|churn\_event\_id|✅ Unique, non-null|

### 5.4 Base Layer Cross-Validation

|Check|Result|
|-|-|
|base\_feature\_usage total\_usage\_count|61,306 ✅ consistent across all queries|
|base\_churn\_monthly deduplication|0 duplicate (month, account\_id) pairs ✅|
|base\_active\_monthly distinct accounts|500 ✅|
|base\_mrr\_monthly plan reconstruction|Basic + Pro + Enterprise = Total MRR, difference = 0.00 ✅|

\---

## 6\. Key Decisions \& Rationale

|Decision|What|Why|
|-|-|-|
|churn\_events = source of truth|Used for all churn metrics|accounts.churn\_flag only 21% accurate|
|COUNT(DISTINCT account\_id) everywhere|Prevents double-counting|Accounts have multiple subscriptions|
|DISTINCT ON for churn deduplication|One row per account per month|Same account can churn multiple times in a month|
|Most recent churn event selected|ORDER BY churn\_date DESC|Captures final churn state for that month|
|account\_type = 'mixed' when both exist|Three-way classification|403/500 accounts have simultaneous paid + trial|
|mixed checked FIRST in CASE|Prevents silent misclassification|paid branch would capture mixed accounts incorrectly|
|signup\_date in base\_active\_monthly|Added via JOIN to accounts|Enables cohort analysis without extra joins downstream|
|plan\_tier in base\_mrr\_monthly|MAX(plan\_tier) per account|Enables plan-wise revenue breakdown without rejoining|
|reason\_code in base\_churn\_monthly|From churn\_events directly|Avoids repeated joins in churn reason analysis|
|preceding\_downgrade\_flag in base\_churn\_monthly|From churn\_events|Pre-churn signal for multi-factor model|
|is\_beta\_feature in base\_feature\_usage\_monthly|Event-level flag|Same feature can be beta or GA in different months|
|total\_usage\_count alongside total\_usage\_events|SUM(usage\_count) vs COUNT(\*)|10x difference — intensity analysis needs source column|
|NULLIF on all divisions|Prevents division by zero|Defensive pattern for early months with small denominators|
|Snapshot date = MAX(end\_date) not CURRENT\_DATE|Dataset is historical|CURRENT\_DATE caused all accounts to show as active|
|MRR aggregated at account level first|Two-step aggregation|Prevents double-counting multi-subscription account revenue|
|Monthly approximation for usage overlap|Not enforced at day level|Monthly grain sufficient for SaaS KPI analysis|
|Raw data never modified|Views and CTEs only|Preserves reproducibility and auditability|

\---

## 7\. Known Limitations

### 7.1 feature\_usage.usage\_id — Not a Reliable Primary Key

21 duplicate `usage\_id` values exist in the raw table. These are distinct usage events with different attributes — not true duplicates.

**Decision:** `usage\_id` is not used for aggregation. Table grain redefined as one row = one feature usage event.

### 7.2 accounts.churn\_flag — Unreliable

Only 21% accurate compared to `churn\_events`. Not used anywhere in analysis.

**Decision:** `churn\_events` selected as source of truth for all churn metrics.

### 7.3 Upgrade/Downgrade Timing

No dedicated plan-change event timestamp exists in the dataset. `upgrade\_flag` and `downgrade\_flag` timing is approximated using subscription `start\_date`.

**Impact:** Upgrade/downgrade rates may slightly overstate movement in months with new subscriptions.

### 7.4 plan\_tier Aggregation in MRR

When an account has multiple subscriptions with different plan tiers in the same month, `MAX(plan\_tier)` is used (Enterprise > Pro > Basic alphabetically).

**Impact:** Minor. Affects plan-level MRR split for multi-tier accounts only.

### 7.5 Mixed Account Classification

`account\_type = 'mixed'` collapses two subscription types into one row. Pure paid-only count requires `WHERE account\_type = 'paid'`. Paid + mixed count (any paid subscription) requires `WHERE account\_type IN ('paid', 'mixed')`.

### 7.6 Snapshot Date for base\_accounts

`active\_accounts = 500 = total\_accounts` because every account has at least one subscription with `end\_date IS NULL`. The snapshot active logic correctly identifies all accounts as having at least one open subscription at dataset end (2024-12-31). This is expected dataset behavior.

### 7.7 12 Zero-Usage Accounts

12 accounts exist in `accounts` but have no records in `base\_feature\_usage\_monthly`. These accounts never used any feature. 7 of 12 churned. Sample too small for statistical conclusions — to be validated at scale in Step 23.

\---

## 8\. Cross-Table Relationships

```
accounts (PK: account\_id)
│
├── subscriptions (FK → account\_id)
│   └── feature\_usage (FK → subscription\_id)
│
├── support\_tickets (FK → account\_id)
└── churn\_events (FK → account\_id)
```

### Analytical Join Paths

|Analysis|Join Path|
|-|-|
|Revenue analysis|accounts → subscriptions|
|Product usage|accounts → subscriptions → feature\_usage|
|Churn analysis|accounts → churn\_events|
|Usage vs churn|subscriptions → feature\_usage + churn\_events|
|Support vs churn|accounts → support\_tickets + churn\_events|

### Grain Differences — Critical Warning

|Table|Grain|
|-|-|
|accounts|1 row per account|
|subscriptions|Multiple per account|
|feature\_usage|Multiple per subscription per day|
|support\_tickets|Multiple per account|
|churn\_events|Multiple per account|

**Do NOT join `accounts` directly to `feature\_usage`** without going through `subscriptions`. This creates a fan-out join that inflates row counts.

\---

## 9\. Usage Guide

### Getting Active Accounts for a Month

```sql
SELECT COUNT(\*) AS active\_accounts
FROM base\_active\_monthly
WHERE month = '2024-06-01'
AND account\_type IN ('paid', 'mixed');  -- paid only
```

### Getting MRR for a Month

```sql
SELECT total\_mrr, arpu
FROM base\_mrr\_monthly
WHERE month = '2024-06-01';
```

### Getting Churned Accounts for a Month

```sql
SELECT COUNT(\*) AS churned\_accounts
FROM base\_churn\_monthly
WHERE month = '2024-06-01';
```

### Getting Feature Usage for an Account

```sql
SELECT feature\_name, total\_usage\_count, total\_errors
FROM base\_feature\_usage\_monthly
WHERE account\_id = 'A-123abc'
ORDER BY month, total\_usage\_count DESC;
```

### Building a Churn Rate Query

```sql
-- Numerator: from base\_churn\_monthly
-- Denominator: active at START of month (stricter than base\_active\_monthly)
WITH start\_active AS (
    SELECT month\_start, COUNT(DISTINCT account\_id) AS active\_accounts
    FROM subscriptions s
    CROSS JOIN month\_spine m
    WHERE s.start\_date <= m.month\_start
      AND (s.end\_date IS NULL OR s.end\_date >= m.month\_start)
    GROUP BY month\_start
),
churned AS (
    SELECT month, COUNT(\*) AS churned\_accounts
    FROM base\_churn\_monthly
    GROUP BY month
)
SELECT
    a.month\_start AS month,
    churned\_accounts \* 100.0 / NULLIF(active\_accounts, 0) AS churn\_rate\_pct
FROM start\_active a
LEFT JOIN churned c ON a.month\_start = c.month;
```

\---

## 10\. Early Analytical Signals

Signals identified during base layer validation — to be formally validated in Phase 3.

### Signal 1 — Revenue Growing Despite High Churn

```
MRR Jan 2023    $4,684
MRR Dec 2024    $10,734,251  (2,291x growth)
Churn rate      70.4% of accounts churned at least once
```

Revenue masking account instability. Large Enterprise deals offsetting smaller account losses.

### Signal 2 — December 2024 Crisis

```
Dec 2024 churn rate    20.17%  (1 in 5 accounts)
Dec 2024 MRR growth    +24.13%
```

Revenue growing while account base hemorrhaging. Pre-launch structural risk.

### Signal 3 — Trials = Feature Experimentation

```
403/500 accounts have simultaneous paid + trial subscriptions
Trial-only accounts peaked at 12, declined to 0 by end of dataset
```

Trials are not onboarding mechanisms — paying customers use them to experiment with additional features.

### Signal 4 — Feature Engagement Low

```
488 accounts used features (12 never did)
avg\_usage\_per\_account per month: 0.51 events
Top feature adoption rate: 5.05% monthly average
```

Engagement density far below healthy SaaS benchmarks. Feature sprawl problem.

### Signal 5 — Beta Quality on Par with GA

```
Beta error rate     0.052 per usage
Non-beta error rate 0.054 per usage
```

Beta features not lower quality. Discoverability problem, not quality problem.

### Signal 6 — Churn Reasons Evenly Distributed

```
features    19.2%
support     17.7%
budget      16.6%
pricing     15.7%
competitor  15.5%
unknown     15.2%
```

No single dominant churn reason. Multi-front problem requiring multi-front solution.

### Signal 7 — 79% of Churned Accounts Reactivated

```
Total churned accounts        352
Never reactivated              73  (20.7%)
Reactivated at least once     279  (79.3%)
```

Churn is subscription instability, not permanent customer loss. Problem is frequency, not finality.

\---

## Document History

|Date|Step|Change|
|-|-|-|
|2026-04-26|Step 5|Data loaded, schema created|
|2026-04-27|Step 6-7|Data cleaning and integrity validation|
|2026-04-28|Step 8-10|Relationship mapping, data dictionary, deep cleaning|
|2026-05-03|Step 12|All 5 base views built and validated|
|2026-05-04|Step 12|Documentation finalized|

\---

*This document is the authoritative reference for the RavenStack base layer. All KPI definitions, analysis decisions, and dashboard metrics should be traceable to the decisions documented here.*

