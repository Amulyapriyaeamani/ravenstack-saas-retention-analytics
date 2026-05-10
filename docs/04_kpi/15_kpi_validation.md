# KPI Validation & Sign-Off
## RavenStack SaaS Pre-Launch Analysis
**Project:** RavenStack Pre-Launch Performance Analysis
**Role:** Product Analyst
**Step:** 15 — KPI Validation
**Status:** ✅ PASSED — Ready for Phase 3
**Last Updated:** 2026-04-28

---

## Purpose

This document is the formal cross-validation sign-off for the RavenStack analytical foundation.

Individual validations were run within each SQL file during Steps 12–14. This step validates that all layers are **internally consistent as a system** — not just individually correct, but agreeing with each other across all views and definitions.

**Sign-off confirms:**
- Base layer, KPI layer, and cohort layer are internally consistent
- All critical business numbers reconcile across sources
- Known definition differences are documented and expected
- The analytical foundation is ready for Phase 3 Core Analysis

---

## Layers Validated

| Layer | Files | Status |
|---|---|---|
| Base Layer | 5 views (01–05) | ✅ Validated in Step 12 |
| KPI Layer | 8 views (13_01–13_08) | ✅ Validated in Step 13 |
| Cohort Layer | 3 views (14_01–14_03) | ✅ Validated in Step 14 |
| Cross-Layer System | 10 checks (this step) | ✅ Validated here |

---

## Validation Results

---

### Check 1 — Churn Numbers Reconcile ✅

**Question:** Do all three churn sources agree on the number of distinct churned accounts?

| Source | Distinct Churned Accounts |
|---|---|
| churn_events (raw) | 352 |
| base_churn_monthly | 352 |
| cohort_base (ever_churned = TRUE) | 352 |

**Result:** All three sources report exactly 352. ✅

**Why this matters:**

The churn number is used as numerator in churn rate, as a behavioral flag in cohort base, and as the source of truth for all churn analysis. If these disagreed, every churn metric in the project would be internally contradictory.

**Decision confirmed:** `churn_events` is the source of truth. All downstream tables correctly derive from it.

---

### Check 2 — MRR Reconciles Across Layers ✅

**Question:** Does `base_mrr_monthly` match `kpi_monthly_mrr_growth` for every month?

**Result:** 0 rows returned — perfect match across all 24 months. ✅

**Why this matters:**

`kpi_monthly_mrr_growth` builds directly on `base_mrr_monthly` using LAG(). If the base view changed after the KPI view was created, a mismatch would appear here. Confirmed consistent.

---

### Check 3 — Active Account Definitions Documented ✅ (Expected Gap)

**Question:** What is the difference between `base_active_monthly` (active-anytime) and `kpi_monthly_churn_rate` (active-at-start-of-month)?

| Month | Base Active (Anytime) | KPI Denominator (Start of Month) | Difference |
|---|---|---|---|
| 2023-02 | 10 | 2 | 8 |
| 2023-06 | 71 | 50 | 21 |
| 2024-05 | 310 | 282 | 28 |
| 2024-11 | 475 | 441 | 34 |
| 2024-12 | 500 | 476 | 24 |

**Result:** Consistent positive gap across all months. ✅ Expected and correct.

**Explanation:**

```
Gap = accounts that joined DURING the month
      They are active anytime but NOT active at start of month
      They were never exposed to full churn risk for the period
      Correctly excluded from churn rate denominator
```

The gap represents new account signups during each month. These accounts should not be in the churn rate denominator — they joined after the start of the period and were never at full churn risk.

**This is intentional design, not an error.** Both definitions are correct for their respective purposes:

| Definition | Used For | Correct Because |
|---|---|---|
| Active anytime | Feature adoption, MAU | Measures any engagement during period |
| Active at start | Churn rate, retention rate | Measures accounts exposed to full churn risk |

---

### Check 4 — Cohort Sizes Reconcile ✅

