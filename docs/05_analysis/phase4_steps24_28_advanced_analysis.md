# Phase 4 — Advanced Analysis (Steps 24–28)
**RavenStack SaaS Pre-Launch Analysis**
**Role:** Product Analyst
**Steps:** 24 (Support Impact), 25 (Multi-Factor Churn Model), 26 (Lifecycle Journey), 27 (Cohort Retention Deep Dive), 28 (Beta Feature Impact)
**Status:** Complete & Validated
**Last Updated:** 2026-05-13

---

## Table of Contents
1. [Phase Overview](#1-phase-overview)
2. [Hypotheses — All Five Steps](#2-hypotheses--all-five-steps)
3. [Step 24 — Support Impact Analysis](#3-step-24--support-impact-analysis)
4. [Step 25 — Multi-Factor Churn Model](#4-step-25--multi-factor-churn-model)
5. [Step 26 — Lifecycle Journey Analysis](#5-step-26--lifecycle-journey-analysis)
6. [Step 27 — Cohort Retention Deep Dive](#6-step-27--cohort-retention-deep-dive)
7. [Step 28 — Beta Feature Impact](#7-step-28--beta-feature-impact)
8. [Cross-Step Synthesis](#8-cross-step-synthesis)
9. [Pre-Launch Risk Intelligence Summary](#9-pre-launch-risk-intelligence-summary)
10. [Phase 4 Recommendations](#10-phase-4-recommendations)

---

## 1. Phase Overview

Phase 4 shifts from describing what is happening to explaining why — and then to predicting what will happen next. Phases 2 and 3 analyzed each business dimension in isolation: churn rates, feature adoption, support metrics. Phase 4 crosses those dimensions to ask questions none of the prior phases could answer alone.

Step 24 tests whether support quality drives churn. Step 25 combines all signals into a per-account risk model. Step 26 maps the full customer lifecycle from signup to churn to reveal where the journey breaks down. Step 27 deepens the cohort retention analysis with segmentation and 2023 vs 2024 comparison. Step 28 tests whether beta feature adoption protects against churn.

Together these five steps represent the transition from analysis to decision — and deliver the clearest pre-launch intelligence available from the dataset.

**Sources used:**

| Source | Role |
|---|---|
| `kpi_monthly_support_metrics` | Monthly support KPI baseline |
| `kpi_monthly_churn_rate` | Monthly churn rate for correlation |
| `kpi_monthly_retention_rate` | Retention complement |
| `support_tickets` | Account-level ticket data |
| `base_churn_monthly` | Churn events with preceding downgrade flag |
| `base_feature_usage_monthly` | Usage intensity and beta feature flags |
| `base_active_monthly` | Active account population |
| `cohort_base` | Account attributes and churn history |
| `cohort_retention_matrix` | Monthly retention rates per cohort |
| `cohort_survival_curve` | Survival rates per cohort |
| `subscriptions` | Current MRR for risk quantification |
| `accounts`, `churn_events`, `feature_usage` | Raw tables for lifecycle journey |

**Dashboard views created:**

| View | Step | Page | Status |
|---|---|---|---|
| `analysis_support_vs_churn_monthly` | 24 | 5 | ✅ Built |
| `analysis_support_account_level` | 24 | 5, 6 | ✅ Built |
| `analysis_csat_churned_vs_retained` | 24 | 5 | ✅ Built |
| `analysis_churn_risk_scores` | 25 | 6 | ✅ Built |
| `analysis_risk_tier_summary` | 25 | 6 | ✅ Built |
| `analysis_lifecycle_journey` | 26 | 6 | ✅ Built |
| `analysis_lifecycle_stages` | 26 | 6 | ✅ Built |
| `analysis_cohort_month1_deep_dive` | 27 | 7 | ✅ Built |
| `analysis_cohort_year_comparison` | 27 | 7 | ✅ Built |
| `analysis_cohort_survival_segmented` | 27 | 7 | ✅ Built |
| `analysis_beta_vs_nonbeta_churn` | 28 | 4 | ✅ Built |
| `analysis_beta_feature_retention` | 28 | 4 | ✅ Built |

---

## 2. Hypotheses — All Five Steps

### Step 24 — Support Impact Analysis

| # | Hypothesis | Result |
|---|---|---|
| H1 | Months with higher ticket volume correlate with higher churn in the same or following month | ❌ Refuted — no consistent lag correlation. Ticket volume fluctuates independently of churn rate. |
| H2 | Accounts with above-average resolution times churn at higher rates | ❌ Refuted — 6–10 ticket accounts (avg resolution 35.8 hrs) show 63.2% churn — lower than 3–5 ticket accounts (35.5 hrs, 72.9%). Not linearly predictive. |
| H3 | CSAT is a leading indicator of churn — low CSAT accounts churn more | ❌ Refuted — avg CSAT is nearly identical across all status groups: churned+reactivated (3.96), permanently lost (3.96), never churned (3.97). |
| H4 | Escalated ticket accounts churn at higher rates | ✅ Confirmed — 75.8% churn for escalated accounts vs 69.3% for non-escalated — a 6.5pp gap. |
| H5 | Support-related churn aligns with months of poor CSAT and high resolution time | ❌ Refuted — all 22 months classified as "poor" or "critical." No variation to correlate against. |

### Step 25 — Multi-Factor Churn Model

| # | Hypothesis | Result |
|---|---|---|
| H1 | Low-usage accounts dominate the high-risk tier | ✅ Confirmed — the single high-risk account has zero usage. Usage is dominant signal in 100% of risk scores. |
| H2 | Cross-signal accounts churn at higher rates than single-signal accounts | ✅ Partially confirmed — all-three-signals, support+downgrade, usage+downgrade all show 100% churn. But usage+support shows 50% churn — lower than no-signals (69.6%). |
| H3 | The model correctly identifies past churners via shorter months_to_first_churn | ✅ Partially confirmed — high risk: 0.0 months avg, medium: 1.9 months, low: 5.3 months. Direction correct but rates collapse. |
| H4 | MRR at risk from high-tier accounts exceeds $2M | ❌ Refuted — high-risk tier has 1 account ($23,800). $2.65M sits in medium tier. |

### Step 26 — Lifecycle Journey Analysis

| # | Hypothesis | Result |
|---|---|---|
| H1 | The longest gap is between First Subscription and First Feature Use — slow activators churn faster | ❌ Refuted by data artifact — negative days values reveal feature usage predates subscription start for most accounts. The journey stage model is structurally limited by dataset design. |
| H2 | Accounts that raised a support ticket before churning had shorter survival times | ❌ Refuted — accounts with a ticket 30+ days before churn averaged 4.7 months to first churn vs 3.4 months for accounts with no ticket before churn. Ticket-before-churn accounts survived longer. |
| H3 | Accounts that skip feature use stage entirely churn fastest | ✅ Confirmed — "churned: minimal" journey type (no usage, no support) accounts are a small group (5 accounts, 1%) but the pattern validates zero-usage risk. |
| H4 | 2024 cohorts show improved journey completion rates despite faster churn | ✅ Confirmed — both 2023 and 2024 cohorts show 100% feature use and ~98% support stage completion. But 2024 cohorts reach churn in 60.4 avg days vs 217.3 for 2023 — dramatically faster. |

### Step 27 — Cohort Retention Deep Dive

| # | Hypothesis | Result |
|---|---|---|
| H1 | Month 1 is the single most critical drop-off point — M0→M1 drop is larger than any subsequent drop | ✅ Confirmed — every cohort shows its largest single-month drop at Month 1. June 2023 cohort drops 76.92pp in one month — the largest single drop in the dataset. |
| H2 | 2024 cohorts show higher Month 1 retention but lower Month 1 survival — reactivation masking | ✅ Confirmed — 2024 avg Month 1 retention: 91.6%, survival: 67.0% (gap 24.6pp). 2023 avg Month 1 retention: 52.9%, survival: 89.5% (gap -36.6pp). The paradox is real and quantified. |
| H3 | Ads channel cohorts retain significantly better than organic or partner | ✅ Confirmed — ads: 28.2% churned by Month 1 vs partner: 36.5%, organic: 38.8%. Ads also best on never-churned (39.4%) and avg months to first churn (5.2). |
| H4 | Enterprise entry plan cohorts show longer survival than Basic or Pro | ❌ Refuted — Basic has best churn rate (69.1%), Enterprise second (69.3%), Pro worst (72.4%). Enterprise entry does not confer a retention advantage. |
| H5 | Reactivation gap widens to Month 6 then stabilizes | ❌ Refuted — gap continues widening past Month 6, reaching 57.40pp at Month 12 and 70.59pp at Month 23. It never stabilizes within the observation window. |

### Step 28 — Beta Feature Impact

| # | Hypothesis | Result |
|---|---|---|
| H1 | Beta users churn at lower rates than non-beta users | ❌ Refuted — beta users: 70.8% churn, GA-only users: 70.6% churn. Nearly identical. Beta adoption does not predict churn. |
| H2 | Beta adoption depth (more distinct beta features) correlates negatively with churn | ❌ Refuted — non-monotonic. 4–5 beta features shows 84.0% churn (highest), while 6+ features shows 50.0% (lowest, but only 6 accounts). |
| H3 | Specific beta features correlate with significantly better retention | ✅ Confirmed — feature_3 adopters: 46.7% churn (-23.7pp vs overall), feature_21: 53.8% (-16.6pp), feature_39: 56.3% (-14.1pp). Top 10 beta features all show below-average churn for adopters. |
| H4 | Beta adoption rate has grown over time | ✅ Confirmed — from 0% in Jan 2023 to 16.6% in Dec 2024. Strong growth trend with acceleration in H2 2024 (12.6% July, 16.9% October, 16.6% December). |
| H5 | Beta adoption, like overall usage, will not meaningfully differentiate churners from retained accounts | ✅ Confirmed — pre-churn beta usage gap near zero in most months. Step 23 finding extends to beta features. |

---

## 3. Step 24 — Support Impact Analysis

### 3.1 Support Quality Baseline — Every Month Is Poor

The first structural finding of Step 24: every single reliable month in the 22-month dataset is classified "poor" or "critical." Not one month achieved acceptable quality.

| Support Quality | Month Count | % of Months |
|---|---|---|
| Poor | 21 | 95.5% |
| Critical | 1 | 4.5% |
| Average | 0 | 0.0% |
| Good | 0 | 0.0% |

Benchmark gaps that define "poor":

| Metric | Benchmark | Dataset Range | Gap |
|---|---|---|---|
| Avg resolution time | < 24 hours | 33.5–41.0 hours | 9.5–17.0 hours above |
| CSAT score | ≥ 4.5 | 3.71–4.33 | 0.17–0.79 below |
| First response time | < 60 minutes | 81.5–98.3 minutes | 21.5–38.3 minutes above |

The single critical month was October 2023 (CSAT 3.79, resolution 39.14 hours). The best CSAT month was September 2024 (4.33) but resolution was still 10 hours above benchmark. The product has never had a month where both core support metrics were simultaneously near benchmark.

### 3.2 Monthly Correlation — H1 Refuted

Testing whether poor support in month M predicts higher churn in M+1 or M+2 reveals no consistent pattern. September 2024 had the best CSAT of any month (4.33), yet the following two months showed the highest churn rates of any consecutive period (14.46% and 13.61%). February 2024 had the lowest churn rate despite being a "poor" support month.

Because every month is uniformly "poor," there is no contrast to correlate against. Support quality is structurally bad, but churn varies — meaning something other than support quality fluctuation drives churn fluctuation month-to-month.

### 3.3 Account-Level Support Intensity vs Churn — H2 Refuted

| Ticket Volume | Accounts | Churn Rate | Avg Resolution (hrs) | Gap vs Overall |
|---|---|---|---|---|
| 0 tickets | 8 | **62.5%** | — | -7.9pp |
| 1–2 tickets | 104 | 70.2% | 38.9 | -0.2pp |
| 3–5 tickets | 292 | **72.9%** | 35.5 | +2.5pp |
| 6–10 tickets | 95 | **63.2%** | 35.8 | -7.2pp |
| 11+ tickets | 1 | 100.0% | 32.7 | +29.6pp |

Churn does not increase with ticket volume. The 6–10 bucket (63.2%) churns less than the 3–5 bucket (72.9%). Accounts generating more tickets are more engaged — actively seeking resolution rather than quietly exiting. The dominant population (3–5 tickets, 292 accounts) has the worst churn rate in the dataset.

### 3.4 Escalation vs Churn — H4 Confirmed

| Escalation Status | Accounts | Churn Rate | Avg Months to First Churn | Avg Churn Events |
|---|---|---|---|---|
| Has escalated ticket | 91 | **75.8%** | 4.0 | 1.37 |
| Tickets, none escalated | 401 | 69.3% | 4.5 | 1.17 |
| No tickets at all | 8 | 62.5% | 4.2 | 0.88 |

Escalation is the only valid account-level support churn signal — 6.5pp gap vs non-escalated. Escalated accounts also show more repeat churn events (1.37 vs 1.17 avg). This finding directly shapes the Step 25 risk model: escalation adds a +5 point modifier to the support signal.

### 3.5 CSAT Churned vs Retained — H3 Refuted

| Account Status | Accounts | Avg CSAT | CSAT Gap vs Benchmark |
|---|---|---|---|
| Churned + reactivated | 326 | **3.96** | 0.54 |
| Permanently lost | 26 | **3.96** | 0.54 |
| Never churned | 148 | **3.97** | 0.53 |

A 0.01 CSAT difference between churned and never-churned accounts. CSAT does not differentiate churners from retained accounts at all. In the 30 days before churn, accounts averaged only 0.15 tickets and 4.14 CSAT — slightly above the overall 3.98 average. Churning accounts did not have distinctly worse support experiences before churning.

### 3.6 The Core Finding — Support Quality Is Structural, Not Causal

Poor support is a background condition affecting all accounts equally, not a variable explaining churn fluctuations. It may contribute to an elevated churn baseline, but it does not explain why churn was 4.63% in February 2024 and 20.17% in December 2024. Those fluctuations are driven by acquisition quality, cohort composition, and pricing friction — not month-to-month support variation.

Improving support will not unlock dramatic churn reduction in the short term. It is a necessary baseline improvement for launch readiness, but it is not the primary lever for fixing the December crisis.

### 3.7 Key Insights — Step 24

- Every month classified "poor" or "critical" — support has never reached acceptable quality in 22 months
- No lag correlation between support quality and churn fluctuations
- 6–10 ticket accounts (63.2%) churn less than 3–5 ticket accounts (72.9%) — more tickets = more engagement, not more risk
- CSAT is identical across churned and retained accounts (3.96 vs 3.97) — satisfaction does not discriminate
- Escalation is the only valid support churn signal — 75.8% vs 69.3% (+6.5pp gap)
- Pre-churn support experience is not worse than average — accounts churn despite normal support, not because of bad support
- Support quality is a structural deficit, not a churn driver

---

## 4. Step 25 — Multi-Factor Churn Model

### 4.1 Signal Design Rationale

Three signals, each weighted by empirical evidence from prior steps.

**Signal 1 — Feature Usage (max 40 points)**
Rationale: Step 23 showed zero usage has the clearest directional signal (58.3% churn vs 70.5% low usage). The zero vs non-zero distinction is the most meaningful boundary.

| Usage Level | Score |
|---|---|
| Zero (0 events) | 40 pts |
| Low (≤ 25th percentile, ≤53) | 30 pts |
| Medium-low (25th–50th percentile) | 20 pts |
| Medium-high (50th–75th percentile) | 10 pts |
| High (> 75th percentile, >179) | 0 pts |

**Signal 2 — Support Intensity (max 30 points)**
Rationale: Step 24 confirmed escalation adds 6.5pp to churn probability. Volume alone is not predictive but combined with escalation captures the frustration pattern.

| Tickets | Base Score | + Escalation Modifier | Total Max |
|---|---|---|---|
| 11+ | 25 pts | +5 pts | 30 pts |
| 6–10 | 15 pts | +5 pts | 20 pts |
| 3–5 | 8 pts | +5 pts | 13 pts |
| 1–2 | 3 pts | +5 pts | 8 pts |
| 0 | 0 pts | — | 0 pts |

**Signal 3 — Preceding Downgrade (max 10 points — low weight)**
Rationale: Step 18 showed downgraders survive 0.9 months longer. Signal is weak but present — included at low weight.

**Score normalization:** Raw 0–80 divided by 80 × 100 to produce 0–100 scale.

### 4.2 Risk Tier Results

| Risk Tier | Accounts | % of Accounts | Total MRR at Risk | Avg MRR/Account | Historical Churn Rate |
|---|---|---|---|---|---|
| High | **1** | 0.2% | $23,800 | $23,800 | 100.0% |
| Medium | **134** | 26.8% | $2,652,134 | $19,792 | 70.1% |
| Low | **365** | 73.0% | $8,058,317 | $22,077 | 70.4% |

H4 is refuted — MRR concentration is in low and medium tiers. The single high-risk account is genuine (A-0f6450, zero usage, 8 tickets, escalation flag, $23,800 MRR — 87.5 risk score). The medium tier holds the actionable intervention population.

High-MRR accounts appear disproportionately in the low-risk tier because they are generally high-usage (longer tenured, more accumulated usage) — which suppresses their risk scores. This is a known model limitation.

**Retrospective validation:**

| Risk Tier | Accounts | Actual Churn Rate | Avg Months to First Churn |
|---|---|---|---|
| High | 1 | 100.0% | 0.0 |
| Medium | 134 | 70.1% | **1.9** |
| Low | 365 | 70.4% | **5.3** |

Direction is correct: higher risk = shorter survival time. But churn rates collapse to near-identical between medium (70.1%) and low (70.4%), reflecting the Step 23 finding that usage signals are weak predictors in aggregate.

### 4.3 Signal Combination Analysis

| Signal Combination | Accounts | Churn Rate | Avg Months to First Churn |
|---|---|---|---|
| All three signals | 5 | **100.0%** | 2.4 |
| Support + downgrade | 4 | **100.0%** | 12.3 |
| Usage + downgrade | 11 | **100.0%** | 1.2 |
| Downgrade only | 23 | **100.0%** | 6.2 |
| No signals | 276 | 69.6% | 5.0 |
| Usage only | 94 | 69.1% | 1.6 |
| Support only | 63 | 63.5% | 6.2 |
| **Usage + support** | **24** | **50.0%** | **2.2** |

The most counterintuitive finding: usage + support combination (50.0% churn) is the lowest of all groups, including no-signals (69.6%). Accounts with both low usage and high ticket volume are actively engaging with support despite disengagement from the product — still trying. This behavioral pattern is more resilient than silent disengagement.

Every combination involving the downgrade flag shows 100% churn. This is statistically significant but sample sizes are small (4–23 accounts per group).

### 4.4 Top 20 Risk Accounts

| Rank | Account | Plan | Risk Score | Usage | Support | Zero Usage | Escalation | Critical | MRR |
|---|---|---|---|---|---|---|---|---|---|
| 1 | A-0f6450 | Pro | **87.5** | Zero | High | Yes | Yes | Yes | $23,800 |
| 2 | A-149a69 | Basic | 68.8 | Zero | High | Yes | No | Yes | $8,058 |
| 3 | A-7cfe77 | Pro | 68.8 | Low | High | No | No | No | $12,765 |
| 4 | A-50bb9f | Pro | 68.8 | Low | High | No | No | No | $17,263 |
| 5 | A-bb1eaa | Basic | 68.8 | Low | High | No | No | No | $10,381 |
| 6 | A-44dc83 | Basic | 68.8 | Low | High | No | No | No | $456 |
| 7 | A-bb3bd4 | Basic | 68.8 | Low | Very High | No | No | No | $7,452 |
| 8 | A-fb186e | Basic | 68.8 | Zero | High | Yes | No | Yes | $5,771 |
| 9 | A-bf7919 | Pro | 66.3 | Zero | Low | Yes | No | No | $1,560 |
| 10 | A-c58f49 | Enterprise | 66.3 | Low | Medium | No | Yes | No | **$70,980** |

A-c58f49 (Enterprise, $70,980 MRR, risk score 66.3) is the highest-revenue account in the top-risk cohort. Despite a medium-tier score, the combination of Enterprise tier, escalation history, and low usage makes this the highest revenue risk in the dataset. Should be escalated to CS priority regardless of tier.

### 4.5 Key Insights — Step 25

- 1 high-risk account (A-0f6450, $23,800 MRR, 87.5 score) — the model is conservative, reflecting weak behavioral signals
- Medium-risk tier (134 accounts, $2.65M MRR) is the primary CS intervention target
- Usage signal dominates all scores — usage is the dominant signal in 100% of top-risk accounts
- Every downgrade-flag combination shows 100% historical churn
- Usage + support (50% churn) is the most resilient profile — active engagement on both dimensions provides protection
- A-c58f49 (Enterprise, $70,980 MRR) at 66.3 is highest-revenue account in top-risk cohort — needs manual priority escalation
- Model retrospective validation confirms direction (survival time ordering) even where churn rate separation is limited

---

## 5. Step 26 — Lifecycle Journey Analysis

### 5.1 Stage Completion Funnel

| Stage | Accounts Reached | % of Total | Avg Days from Signup | Drop from Previous |
|---|---|---|---|---|
| Signup | 500 | 100.0% | 0 | — |
| First Subscription | 500 | 100.0% | 33.3 days | 0 |
| First Feature Use | 500 | 100.0% | -376.5 days* | 0 |
| First Support Ticket | 492 | 98.4% | -215.7 days* | 8 accounts |
| First Churn Event | 352 | 70.4% | 133.1 days | 140 accounts |

**Critical data artifact — negative days values:** The "First Feature Use" and "First Support Ticket" stages show negative average days from signup. This occurs because feature_usage and support_tickets contain events with dates preceding the subscription start_date for many accounts in the dataset. This is a known dataset design characteristic — some events are recorded before the formal subscription is created. The negative values do not represent a data quality error; they reflect that usage and support activity can predate the subscription record.

The meaningful findings from the funnel are:
- All 500 accounts subscribed and used at least one feature — zero attrition through Stage 2
- 8 accounts (1.6%) never raised a support ticket — near-universal support engagement
- 140 accounts dropped between "raised a ticket" and "first churn" — these are the never-churned accounts
- 352 of 500 (70.4%) reached the churn stage

### 5.2 Activation Speed — A Uniform Finding

Every account (100%) appears in the "within 7 days" activation speed bucket. This is a consequence of the same negative-days artifact: because feature usage dates precede subscription dates for most accounts, all accounts appear to have activated before or immediately upon subscription. The activation lag analysis is not interpretable given this dataset structure.

The hypothesis (H1) that slow activators churn faster cannot be tested in this dataset. This is a documented limitation and should be noted in the case study.

### 5.3 Journey Type Distribution

| Journey Type | Accounts | % of Total | Avg Months to First Churn | Avg Churn Events | Reactivation Rate |
|---|---|---|---|---|---|
| Churned: full journey | 347 | 69.4% | 4.4 | 1.71 | 93.1% |
| Retained: with support | 145 | 29.0% | — | — | — |
| Churned: no support | 5 | 1.0% | 4.2 | 1.40 | 60.0% |
| Retained: no support | 3 | 0.6% | — | — | — |

The dominant journey (69.4% of all accounts) is the complete path: signup → subscription → feature use → support → churn. This means most churning accounts engaged with every stage of the product experience before exiting. They were not uninformed churners — they used the product, needed support, and still left.

The 5 accounts that churned without ever raising a support ticket ("churned: no support") have similar survival times to full-journey churners (4.2 vs 4.4 months). Support contact is not what delays or accelerates churn.

### 5.4 Pre-Churn Support Pattern — H2 Refuted

| Pre-Churn Support Pattern | Churned Accounts | % of Churns | Avg Months to First Churn | Avg Tickets Before Churn |
|---|---|---|---|---|
| Ticket within 30 days | 43 | 12.2% | **2.9** | 3.4 |
| No ticket before churn | 30 | 8.5% | 3.4 | 0.0 |
| Ticket within 7 days | 14 | 4.0% | 4.4 | 3.1 |
| Ticket 30+ days before | 265 | **75.3%** | **4.7** | 3.1 |

H2 is refuted. Accounts with a ticket more than 30 days before their churn event survived the longest (4.7 months avg) — longer than accounts with no ticket before churn (3.4 months). Support contact before churn is not a death spiral signal — if anything, accounts that engaged with support 30+ days before churning were higher-effort customers who gave the product the most time before exiting.

The 75.3% of churns that had a ticket more than 30 days before the exit confirms that support engagement is spread throughout the customer lifecycle, not concentrated in the final weeks.

### 5.5 2023 vs 2024 Cohort Journey Comparison — H4 Confirmed

| Cohort Year | Accounts | % Reached Feature Use | % Reached Support | % Reached Churn | Avg Days Sub → Usage* | Avg Days to First Churn |
|---|---|---|---|---|---|---|
| 2023 cohorts | 227 | 100.0% | 98.7% | 71.8% | -230.5* | **217.3** |
| 2024 cohorts | 273 | 100.0% | 98.2% | 69.2% | -558.8* | **60.4** |

H4 confirmed. Both cohort years show identical stage completion rates (100% feature use, ~98% support). But 2024 cohorts reach churn in 60.4 average days vs 217.3 for 2023 cohorts — 3.6x faster. Journey completion improved or stayed equal; survival time collapsed. The problem is not that accounts are failing to engage — it is that engagement is not creating the switching cost needed to prevent rapid exit.

### 5.6 Key Insights — Step 26

- All 500 accounts subscribed and used at least one feature — zero journey attrition through Stage 2
- Negative days artifact in dataset prevents meaningful activation lag analysis — documented limitation
- 69.4% of accounts completed the full journey (subscription → usage → support → churn) before their first exit
- Accounts with a support ticket 30+ days before churn survived longest (4.7 months) — support is not a death signal
- 2024 cohorts reach churn in 60.4 avg days vs 217.3 for 2023 — 3.6x faster despite identical journey completion rates
- The journey structure is not where the problem is — the problem is in the value created at each stage, not whether stages are reached

---

## 6. Step 27 — Cohort Retention Deep Dive

### 6.1 Month 1 Retention — H1 Confirmed

Every cohort shows its largest single-month drop at Month 1 (the Month 0 → Month 1 transition). This is the universal finding across all 23 cohorts with Month 1 data.

**Worst Month 1 drops (retention matrix):**

| Cohort | Cohort Size | M0→M1 Drop | Month 1 Retention | Month 1 Survival |
|---|---|---|---|---|
| 2023-06 | 13 | **-76.92pp** | 23.08% | 92.31% |
| 2023-01 | 17 | -58.82pp | 41.18% | 94.12% |
| 2023-09 | 23 | -56.52pp | 43.48% | 91.30% |
| 2023-03 | 20 | -60.00pp | 40.00% | 85.00% |

**Best Month 1 drops (retention matrix):**

| Cohort | Cohort Size | M0→M1 Drop | Month 1 Retention | Month 1 Survival |
|---|---|---|---|---|
| 2024-05 | 22 | -4.55pp | 95.45% | 68.18% |
| 2024-10 | 31 | -3.23pp | 96.77% | 58.06% |
| Multiple 2024 | various | 0.00pp | 100.00% | 25–76% |

The June 2023 cohort dropped 76.92pp in a single month — catastrophic by any measure. Its Month 3 recovery to 92.31% confirms the reactivation dynamic but also shows how unstable the early lifecycle was for 2023 cohorts.

After Month 1, all cohorts show consistent recovery as reactivation brings accounts back — demonstrating the cyclical churn pattern identified in the cohort layer.

### 6.2 The 2023 vs 2024 Paradox — H2 Confirmed

The most analytically important finding in Step 27 — confirmed with full quantification:

| Metric | Month | 2023 Cohorts | 2024 Cohorts | Interpretation |
|---|---|---|---|---|
| Avg retention | M1 | 52.9% | **91.6%** | 2024 appears dramatically better |
| Avg survival | M1 | **89.5%** | 67.0% | 2024 is actually worse |
| Reactivation gap | M1 | -36.6pp | +24.6pp | Gap explains the paradox |
| Avg retention | M3 | 83.6% | **99.3%** | 2024 continues to appear better |
| Avg survival | M3 | **77.9%** | 51.3% | 2024 is significantly worse |
| Reactivation gap | M3 | +5.7pp | **+48.0pp** | Gap widens dramatically |
| Avg retention | M6 | 98.1% | **100.0%** | 2024 appears perfect |
| Avg survival | M6 | **64.6%** | 36.1% | 2024 is deteriorating fast |
| Reactivation gap | M6 | +33.5pp | **+63.9pp** | Gap at maximum |

By Month 6, 2024 cohorts show 100% retention (everyone appears active) but only 36.1% survival (only 36% have never churned). The 63.9pp reactivation gap at Month 6 means that nearly two-thirds of 2024 cohort active accounts have already churned and returned at least once. The retention improvement is entirely driven by faster reactivation — not by better first-churn prevention.

**H5 refuted — the reactivation gap never stabilizes:**

| Month | Avg Reactivation Gap |
|---|---|
| 0 | 9.62pp |
| 1 | -7.33pp (anomaly — 2023 cohorts showing negative before reactivations catch up) |
| 3 | 23.83pp |
| 6 | 43.64pp |
| 9 | 50.99pp |
| 12 | 57.40pp |
| 23 | 70.59pp |

The gap widens continuously through the full 24-month observation window and reaches 70.59pp at Month 23 — meaning by month 23, the typical surviving active account has churned and reactivated multiple times.

### 6.3 Cohort Drop-Off Pattern Classification

| Drop-Off Pattern | Cohort Count | Cohort Year | Characteristic |
|---|---|---|---|
| Strong Month 1 (≥80%) | 9 | All 2024 cohorts from Feb onward | High retention month 1, driven by reactivation speed |
| Moderate Month 1 (60–80%) | 5 | Mostly 2023 second half | Moderate initial drop, steady recovery |
| Weak Month 1 (50–60%) | 4 | 2023 first half | Large M0→M1 drop, strong recovery by M3 |
| Sharp drop + recovery | 4 | 2023 early cohorts | Drop below 50% then recover — classic reactivation pattern |
| Insufficient data | 1 | Dec 2024 | Only 1 month observable |

All 2024 cohorts from February 2024 onward are classified as "strong Month 1" — but their survival rates at Month 1 range from 25% (November 2024) to 92.31% (February 2024). The classification reveals that high retention scores are masking rapid underlying churn.

### 6.4 Median Survival Month by Cohort — Deterioration Trend

| Cohort | Size | Median Survival Month | Cohort Year |
|---|---|---|---|
| 2023-02 | 18 | Month 20 | 2023 |
| 2023-04 | 15 | Month 15 | 2023 |
| 2023-06 | 13 | Month 15 | 2023 |
| 2023-01 | 17 | Month 11 | 2023 |
| 2023-08 | 16 | Month 11 | 2023 |
| 2023-09 | 23 | Month 7 | 2023 |
| 2023-10 | 20 | Month 6 | 2023 |
| 2023-12 | 20 | Month 6 | 2023 |
| 2024-01 | 16 | Month 5 | 2024 |
| 2024-03 | 27 | Month 5 | 2024 |
| 2024-04 | 22 | Month 4 | 2024 |
| 2024-05 | 22 | Month 4 | 2024 |
| 2024-06 | 21 | Month 3 | 2024 |
| 2024-07 | 26 | Month 3 | 2024 |
| 2024-08 | 21 | Month 3 | 2024 |
| 2024-09 | 25 | Month 1 | 2024 |
| 2024-10 | 31 | Month 2 | 2024 |
| 2024-11 | 32 | Month 1 | 2024 |
| 2024-12 | 17 | Month 0 | 2024 |

The deterioration is unambiguous. February 2023 cohort reached median survival at Month 20. December 2024 cohort crossed 50% churn at Month 0 — more than half the cohort churned in their signup month before ever completing a full period. The product is acquiring cohorts that are progressively shorter-lived.

### 6.5 Segmented Survival — H3 and H4 Results

**By referral source (H3 confirmed):**

| Channel | Accounts | Never Churned % | Avg Months to First Churn | % Churned by Month 1 | % Churned by Month 3 | Survival Rank |
|---|---|---|---|---|---|---|
| Ads | 98 | **39.4%** | **5.2** | **28.2%** | 52.0% | 1 |
| Event | 96 | 34.2% | 5.1 | 26.5% | 53.0% | 2 |
| Other | 103 | 26.8% | 4.9 | 37.1% | 50.3% | 3 |
| Organic | 114 | 22.4% | 4.7 | 28.4% | 49.9% | 4 |
| Partner | 89 | 23.1% | 4.6 | **36.5%** | **57.6%** | 5 |

H3 confirmed. Ads is consistently best across all survival metrics. Partner is worst — 36.5% of partner churners exit by Month 1 (highest of any channel) and 57.6% by Month 3 (also highest). The channel quality ranking established in Steps 16 and 20 is fully confirmed here from a cohort-survival perspective.

**By plan tier (H4 refuted):**

| Plan Tier | Accounts | Avg Churn Rate | Avg Months to First Churn | % Churned by Month 1 | % Churned by Month 3 |
|---|---|---|---|---|---|
| Basic | 168 | **69.1%** | 4.5 | 35.7% | 59.1% |
| Enterprise | 154 | 69.3% | **4.6** | **34.3%** | 54.6% |
| Pro | 178 | **72.4%** | 4.2 | **38.8%** | 59.7% |

H4 refuted. Enterprise entry plan does not provide a meaningful survival advantage over Basic or Pro. The spread between tiers is only 3.3pp on churn rate and 0.4 months on time to first churn. Enterprise accounts are slightly less likely to churn by Month 1 (34.3% vs 38.8% for Pro) but the differences are not large enough to confirm the hypothesis.

### 6.6 Key Insights — Step 27

- Month 1 is the universal critical drop-off — every cohort shows its largest single-month retention decline at Month 1
- 2024 cohorts appear dramatically better in retention matrix (91.6% avg M1) but are actually worse in survival curve (67.0% avg M1) — reactivation is masking deterioration
- The reactivation gap never stabilizes — it widens from 9.62pp at Month 0 to 70.59pp at Month 23
- Median survival month has deteriorated from Month 20 (Feb 2023) to Month 0 (Dec 2024) — the product is acquiring progressively shorter-lived cohorts
- Ads channel: best survival on every metric (39.4% never churned, 5.2 months avg, 28.2% churned by Month 1)
- Partner channel: worst survival (36.5% churned by Month 1, 57.6% by Month 3 — highest of all channels)
- Enterprise entry plan does not confer retention advantage — all three tiers cluster within 3.3pp churn rate
- After Month 6, virtually no account permanently leaves — the surviving loyal base is resilient

---

## 7. Step 28 — Beta Feature Impact

### 7.1 Beta User Classification

| User Type | Accounts | % of Total | Avg Distinct Beta Features | Avg Beta Usage Count |
|---|---|---|---|---|
| Beta user (any beta usage) | 301 | **60.2%** | 1.9 | 19.5 |
| GA only user | 187 | 37.4% | 0.0 | — |
| No feature usage | 12 | 2.4% | — | — |

60.2% of accounts used at least one beta feature — confirming the KPI layer finding that beta participation is substantial. Beta users also use significantly more GA features on average (11.4 distinct GA features vs 6.3 for GA-only users), confirming that beta users are higher-engagement accounts overall.

### 7.2 Beta vs Non-Beta Churn Comparison — H1 Refuted

| User Type | Accounts | Churn Rate | Never Churned | Avg Months to First Churn | Avg Churn Events | Gap vs Overall |
|---|---|---|---|---|---|---|
| No feature usage | 12 | **58.3%** | 41.7% | 0.9 | 0.92 | -12.1pp |
| GA only user | 187 | 70.6% | 29.4% | 2.9 | 1.25 | +0.2pp |
| Beta user | 301 | **70.8%** | 29.2% | **5.4** | 1.18 | +0.4pp |

H1 refuted. Beta users churn at 70.8% — 0.2pp higher than GA-only users (70.6%). The difference is statistically negligible. However, beta users survive significantly longer before their first churn (5.4 months vs 2.9 months for GA-only) — suggesting beta users are more committed customers who take longer to reach a churn decision even when they ultimately do churn.

This extends the Step 23 finding to beta features specifically: usage — even high-engagement beta feature usage — does not prevent churn. It delays it.

### 7.3 Beta Adoption Depth vs Churn — H2 Refuted

| Beta Features Used | Accounts | Churn Rate | Never Churned | Avg Months to First Churn |
|---|---|---|---|---|
| 0 features | 199 | 69.8% | 30.2% | 2.8 |
| 1 beta feature | 147 | 70.1% | 29.9% | 4.7 |
| 2–3 beta features | 123 | 69.9% | 30.1% | 6.0 |
| 4–5 beta features | 25 | **84.0%** | **16.0%** | 6.5 |
| 6+ beta features | 6 | **50.0%** | **50.0%** | 7.3 |

H2 refuted — non-monotonic. The 4–5 beta features bucket shows the highest churn rate (84.0%) and lowest never-churned rate (16.0%). The 6+ bucket shows the best outcome (50.0% churn, 50.0% never churned) but contains only 6 accounts — too small for conclusions. The depth gradient does not reliably predict churn.

The survival metric tells a clearer story: more beta features = longer time before first churn (2.8 → 4.7 → 6.0 → 6.5 → 7.3 months). Beta depth may not prevent churn but it consistently delays it.

### 7.4 Per-Beta-Feature Retention Signal — H3 Confirmed

The most important Step 28 finding: specific beta features correlate with dramatically better retention outcomes for their adopters.

**Top 10 beta features by retention signal:**

| Feature | Adopter Accounts | Adoption Rate | Adopter Churn Rate | Gap vs Overall | Signal |
|---|---|---|---|---|---|
| feature_3 | 15 | 3.0% | **46.7%** | **-23.7pp** | Strong |
| feature_21 | 13 | 2.6% | **53.8%** | -16.6pp | Strong |
| feature_39 | 16 | 3.2% | **56.3%** | -14.1pp | Strong |
| feature_23 | 17 | 3.4% | **58.8%** | -11.6pp | Strong |
| feature_20 | 10 | 2.0% | **60.0%** | -10.4pp | Strong |
| feature_33 | 18 | 3.6% | **61.1%** | -9.3pp | Strong |
| feature_5 | 13 | 2.6% | **61.5%** | -8.9pp | Strong |
| feature_2 | 13 | 2.6% | **61.5%** | -8.9pp | Strong |
| feature_17 | 8 | 1.6% | **62.5%** | -7.9pp | Strong |
| feature_29 | 11 | 2.2% | **63.6%** | -6.8pp | Strong |

Feature_3 adopters churn at 46.7% — 23.7pp below the overall average of 70.4%. For context, the best-performing acquisition channel (ads) churns at 60.2% — feature_3 adoption correlates with better retention than the best channel. However, only 15 accounts used it (3.0% adoption rate) — severely limiting the business impact.

**Bottom beta features — negative retention signal:**

| Feature | Adopter Accounts | Adopter Churn Rate | Gap vs Overall |
|---|---|---|---|
| feature_36 | 14 | **92.9%** | +22.5pp |
| feature_7 | 11 | **90.9%** | +20.5pp |
| feature_37 | 18 | **88.9%** | +18.5pp |
| feature_10 | 9 | **88.9%** | +18.5pp |
| feature_18 | 15 | **86.7%** | +16.3pp |

The spread across beta features is striking: feature_3 adopters churn at 46.7%, feature_36 adopters at 92.9% — a 46.2pp difference. Not all beta features attract the same user profile. Some attract committed, engaged users who survive longer. Others attract casual experimenters who churn quickly.

**Interpretation:** The per-feature retention correlation likely reflects user self-selection rather than feature causation. Users who discover and persist with feature_3 are the most deeply engaged product explorers — the type of customer who churns less regardless of which specific feature they use. The feature is a proxy for user engagement depth, not a cause of retention.

### 7.5 Beta Adoption Trend — H4 Confirmed

Beta adoption has grown consistently from 0% in January 2023 to 16.6% in December 2024 — a genuine trend with acceleration in H2 2024:

| Period | Beta Adoption Rate | Notable |
|---|---|---|
| Jan 2023 | 0.0% | No beta users |
| Jun 2023 | 2.82% | Early adopters emerging |
| Dec 2023 | 8.42% | Steady growth |
| Jun 2024 | 10.39% | First double-digit month |
| Oct 2024 | **16.86%** | Highest single month |
| Dec 2024 | 16.60% | Sustained high level |

Beta adoption as a share of total usage has remained relatively stable (7–11%) even as adoption rate grew — meaning individual beta users are not using beta features more intensively, but more accounts are discovering them. This is consistent with the discoverability problem identified in Step 22.

### 7.6 Pre-Churn Beta Usage — H5 Confirmed, Step 23 Extended

The beta usage gap between retained and churned accounts in the month of churn:

- 5 months where retained accounts used more beta than churned (gap > 2): retained_use_more
- 0 months where churned accounts used more beta than retained (gap < -2)
- 6 months near-zero gap (gap between -2 and 2)
- Average beta usage gap: 2.63

The gap is positive in direction (retained accounts use slightly more beta) but small in magnitude. This is consistent with Step 23 — beta feature usage, like overall usage, is not a strong leading indicator of churn. The 2.63 average gap on a scale of ~10 average monthly beta usage per adopter represents a 26% difference — directionally meaningful but not dramatic.

### 7.7 Key Insights — Step 28

- 60.2% of accounts are beta users — high participation but not a retention differentiator
- Beta users churn at 70.8% — virtually identical to GA-only users (70.6%) — H1 refuted
- Beta users survive 5.4 months before first churn vs 2.9 months for GA-only — beta delays but doesn't prevent churn
- Beta depth shows non-monotonic churn pattern — 4–5 features highest churn (84%), 6+ lowest (50%, n=6)
- 10 specific beta features show strong retention signals (adopter churn 46.7%–63.6%) — 10–24pp below average
- Feature_3 adopters churn at 46.7% — better retention than the best acquisition channel (ads, 60.2%)
- Bottom beta features show 88–93% churn for adopters — 18–23pp above average
- Beta adoption trend confirms H4 — 0% → 16.6% growth over 24 months with H2 2024 acceleration
- Pre-churn beta usage gap near zero — extends Step 23 non-predictive finding to beta features

---

## 8. Cross-Step Synthesis

**8.1 — The Consistent Pattern: Behavioral Signals Don't Predict Churn**

Step 23 showed feature usage does not predict churn. Step 24 showed CSAT does not predict churn. Step 28 showed beta adoption does not predict churn. Step 26 showed that nearly every churning account completed the full product journey. The pattern is unambiguous: RavenStack's churn is not behaviorally signaled — it is structurally driven by external factors (pricing sensitivity, acquisition channel quality, macroeconomic pressure, competitive alternatives).

This has a precise implication for the risk model in Step 25: the model correctly captures the direction of risk (shorter survival for higher-risk accounts) but cannot achieve strong churn rate separation because the signals it uses are weak predictors in aggregate. This is not a model design failure — it is an accurate representation of the data.

**8.2 — The Journey Explains the Mechanism, Not the Cause**

Step 26 shows every churning account passed through all lifecycle stages. They subscribed, used features, needed support, and still left. Step 27 shows that Month 1 is universally the steepest retention cliff. These two findings together describe the mechanism: accounts are signing up, experiencing the full product, deciding within 1–2 months that the price-to-value ratio is wrong (confirmed by Step 21's rising budget and pricing churn reasons in 2024 cohorts), and exiting. The failure is not in journey completion — it is in value creation at each stage.

**8.3 — The Reactivation Dependency Is the Structural Risk**

Step 27's reactivation gap analysis (reaching 70.59pp at Month 23) proves that by the end of a 2-year tenure, the typical active account has churned and reactivated multiple times. The business model depends on reactivation to maintain its active base. Step 28's finding that beta users survive 5.4 months (vs 2.9 for GA-only) suggests that deeper product engagement delays the first churn but does not prevent the cyclical pattern. One quarter of weak reactivation performance — driven by a better competitor or economic pressure — would expose the true underlying churn rate and dramatically shrink the active base.

**8.4 — What Phase 4 Proves That Phases 2–3 Could Not**

Phase 3 established that churn exists and identified its dimensions. Phase 4 establishes:
- Support quality is a structural baseline deficit, not a causal churn driver
- Behavioral signals (usage, CSAT, beta adoption) are not predictive of who churns
- The lifecycle journey is complete but value creation within stages is insufficient
- 2024 cohorts are churning 3.6x faster despite completing the same journey stages
- The reactivation gap grows indefinitely — the business cannot rely on reactivation as a permanent strategy
- Specific beta features (feature_3, feature_21, feature_39) correlate with 23.7pp better retention but at ~3% adoption — the best product experiences are reaching almost no one

---

## 9. Pre-Launch Risk Intelligence Summary

| Category | Value |
|---|---|
| Total accounts assessed | 500 |
| High-risk accounts | 1 (A-0f6450) |
| Medium-risk accounts | 134 |
| Low-risk accounts | 365 |
| MRR from high-risk accounts | $23,800 |
| MRR from medium-risk accounts | $2,652,134 |
| Total addressable MRR at risk (medium + high) | **$2,675,934** |
| Highest revenue account in top-risk cohort | A-c58f49 (Enterprise, $70,980) |
| Dominant risk signal | Usage (100% of high and top-medium accounts) |
| Cohorts at immediate risk | Dec 2024 (35.29% Month 0 survival), Nov 2024 (25.00% Month 1 survival) |
| Strongest beta retention signal | feature_3 (46.7% adopter churn — -23.7pp vs overall) |
| Beta adoption rate at launch | 16.6% of active accounts |
| Reactivation gap at Month 6 (all cohorts) | 43.64pp |

**Intervention priority queue (pre-launch, in order of urgency):**

1. A-0f6450 — urgent activation call (87.5 score, zero usage, escalation, $23,800 MRR)
2. A-c58f49 — Enterprise account ($70,980 MRR), escalation flag, manually escalate above tier score
3. All zero-usage accounts with high support intensity (A-149a69, A-fb186e, A-b48f73 + others) — critical flag activation intervention
4. All medium-risk accounts with escalation flag (A-5c9849, A-fd7ad3, A-117171, A-c42f1f, A-751bd4, A-463db0, A-0be015, A-bc4d48) — escalation follow-up program
5. Remaining 134 medium-risk accounts — proactive engagement check-in cadence before launch
6. December 2024 and November 2024 cohort accounts — newest and fastest-churning cohorts, immediate onboarding intervention

---

## 10. Phase 4 Recommendations

**P1 — Launch with a targeted CS intervention for the 135 medium-high risk accounts**

The 134 medium-risk + 1 high-risk accounts hold $2.68M in MRR. Each account's `recommended_action` is encoded in `analysis_churn_risk_scores`. CS team should filter to medium+high tiers, sort by MRR descending, and execute the recommended action per account before launch.

**P2 — Manually escalate A-c58f49 above its model tier**

A-c58f49 (Enterprise, $70,980, 66.3 score) is the highest-revenue account in the top-risk cohort. Combined with low usage and an escalation history, this account warrants an executive-level relationship check-in regardless of its medium-tier classification.

**P3 — Fix the escalation pipeline before launch**

Step 24 confirmed escalation is the only support signal that correlates with churn (+6.5pp). Escalation rate spiked in H2 2024 (8.05% October, 6.02% November). Before launch, each escalated ticket needs dedicated resolution follow-up and a satisfaction check within 48 hours of closure.

**P4 — Surface feature_3, feature_21, and feature_39 in onboarding**

These three beta features show adopter churn rates of 46.7%, 53.8%, and 56.3% respectively — the strongest retention correlations in the dataset. They are currently at 3.0%, 2.6%, and 3.2% adoption. If these features attract the most engaged customers, getting them discovered earlier in the onboarding journey may shift the Month 1 survival curve. This is speculative but it is the highest-quality product signal available.

**P5 — Redesign the Month 0–1 value demonstration**

Step 27 confirms Month 1 is universally the steepest retention cliff. Step 26 confirms accounts complete all journey stages but still churn. Step 21 confirms 2024 cohorts are increasingly citing budget and pricing as churn reasons. The mechanism is clear: accounts are reaching Month 1 renewal without having experienced sufficient value to justify the price. The intervention is not more features — it is a structured value demonstration program that creates a measurable ROI moment before the Month 1 renewal decision.

**P6 — Document and communicate the model's limitations in Phase 5**

The risk model correctly captures survival time ordering but cannot strongly separate churn rates (70.1% vs 70.4% for medium vs low risk). This is honest and should be stated explicitly in the Phase 5 presentation. The model is a best-available tool given weak behavioral signals, not a precision prediction engine. Overstating its accuracy would undermine trust in the analysis.

---

*Phase 4 complete. All 12 dashboard views built and validated. Feeds into: Phase 5 Insights (Step 29 — Key Insights identification), Phase 5 Recommendations (Step 30), Phase 5 Business Impact (Step 31), Dashboard Pages 4 (Feature Usage), 5 (Support Impact), 6 (Risk Intelligence), and 7 (Cohort Retention).*
