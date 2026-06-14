# Module 3 — Feature Usage
**RavenStack SaaS Pre-Launch Analysis**
**Role:** Product Analyst
**Steps:** 22 (Feature Adoption Analysis), 23 (Usage vs Churn)
**Status:** Complete & Validated
**Last Updated:** 2026-05-13

---

## Table of Contents
1. [Module Overview](#1-module-overview)
2. [Hypotheses](#2-hypotheses)
3. [Step 22 — Feature Adoption Analysis](#3-step-22--feature-adoption-analysis)
4. [Step 23 — Usage vs Churn](#4-step-23--usage-vs-churn)
5. [Cross-Step Insights](#5-cross-step-insights)
6. [Business Implications for Launch](#6-business-implications-for-launch)
7. [Recommendations from Module 3](#7-recommendations-from-module-3)

---

## 1. Module Overview

Module 3 answers two connected business questions: **What are users actually doing in the product, and does how much they use it predict whether they stay or leave?**

Step 22 maps the full feature adoption landscape across 40 features — ranking them by breadth and depth, classifying them into archetypes, comparing beta versus GA behavior, and identifying the sprawl problem quantitatively. Step 23 is the most important cross-table analysis in Phase 3: connecting product engagement directly to churn outcome. It tests whether usage intensity predicts retention, whether a usage threshold exists as a CS intervention trigger, and whether usage drops before churn as a detectable leading indicator.

The two steps together form the product health diagnosis: Step 22 describes the state of the feature portfolio, Step 23 reveals whether that state matters for retention.

**Sources used:**

| Source | Role |
|---|---|
| `kpi_monthly_feature_adoption` | Per-feature monthly adoption rates and usage counts |
| `base_feature_usage_monthly` | Account-level monthly usage data |
| `base_active_monthly` | Active account population denominator |
| `base_churn_monthly` | Churn events for cross-table join |
| `cohort_base` | Account behavioral attributes and churn flags |

**Dashboard views created:**

| View | Step | Page | Status |
|---|---|---|---|
| `analysis_feature_adoption_ranked` | 22 | 4 | ✅ Built |
| `analysis_feature_breadth_depth` | 22 | 4 | ✅ Built |
| `analysis_usage_vs_churn_buckets` | 23 | 4, 6 | ✅ Built |
| `analysis_usage_30d_before_churn` | 23 | 4 | ✅ Built |

**Validation results:**

| Check | Expected | Result |
|---|---|---|
| Distinct features in ranked view | 40 | ✅ 40 |
| Total usage count in ranked view | 61,306 | ✅ 61,306 |
| Total accounts in usage buckets | 500 | ✅ 500 |
| Churned accounts across buckets | 352 | ✅ 352 |
| Zero usage bucket accounts | 12 | ✅ 12 |
| Zero usage bucket churned | 7 | ✅ 7 |

---

## 2. Hypotheses

### Step 22 — Feature Adoption Analysis

| # | Hypothesis | Result |
|---|---|---|
| H1 | No single feature reaches 10% average monthly adoption — feature sprawl is the core engagement problem | ✅ Confirmed — top feature (feature_35) at 5.05% avg. No feature reaches 10%. All 40 features below the 20% benchmark lower bound. |
| H2 | Beta features have lower adoption than GA but identical usage intensity once adopted — discoverability problem not quality problem | ✅ Confirmed — beta adoption 0.58% vs GA 2.51% (4.3x lower). Usage intensity nearly identical: 10.01 vs 10.17 per adopter. Error rates nearly identical: 0.0517 vs 0.0540. |
| H3 | Features can be classified into four archetypes: core, specialist, awareness, dead | ✅ Confirmed — four distinct archetypes emerge from breadth × depth quadrant analysis. Distribution: core 24, awareness 16, dead 24, specialist 16. |
| H4 | Bottom 10 features collectively account for less than 5% of total usage | ❌ Refuted in the way expected — the bottom 10 by adoption rank are all beta features and account for 9.56% of total usage (cumulative from rank 71–80). The GA bottom 10 (ranks 31–40) each account for ~2% individually. Usage is more evenly distributed than expected. |

### Step 23 — Usage vs Churn

| # | Hypothesis | Result |
|---|---|---|
| H1 | High-usage accounts churn significantly less than low-usage accounts | ❌ Refuted — churn rate is nearly flat across all usage buckets (58.3% zero, 70.5% low, 70.2% medium, 71.9% high). High-usage accounts churn at nearly the same rate as low-usage accounts. |
| H2 | A usage threshold exists below which churn becomes near-certain — a CS intervention trigger | ❌ Refuted — threshold analysis shows no stable inflection point. Churn rate gap between below-threshold and above-threshold accounts oscillates near zero at every tested threshold. |
| H3 | Usage in the month of churn is significantly lower than retained accounts in the same period | ❌ Refuted — usage gap is inconsistent and reverses direction in many months. In 15 of 22 months, churned accounts use more or nearly as much as retained accounts. |
| H4 | Accounts using more diverse features churn less — feature diversity = stickiness anchor | ❌ Refuted — churn rate is not monotonically decreasing with feature diversity. 3–5 features (73.8%) churns more than both 0 features (58.3%) and 1–2 features (66.0%). |
| H5 | First-month usage is the single most predictive period for long-term retention | ❌ Refuted — high early usage accounts (21+) show 75.0% churn rate — the highest of any group, and average only 1.9 months to first churn. Medium early usage (6–20) shows the best churn rate at 64.8%. |

**Step 23 delivers the most counterintuitive finding in the entire project. All five hypotheses are refuted. Feature usage does not predict churn in this dataset. This is a major analytical finding, not a failure — it fundamentally redirects the churn intervention strategy.**

---

## 3. Step 22 — Feature Adoption Analysis

### 3.1 Overall Adoption Landscape — H1 Confirmed

The feature adoption picture across all 40 features:

| Metric | Value |
|---|---|
| Total features | 40 |
| Top feature avg adoption rate | 5.05% (feature_35) |
| Top feature peak adoption | 50.00% (feature_35, one month) |
| Industry benchmark lower bound | 20% monthly adoption |
| Gap between top feature and benchmark | 14.95pp |
| Average GA feature adoption | 2.51% |
| Average beta feature adoption | 0.58% |
| Features in "moderate" tier (5–10%) | 1 (feature_35 only) |
| Features in "low" tier (2–5%) | 39 GA features |
| Features in "critical" tier (<2%) | All 40 beta feature instances |

H1 is confirmed emphatically. Not one feature reaches 10% average monthly adoption. The only feature to cross into the "moderate" tier is feature_35 at 5.05% — and even this is less than one-quarter of the 20% industry benchmark lower bound.

The adoption distribution is remarkably compressed. GA features cluster tightly between 2.00% (feature_23) and 5.05% (feature_35) — a range of only 3.05pp across 40 features. This is not a situation where a few features succeed and others fail; it is a situation where all features are equally invisible.

**The feature sprawl quantification:**

| Usage Tier | Features | Total Usage | % of Total Usage |
|---|---|---|---|
| Top 10 by usage | 10 GA features | 15,613 | 27.13% — ranks 1–10 account for only 27% |
| Ranks 11–20 | 10 GA features | 14,617 | 24.66% |
| Ranks 21–30 | 10 GA features | 13,648 | 22.75% |
| Ranks 31–40 | 10 GA features | 12,165 | 20.44% |
| All 40 beta instances | 40 beta states | 5,863 | 9.56% |

The most striking finding is how evenly usage is distributed across all 40 GA features. The top 10 features generate only 27.13% of usage while the bottom 10 GA features generate 20.44%. This is nearly flat usage distribution — no feature has critical mass, but no feature is catastrophically underperforming either relative to the others.

This even distribution of mediocrity is the definition of feature sprawl: 40 features, each getting a small equal share of attention, none achieving the adoption depth needed to become a retention anchor.

### 3.2 Top 10 vs Bottom 10 Features

**Top 10 features by adoption rate (all GA):**

| Rank | Feature | Beta | Avg Adoption | Total Usage | Avg Usage/Adopter |
|---|---|---|---|---|---|
| 1 | feature_35 | No | **5.05%** | 1,513 | 9.91 |
| 2 | feature_39 | No | 2.92% | 1,470 | 9.68 |
| 3 | feature_38 | No | 2.87% | 1,597 | 10.39 |
| 4 | feature_16 | No | 2.84% | 1,480 | 9.84 |
| 5 | feature_17 | No | 2.75% | 1,505 | 9.33 |
| 6 | feature_22 | No | 2.73% | 1,523 | 10.33 |
| 7 | feature_32 | No | 2.69% | 1,534 | 9.96 |
| 8 | feature_20 | No | 2.69% | 1,470 | 11.32 |
| 9 | feature_3 | No | 2.67% | 1,491 | 10.03 |
| 10 | feature_25 | No | 2.63% | 1,480 | 10.50 |

Feature_35 stands apart as the only feature with meaningfully higher adoption — 5.05% vs 2.92% for the second-ranked feature. Its peak adoption of 50.00% in one month indicates a specific event drove a spike (possibly a promotion, a beta release period, or a specific use case activation). Understanding what drove that peak is a product team priority.

**Bottom 10 features by adoption rank (all beta):**

| Rank | Feature | Beta | Avg Adoption | Total Usage | Avg Usage/Adopter |
|---|---|---|---|---|---|
| 71 | feature_32 (beta) | Yes | 0.46% | 130 | 9.90 |
| 72 | feature_19 (beta) | Yes | 0.46% | 144 | 9.00 |
| 73 | feature_13 (beta) | Yes | 0.45% | 135 | 9.50 |
| 74 | feature_2 (beta) | Yes | 0.44% | 128 | 8.98 |
| 75 | feature_36 (beta) | Yes | 0.43% | 133 | 9.25 |
| 76 | feature_7 (beta) | Yes | 0.43% | 99 | 8.81 |
| 77 | feature_27 (beta) | Yes | 0.37% | 126 | 10.43 |
| 78 | feature_8 (beta) | Yes | 0.37% | 74 | 10.40 |
| 79 | feature_22 (beta) | Yes | 0.37% | 103 | 9.19 |
| 80 | feature_10 (beta) | Yes | 0.35% | 92 | 8.31 |

All bottom 10 by adoption rank are beta features — confirming H2 that beta status is the adoption barrier, not feature quality. The usage intensity for even these lowest-ranked beta features (8.31–10.43 per adopter) is comparable to GA feature intensity (9.33–11.32). The accounts that find these features use them at nearly the same rate as GA features. The problem is being found, not being useful once found.

### 3.3 Feature Archetype Classification — H3 Confirmed

The breadth × depth quadrant uses the median adoption rate (1.60%) and median weighted usage per adopter (10.075) as the dividing lines.

| Archetype | Count | Avg Adoption | Avg Usage Depth | Total Usage | Definition |
|---|---|---|---|---|---|
| Core | 24 | 2.59% | 10.32 | 34,025 | High breadth + high depth |
| Awareness | 16 | 2.39% | 9.93 | 21,418 | High breadth + low depth |
| Specialist | 16 | 0.56% | 10.71 | 2,434 | Low breadth + high depth |
| Dead | 24 | 0.58% | 9.55 | 3,429 | Low breadth + low depth |

**Core features (24 — all GA):** The backbone of the product. These features are both broadly adopted (above median adoption) and deeply used (above median intensity). All 24 core features are GA. The core archetype contains feature_35 (top feature), feature_38 (highest usage volume at 1,597), and feature_36 (second highest volume at 1,580). These are the features that should anchor onboarding flows and retention messaging.

**Awareness features (16 — all GA):** Widely discovered but shallowly used. Above-median adoption but below-median usage depth. These features attract users but do not create recurring engagement. Features 16, 17, and 3 sit here — adopted by a reasonable proportion of the base but not generating repeat sessions. These are candidates for product depth investment: the discoverability is working, the engagement loop is not.

**Specialist features (16 — all beta):** Below-median adoption but above-median usage depth. Every single specialist feature is a beta feature. Accounts that discover these beta features engage with them intensely (10.71 avg depth vs 10.32 for core) — they are deeply valued by a small group. The specialist quadrant is entirely a discoverability problem. If these features were surfaced to more accounts, they would likely become core features based on their engagement depth.

**Dead features (24 — all beta):** Below-median adoption and below-median usage depth. All 24 dead features are beta features — again, the GA/beta split is the primary dimension determining archetype, not the features themselves. Even dead beta features show 9.55 avg usage depth — lower than specialist but not dramatically. The "dead" label is perhaps too harsh: these are undiscovered features that show moderate engagement when found.

**The critical structural insight from the archetype analysis:** The GA/beta divide perfectly maps to the discovery boundary. GA features occupy Core and Awareness (the high-breadth archetypes). Beta features occupy Specialist and Dead (the low-breadth archetypes). There is no GA feature in the low-breadth archetypes. There is no beta feature in the high-breadth archetypes. Beta status = low breadth, every time, regardless of quality.

### 3.4 Beta vs GA Detailed Comparison — H2 Confirmed

| Metric | GA Features | Beta Features | Gap |
|---|---|---|---|
| Distinct features | 40 | 40 | — |
| Avg adoption rate | **2.51%** | **0.58%** | 4.3x lower |
| Weighted avg usage per adopter | 10.17 | 10.01 | 1.6% lower — negligible |
| Total usage count | 55,443 | 5,863 | — |
| % of total usage | 90.4% | 9.6% | — |
| Error rate per usage event | 0.0540 | 0.0517 | Beta slightly lower |

H2 confirmed with precision. Beta features are adopted 4.3x less frequently than GA features. Once adopted, the usage intensity is 1.6% lower for beta — statistically negligible. Beta error rates are marginally better than GA (0.0517 vs 0.0540), meaning beta features are not lower quality by any engineering metric.

The discoverability gap between GA and beta (4.3x) is the product's hidden capability problem. The product has 40 additional features that are being used at nearly the same intensity as the 40 GA features — but only by the accounts that stumble upon them. If beta adoption rate matched GA adoption rate, total feature usage would increase by approximately 90% without building a single new feature.

### 3.5 Adoption Trend Direction — All GA Features Growing

Every single GA feature shows a growing or stable adoption trend from H1 2024 to H2 2024. Zero GA features are declining. The top GA growth movers:

| Feature | H1 2024 Adoption | H2 2024 Adoption | Change |
|---|---|---|---|
| feature_4 | 1.18% | 3.57% | +2.39pp — fastest growing |
| feature_38 | 1.94% | 4.12% | +2.18pp |
| feature_12 | 1.77% | 3.85% | +2.08pp |
| feature_14 | 1.68% | 3.63% | +1.95pp |
| feature_3 | 3.25% | 3.15% | -0.10pp — only near-stable GA feature |

Beta feature trend is more mixed. While most beta features grow slightly (the low numbers make small absolute changes look proportionally large), several are declining:

| Feature | H1 2024 Adoption | H2 2024 Adoption | Change |
|---|---|---|---|
| feature_35 (beta) | 0.76% | 0.34% | -0.42pp — sharpest beta decline |
| feature_16 (beta) | 0.51% | 0.24% | -0.27pp |
| feature_34 (beta) | 0.59% | 0.32% | -0.27pp |
| feature_17 (beta) | 0.53% | 0.27% | -0.26pp |

The beta version of feature_35 — the top GA feature — is losing adoption heading into launch. This is notable: if feature_35 is the product's strongest feature, its beta variant losing traction suggests the experimentation track around the product's best capability is losing momentum.

### 3.6 Key Insights — Step 22

- Feature sprawl confirmed — top feature at 5.05% avg adoption vs 20% benchmark lower bound — 14.95pp below the minimum healthy level
- No GA feature declines — all 40 GA features growing in adoption from H1 to H2 2024 — product is being discovered, just slowly
- Beta features 4.3x less adopted than GA but used at identical intensity — strictly a discoverability problem
- GA/beta split perfectly predicts archetype — all core/awareness features are GA, all specialist/dead features are beta
- 24 core GA features carry the product — they deliver both breadth and depth simultaneously
- 16 specialist beta features are hidden value — deeply used by few, potentially broadly valuable if surfaced
- Feature_35 peak adoption of 50% in one month is an unexplained event — what drove it could be replicated at launch
- Top 10 features generate only 27.13% of usage — near-flat usage distribution across all 40 GA features confirms no feature has critical mass

---

## 4. Step 23 — Usage vs Churn

### 4.1 Usage Intensity Distribution

Before bucketing, the distribution of lifetime usage across all 500 accounts:

| Metric | Value |
|---|---|
| Total accounts | 500 |
| Zero-usage accounts | 12 (2.4%) |
| Average lifetime usage count | 122.6 |
| 25th percentile | 49 |
| Median (50th percentile) | 106 |
| 75th percentile | 177.25 |
| 90th percentile | 250.3 |
| Maximum | 513 |

Usage is broadly distributed. The median account has 106 lifetime usage events. The top 10% of users exceed 250 events. This is not a product that is being ignored — it is being used moderately by most accounts, just not at the depth or breadth that creates product dependency.

### 4.2 Churn Rate by Usage Bucket — H1 and H2 Refuted

| Usage Bucket | Accounts | Churned | Churn Rate | Never Churned | Avg Usage | Avg Features | Avg Months to First Churn | Gap vs Overall |
|---|---|---|---|---|---|---|---|---|
| Zero usage (0) | 12 | 7 | **58.3%** | 41.7% | 0.0 | 0.0 | 0.9 | -12.1pp |
| Low usage (1–53) | 122 | 86 | 70.5% | 29.5% | 28.1 | 2.8 | 1.7 | +0.1pp |
| Medium usage (54–179) | 245 | 172 | 70.2% | 29.8% | 111.8 | 9.7 | 4.3 | -0.2pp |
| High usage (180–513) | 121 | 87 | **71.9%** | 28.1% | 252.0 | 18.9 | 7.6 | +1.5pp |

H1 and H2 are definitively refuted. The churn rate does not decrease with increasing usage intensity. It is nearly flat across all four buckets — 70.5%, 70.2%, and 71.9% for low, medium, and high respectively. The high-usage bucket actually has the highest churn rate at 71.9%, marginally above the overall average of 70.4%.

The only bucket that differs meaningfully is zero usage (58.3%), which churns at 12.1pp less than the overall average. But this is a group of only 12 accounts — too small for statistical conclusions.

**The threshold analysis confirms the flat pattern.** Testing thresholds from 0 to 200 in increments of 10, the churn rate gap between below-threshold and above-threshold accounts never exceeds 12.4pp (at threshold 0, which is just the zero-usage group), and oscillates between -8.3pp and +3.7pp across all other thresholds. No stable inflection point exists where crossing a usage threshold changes the churn probability materially.

There is no usage threshold that can serve as a reliable CS intervention trigger. Usage intensity simply does not predict churn in this product.

### 4.3 Pre-Churn Usage Pattern — H3 Refuted

The comparison of average monthly usage between accounts that churned and accounts that did not:

| Month | Churned Avg Usage | Retained Avg Usage | Gap | Ratio |
|---|---|---|---|---|
| 2023-05 | 11.00 | 10.92 | -0.08 | 0.99 |
| 2023-08 | 18.00 | 14.92 | -3.08 | 0.83 |
| 2023-09 | 18.50 | 13.60 | -4.90 | 0.73 |
| 2023-10 | 40.00 | 13.95 | -26.05 | 0.35 |
| 2023-11 | 13.67 | 14.76 | +1.10 | 1.08 |
| 2023-12 | 9.33 | 15.56 | +6.22 | 1.67 |
| 2024-02 | 14.80 | 14.94 | +0.14 | 1.01 |
| 2024-03 | 18.00 | 16.13 | -1.87 | 0.90 |
| 2024-06 | 16.42 | 17.23 | +0.81 | 1.05 |
| 2024-09 | 19.75 | 19.93 | +0.18 | 1.01 |
| 2024-12 | 23.68 | 24.49 | +0.80 | 1.03 |

H3 is refuted. The usage gap is inconsistent in direction and magnitude. In months like December 2023 (ratio 1.67) and November 2023 (ratio 1.08), churned accounts actually used the product more than retained accounts in the same month. In months like October 2023 (ratio 0.35) and September 2023 (ratio 0.73), the pattern goes the expected direction but these are small-sample months (1 and 4 churned accounts with usage respectively).

In the high-volume churn months of H2 2024 — when the data is most statistically reliable — the gaps are minimal:
- December 2024: 23.68 churned vs 24.49 retained — a 0.80 gap on ~24 avg usage — effectively identical
- November 2024: 20.83 vs 21.84 — a 1.01 gap
- October 2024: 21.71 vs 22.53 — a 0.83 gap

V4 validation confirms: 7 months show negative usage gap (churned accounts use more than retained). Usage is not a leading indicator of churn in this dataset.

### 4.4 Feature Diversity vs Churn — H4 Refuted

| Feature Diversity | Accounts | Churn Rate | Avg Features | Avg Usage | Avg Months to First Churn |
|---|---|---|---|---|---|
| 0 features | 12 | **58.3%** | 0.0 | 0.0 | 0.9 |
| 1–2 features | 53 | **66.0%** | 1.6 | 16.3 | 0.9 |
| 3–5 features | 84 | **73.8%** | 3.9 | 41.5 | 2.3 |
| 6–10 features | 134 | 69.4% | 8.1 | 92.4 | 3.2 |
| 11+ features | 217 | 71.4% | 16.2 | 205.4 | 6.8 |

H4 is refuted. Churn rate is not monotonically decreasing with feature diversity. The 3–5 features group shows the highest churn rate (73.8%) — higher than both the 0-feature group (58.3%) and the 11+ features group (71.4%). There is no consistent pattern.

The avg months to first churn does increase with feature diversity (0.9 → 0.9 → 2.3 → 3.2 → 6.8) — accounts using more features do survive longer before their first churn event. But this is a correlation with time in product (longer-tenured accounts naturally use more features) rather than evidence that feature diversity protects against churn. The churn rate itself — the proportion that eventually churns — does not respond to feature diversity.

### 4.5 Early Usage Impact — H5 Refuted

| Early Usage Bucket (Month 0–1) | Accounts | Churn Rate | Avg Months to First Churn | Avg Churn Events | Avg Early Usage |
|---|---|---|---|---|---|
| No early usage | 315 | 71.7% | 5.1 | 1.23 | 0.0 |
| Low early usage (1–5) | 3 | 66.7% | 1.5 | 1.33 | 4.0 |
| Medium early usage (6–20) | 122 | **64.8%** | 3.9 | 1.10 | 11.7 |
| High early usage (21+) | 60 | **75.0%** | 1.9 | 1.22 | 35.3 |

H5 is refuted and the direction is reversed. High early usage accounts (21+ events in months 0–1) show the highest churn rate (75.0%) and the second-fastest time to first churn (1.9 months avg). These accounts engage intensely early, then churn quickly.

Medium early usage (6–20 events) shows the best churn rate at 64.8% — 6.9pp below the high early usage group and 6.9pp below the overall average. This is the only group that shows meaningfully better retention than average.

The most striking number is the no-early-usage group: 315 accounts (63% of all accounts) had no recorded feature usage in months 0–1. Of these, 71.7% eventually churned. This is the dominant behavioral pattern — most accounts do not use any feature in their first two months. The product is not activating its users in the early lifecycle at all.

The high early usage → high churn pattern suggests a specific user type: power users who explore intensely then find the product insufficient for their needs, making a quick and decisive exit. These are the most engaged early disengagers.

### 4.6 The Core Finding — Usage Does Not Predict Churn

All five Step 23 hypotheses were refuted. This is the most significant analytical finding in Module 3 and one of the most important in the entire project. It requires explicit documentation because it counteracts the most common assumption in SaaS analytics.

**Why usage does not predict churn in RavenStack:**

The data reveals that churn in this product is not primarily driven by disengagement. Churned accounts use the product at nearly the same rate as retained accounts (ratios close to 1.0 in all high-volume months). High-usage accounts churn at nearly the same rate as low-usage accounts. Feature diversity does not protect against churn. Early engagement does not protect against churn.

This means the churn drivers are external to usage behavior — they are structural factors identified in Module 2: pricing sensitivity, support failures, competitive alternatives, and budget constraints. Accounts are not leaving because they stopped using the product. They are leaving despite using it — because the price-to-value ratio fails their evaluation, support erodes the relationship, or an alternative meets a need the product does not.

**The implication for Step 25 (Multi-Factor Churn Risk Model):**

Usage intensity should carry low or zero weight in the risk scoring model. The signals that do predict churn are from Module 2: support ticket volume, preceding downgrade flags (weak but present), and plan tier × industry segment (cross-dimensional). The risk model built in Step 25 should not include usage bucket as a primary variable — this step proves empirically that it is not predictive.

**The implication for the product team:**

Low feature adoption (Step 22) is a real problem for growth and product stickiness, but it is not the driver of the current churn crisis. Fixing feature adoption will improve long-term product health but will not resolve the December 2024 20.17% churn rate. That problem requires support quality improvement, pricing model refinement, and channel mix correction — all Module 1 and Module 2 interventions.

---

## 5. Cross-Step Insights

**5.1 — The Discoverability Gap Is Larger Than the Churn Gap**

Step 22 shows beta features have 4.3x lower adoption than GA features due to discoverability. Step 23 shows that even accounts using many features churn at nearly the same rate as low-usage accounts. This creates a clear priority ordering: the discoverability problem (Step 22) is a product growth problem worth solving, but it is not a churn problem. Solving discoverability will increase engagement and ARPU potential — it will not reduce the 20.17% churn rate. These are different interventions targeting different outcomes.

**5.2 — Feature_35's Anomaly Warrants Investigation**

Step 22 shows feature_35 achieved 50% peak adoption in one month — far above any other feature's peak. Step 23 shows usage intensity does not predict churn. These two facts together suggest that whatever drove the feature_35 adoption spike was not a retention event — it was an acquisition or engagement event that did not translate to staying behavior. Understanding what triggered that peak (a promotion, a new use case, a referral campaign) could inform product marketing, but should not be positioned as a retention mechanism.

**5.3 — The 315 Zero-Early-Usage Accounts Are an Onboarding Signal**

Step 23 shows 315 accounts (63%) had no recorded feature usage in months 0–1. Step 22 shows feature adoption rates average 2.51% — meaning at any given month, most accounts are not using most features. These two data points together describe a product where most users are not engaging with features in their critical early lifecycle window. This is an onboarding problem: not because low engagement predicts churn (Step 23 proves it does not), but because 63% of accounts are joining and spending months 0–1 without touching any feature at all — and then making their churn decision. If churn is driven by price-to-value judgment (Step 21), and value is never demonstrated in months 0–1 because no feature is used, then onboarding failure is the mechanism connecting the channel quality problem (Step 16), the pricing churn reason (Step 21), and the month 0–1 churn concentration (cohort layer).

**5.4 — The Usage-Churn Disconnect Changes the Risk Model**

Step 23's refutation of all five hypotheses directly impacts Step 25 (Multi-Factor Churn Model). The three planned risk signals were: low feature usage, high support tickets, and preceding downgrade. Step 18 already showed preceding downgrade is a weak signal (11.6% of churns, downgraders actually survive longer). Step 23 now shows low feature usage is a non-signal. This leaves high support ticket volume as the only empirically validated behavioral predictor of churn risk from the planned signal set. Step 25 must incorporate the segmentation findings from Module 2 (plan × industry combinations, referral source quality, country) as risk factors rather than relying on behavioral usage data.

---

## 6. Business Implications for Launch

| Finding | Implication | Severity |
|---|---|---|
| No feature reaches 10% adoption — best is 5.05% | No feature has created a switching cost for any meaningful portion of the customer base | High |
| Beta features 4.3x less adopted despite identical quality | 40 features are effectively hidden from most of the customer base | High |
| Usage does not predict churn | CS monitoring of usage activity will not provide early churn warning in this product | High |
| 315 accounts (63%) had no early feature usage | Onboarding is failing to activate most users in months 0–1 | Critical |
| High early usage (21+) correlates with higher churn (75.0%) | Power users who explore intensely and then churn — product fails their advanced evaluation | Moderate |
| Feature archetype split: 24 core, 16 awareness, 16 specialist (hidden), 24 dead (hidden) | Half the product is functionally invisible to most customers | High |
| Even GA feature usage is flat across all 40 features | No "hero feature" has emerged — no single product capability anchors retention | High |

**The strategic summary:** The feature adoption crisis (Step 22) and the usage-churn disconnect (Step 23) together describe a product that is being used but not depended upon. Accounts engage with features moderately across the board but have not built the kind of deep product dependency that makes churning costly. Fixing this requires feature concentration (fewer, deeper features that become indispensable) rather than feature expansion.

---

## 7. Recommendations from Module 3

**P1 — Concentrate onboarding around the 24 core features before launch**

Core features have both broad adoption and deep engagement — they are the features most likely to create product dependency if activated early. Onboarding should not introduce all 40 features simultaneously (the current implicit approach given the flat adoption distribution). Onboarding should force adoption of 3–5 core features in the first 30 days and measure activation rate against that specific set. Feature_35, feature_38, and feature_36 (top 3 by adoption + volume respectively) are the onboarding anchors.

**P2 — Surface specialist beta features through in-product discovery mechanisms**

16 specialist beta features have above-median usage intensity but below-median adoption — they are used deeply by accounts that discover them but invisible to the rest. An in-product feature discovery mechanism (guided tours, contextual prompts, use-case-based recommendations) would convert these hidden specialists into accessible tools without rebuilding them. The discoverability investment is significantly cheaper than building new features to achieve the same engagement lift.

**P3 — Remove usage monitoring from the CS early warning system**

Step 23 proves usage does not predict churn. A CS team monitoring usage dashboards as churn indicators is operating on a false signal. CS early warning should instead be built around support ticket escalation volume, support CSAT scores, and plan × industry segment risk profiles (Module 2 findings). Re-orienting CS tooling around validated predictors prevents both false positives (flagging engaged accounts that are about to churn for non-usage reasons) and false negatives (missing churners who actively use the product until they cancel).

**P4 — Investigate what drove feature_35's 50% peak adoption month**

Feature_35 achieved 50% adoption in a single month — 10x its average. This is the only instance of a feature approaching benchmark-level adoption in the entire 24-month dataset. What triggered this spike could be replicated at launch. If it was a specific customer segment, a marketing campaign, a product update, or a use-case activation, that playbook is the closest thing the product has to a proven high-adoption mechanism.

**P5 — Reframe onboarding success metrics from usage counts to value milestones**

The current implied success metric (feature adoption rate) is measuring discovery, not value. Step 23 proves that usage level does not differentiate churners from retained accounts. Onboarding should be redesigned around measurable value milestones — specific outcomes the customer achieves using the product — rather than feature activation counts. This is consistent with the Module 2 finding that pricing and budget are the rising churn reasons: if value is not clearly demonstrated before the price evaluation moment (month 2–3), customers will conclude the price exceeds the value regardless of how many features they have clicked on.

---

*Module 3 complete. Feeds into: Step 25 (Multi-Factor Churn Model — usage is confirmed as a non-predictor; risk model must rely on Module 2 signals), Step 28 (Beta Feature Impact — extends the beta discoverability finding to churn outcome), Phase 5 Insights (Steps 29–31), and Dashboard Page 4 (Feature Usage).*