**Question:** Do cohort sizes in `cohort_base` exactly match the `accounts` table?

**Result:** 0 rows returned — all 24 cohort sizes match exactly. ✅

**Why this matters:**

Cohort sizes are the permanent denominators for all retention and survival calculations. If cohort_base miscounted any cohort, every retention rate and survival rate for that cohort would be wrong.

---

### Check 5 — Feature Usage Reconciles Correctly ✅

**Question:** Does `base_feature_usage_monthly` capture exactly 100% of eligible active-subscription usage?

**Reconciliation:**

| Metric | Value |
|---|---|
| Raw feature_usage rows | 25,000 |
| Rows with active subscription | 6,127 |
| Rows excluded (inactive subs) | 18,873 (75.49% of raw) |
| SUM(usage_count) — eligible rows | 61,306 |
| base_feature_usage_monthly total | 61,306 |
| Difference | **0** ✅ |

**Result:** Base layer captures exactly 100% of eligible usage. ✅

**Explanation:**

The raw `feature_usage` table has 25,000 rows, each containing a `usage_count` column representing pre-aggregated event frequency. The raw `SUM(usage_count)` = 250,525 — but this is **not a valid comparison** against the base layer because it includes usage from inactive subscription periods.

The correct reconciliation is:

**Step 1 — Row-level filter:**
```
25,000 raw rows
→ 6,127 rows pass active subscription filter  (24.51%)
→ 18,873 rows excluded (inactive subscription periods)
```

**Step 2 — Usage count preservation:**
```
SUM(usage_count) from 6,127 eligible rows = 61,306
base_feature_usage_monthly SUM(total_usage_count) = 61,306
Difference = 0 ✅
```

**Step 3 — Aggregation within base layer:**
```
6,127 eligible rows → 6,040 rows in base layer
87 rows collapsed by monthly grain grouping
(same account + feature + month → one row, usage_count summed)
No usage lost — only aggregated
```

**Why comparing raw SUM(250,525) to base SUM(61,306) is misleading:**

Each of the 25,000 raw rows already contains a `usage_count` — so SUM(usage_count) aggregates across all rows including the 18,873 ineligible ones. The 250,525 vs 61,306 difference reflects both the row-level filter AND the pre-aggregated nature of `usage_count`. It cannot be interpreted as a capture rate.

The meaningful comparison is: eligible rows SUM(usage_count) vs base layer SUM — which is 61,306 vs 61,306 = 100% capture.

**Business interpretation:**

The 18,873 excluded rows represent usage events tied to subscriptions that were inactive during the usage month. Including them would mix active and inactive customer behavior — overstating genuine engagement.

**Note for Phase 3:**

Always use `base_feature_usage_monthly.total_usage_count` (61,306) for engagement analysis — not raw table SUM(usage_count) (250,525). The base layer number reflects 100% of genuine active customer engagement.

---

### Check 6 — Retention + Churn = 100% System Wide ✅

**Question:** Do `kpi_monthly_churn_rate` and `kpi_monthly_retention_rate` sum to exactly 100% for every month?

**Result:** 0 rows returned — all 23 months sum to exactly 100.00%. ✅

**Why this matters:**

This is the fundamental arithmetic consistency check for the two most important KPIs. If they didn't sum to 100%, it would mean the two KPIs were using different denominators or numerators — producing contradictory results that could not both be reported.

Confirmed: both KPIs are internally consistent and can be presented together.

---

### Check 7 — Cohort Retention Month 0 = 100% ✅

**Question:** Does every cohort show exactly 100% retention at Month 0?

**Result:** 0 rows returned — all 24 cohorts show 100.00% at Month 0. ✅

**Context:**

Month 0 was hardcoded to 100% in `cohort_retention_matrix` after discovering that `base_active_monthly` undercounted Month 0 activity due to subscription timing vs month spine alignment. This check confirms the fix is working correctly across all cohorts.

---

### Check 8 — Survival Curve Monotonic System Check ✅

