# Module 2 — Churn Analysis
**RavenStack SaaS Pre-Launch Analysis**
**Role:** Product Analyst
**Steps:** 19 (Churn Rate Analysis), 20 (Churn Segmentation), 21 (Churn Reason Analysis)
**Status:** Complete & Validated
**Last Updated:** 2026-05-13

---

## Table of Contents
1. [Module Overview](#1-module-overview)
2. [Hypotheses](#2-hypotheses)
3. [Step 19 — Churn Rate Analysis](#3-step-19--churn-rate-analysis)
4. [Step 20 — Churn Segmentation](#4-step-20--churn-segmentation)
5. [Step 21 — Churn Reason Analysis](#5-step-21--churn-reason-analysis)
6. [Cross-Step Insights](#6-cross-step-insights)
7. [Business Implications for Launch](#7-business-implications-for-launch)
8. [Recommendations from Module 2](#8-recommendations-from-module-2)

---

## 1. Module Overview

Module 2 answers one core business question: **Why are accounts leaving, how bad is it, and who is most at risk?**

Step 19 establishes the full churn picture — the overall rate, when it accelerated, and how paid versus trial accounts differ. Step 20 segments that churn across four business dimensions — plan tier, industry, country, and referral source — to identify which segments are structurally at risk versus which are performing acceptably. Step 21 identifies why accounts are leaving and whether the reason varies by plan, over time, or by cohort year.

Together these three steps transform a single headline number (70.4% lifetime churn) into an actionable map of where, when, and why the business is losing customers.

**Sources used:**

| Source | Role |
|---|---|
| `kpi_monthly_churn_rate` | Monthly churn rate baseline |
| `kpi_monthly_retention_rate` | Retention complement |
| `base_churn_monthly` | Account-level churn events with reason_code |
| `base_active_monthly` | Active account population and type classification |
| `cohort_base` | Segmentation dimensions and behavioral attributes |
| `churn_events` | Raw event data for lifetime picture |

**Dashboard views created:**

| View | Step | Page | Status |
|---|---|---|---|
| `analysis_churn_rate_trend` | 19 | 3 | ✅ Built |
| `analysis_churn_paid_vs_trial` | 19 | 3 | ✅ Built |
| `analysis_churn_by_plan` | 20 | 3 | ✅ Built |
| `analysis_churn_by_industry` | 20 | 3 | ✅ Built |
| `analysis_churn_by_country` | 20 | 3 | ✅ Built |
| `analysis_churn_reason_distribution` | 21 | 3 | ✅ Built |
| `analysis_churn_reason_by_plan` | 21 | 3 | ✅ Built |
| `analysis_churn_reason_trend` | 21 | 3 | ✅ Built |

---

## 2. Hypotheses

### Step 19 — Churn Rate Analysis

| # | Hypothesis | Result |
|---|---|---|
| H1 | Churn acceleration began in June 2024 and represents a structural shift, not noise | ✅ Confirmed — June 2024 is a genuine regime change. Crossed 10% and never recovered. Rolling 3-month average confirms sustained upward trend. |
| H2 | Trial accounts churn at significantly higher rates than paid accounts | ❌ Refuted — trial churn is near-zero in most months. The churn problem is entirely in paid accounts. |
| H3 | September 2023 (5.13%) represents the product's natural healthy state | ✅ Partially confirmed — it is the closest reliable month to benchmark, but at 5.13% it is still elevated, not a true healthy state. |

### Step 20 — Churn Segmentation

| # | Hypothesis | Result |
|---|---|---|
| H1 | Enterprise accounts churn less than Basic and Pro | ❌ Refuted — Enterprise (70.1%) churns more than Basic (68.5%). All three tiers cluster within 4pp of each other. |
| H2 | Certain industries show significantly higher churn than others | ✅ Confirmed — HealthTech (66.7%) to DevTools (73.5%), a 6.8pp spread. Consistent and directionally meaningful. |
| H3 | Churn rates vary meaningfully by country | ✅ Confirmed — Germany (56.0%) to UK (77.6%), a 21.6pp spread. Most significant geographic signal in the dataset. |
| H4 | Referral source segmentation confirms Step 16 quality ranking | ✅ Confirmed — ads (60.2%) to partner (75.3%) quality ranking identical across both analytical approaches. |

### Step 21 — Churn Reason Analysis

| # | Hypothesis | Result |
|---|---|---|
| H1 | Features is the top churn reason reflecting product gaps | ✅ Technically confirmed — features leads at 19.2% — but only by 3.7pp from the last-place reason. The even distribution is the real finding. |
| H2 | Churn reason varies significantly by plan tier | ✅ Confirmed — support leads for Basic and Pro but ranks last for Enterprise. Enterprise uniquely leads with features and unknown. |
| H3 | Support-related churn concentrates in months with poor CSAT | 🔄 Pending — requires Step 24 cross-validation. No obvious temporal spike confirmed yet. |
| H4 | Unknown churns represent silent disengaged customers | ✅ Partially confirmed — unknown churners survive 0.5 months less (3.6 vs 4.1 avg), consistent with disengagement, but behavioral profiles are otherwise similar. |
| H5 | Support churn is fastest, competitor churn is slowest | ❌ Refuted — pricing is fastest (3.2 months avg). Support is actually slowest (5.1 months). The direction was reversed. |

---

## 3. Step 19 — Churn Rate Analysis

### 3.1 Lifetime Churn Picture

| Metric | Value |
|---|---|
| Total accounts | 500 |
| Ever churned | 352 (70.4%) |
| Never churned | 148 (29.6%) |
| Permanently lost | 26 (5.2%) |
| Reactivated at least once | 326 (65.2%) |
| Avg churn events per churned account | 1.70 |
| Active paid accounts (December 2024) | 500 |

The 70.4% lifetime churn rate requires context before interpretation. Only 5.2% of accounts (26) are permanently lost — never reactivated. The remaining 65.2% that churned came back at least once. This confirms the Step 14 cohort finding: churn is subscription instability, not permanent customer loss.

However, the average of 1.70 churn events per churned account means the average churned customer has been lost and reacquired nearly twice. Each churn cycle represents lost revenue, CS intervention cost, and reacquisition effort. At scale this is expensive even when the customer returns.

### 3.2 Churn Severity Distribution

Of the 22 reliable months in the dataset:

| Severity Tier | Definition | Months | % of Months | Avg Churn Rate | Period |
|---|---|---|---|---|---|
| Benchmark range | < 5% | 1 | 4.5% | 4.63% | Feb 2024 only |
| Elevated | 5–10% | 11 | 50.0% | 8.13% | May 2023 – Jul 2024 |
| High | 10–15% | 8 | 36.4% | 12.26% | Multiple periods |
| Crisis | ≥ 15% | 2 | 9.1% | 35.09% | Mar 2023, Dec 2024 |

Only 1 month (4.5%) ever reached the benchmark range. The product has spent 95.5% of its reliable operating history above the industry benchmark. Elevated churn has been the baseline from the beginning — the H2 2024 acceleration is a worsening of an already problematic baseline, not a new problem appearing from nowhere.

The two crisis months are structurally different. March 2023 (50%) is a small-base artifact — 10 accounts active, 5 churned. December 2024 (20.17%) is a genuine large-scale event — 476 active accounts, 96 churned. December is the real crisis.

### 3.3 Three-Phase Churn Trajectory

**Phase 1 — Early Stage (Jan–May 2023)**

High percentage rates but small absolute numbers. March 2023 at 50% is statistically unreliable (10 accounts). The rolling 3-month average drops from 50% to 24% to 10.8% as the base grows — confirming early spikes were base-size artifacts, not product failures. The product was not failing in early 2023; the denominator was simply too small to produce stable rates.

**Phase 2 — Stabilization (Jun 2023–May 2024)**

Churn oscillates between 5.13% (Sep 2023) and 10.21% (Mar 2024). Rolling 3-month average stays between 6.48% and 9.26% — elevated but not directionally worsening. One benchmark-range month occurred: February 2024 at 4.63%.

The February–March 2024 anomaly is unexplained and warrants investigation. February dropped to 4.63% (best reliable month ever), then March jumped to 10.21% — a 5.58pp single-month increase. This pattern is consistent with delayed churns from February catching up in March rather than a genuine improvement reversing. Step 24 will test whether February had unusually strong support metrics.

**Phase 3 — Acceleration (Jun 2024–Dec 2024)**

June 2024 is the confirmed structural inflection point. Churn hit 12.14% and the rolling 3-month average began a monotonic climb from 9.91% to 16.08%. The product never returned below 10% after June 2024.

| Month | Churn Rate | MoM Change | Acceleration Status |
|---|---|---|---|
| Jun 2024 | 12.14% | +3.27pp | Accelerating — inflection point |
| Jul 2024 | 9.76% | -2.38pp | Decelerating — brief relief |
| Aug 2024 | 10.93% | +1.17pp | Stable — above 10% |
| Sep 2024 | 12.47% | +1.54pp | Stable — worsening |
| Oct 2024 | 14.46% | +1.99pp | Stable — worsening |
| Nov 2024 | 13.61% | -0.85pp | Stable — marginal relief |
| Dec 2024 | **20.17%** | **+6.56pp** | Accelerating — **crisis** |

Ten consecutive months above 10% by December 2024. The July deceleration was temporary. H1 confirmed — this is a structural regime change, not monthly noise.

### 3.4 Paid vs Trial Churn — H2 Refuted

Trial churn is effectively zero in most months. Where trial churn appears, sample sizes are too small to be meaningful (1–3 accounts). The two extreme trial churn months — July 2024 (60.00%, 3 accounts) and October 2024 (100.00%, 2 accounts) — are statistically unreliable.

The core finding is unambiguous: the churn crisis is entirely a paid account problem. All interventions should target paid account retention. Trial management is not a lever for improving the headline churn metric.

By December 2024: 500 paid accounts active, 96 churned (19.20% paid churn rate), 0 trial accounts remaining. The trial population effectively disappears as the dataset matures — confirming trials are experimental, not an ongoing acquisition mechanism.

### 3.5 2023 vs 2024 Cohort Comparison

| Cohort Year | Accounts | Churned | Churn Rate | Avg Months to First Churn | Avg Churn Events |
|---|---|---|---|---|---|
| 2023 cohorts | 227 | 163 | 71.8% | **7.2** | 1.22 |
| 2024 cohorts | 273 | 189 | 69.2% | **2.0** | 1.18 |

At face value 2024 cohorts (69.2%) appear to churn less than 2023 (71.8%). The critical number is avg months to first churn: 2.0 for 2024 vs 7.2 for 2023 — a 3.6x difference. 2024 cohorts churn dramatically faster before their first churn event.

The lower 2024 lifetime churn rate is an observation window artifact — 2024 cohorts have had fewer months to accumulate events, not because they are higher quality customers. This directly cross-validates the survival curve deterioration identified in Step 14.

### 3.6 Key Insights — Step 19

- Only 1 of 22 reliable months (4.5%) ever reached the SaaS benchmark range — elevated churn is the baseline, not an aberration
- June 2024 is the confirmed structural inflection point — churn crossed 10% and the rolling 3-month average never reversed
- December 2024: 20.17% — 96 accounts lost in one month — largest single-month churn event in the dataset
- The churn crisis is entirely a paid account problem — trial churn is statistically negligible
- 2024 cohorts churn 3.6x faster (avg 2.0 months) than 2023 cohorts (avg 7.2 months) — deterioration confirmed
- 70.4% lifetime churn with 79.3% reactivation means churn is expensive instability, not permanent loss — but the cost accumulates

---

## 4. Step 20 — Churn Segmentation

### 4.1 Churn by Plan Tier — H1 Refuted

| Plan Tier | Accounts | Churn Rate | Never Churned | Avg Months to First Churn | Avg Churn Events | Reactivation Rate | Gap vs Overall |
|---|---|---|---|---|---|---|---|
| Basic | 168 | **68.5%** | 31.5% | 4.5 | 1.07 | 92.2% | -1.9pp |
| Enterprise | 154 | 70.1% | 29.9% | 4.6 | **1.27** | **93.5%** | -0.3pp |
| Pro | 178 | **72.5%** | 27.5% | **4.2** | 1.26 | 92.2% | +2.1pp |

H1 is refuted. Enterprise does not churn less — it churns at 70.1%, only 0.3pp below the overall average and 1.6pp above Basic. All three tiers cluster within a 4pp range. Entry plan tier is not a meaningful predictor of whether an account churns.

This suggests the product lacks differentiated retention mechanisms across plan tiers — or that the value proposition is consistent enough that plan level does not change the fundamental retention dynamic.

**What does differ meaningfully:**

Enterprise has the highest reactivation rate (93.5%) and longest avg time to first churn (4.6 months) — Enterprise accounts take longer to decide to leave and come back more reliably when they do. Enterprise churn is more deliberate and more recoverable.

Basic has the lowest avg churn events (1.07) — Basic accounts churn fewer times. They either stay or leave more cleanly than Pro or Enterprise.

Pro is the most volatile tier: highest churn rate (72.5%), shortest avg months to first churn (4.2), and high avg churn events (1.26). Pro accounts churn faster and more repeatedly. This aligns with the Step 17 finding that Pro revenue peaked in November 2024 and dropped $49,648 in December.

**December 2024 breakdown by plan tier:**

| Plan Tier | December 2024 Churned |
|---|---|
| Basic | 30 |
| Enterprise | 31 |
| Pro | **35** |

All three tiers accelerated simultaneously. The December crisis was not concentrated in one failing tier — it was systemic.

### 4.2 Cross-Dimension Analysis — Plan × Industry

The plan × industry cross-dimension reveals what summary statistics by either dimension alone conceals:

| Plan | Industry | Accounts | Churn Rate | Avg Months to First Churn |
|---|---|---|---|---|
| Enterprise | HealthTech | 27 | **51.9%** | 4.5 — best combination |
| Basic | FinTech | 34 | **55.9%** | 5.4 — second best |
| Pro | Cybersecurity | 38 | 63.2% | 4.0 |
| Basic | EdTech | 28 | 64.3% | 2.8 |
| Basic | DevTools | 36 | 66.7% | 3.8 |
| Pro | DevTools | 42 | 81.0% | 5.3 |
| Enterprise | EdTech | 24 | **83.3%** | 4.1 — worst combination |

Enterprise × HealthTech (51.9% churn) is the best-performing combination — the closest segment to genuine product-market fit. Enterprise × EdTech (83.3%) is the worst — 31.4pp higher than the best combination despite being the same entry plan tier.

Plan tier alone explains nothing. Industry context determines the outcome. This cross-dimensional finding is the most actionable segmentation insight in the module — it defines both who to target and who to deprioritize at launch.

### 4.3 Churn by Industry — H2 Confirmed

| Industry | Accounts | Churn Rate | Never Churned | Avg Months to First Churn | Gap vs Overall |
|---|---|---|---|---|---|
| HealthTech | 96 | **66.7%** | 33.3% | **5.3** | -3.7pp |
| FinTech | 112 | 67.9% | 32.1% | 4.4 | -2.5pp |
| Cybersecurity | 100 | 72.0% | 28.0% | 4.0 | +1.6pp |
| EdTech | 79 | 72.2% | 27.8% | **3.6** | +1.8pp |
| DevTools | 113 | **73.5%** | 26.5% | 4.6 | +3.1pp |

HealthTech and FinTech are the two best-performing industries on every metric — lowest churn rate, highest never-churned proportion, and HealthTech has the longest average survival before first churn (5.3 months vs 3.6 for EdTech). Together they represent 208 accounts (41.6% of the customer base) and anchor the retained customer base.

EdTech is the fastest-churning vertical — lowest avg months to first churn (3.6 months), second-worst churn rate (72.2%), and lowest reactivation rate of all industries (87.7%). EdTech accounts churn fast and are least likely to return. This combination makes EdTech the highest-risk vertical for customer lifetime value.

DevTools has the worst churn rate (73.5%) despite being the largest industry segment by account count (113 accounts). DevTools represents the product's largest market but its poorest-performing one. Mitigating factor: DevTools has the highest reactivation rate (95.2%) — these accounts churn frequently but return reliably.

The 6.8pp spread between best (HealthTech 66.7%) and worst (DevTools 73.5%) is meaningful for targeting but does not explain the fundamental churn problem. All industries are structurally above healthy benchmark levels.

### 4.4 Churn by Country — H3 Confirmed

| Country | Accounts | Churn Rate | Never Churned | Avg Months to First Churn | Gap vs Overall |
|---|---|---|---|---|---|
| DE (Germany) | 25 | **56.0%** | **44.0%** | **7.4** | **-14.4pp** |
| IN (India) | 49 | 67.3% | 32.7% | 4.7 | -3.1pp |
| AU (Australia) | 32 | 68.8% | 31.3% | 4.1 | -1.7pp |
| CA (Canada) | 23 | 69.6% | 30.4% | 3.2 | -0.8pp |
| US (United States) | 291 | 70.8% | 29.2% | 4.1 | +0.4pp |
| FR (France) | 22 | 72.7% | 27.3% | 4.5 | +2.3pp |
| UK (United Kingdom) | 58 | **77.6%** | **22.4%** | 4.9 | **+7.2pp** |

Germany is the standout finding — 56.0% churn rate, 44.0% never-churned, and 7.4 months average before first churn. German accounts survive 80% longer before their first churn than the dataset average. The -14.4pp gap from overall is the largest positive geographic deviation in the dataset. Germany represents strong product-market fit for a small but high-quality segment.

The UK is the weakest geographic market — 77.6% churn, 22.4% never-churned, 7.2pp above overall average. At 58 accounts (second largest non-US market), the UK combines volume with poor quality. The 21.6pp churn gap between Germany and the UK is the most significant bilateral country comparison in the dataset.

The United States dominates by volume (291 accounts, 58.2% of total) at a churn rate of 70.8% — nearly exactly at the overall average. The US is the representative market. Any intervention that moves US churn materially moves the headline metric given the volume concentration.

**Geographic pattern observation:** English-speaking markets (US 70.8%, UK 77.6%) show higher churn than non-English European markets (DE 56.0%, FR 72.7%). This may indicate localization factors, competitive landscape differences, or different B2B buyer behavior patterns across markets. Worth investigating in launch go-to-market planning.

### 4.5 Referral Source Cross-Validation — H4 Confirmed

| Channel | Accounts | Churn Rate | Never Churned | Avg Months to First Churn | Quality Rank |
|---|---|---|---|---|---|
| Ads | 98 | **60.2%** | **39.8%** | **5.1** | 1 |
| Event | 96 | 70.8% | 29.2% | 4.1 | 2 |
| Other | 103 | 70.9% | 29.1% | 4.4 | 3 |
| Organic | 114 | 74.6% | 25.4% | 4.1 | 4 |
| Partner | 89 | **75.3%** | **24.7%** | 4.4 | 5 |

Quality ranking is identical to Step 16. The finding is robust across two independent analytical approaches. Ads leads by 10.6pp over the second channel. Partner is last on every metric. This cross-validation confirms the Step 16 recommendation is analytically sound — two different methodologies reaching the same conclusion strengthens the case for action.

### 4.6 Key Insights — Step 20

- Plan tier is not a meaningful churn predictor — Basic, Pro, and Enterprise cluster within 4pp (68.5%–72.5%)
- Pro is the most volatile tier — highest churn rate (72.5%), fastest time to first churn (4.2 months)
- Enterprise × HealthTech (51.9% churn) is the best-performing segment — closest to product-market fit in the dataset
- Enterprise × EdTech (83.3%) is the worst — 31.4pp above the best combination despite same plan tier
- Germany is the strongest geographic market (-14.4pp gap) — 44% never churned, 7.4 months avg survival
- UK is the weakest (-7.2pp gap) — second largest non-US market with worst retention
- HealthTech and FinTech anchor the retained base — clearest launch targeting candidates
- DevTools (73.5%) is largest industry segment but poorest performer — high reactivation (95.2%) softens the impact
- Channel quality ranking cross-validated — ads best, partner worst, consistent across both Step 16 and Step 20

---

## 5. Step 21 — Churn Reason Analysis

### 5.1 Overall Reason Distribution — The Multi-Front Finding

| Reason | Churn Events | Distinct Accounts | % of Total | Avg Months to First Churn | Preceded by Downgrade | Reactivation Rate |
|---|---|---|---|---|---|---|
| Features | 105 | 96 | **19.2%** | 3.8 | 6.7% | **95.8%** |
| Support | 97 | 89 | 17.7% | **5.1** | 12.4% | 92.1% |
| Budget | 91 | 85 | 16.6% | 4.0 | 5.5% | 92.9% |
| Pricing | 86 | 84 | 15.7% | **3.2** | 4.7% | 94.0% |
| Competitor | 85 | 75 | 15.5% | 4.4 | **11.8%** | **96.0%** |
| Unknown | 83 | 77 | 15.2% | 3.6 | 10.8% | 92.2% |

All six reasons fall within a 3.7pp range (15.2%–19.2%). This is the core finding of Step 21. No reason dominates. Features leads at 19.2% but only by 4.0pp over unknown in last place.

This distribution has a precise business implication: there is no silver bullet. Fixing features alone recovers at most 19.2% of churn events. Eliminating support-driven churn recovers 17.7%. No single intervention is decisive. All six vectors must be addressed simultaneously. This is a multi-front problem requiring a multi-front solution.

**Secondary findings within the distribution:**

Support churners survive the longest before first churn (5.1 months avg) — meaning the product worked for them initially, and a support failure triggered departure after extended engagement. These are recoverable customers. The 92.1% reactivation rate confirms most return.

Pricing churners are fastest to exit (3.2 months avg, 38.1% by month 1) — pricing friction hits before the product has time to prove its value. The price-to-value judgment is made early.

Competitor churners have the highest reactivation rate (96.0%) — accounts that leave for a competitor come back almost universally. Competitor alternatives are tried and found wanting, leading to return. The 30.7% churned-by-month-1 rate for competitor (lowest of all reasons) confirms competitor evaluation is deliberate, not impulsive.

### 5.2 Churn Reason by Plan Tier — H2 Confirmed

| Reason | Basic % | Enterprise % | Pro % | Key Pattern |
|---|---|---|---|---|
| Support | **21.8%** | **12.6%** | **18.8%** | Top for Basic & Pro, last for Enterprise |
| Features | 20.0% | **19.4%** | 18.3% | Top for Enterprise, consistent across all |
| Budget | 15.3% | 17.1% | 17.3% | More prominent in Enterprise and Pro |
| Pricing | 16.5% | 16.6% | 14.4% | Consistent across all tiers |
| Competitor | 14.7% | 16.6% | 15.3% | Consistent, slight Enterprise lean |
| Unknown | **11.8%** | **17.7%** | 15.8% | Elevated for Enterprise — silent exits |

Support is the top churn reason for Basic (21.8%) and Pro (18.8%) but ranks last for Enterprise (12.6%) — a 9.2pp gap between Enterprise and Basic on the same reason. Enterprise accounts are significantly less likely to cite support as their churn driver.

Enterprise uniquely leads with features (19.4%) and has elevated unknown (17.7% — highest of any plan tier). Enterprise accounts leaving without explanation or citing product gaps represent a more sophisticated evaluation — they are leaving because the product does not do what they need (features gap), not because of the experience of using it.

The unknown concentration in Enterprise is the most actionable single finding in Step 21. Enterprise accounts churning silently — without explanation — represent the highest-value silent exits in the dataset. Dedicated exit interview outreach for every Enterprise churn event is required before launch to convert this unknown signal into product intelligence.

The support concentration in Basic and Pro (21.8% and 18.8%) suggests lower-tier accounts have lower tolerance for support friction or receive lower-quality support. If the support team is implicitly prioritizing Enterprise tickets (appropriate from a revenue standpoint), this accelerates Basic and Pro churn while keeping Enterprise satisfied — which partially explains the plan-tier pattern.

### 5.3 Time to Churn by Reason — H5 Corrected

| Reason | Avg Months to First Churn | Median | % Churned by Month 1 | Interpretation |
|---|---|---|---|---|
| Pricing | **3.2** | 2 | **38.1%** | Fastest — early price-to-value friction |
| Unknown | 3.6 | 2 | 39.0% | Early disengagement |
| Features | 3.8 | 2 | 42.7% | Product gaps hit early in lifecycle |
| Budget | 4.0 | 2 | 42.4% | Budget review timing |
| Competitor | 4.4 | **3** | **30.7%** | Deliberate evaluation — longest window |
| Support | **5.1** | 3 | 38.2% | Relationship erosion over time |

H5 was reversed by the data. Support is the slowest reason (5.1 months), not the fastest. Pricing is fastest (3.2 months). This matters for intervention design:

Pricing churn is an onboarding problem — accounts decide the price is wrong within 3 months, before value has been demonstrated. The intervention is faster time-to-value: if accounts realize value within the first 30 days, pricing objections are less likely to trigger departure at months 2–3.

Support churn is a relationship erosion problem — accounts survive 5.1 months on average before a support failure triggers exit. These accounts found value, then had the relationship damaged. The intervention is support quality during months 3–5, not month 1.

Competitor churn (4.4 months avg, only 30.7% by month 1) is the most deliberate — accounts evaluate alternatives before switching, giving the longest intervention window. Accounts beginning a competitor evaluation can potentially be retained through proactive CS outreach, feature demonstrations, or pricing adjustments before the switch finalizes.

Four of six reasons have a median of 2 months — meaning more than half of churns for features, pricing, budget, and unknown happen before the account reaches month 3. This reinforces the cohort layer finding (36.4% of all churns in months 0–1): the first 2 months are the highest-risk period across almost every churn dimension.

### 5.4 Unknown Churn Profile — H4 Partially Confirmed

| Dimension | Known Reason | Unknown |
|---|---|---|
| Distinct accounts | 316 | 77 |
| Avg months to first churn | 4.1 | 3.6 |
| Avg churn events | 2.05 | 2.05 |
| Reactivation rate | 93.0% | 92.2% |
| Basic proportion | 33.5% | **24.7%** |
| Pro proportion | 36.1% | **37.7%** |
| Enterprise proportion | 30.4% | **37.7%** |

Unknown churners survive 0.5 months less before first churn (3.6 vs 4.1) — consistent with disengagement. But the differences are not dramatic. Average churn events are identical (2.05), reactivation rates nearly identical (92.2% vs 93.0%). Unknown churners are disproportionately Pro and Enterprise (37.7% each) — higher-tier accounts are more likely to exit silently without providing feedback.

The hypothesis that unknown = low usage is plausible from the survival pattern but not proven here. Step 23 (usage vs churn) will test this directly.

### 5.5 Churn Reason Shift by Cohort Year — Structural Change

| Reason | 2023 Cohorts % | 2024 Cohorts % | Change |
|---|---|---|---|
| Support | **20.8%** | 14.7% | ↓ -6.1pp |
| Features | 19.3% | 19.1% | → Stable |
| Competitor | **18.6%** | 12.6% | ↓ -6.0pp |
| Unknown | 14.9% | 15.5% | → Stable |
| Budget | 13.4% | **19.8%** | ↑ +6.4pp |
| Pricing | 13.0% | **18.3%** | ↑ +5.3pp |

This is one of the most structurally important findings in Module 2. The reason composition has shifted significantly between cohort years:

Support and competitor churn have declined as proportions. Budget and pricing churn have risen sharply — budget went from 13.4% to 19.8% (+6.4pp) and pricing from 13.0% to 18.3% (+5.3pp).

2024 cohorts are increasingly citing financial reasons for churning, while 2023 cohorts cited relationship and experience reasons. This shift suggests one or both of:

2024 acquired accounts are more price-sensitive than 2023 accounts — consistent with the Step 16 finding that the acquisition mix shifted toward organic (74.6% churn rate, likely more cost-conscious buyers) and away from ads (60.2% churn, more committed buyers).

The pricing model has become less competitive for lower-tier acquisition as ARPU and Enterprise pricing scaled upward. What was affordable for 2023 accounts at lower ARPU levels may be misaligned with 2024 account expectations.

Combined with the Step 17 finding that Basic and Pro are dying as plan tiers, this pattern suggests the product is pricing itself out of its lower-tier acquisition funnel. 2024 cohorts are joining as Basic or Pro accounts and finding the price-to-value ratio insufficient within months 2–3 of their lifecycle.

### 5.6 Key Insights — Step 21

- No dominant churn reason — all six within 3.7pp (15.2%–19.2%) — multi-front problem, no single fixable cause
- Support is top reason for Basic (21.8%) and Pro (18.8%) but last for Enterprise (12.6%) — plan-specific interventions required
- Enterprise unknown churn (17.7%) is highest of any plan-reason combination — silent high-value exits need exit interview investment
- Pricing churn is fastest (3.2 months avg) — price-to-value failures happen before product proves itself
- Support churn is slowest (5.1 months avg) — relationship erosion after extended engagement — recoverable with proactive CS
- Competitor churners have 96.0% reactivation rate — competitors are not winning definitively
- 2024 cohorts shifting toward financial churn reasons (budget +6.4pp, pricing +5.3pp) — price sensitivity rising with channel quality degrading
- 2023 cohorts led with support and competitor — 2024 cohorts lead with budget and features — the problem is evolving, not static

---

## 6. Cross-Step Insights

**6.1 — The Acceleration-Segmentation Connection**

Step 19 identifies June 2024 as the structural inflection point. Step 20's plan-tier trend shows all three tiers accelerated simultaneously in H2 2024 — Basic (30), Enterprise (31), and Pro (35) all had their worst months in December 2024. The acceleration is systemic, not concentrated in a failing segment. This means the cause is upstream of segmentation — either an acquisition quality problem (confirmed in Step 16: ads declining, organic growing), a macroeconomic pressure, or both. Solving a single segment's churn will not reverse the acceleration.

**6.2 — The Pricing-Cohort-Channel Triangle**

Step 21 shows 2024 cohorts shifting toward budget and pricing churn. Step 16 shows 2024 cohorts arriving increasingly through organic channels (74.6% churn rate) rather than ads (60.2%). Step 19 shows 2024 cohorts averaging only 2.0 months before first churn vs 7.2 for 2023. These three data points form a coherent story: lower-quality acquisition channels are bringing price-sensitive accounts that exit faster citing financial reasons. The solution is not to lower prices — it is to fix the channel mix back toward ads, which brings accounts that are 10pp less likely to churn, survive 1 month longer, and are less likely to cite financial reasons for leaving.

**6.3 — The Support Paradox**

Step 21 shows support is the top churn reason for Basic and Pro but last for Enterprise. Step 20 shows Enterprise has the highest reactivation rate (93.5%) and the longest time to first churn (4.6 months). This combination suggests Enterprise accounts either receive better support or have more patience for support friction — while Basic and Pro accounts exit faster when support fails. The below-benchmark resolution times and CSAT scores from the KPI layer (Steps 13.8) disproportionately harm Basic and Pro retention. Step 24 will quantify this relationship, but the direction is already clear: support improvements will benefit Basic and Pro retention more than Enterprise.

**6.4 — Germany as the Launch Template**

Step 20 identifies Germany as the strongest geographic market by a significant margin: 56.0% churn, 44.0% never-churned, 7.4 months avg survival before first churn — 14.4pp better than the overall average. This is not a noise finding — at 25 accounts it is a small but consistent signal. Germany represents what RavenStack looks like when it works. Understanding the acquisition source, use case, industry composition, and buyer profile of German accounts should directly inform launch targeting and product messaging. This is an underexplored signal deserving dedicated investigation.

---

## 7. Business Implications for Launch

| Risk | Evidence | Severity |
|---|---|---|
| Churn acceleration is structural, not cyclical | June 2024 inflection confirmed, rolling 3-month average monotonically increasing to 16.08% | Critical |
| December 2024 crisis level heading into launch | 20.17% — 96 accounts lost — 10 consecutive months above 10% | Critical |
| No single fixable churn reason | All six reasons within 3.7pp — multi-front problem requiring multi-front solution | High |
| 2024 cohorts churning 3.6x faster than 2023 | Avg 2.0 months to first churn vs 7.2 — acquisition quality deteriorating | High |
| Rising financial churn in 2024 cohorts | Budget +6.4pp, pricing +5.3pp vs 2023 cohorts | High |
| Enterprise silent exits elevated | Unknown reason 17.7% for Enterprise — highest value accounts leaving without explanation | High |
| UK market underperforming at volume | 77.6% churn, 7.2pp above average, second largest non-US market | Moderate |
| EdTech fastest-churning vertical | 3.6 months avg survival, 72.2% churn, lowest reactivation (87.7%) | Moderate |

**The pre-launch state in one sentence:** Churn is accelerating across all plan tiers and industries simultaneously, 2024 cohorts are departing 3.6x faster than 2023 cohorts, and no single intervention can fix it because the problem operates on six dimensions simultaneously.

---

## 8. Recommendations from Module 2

**P1 — Implement a Month 0–1 intervention program before launch**

The convergence of findings from Steps 19, 21, and the cohort layer all point to the same moment. 36.4% of all churns happen in months 0–1. Pricing churn (fastest reason) hits at 3.2 months avg. 2024 cohorts churn at 2.0 months avg. The product needs a structured onboarding sequence that creates demonstrable value before the first renewal decision. This is the single highest-leverage intervention available before launch.

**P2 — Fix support quality with a plan-tier-prioritized approach**

Support is the top churn reason for Basic (21.8%) and Pro (18.8%). Resolution time and CSAT are below benchmark for all tiers. However, interventions should be designed specifically for Basic and Pro accounts — because Enterprise shows support as its lowest churn reason. The CS team should triage with priority weighting that accounts for churn risk by account type, not just ticket severity classification alone.

**P3 — Build an Enterprise exit interview program immediately**

Enterprise unknown churn is 17.7% — the highest plan-reason concentration in the dataset. Enterprise accounts are the highest-value customers and they are leaving without explanation at the highest rate. A dedicated exit interview program for every Enterprise churn event — even post-reactivation — converts this unknown signal into product and sales intelligence before launch.

**P4 — Launch targeting: prioritize Enterprise × HealthTech and Basic × FinTech**

Enterprise × HealthTech (51.9% churn) and Basic × FinTech (55.9% churn) are 14–19pp below the overall average — the clearest product-market fit signals in the dataset. Launch go-to-market should weight toward these segments in both sales targeting and marketing messaging. Deprioritize Enterprise × EdTech (83.3%) until the vertical-specific churn drivers are understood.

**P5 — Address pricing perception for 2024 cohort profile**

Budget (+6.4pp) and pricing (+5.3pp) churn reasons are rising in 2024 cohorts while support and competitor decline. The 2024 cohort profile — price-sensitive, churning within 2 months — needs faster time-to-value delivery, not necessarily a price reduction. If accounts realize value before month 2, the price objection arrives after switching cost has been established. This connects directly to the month 0–1 onboarding intervention above.

---

*Module 2 complete. Feeds into: Step 23 (Usage vs Churn — cross-validates unknown churn = low usage hypothesis), Step 24 (Support Impact — validates H3 on support-CSAT-churn correlation), Step 25 (Multi-Factor Churn Model — combines signals into account risk scores), Phase 5 Insights (Steps 29–31), and Dashboard Page 3 (Churn Analysis).*
