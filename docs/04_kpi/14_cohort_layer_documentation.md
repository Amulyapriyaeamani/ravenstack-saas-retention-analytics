# Cohort Layer Documentation

## RavenStack SaaS Pre-Launch Analysis

**Project:** RavenStack Pre-Launch Performance Analysis
**Role:** Product Analyst
**Step:** 14 — Cohort Layer
**Status:** Complete \& Validated
**Last Updated:** 2026-04-28

\---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Design Principles](#3-design-principles)
4. [File Reference](#4-file-reference)

   * [14.1 — cohort\_base](#41-cohort_base)
   * [14.2 — cohort\_retention\_matrix](#42-cohort_retention_matrix)
   * [14.3 — cohort\_survival\_curve](#43-cohort_survival_curve)
5. [Validation Summary](#5-validation-summary)
6. [Key Decisions \& Rationale](#6-key-decisions--rationale)
7. [Known Limitations](#7-known-limitations)
8. [Retention vs Survival — The Critical Distinction](#8-retention-vs-survival--the-critical-distinction)
9. [Cohort Findings Summary](#9-cohort-findings-summary)
10. [Pre-Launch Implications](#10-pre-launch-implications)

\---

## 1\. Overview

The cohort layer enables **time-based customer lifecycle analysis** — tracking how groups of accounts acquired in the same month behave over time.

It sits between the KPI layer and core analysis:

```
Raw Tables
    ↓
Base Layer       (Step 12 — complete)
    ↓
KPI Layer        (Step 13 — complete)
    ↓
Cohort Layer     ← YOU ARE HERE
    ↓
Core Analysis    (Steps 16–23)
Advanced Analysis (Steps 24–28)
Dashboard        (Phase 6)
```

### Why Cohort Analysis Is Necessary

Monthly KPIs mix all cohorts together — making it impossible to know if the product is getting better or worse at retaining customers over time.

|Monthly KPI Question|Cohort Question|
|-|-|
|How many churned this month?|Which cohorts churn fastest?|
|What is overall retention?|Are newer cohorts improving?|
|How does engagement trend?|At what month does the biggest drop occur?|

Cohort analysis separates these questions — giving a true picture of customer lifecycle quality across time.

### Two Analytical Perspectives

This layer builds two complementary views of cohort behavior:

```
Retention Matrix   → Is the account active NOW at month N?
Survival Curve     → Has the account EVER churned by month N?
```

Both are valid. They answer fundamentally different questions and must both be used for complete analysis. See Section 8 for the full distinction.

Month 0 asymmetry between retention and survival is intentional.

Retention: forced to 100% — technical artifact correction.

Survival: actual data — real business signal preserved.

\---

## 2\. Architecture

### File Structure

```
📁 sql/
├── 14\_01\_cohort\_base.sql
├── 14\_02\_cohort\_retention\_matrix.sql
└── 14\_03\_cohort\_survival\_curve.sql
```

### Dependency Map

```
accounts
churn\_events
subscriptions        ──→  cohort\_base (14\_01)
base\_active\_monthly              ↓              ↓
                    cohort\_retention\_matrix  cohort\_survival\_curve
                         (14\_02)               (14\_03)
                    + base\_active\_monthly    (cohort\_base only)
```

### Build Order

```
14\_01 first → 14\_02 and 14\_03 both depend on it
14\_02 and 14\_03 can be built in either order
```

### Row Counts

|File|Rows|Grain|
|-|-|-|
|cohort\_base|500|One per account|
|cohort\_retention\_matrix|300|One per cohort per month\_since\_signup|
|cohort\_survival\_curve|300|One per cohort per month\_since\_signup|

\---

## 3\. Design Principles

### 3.1 Cohort Assignment is Permanent

```
cohort\_month = DATE\_TRUNC('month', signup\_date)
```

An account's cohort never changes — regardless of upgrades, downgrades, churns, or reactivations. This is the only correct approach for longitudinal cohort analysis.

### 3.2 Cohort Size Locked at Month 0

The original cohort size is calculated once and used as the permanent denominator for all retention and survival calculations. It never changes.

```
Jan 2023 cohort\_size = 17 (always, at every month N)
```

Recalculating the denominator at later months is the most common cohort analysis mistake. It produces artificially high retention by hiding the denominator shrinkage.

### 3.3 Calendar Month Arithmetic — Identical Across All Files

All three files use the same month arithmetic:

```sql
months\_since\_signup =
    (EXTRACT(YEAR FROM month\_B)::INTEGER \* 12
     + EXTRACT(MONTH FROM month\_B)::INTEGER)
    -
    (EXTRACT(YEAR FROM month\_A)::INTEGER \* 12
     + EXTRACT(MONTH FROM month\_A)::INTEGER)
```

This is used instead of `DATE\_PART('month', AGE(...))` because `AGE()` counts elapsed full months — returning 0 for January 31 → February 1 transitions. Calendar arithmetic always returns 1, correctly aligning with cohort month boundaries.

**Critical:** All three files must use identical arithmetic. Mixing approaches misaligns retention matrix with survival curve — making cross-analysis invalid.

### 3.4 Age Cap Enforced

Only months a cohort has actually lived through are included:

```
activity\_month <= '2024-12-01' (dataset end)
```

Without the age cap, later cohorts appear to have perfect retention at future months. With it:

```
Dec 2024 cohort → Month 0 only
Nov 2024 cohort → Months 0-1 only
Jan 2023 cohort → Months 0-23 (full 24-month window)
```

### 3.5 Two Definitions — Never Mixed

Retention and survival use fundamentally different definitions. They are never mixed within a single file or calculation.

|Property|Retention Matrix|Survival Curve|
|-|-|-|
|Reactivations|Counted as retained|Ignored|
|Curve direction|Can increase|Only flat or decreasing|
|Month 0|Forced to 100%|Based on actual survival|
|Data source|base\_active\_monthly|cohort\_base.months\_to\_first\_churn|

\---

## 4\. File Reference

\---

### 4.1 cohort\_base

**File:** `14\_01\_cohort\_base.sql`
**Purpose:** Master cohort dimension table
**Grain:** One row per account (500 rows)
**Type:** Permanent reference — never changes

#### Purpose

Every account is assigned to exactly one cohort. This file is the permanent reference for all downstream cohort analysis. It contains both identity/segmentation attributes and behavioral flags derived from churn history.

#### Output Schema

**Group 1 — Identity \& Cohort Assignment**

|Column|Type|Description|
|-|-|-|
|cohort\_month|date|DATE\_TRUNC('month', signup\_date)|
|account\_id|varchar|Unique account identifier|
|signup\_date|date|Exact signup date|

**Group 2 — Segmentation Dimensions**

|Column|Type|Description|
|-|-|-|
|plan\_tier|varchar|ENTRY plan at signup (not current plan)|
|industry|varchar|SaaS vertical|
|country|varchar|ISO-2 country code|
|referral\_source|varchar|Acquisition channel|
|seats|integer|Licensed user count (company size proxy)|
|is\_trial|boolean|Started as trial|

**Group 3 — Churn Behavior**

|Column|Type|Description|
|-|-|-|
|ever\_churned|boolean|Had any churn event|
|ever\_reactivated|boolean|Churned AND came back|
|churn\_count|integer|Total churn events|
|first\_churn\_date|date|MIN(churn\_date)|
|last\_churn\_date|date|MAX(churn\_date)|
|months\_to\_first\_churn|integer|Calendar months from signup to first churn|
|is\_currently\_active|boolean|Active at dataset end (2024-12-31)|

**Group 4 — Current Status**

|Column|Type|Description|
|-|-|-|
|is\_currently\_active|boolean|Has active subscription on 2024-12-31|

#### Key Logic Notes

**plan\_tier** uses `accounts.plan\_tier` — the entry plan, not the current plan. Cohort segmentation by entry plan tracks where customers started, not where they ended up.

**ever\_reactivated** is only TRUE when `ever\_churned = TRUE` AND a paid subscription exists with `start\_date > first\_churn\_date`. An account that never churned cannot be reactivated.

**months\_to\_first\_churn** uses calendar month arithmetic. `AGE()` was explicitly rejected because it returns 0 for January 31 → February 1 transitions (same-month boundary crossing).

**is\_currently\_active** uses a point-in-time snapshot against `subscriptions WHERE end\_date IS NULL OR end\_date >= '2024-12-31'` — NOT `base\_active\_monthly`. Active-anytime-during-month is insufficient for a point-in-time current status check.

Note: All 500 accounts show `is\_currently\_active = TRUE` because every account has at least one open subscription (`end\_date IS NULL`). This reflects dataset design — use `ever\_churned` and `ever\_reactivated` flags for permanence analysis instead.

#### Validated Output

```
Total rows                  500  ✅
Distinct accounts           500  ✅
Distinct cohorts             24  ✅ (Jan 2023 – Dec 2024)
ever\_churned = TRUE         352  ✅ matches churn\_events
ever\_churned = FALSE        148  ✅
Reactivation inconsistency    0  ✅ (no reactivated without churned)
Negative months\_to\_churn      0  ✅
```

#### Behavioral Segments

|Segment|ever\_churned|ever\_reactivated|Accounts|%|
|-|-|-|-|-|
|Stable|FALSE|FALSE|148|29.6%|
|Lost|TRUE|FALSE|26|5.2%|
|Cyclical|TRUE|TRUE|326|65.2%|

The dominant pattern is **cyclical** — 65.2% of accounts churned and came back at least once.

#### Churn Count Distribution

|churn\_count|accounts|
|-|-|
|0|148|
|1|177|
|2|116|
|3|47|
|4|10|
|5|2|

Average churn events per churned account: **1.70**

#### Time-to-First-Churn Distribution

```
Month 0    49 accounts  (churned in signup month)
Month 1    79 accounts  (churned in first full month) ← highest
Month 2    36 accounts
Month 3    40 accounts
Month 4    24 accounts
...
Month 20    3 accounts
```

**36.4% of all churns (128/352) happen in Months 0-1.** Classic onboarding failure pattern.

#### Referral Source Churn Rates

|Source|Accounts|Churn Rate|
|-|-|-|
|partner|89|75.3% ← highest|
|organic|114|74.6%|
|other|103|70.9%|
|event|96|70.8%|
|ads|98|60.2% ← lowest|

Counterintuitive finding: paid acquisition (ads) retains better than organic or partner channels.

\---

### 4.2 cohort\_retention\_matrix

**File:** `14\_02\_cohort\_retention\_matrix.sql`
**Purpose:** Month-by-month retention rate per cohort
**Grain:** One row per cohort\_month per months\_since\_signup (300 rows)
**Definition:** Point-in-time active retention

#### Definition Used

> An account is retained at month N if it has at least one active subscription during that month.

Source: `base\_active\_monthly`

Reactivations count as retained. Retention CAN increase in later months due to reactivations. This is intentional and documented.

For monotonically decreasing analysis → see cohort\_survival\_curve (14\_03).

#### Output Schema

|Column|Type|Description|
|-|-|-|
|cohort\_month|date|Cohort identifier|
|cohort\_size|integer|Original cohort count (locked)|
|months\_since\_signup|integer|0, 1, 2 ... up to 23|
|activity\_month|date|Actual calendar month|
|active\_accounts|integer|Accounts active at month N|
|retention\_rate\_pct|numeric|active / cohort\_size × 100|

#### Month 0 Handling

Month 0 is **hardcoded as 100%** — `active\_accounts = cohort\_size`.

Reason: `base\_active\_monthly` may undercount Month 0 for accounts whose subscription `start\_date` falls after the month spine's first date. Every account was definitionally active in their signup month by virtue of being in the cohort.

#### CTE Chain

```
cohort\_sizes        → lock cohort sizes permanently
cohort\_month\_spine  → generate valid cohort × month combinations with age cap
active\_per\_cohort\_month → count active accounts per cohort per month
                         (Month 0 hardcoded, Month 1+ from base\_active\_monthly)
```

#### Validated Output

```
Month 0 = 100% all cohorts    ✅ (after hardcoding fix)
No retention > 100%           ✅
Age cap working               ✅ Dec 2024 = 1 row
Cohort sizes consistent       ✅ matches cohort\_base
```

#### Average Retention Curve

|Month|Avg Retention|Min|Max|
|-|-|-|-|
|0|100.00%|100%|100%|
|1|71.41%|23.08%|100%|
|2|84.30%|52.94%|100%|
|3|90.32%|66.67%|100%|
|6|98.76%|88.24%|100%|
|12|99.51%|94.12%|100%|
|14|100.00%|100%|100%|

Retention drops at Month 1 then climbs back to \~100% by Month 14. Driven entirely by the reactivation effect (65.2% of accounts are cyclical).

#### Month 1 Retention — The Critical Split

```
2023 cohorts    Month 1 range    23–71%   avg \~55%
2024 cohorts    Month 1 range    75–100%  avg \~92%
Gap             \~37 percentage points
```

2024 cohorts appear dramatically better at Month 1. See Section 8 for why this is misleading when viewed without the survival curve.

#### Key Insight — June 2023 Anomaly

```
2023-06    Month 1: 23.08%  (only 3/13 survived)
2023-06    Month 3: 92.31%  (near-full recovery)
```

Catastrophic Month 1 drop followed by rapid recovery. Something specific happened in July 2023 for June signups. Investigate in Step 24 (Support Impact Analysis).

\---

### 4.3 cohort\_survival\_curve

**File:** `14\_03\_cohort\_survival\_curve.sql`
**Purpose:** Cumulative churn survival curve per cohort
**Grain:** One row per cohort\_month per months\_since\_signup (300 rows)
**Definition:** Cumulative survival — once churned always lost

#### Definition Used

> An account survives month N if it has never had a first churn event by month N.

```
surviving at month N =
    ever\_churned = FALSE
    OR months\_to\_first\_churn > N
```

Reactivations are ignored. First churn = permanent loss.
Curve is monotonically non-increasing — never goes up.

Source: `cohort\_base.months\_to\_first\_churn` only.
No dependency on `base\_active\_monthly`.

#### Output Schema

|Column|Type|Description|
|-|-|-|
|cohort\_month|date|Cohort identifier|
|cohort\_size|integer|Original cohort count (locked)|
|months\_since\_signup|integer|0, 1, 2 ... up to 23|
|surviving\_accounts|integer|Accounts with no churn by month N|
|survival\_rate\_pct|numeric|surviving / cohort\_size × 100|
|churned\_by\_month\_n|integer|cohort\_size − surviving|
|cumulative\_churn\_rate\_pct|numeric|100 − survival\_rate\_pct|

Note: `survival\_rate\_pct + cumulative\_churn\_rate\_pct = 100%` always.

#### Month 0 Handling

Month 0 is **NOT forced to 100%** in the survival curve.

Accounts with `months\_to\_first\_churn = 0` churned in their signup month. They are correctly excluded from Month 0 survival — they did not survive beyond their signup month.

This differs from the retention matrix. The survival curve measures permanence of churn, not current activity.

49 accounts in `cohort\_base` have `months\_to\_first\_churn = 0` — explaining why several cohorts show Month 0 survival below 100%.

#### NULL Handling

Accounts with `ever\_churned = FALSE` have `months\_to\_first\_churn = NULL`. In SQL, `NULL > N` evaluates to NULL (not TRUE). Therefore both conditions must be checked:

```sql
WHERE
    cb.ever\_churned = FALSE           -- catches NULL months\_to\_first\_churn
    OR cb.months\_to\_first\_churn > N   -- catches accounts that churn later
```

Omitting the first condition would silently exclude all 148 never-churned accounts from survival counts — causing systematic undercounting.

#### Validated Output

```
Monotonically non-increasing    ✅ 0 violations
No survival > 100%              ✅
survival + cumulative = 100%    ✅ all rows
Age cap working                 ✅ Dec 2024 = 1 row
```

#### Average Survival Curve

|Month|Avg Survival|Avg Cumulative Churn|
|-|-|-|
|0|90.38%|9.62%|
|1|78.73%|21.27%|
|3|66.49%|33.51%|
|6|55.12%|44.88%|
|9|48.62%|51.38%|
|12|42.11%|57.89%|
|23|29.41%|70.59%|

Average crosses 50% survival around Month 9. Long-term floor \~29-30% — aligns with the 29.6% never-churned proportion from cohort\_base.

#### Median Survival Month by Cohort

|Cohort|Median Survival Month|
|-|-|
|2023-05|Month 19 ← best|
|2023-04|Month 15|
|2023-01|Month 11|
|2023-10|Month 6|
|2024-07|Month 3|
|2024-09|Month 1|
|2024-11|Month 1|
|2024-12|Month 0 ← worst|

Clear deterioration in 2024 cohorts. December 2024 crosses 50% churn at Month 0 — more than half the cohort churned in their signup month.

#### SaaS Survival Checkpoints

|Cohort|M0|M1|M3|M6|M12|
|-|-|-|-|-|-|
|2023-01|94.12%|94.12%|88.24%|70.59%|41.18%|
|2023-05|100.00%|100.00%|88.46%|76.92%|65.38%|
|2023-08|100.00%|93.75%|93.75%|75.00%|43.75%|
|2024-01|93.75%|87.50%|75.00%|37.50%|—|
|2024-06|90.48%|76.19%|47.62%|28.57%|—|
|2024-09|80.00%|36.00%|16.00%|—|—|
|2024-11|75.00%|25.00%|—|—|—|
|2024-12|35.29%|—|—|—|—|

**2023 early cohorts: M6 survival 70-85%
2024 later cohorts: M6 survival 28-37%**

Dramatic deterioration across the dataset.

\---

## 5\. Validation Summary

### 5.1 cohort\_base Validations

|Check|Expected|Result|
|-|-|-|
|Total rows|500|✅|
|Distinct accounts|500|✅|
|Distinct cohorts|24|✅|
|ever\_churned = TRUE|352|✅|
|Reactivated without churned|0|✅|
|Negative months\_to\_first\_churn|0|✅|
|churn\_count = 0 when not churned|consistent|✅|

### 5.2 cohort\_retention\_matrix Validations

|Check|Expected|Result|
|-|-|-|
|Month 0 = 100% all cohorts|0 violations|✅ (after fix)|
|Retention > 100%|0 violations|✅|
|Age cap (Dec 2024 = 1 row)|1 row|✅|
|Cohort sizes match cohort\_base|0 mismatches|✅|
|Total rows|300|✅|

### 5.3 cohort\_survival\_curve Validations

|Check|Expected|Result|
|-|-|-|
|Monotonically non-increasing|0 violations|✅|
|Survival > 100%|0 violations|✅|
|survival + cumulative = 100%|0 violations|✅|
|Age cap (Dec 2024 = 1 row)|1 row|✅|
|Total rows|300|✅|

\---

## 6\. Key Decisions \& Rationale

|Decision|What|Why|
|-|-|-|
|Calendar month arithmetic|(year×12 + month) difference|AGE() returns 0 for Jan-31 → Feb-01, misaligning with cohort month boundaries|
|Identical arithmetic across all 3 files|Same formula everywhere|Mismatched arithmetic makes survival vs retention cross-analysis invalid|
|Cohort size locked at Month 0|COUNT at signup, never recalculate|Recalculating denominator produces artificially inflated retention|
|Age cap enforced|activity\_month <= 2024-12-01|Without cap, later cohorts falsely show 100% retention at future months|
|Month 0 = 100% in retention matrix|Hardcoded|base\_active\_monthly may undercount Month 0 due to subscription timing|
|Month 0 NOT forced in survival curve|Actual survival logic|Same-month churners correctly excluded — real data finding|
|Two separate files for retention vs survival|Never mixed|Fundamentally different definitions serve different analytical purposes|
|ever\_churned check before months\_to\_first\_churn|Two-condition WHERE|NULL > N = NULL in SQL — missing condition silently excludes never-churned accounts|
|Entry plan\_tier not current|accounts.plan\_tier|Cohort segmentation should reflect starting state not ending state|
|ever\_reactivated requires ever\_churned|Logic enforced|Cannot reactivate without having churned first|
|is\_currently\_active from raw subscriptions|Not base\_active\_monthly|Point-in-time snapshot needs exact date check, not monthly overlap|
|reactivation\_check excludes trials|is\_trial = FALSE|Trial restarts after churn are not genuine paid reactivation|

\---

## 7\. Known Limitations

### 7.1 Month 0 Retention Hardcoding

Month 0 in the retention matrix is hardcoded to 100% regardless of `base\_active\_monthly` data. This is necessary because `base\_active\_monthly` may undercount Month 0 due to subscription start\_date timing. However it means same-month churners are invisible in the retention matrix at Month 0 — they only appear in the survival curve.

### 7.2 Survival Curve — No Month 0 = 100% Guarantee

The survival curve correctly shows same-month churners as lost at Month 0. Some cohorts show Month 0 survival below 100%. This is not a bug — it reflects accounts that signed up and churned within the same calendar month. December 2024 at 35.29% is a genuine data signal, not a quality issue.

### 7.3 Age Cap Means Incomparable Later Cohorts

2024 cohorts have fewer observation months than 2023 cohorts. Comparisons at Month 12 are only available for cohorts up to December 2023. Direct 2023 vs 2024 comparison is only valid at Month 3 and earlier for the full cohort set.

### 7.4 Small Cohort Sizes

Cohort sizes range from 13 to 32 accounts. Small cohorts produce volatile percentages — one account churning or reactivating moves the rate by 3-8 percentage points. Treat individual cohort data with appropriate statistical caution.

### 7.5 is\_currently\_active = TRUE for All 500 Accounts

All 500 accounts show `is\_currently\_active = TRUE` because every account has at least one open subscription (`end\_date IS NULL`). This is dataset design, not a bug. Use `ever\_churned` and `ever\_reactivated` for permanence analysis instead of `is\_currently\_active`.

### 7.6 Reactivation Definition Excludes Trial Reactivations

`ever\_reactivated` only counts paid subscription restarts (`is\_trial = FALSE`). Accounts that returned via trial after churning are counted as `ever\_reactivated = FALSE`. This may slightly undercount true reactivation.

\---

## 8\. Retention vs Survival — The Critical Distinction

This is the most important analytical concept in the cohort layer.

### The Two Definitions

```
Retention Matrix:   Is the account active NOW at month N?
Survival Curve:     Has the account EVER churned by month N?
```

### The Paradox in This Dataset

```
Retention Matrix signal:    2024 cohorts IMPROVING  ↑
Survival Curve signal:      2024 cohorts WORSENING  ↓
```

**Both are simultaneously true.**

2024 cohorts churn faster than 2023 cohorts — the survival curve correctly shows this.
2024 churned accounts come back faster than 2023 churned accounts — this masks the deterioration in the retention matrix.

### The Reactivation Gap

The gap between the two curves at each month quantifies reactivated accounts:

```
Month 6:
  Retention:  98.76% (nearly everyone appears active)
  Survival:   55.12% (only 55% have never churned)
  Gap:        43.64% = accounts active despite having churned at least once
```

**43.64% of active accounts at Month 6 have churned at least once and come back.**

### The Business Implication

The business has gotten better at winning back churned customers — but worse at preventing the first churn. This is a fundamentally unstable model:

```
Reactivation = expensive, unreliable, reactive
Prevention    = cheap, reliable, proactive
```

A product that relies on reactivation to maintain its active base is building on an unstable foundation. One quarter of weak reactivation performance could reveal the true churn rate underneath.

### How to Present Both

Always present the retention matrix and survival curve together:

> "The retention matrix shows 2024 cohorts retaining at 92% at Month 1 — a dramatic improvement from 55% for 2023 cohorts. However the survival curve shows 2024 cohorts actually churning faster — only 75% of 2024 accounts survive to Month 1 without a first churn, compared to 83% for 2023 accounts. The apparent improvement in the retention matrix is driven entirely by faster reactivation, not better initial retention."

\---

## 9\. Cohort Findings Summary

### 9.1 Behavioral Segments

```
Stable (never churned)     148 accounts    29.6%
Lost (churned, not back)    26 accounts     5.2%
Cyclical (churned + back)  326 accounts    65.2%
```

Dominant behavior is cyclical. Churn is instability, not permanent loss.

### 9.2 Time-to-First-Churn

```
Months 0-1 churn    128 accounts    36.4% of all churns
Month 1 peak         79 accounts    most common churn timing
Avg churn events     1.70 per churned account
```

Over one third of all churns happen within the first full month — classic onboarding failure.

### 9.3 Retention Matrix Signals

```
Month 0    100%     (hardcoded baseline)
Month 1     71.41%  avg (steepest drop)
Month 3     90.32%  avg (recovery begins)
Month 6     98.76%  avg (near-full recovery)
Month 14   100.00%  avg (complete reactivation recovery)

2023 Month 1 avg    \~55%
2024 Month 1 avg    \~92%
Gap                 +37pp (reactivation-driven improvement)
```

### 9.4 Survival Curve Signals

```
Month 0     90.38% avg (same-month churn visible)
Month 1     78.73% avg
Month 6     55.12% avg (median survival approaching)
Month 9     48.62% avg (median survival)
Month 23    29.41% avg (long-term loyal floor)

2023 Month 3 avg    \~79%
2024 Month 3 avg    \~52%
Gap                 -27pp (survival deteriorating)
```

### 9.5 Median Survival by Cohort

```
Best:  May 2023      Month 19
Good:  Apr 2023      Month 15
Mid:   Jan 2023      Month 11
Poor:  Oct 2023      Month 6
Bad:   Sep/Nov 2024  Month 1
Worst: Dec 2024      Month 0
```

### 9.6 Referral Source Performance

```
Best retention:  ads       60.2% churn rate
Worst retention: partner   75.3% churn rate
```

### 9.7 Reactivation Gap at Month 6

```
Retention:  98.76%
Survival:   55.12%
Gap:        43.64% = reactivated account proportion
```

\---

## 10\. Pre-Launch Implications

### Critical Risk — December 2024 Cohort

```
Month 0 survival: 35.29%
11 of 17 accounts churned in their signup month
Unprecedented in entire dataset
```

If this pattern continues post-launch, the product cannot sustain growth through acquisition alone. New customers are leaving before completing their first month.

### Critical Risk — Survival Deterioration Hidden by Reactivation

The retention matrix improvement signal is misleading without the survival curve context. The product is:

* Getting better at winning customers back (positive)
* Getting worse at keeping them in the first place (negative)

Pre-launch focus must shift to first-churn prevention.

### Critical Risk — Onboarding Failure Pattern

36.4% of all churns happen in Months 0-1. Month 1 (first renewal) is the single most dangerous moment in the customer lifecycle. Onboarding must create value before Month 1 renewal decision.

### Positive Signal — Long-term Loyal Base

29.6% of accounts never churned. 29.41% long-term survival floor for fully observed cohorts. Once customers survive Month 6, they very rarely leave permanently.

### Positive Signal — Early Cohort Quality

May 2023 cohort (Month 19 median survival) shows that when the product finds the right customer — retention is excellent. The product CAN retain well. The problem is reaching those right customers consistently.

### Recommended Actions

Based on cohort analysis:

|Priority|Action|Evidence|
|-|-|-|
|P1|Fix Month 0-1 onboarding|36.4% of churns in Months 0-1|
|P1|Investigate Dec 2024 spike|35.29% Month 0 survival unprecedented|
|P2|Reduce first-churn rate in 2024 cohorts|Survival deteriorating despite retention appearing better|
|P2|Investigate June 2023 anomaly|23% Month 1 retention — specific event suspected|
|P3|Evaluate partner channel ROI|75.3% churn rate — worst of all channels|
|P3|Scale ads acquisition|60.2% churn rate — best performing channel|

\---

## Document History

|Date|Step|Change|
|-|-|-|
|2026-04-28|Step 14.1|cohort\_base built and validated|
|2026-04-28|Step 14.1|Calendar month arithmetic fix applied|
|2026-04-28|Step 14.1|is\_currently\_active logic corrected|
|2026-04-28|Step 14.2|cohort\_retention\_matrix built and validated|
|2026-04-28|Step 14.2|Month 0 = 100% hardcoding fix applied|
|2026-04-28|Step 14.3|cohort\_survival\_curve built and validated|
|2026-04-28|Step 14.3|NULL handling for ever\_churned documented|
|2026-04-28|Step 14|Documentation finalized|

\---

*This document is the authoritative reference for the RavenStack cohort layer. All advanced analysis in Steps 24-28 and dashboard cohort sections in Phase 6 should reference the definitions, decisions, and findings documented here.*