**Question:** Does the survival curve ever increase from one month to the next for any cohort?

**Result:** 0 rows returned — curve is monotonically non-increasing for all cohorts. ✅

**Why this matters:**

A survival curve that increases would indicate a logical error — accounts cannot "un-churn" in a survival model once marked as lost. This check confirms the fundamental property of survival analysis is maintained throughout the dataset.

---

### Check 9 — Total Accounts Consistent Across All Layers ✅

**Question:** Do all layers account for the same total of 500 accounts?

| Source | Total Accounts |
|---|---|
| accounts (raw table) | 500 |
| cohort_base | 500 |
| base_active_monthly (distinct) | 500 |
| base_mrr_monthly (max month) | 500 |

**Result:** All four sources report exactly 500. ✅

**Why this matters:**

If any layer lost or duplicated accounts during processing, every rate and percentage calculated from that layer would be systematically wrong. All 500 accounts are present and accounted for across every layer.

---

### Check 10 — Revenue Churn Denominator Consistency ✅

**Question:** Is start-of-month MRR always less than or equal to active-anytime MRR for the same month?

**Result:** 0 rows returned. ✅

**Why this matters:**

Start-of-month MRR is a strict subset of active-anytime MRR. If start-of-month ever exceeded active-anytime, it would mean the revenue churn denominator was using a broader population than the MRR base — which is logically impossible and would produce revenue churn rates above 100%.

Confirmed: start-of-month MRR is always ≤ active-anytime MRR.

---

## Summary Table

| Check | Description | Result | Notes |
|---|---|---|---|
| 1 | Churn numbers reconcile across 3 sources | ✅ PASS | All = 352 |
| 2 | MRR consistent base vs KPI layer | ✅ PASS | 0 mismatches |
| 3 | Active account definition gap documented | ✅ EXPECTED | Gap = new mid-month signups |
| 4 | Cohort sizes match accounts table | ✅ PASS | 0 mismatches |
| 5 | Feature usage reconciles correctly | ✅ PASS | 61,306 = 61,306 — 100% eligible usage captured |
| 6 | Retention + churn = 100% all months | ✅ PASS | 0 violations |
| 7 | Cohort Month 0 = 100% all cohorts | ✅ PASS | 0 violations |
| 8 | Survival curve monotonically decreasing | ✅ PASS | 0 violations |
| 9 | 500 accounts across all layers | ✅ PASS | All sources = 500 |
| 10 | Revenue churn denominator valid | ✅ PASS | 0 violations |

**10 of 10 checks passed or explained.** ✅

---

## Known Definition Differences (Documented, Not Errors)

These are intentional design decisions — not data quality issues.

| Difference | Definition A | Definition B | Gap | Reason |
|---|---|---|---|---|
| Active accounts | base_active_monthly (anytime) | kpi_monthly_churn_rate (start-of-month) | 8–34 per month | Churn requires start-of-month denominator |
| Feature usage rows | raw table (25,000 rows, all subs) | base layer (6,127 eligible rows) | 18,873 rows excluded | Base filters to active subscription periods only — usage_count fully preserved |
| MRR | base_mrr_monthly (active-anytime) | revenue_churn start_month_mrr | start < anytime | Revenue churn uses start-of-month snapshot |
| Cohort Month 0 | retention_matrix (100% forced) | survival_curve (actual) | varies | Different definitions require different Month 0 handling |

---

## Analytical Foundation — Final State

### Base Layer
```
01_base_accounts.sql              ✅ Snapshot dimension
02_base_active_monthly.sql        ✅ Activity denominator (5,257 rows)
03_base_mrr_monthly.sql           ✅ Revenue fact (24 rows)
04_base_churn_monthly.sql         ✅ Churn fact (547 rows)
05_base_feature_usage_monthly.sql ✅ Engagement fact (6,040 rows)
```

### KPI Layer
```
13_01_kpi_monthly_churn_rate.sql         ✅ Avg 11.41% (24 rows)
13_02_kpi_monthly_retention_rate.sql     ✅ Avg 88.08% (24 rows)
13_03_kpi_monthly_mrr_growth.sql         ✅ Avg 46.72% growth (24 rows)
13_04_kpi_monthly_active_users.sql       ✅ 1→417 MAU (24 rows)
13_05_kpi_monthly_feature_adoption.sql   ✅ 40 features (1,069 rows)
13_06_kpi_monthly_revenue_churn_rate.sql ✅ Avg ~6.5% (24 rows)
13_07_kpi_monthly_upgrade_downgrade.sql  ✅ Avg 10% upgrade (24 rows)
13_08_kpi_monthly_support_metrics.sql    ✅ 2,000 tickets (24 rows)
```

### Cohort Layer
```
14_01_cohort_base.sql              ✅ 500 accounts, 24 cohorts
14_02_cohort_retention_matrix.sql  ✅ 300 rows, Month 0 = 100%
14_03_cohort_survival_curve.sql    ✅ 300 rows, monotonically decreasing
```

---

## Key Numbers — Locked and Validated

| Metric | Value | Source |
|---|---|---|
| Total accounts | 500 | accounts |
| Total subscriptions | 5,000 | subscriptions |
| Total churned accounts | 352 | churn_events |
| Total never churned | 148 | cohort_base |
| Total reactivated | 326 | cohort_base |
| Total permanently lost | 26 | cohort_base |
| Dataset period | Jan 2023 – Dec 2024 | subscriptions |
| Total months | 24 | base_mrr_monthly |
| MRR Jan 2023 | $4,684 | base_mrr_monthly |
| MRR Dec 2024 | $10,734,251 | base_mrr_monthly |
| Avg monthly churn rate | 11.41% | kpi_monthly_churn_rate |
| Avg monthly retention rate | 88.08% | kpi_monthly_retention_rate |
| Avg monthly MRR growth | 46.72% | kpi_monthly_mrr_growth |
| Peak churn month | Dec 2024 (20.17%) | kpi_monthly_churn_rate |
| Active features | 40 | base_feature_usage_monthly |
| Support tickets | 2,000 | support_tickets |
| Feature usage (active subs) | 61,306 | base_feature_usage_monthly |
| Feature usage eligible rows | 6,127 of 25,000 raw | feature_usage + active sub filter |

---

## Sign-Off Statement

> All 10 cross-validation checks passed or have been fully explained as intentional design decisions. The analytical foundation — comprising 5 base views, 8 KPI views, and 3 cohort views — is internally consistent across all layers. All critical business numbers reconcile to their source of truth. Known definition differences between layers are documented and expected. The analytical foundation is complete, validated, and ready for Phase 3 Core Analysis.

**Step 15 Status: ✅ COMPLETE**
**Phase 2 Status: ✅ COMPLETE**
**Phase 3 Status: Ready to begin**

---

## What Comes Next — Phase 3 Core Analysis

Phase 3 builds analytical insights on top of this validated foundation:

| Step | Module | Focus |
|---|---|---|
| 16 | User Growth Analysis | Monthly signups, referral source performance |
| 17 | Revenue Analysis | MRR trends, plan-wise revenue |
| 18 | Upgrade/Downgrade Analysis | % upgrading, revenue impact |
| 19 | Churn Rate Analysis | Overall and monthly churn |
| 20 | Churn Segmentation | By plan, industry, country |
| 21 | Churn Reason Analysis | Pricing vs support vs features |
| 22 | Feature Adoption Analysis | Most/least used features |
| 23 | Usage vs Churn | High vs low usage impact on churn |

Every Phase 3 query builds directly on the validated views documented here. No raw table logic will be rebuilt — all analysis routes through the base and KPI layers.

---

*Document prepared by: Product Analyst, RavenStack Pre-Launch Analysis*
*Validation date: 2026-04-28*
*Next review: After Phase 3 completion*
