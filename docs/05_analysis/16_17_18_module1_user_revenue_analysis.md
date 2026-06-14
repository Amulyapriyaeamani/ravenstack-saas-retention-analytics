# Module 1 — User & Revenue Analysis
**RavenStack SaaS Pre-Launch Analysis**
**Role:** Product Analyst
**Steps:** 16 (User Growth), 17 (Revenue Analysis), 18 (Upgrade/Downgrade Analysis)
**Status:** Complete & Validated
**Last Updated:** 2026-05-13

---

## Table of Contents
1. [Module Overview](#1-module-overview)
2. [Hypotheses](#2-hypotheses)
3. [Step 16 — User Growth Analysis](#3-step-16--user-growth-analysis)
4. [Step 17 — Revenue Analysis](#4-step-17--revenue-analysis)
5. [Step 18 — Upgrade/Downgrade Analysis](#5-step-18--upgradedowngrade-analysis)
6. [Cross-Step Insights](#6-cross-step-insights)
7. [Business Implications for Launch](#7-business-implications-for-launch)
8. [Recommendations from Module 1](#8-recommendations-from-module-1)

---

## 1. Module Overview

Module 1 answers one core business question: **How is the user and revenue base performing heading into public launch?**

The three steps build on each other in sequence. Step 16 establishes who the users are and how acquisition is performing. Step 17 translates that user base into revenue and reveals the structural risks underneath headline growth. Step 18 examines how users move between plans and whether the expansion engine is sustainable.

**Sources used:**

| Source | Role |
|---|---|
| `cohort_base` | User identity, segmentation, churn behavior |
| `kpi_monthly_mrr_growth` | MRR, ARPU, plan-level revenue |
| `kpi_monthly_upgrade_downgrade` | Plan movement rates |
| `subscriptions` | MRR impact of plan movement, concentration analysis |
| `base_churn_monthly` | Preceding downgrade flag |

**Dashboard views created:**

| View | Dashboard Page | Visual Type |
|---|---|---|
| `analysis_user_growth_monthly` | Revenue & Growth | Line chart — signup trend |
| `analysis_user_growth_by_channel` | Revenue & Growth | Table — channel quality ranking |
| `analysis_user_growth_channel_mix` | Revenue & Growth | Stacked bar — channel mix over time |
| `analysis_revenue_mrr_trend` | Revenue & Growth | Line chart — MRR with phase annotations |
| `analysis_revenue_plan_breakdown` | Revenue & Growth | Stacked bar — plan revenue evolution |
| `analysis_revenue_concentration` | Revenue & Growth | Table — concentration risk by tier |
| `analysis_upgrade_downgrade_trend` | Revenue & Growth | Line chart — upgrade/downgrade rate trend |
| `analysis_upgrade_downgrade_revenue` | Revenue & Growth | Bar chart — MRR impact of plan movement |

---

## 2. Hypotheses

### Step 16 — User Growth
| # | Hypothesis | Result |
|---|---|---|
| H1 | Organic and partner bring the most signups by volume, but ads brings the highest quality customers | ✅ Confirmed — organic highest volume, ads best quality |
| H2 | Monthly signup growth accelerated in H2 2024 | ✅ Partially confirmed — Oct/Nov strong, Dec reversed |
| H3 | Channel mix has shifted over time — ads proportion growing in later cohorts | ✅ Confirmed — but shifting in the wrong direction (ads declining, organic growing) |

### Step 17 — Revenue Analysis
| # | Hypothesis | Result |
|---|---|---|
| H1 | Revenue growth is driven by ARPU expansion, not account growth | ✅ Confirmed — accounts 250x, MRR 2,291x, ARPU 9.2x |
| H2 | Enterprise dominance accelerated after mid-2023; Basic and Pro dying in absolute terms | ✅ Confirmed — Basic declining since Sep 2023, Pro peaked Nov 2024 |
| H3 | Top 10% of accounts drive majority of MRR | ✅ Confirmed with nuance — top 10% = 28.1% MRR, driven by subscription volume not plan tier |

### Step 18 — Upgrade/Downgrade Analysis
| # | Hypothesis | Result |
|---|---|---|
| H1 | Upgrade MRR consistently exceeds downgrade MRR until H2 2024 | ✅ Partially confirmed — only 2 net-negative months (Feb 2023, Jul 2024) |
| H2 | December 2024 has highest absolute plan movement | ✅ Confirmed — 84 total plan changes, all-time high |
| H3 | Accounts that downgrade are significantly more likely to churn within 3 months | ❌ Refuted — downgraders survive longer (4.9 months vs 4.0 months average) |

---

## 3. Step 16 — User Growth Analysis

### 3.1 Monthly Signup Trend

Total signups across 24 months: **500 accounts**, averaging ~21 per month. Growth is volatile and episodic rather than smooth — alternating between spikes and declines throughout the dataset.

**Growth classification breakdown:**

| Classification | Months |
|---|---|
| High growth (>20% MoM) | May 2023 (+73%), Sep 2023 (+44%), Mar 2024 (+108%), Jul 2024 (+24%), Oct 2024 (+24%) |
| Moderate growth | Several months throughout |
| Decline | Apr, Jun, Oct, Dec 2023 — Jan, Feb, Apr, Jun, Aug, Dec 2024 |

No sustained multi-month growth curve exists. The pattern suggests an episodic acquisition model with no repeatable engine driving consistent signup flow. This is a pre-launch structural concern.

**Notable events:**

- **March 2024 (+107.69%):** Largest single-month jump — 13 to 27 signups. Likely driven by a specific campaign or event. Channel mix investigation confirms ads peaked at 38.5% that month — worth attempting to replicate.
- **December 2024 (-46.88%):** Final month dropped from 32 to 17 signups. The product is losing acquisition momentum exactly when it needs it most heading into public launch.

**H2 partial confirmation:**

| Period | Avg Signups/Month |
|---|---|
| H2 2023 | ~19 |
| H1 2024 | ~18 (flat) |
| H2 2024 | ~25 (improvement) |

H2 2024 did show improvement in volume but December's reversal undermines the trend. The hypothesis is partially true in aggregate but not stable.

### 3.2 Referral Source Volume

| Channel | Accounts | % of Total |
|---|---|---|
| Organic | 114 | 22.8% |
| Other | 103 | 20.6% |
| Ads | 98 | 19.6% |
| Event | 96 | 19.2% |
| Partner | 89 | 17.8% |

All five channels fall between 17–23% — a remarkably even distribution. In most SaaS companies one or two channels dominate acquisition. This near-equal split suggests either no deliberate acquisition strategy or a deliberate multi-channel experiment with no clear winner yet. All channels have been active since January 2023 with no channel added or dropped mid-dataset.

### 3.3 Referral Source Quality

| Channel | Accounts | Churn Rate | Never Churned | Avg Months to First Churn | Avg Churn Events | Reactivation Rate |
|---|---|---|---|---|---|---|
| Ads | 98 | **60.2%** | **39.8%** | **5.1** | **1.02** | 93.2% |
| Event | 96 | 70.8% | 29.2% | 4.1 | 1.28 | 95.6% |
| Other | 103 | 70.9% | 29.1% | 4.4 | 1.25 | 94.5% |
| Organic | 114 | 74.6% | 25.4% | 4.1 | 1.36 | 91.8% |
| Partner | 89 | **75.3%** | **24.7%** | 4.4 | 1.46 | **88.1%** |

**Ads is the best quality channel on every metric:**
- Lowest churn rate: 60.2% — 15 percentage points below partner
- Highest never-churned proportion: 39.8% — nearly 4 in 10 ads customers never left
- Longest survival before first churn: 5.1 months (1 full month more than organic and event)
- Fewest average churn events: 1.02 per churned account

**Partner is the worst channel on every metric:**
- Highest churn rate: 75.3%
- Lowest never-churned: 24.7%
- Lowest reactivation rate: 88.1%
- Partner brings the fewest signups AND the worst retention — worst on both volume and quality dimensions.

**Organic is a volume-quality mismatch:**
- Highest volume channel: 114 accounts (22.8%)
- But second-worst churn rate: 74.6%
- The channel generating the most customers is not generating the best customers.

### 3.4 Combined Channel Ranking

| Channel | Quality Rank | Volume Rank | Combined Score | Assessment |
|---|---|---|---|---|
| Ads | 1 | 3 | 4 | Best overall |
| Other | 3 | 2 | 5 | Second |
| Organic | 4 | 1 | 5 | Second (tied) |
| Event | 2 | 4 | 6 | Middle |
| Partner | 5 | 5 | 10 | Worst overall |

### 3.5 Channel Mix Shift Over Time (H3)

The hypothesis that channel mix is shifting is confirmed — but the direction is unfavorable.

**Ads proportion declining:**

| Month | Ads % |
|---|---|
| Jun 2024 | 52.4% (peak — likely campaign) |
| Aug 2024 | 9.5% |
| Oct 2024 | 9.7% |
| Dec 2024 | 11.8% |

**Organic surging:**

| Month | Organic % |
|---|---|
| Nov 2024 | 40.6% |
| Dec 2024 | 35.3% |

The best-quality channel (ads, 60.2% churn) is declining as a proportion. The worst-retention high-volume channel (organic, 74.6% churn) is growing. The acquisition mix is deteriorating in quality terms heading into launch. This channel quality degradation partially explains the December 2024 churn spike — worse-quality cohorts replacing better-quality ones.

### 3.6 Key Insights — Step 16

- Growth is volatile and episodic — no repeatable acquisition engine exists
- All 5 channels are roughly equal in volume — no dominant channel strategy
- Ads is the clear quality winner (60.2% churn) but declining as a share of mix
- Partner is worst on both dimensions — ROI should be evaluated immediately
- Organic brings the most users but second-worst retention — quantity over quality
- Channel mix is shifting toward worse-quality channels pre-launch
- December 2024: -47% signup crash heading into launch — acquisition momentum lost

---

## 4. Step 17 — Revenue Analysis

### 4.1 MRR Growth Phases

| Phase | Period | MoM Growth Range | Character |
|---|---|---|---|
| Phase 1 — Hypergrowth | Jan–May 2023 | 100–237% | Small base, explosive early growth |
| Phase 2 — Strong Growth | Jun 2023–Mar 2024 | 20–49% | Sustainable expansion |
| Phase 3 — Moderation | Apr–Nov 2024 | 13–20% | Deceleration as base grows |
| Phase 4 — Re-acceleration | Dec 2024 | 24.13% | Enterprise spike |

**Revenue milestones:**

| Milestone | Month Reached | Time from Start |
|---|---|---|
| $100K MRR | May 2023 | Month 5 |
| $500K MRR | Aug 2023 | Month 8 |
| $1M MRR | Nov 2023 | Month 11 |
| $5M MRR | Aug 2024 | Month 20 |
| $10M MRR | Dec 2024 | Month 24 |

$1M to $10M in 13 months reflects strong growth velocity in absolute terms. However, December's re-acceleration is entirely Enterprise-driven — not a broad-based recovery.

### 4.2 Plan Revenue Evolution

**Basic plan — dying in absolute terms:**

| Data Point | Value |
|---|---|
| Peak MRR | $19,779 (Aug 2023) |
| Dec 2024 MRR | $4,446 |
| Decline from peak | -$15,333 (-77.5%) |
| First absolute decline | Sep 2023 (-$3,363) |

Basic revenue has been declining in absolute terms since September 2023 — not just shrinking as a percentage of total, but actively losing dollars month over month. The plan is structurally dead.

**Pro plan — peaked and now declining:**

| Data Point | Value |
|---|---|
| Peak MRR | $235,342 (Nov 2024) |
| Dec 2024 MRR | $185,694 |
| Dec 2024 decline | -$49,648 |

Pro peaked in November 2024 and dropped $49,648 in a single month — the largest absolute Pro decline ever. This aligns directly with the downgrade rate hitting 6.60% in December.

**Enterprise — the entire revenue story:**

| Data Point | Value |
|---|---|
| Jan 2023 MRR | $3,753 |
| Dec 2024 MRR | $10,544,111 |
| Total growth | 2,808x |
| Dec 2024 single-month gain | +$2,138,262 |

Enterprise added $2.1M in revenue in a single month while Basic lost $2,299 and Pro lost $49,648. The plan mix is no longer a mix — it is a single-plan business.

**Plan contribution trend:**

| Month | Basic % | Pro % | Enterprise % |
|---|---|---|---|
| Jan 2023 | 0.0% | 19.9% | 80.1% |
| Jun 2023 | 4.6% | 17.9% | 77.5% |
| Jun 2024 | 0.4% | 5.5% | 94.1% |
| Dec 2024 | 0.0% | 1.7% | **98.2%** |

### 4.3 Revenue Concentration Risk

474 accounts appear in the concentration analysis. The 26 excluded accounts are the permanently lost accounts from `cohort_base` (ever_churned = TRUE, ever_reactivated = FALSE) with no active paid subscriptions — correctly excluded.

| Tier | Accounts | % of Accounts | MRR | % of MRR | Avg MRR/Account |
|---|---|---|---|---|---|
| Top 10% | 47 | 9.9% | $2,387,633 | **28.1%** | $50,801 |
| Top 25% | 71 | 15.0% | $1,958,631 | 23.0% | $27,586 |
| Top 50% | 119 | 25.1% | $2,225,170 | 26.2% | $18,699 |
| Bottom 50% | 237 | 50.0% | $1,935,924 | 22.8% | $8,168 |

Top 10% of accounts (47 accounts) generate 28.1% of all MRR. Top 25% (118 accounts) generate 51.1% of all MRR. More than half the revenue comes from less than a quarter of accounts.

**The surprising finding — concentration is not plan-tier driven:**

| Rank | Account | Entry Plan | Active Subs | Total MRR | Max Single Sub |
|---|---|---|---|---|---|
| 1 | A-5b1bcd | **Pro** | 15 | $133,298 | $14,527 |
| 2 | A-d4e0d4 | **Basic** | 10 | $138,060 | $23,283 |
| 3 | A-5a215a | Enterprise | 18 | $130,152 | $17,313 |
| 4 | A-1f0636 | **Pro** | 11 | $94,710 | $20,895 |
| 5 | A-30b4ca | **Basic** | 8 | $75,938 | $17,114 |

The top revenue account entered as Pro. The second-highest entered as Basic. Concentration risk spans all entry plan tiers — `plan_tier` in `accounts` is the entry plan, not the current state. These accounts have expanded massively through multiple subscriptions, upgrades, and seat growth over time.

**Concentration is driven by subscription accumulation, not single large contracts:**

- A-5b1bcd: 15 subscriptions × avg $8,887 = $133,298
- A-d4e0d4: 10 subscriptions × avg $13,806 = $138,060
- A-5a215a: 18 subscriptions × avg $7,231 = $130,152
- Highest single subscription in the top 5: $23,283 — not catastrophically large on its own

The risk is that losing one account means losing all of their subscriptions simultaneously. An account with 15 active subscriptions is not 15 separate loss events — it is one churn decision that removes $133K from MRR overnight.

**Notable anomaly — A-d4e0d4:** Entered as Basic in October 2024 and accumulated 10 subscriptions worth $138,060 in approximately 2 months. This is the fastest account expansion in the dataset. Either a genuine Enterprise-level buyer who signed up on the wrong plan tier, or a data artifact worth flagging.

### 4.4 ARPU Growth

| Month | ARPU |
|---|---|
| Jan 2023 | $2,342 |
| Jun 2023 | $3,814 (+63% in 6 months) |
| Jan 2024 | $7,435 (+100% year-on-year) |
| Jun 2024 | $11,574 |
| Dec 2024 | $21,469 (9.2x total) |

ARPU growing 9.2x while account count grew 250x confirms H1 completely. Revenue is driven by expansion within accounts that stay — not by acquiring new accounts. This is healthy upsell behavior, but it is entirely dependent on retaining the accounts that are expanding. If the high-ARPU accounts churn, the revenue engine collapses. This makes the 20.17% December churn rate an existential concern — not just an operational one.

### 4.5 Key Insights — Step 17

- Revenue grew 2,291x in 24 months — headline number looks exceptional
- Growth is almost entirely ARPU-driven — accounts that stay are buying 9.2x more
- Basic plan is dead: declining in absolute terms since Sep 2023, down 77.5% from peak
- Pro plan peaked Nov 2024 and dropped $49,648 in December alone
- Enterprise is 98.2% of MRR — the business is a single-plan revenue story
- Top 10% of accounts (47) generate 28.1% of MRR — extreme concentration
- Concentration is driven by subscription accumulation, not entry plan or single large deals
- Revenue growth masks account instability — MRR growing while customer base deteriorates

---

## 5. Step 18 — Upgrade/Downgrade Analysis

### 5.1 Rate Trend Overview

| Metric | Value | Benchmark Note |
|---|---|---|
| Average monthly upgrade rate | 10.00% | Strong upsell motion |
| Average monthly downgrade rate | 3.97% | Rising through 2024 |
| Net expansion classification | Positive in 22/24 months | |
| Contraction months | Feb 2023, Jul 2024 | Feb 2023 = early noise |

Upgrade rate has remained healthy at ~10% throughout the dataset. The concern is on the downgrade side — downgrade rate tripled from 2.42% in January 2024 to 6.60% in December 2024 within a single year.

**Expansion classification by month:**

| Classification | Definition | Month Count |
|---|---|---|
| Strong expansion | Net upgrade rate > 5% | 10 months |
| Mild expansion | Upgrades > downgrades, rate ≤ 5% | 12 months |
| Neutral | Upgrades = downgrades | 2 months |
| Contraction | Downgrades > upgrades | 2 months |

### 5.2 MRR Impact of Plan Movement

| Month | Upgrade MRR | Downgrade MRR | Net Expansion MRR | Status |
|---|---|---|---|---|
| Apr 2024 | $97,594 | $16,874 | **$80,720** | Peak expansion |
| Sep 2024 | $112,238 | $26,434 | $85,804 | Near-peak |
| Nov 2024 | $119,623 | $28,287 | **$91,336** | Highest net ever |
| Jul 2024 | $45,770 | $46,467 | **-$697** | Only true contraction |
| Dec 2024 | $160,180 | $133,955 | **$26,225** | Crisis compression |

**Net expansion MRR collapsed 71% in a single month** — from $91,336 in November to $26,225 in December — despite December recording the highest ever upgrade MRR ($160,180). The compression was entirely driven by downgrade MRR exploding to $133,955.

**July 2024 — The first contraction signal:** The only month where downgrade MRR exceeded upgrade MRR. On an account-count basis it still showed mild expansion (3 net upgrades), but on a revenue basis the expansion engine briefly reversed. This is a leading indicator that should have triggered investigation at the time.

### 5.3 High-Value Accounts Downgrading in December

The most important number in this step is the average MRR comparison for December 2024:

| Account Type | Avg MRR per Account (Dec 2024) |
|---|---|
| Upgrading accounts | $3,141 |
| Downgrading accounts | **$4,059** |

Downgrading accounts are worth 29% more per account than upgrading accounts in the final month of the dataset. The accounts reducing their commitment are your higher-value customers. Revenue quality is compressing even while upgrade counts reach all-time highs. This creates a false positive on the upgrade count metric while the underlying revenue health deteriorates.

September 2023 showed a similar pattern (avg downgrade MRR $3,747 vs upgrade MRR $2,865) — so this is not unprecedented, but December's scale makes it the clearest structural signal.

### 5.4 Highest Plan Movement Months

| Rank | Month | Total Changes | Upgrade Rate | Downgrade Rate | Total Movement Rate |
|---|---|---|---|---|---|
| 1 | Dec 2024 | 84 | 10.20% | 6.60% | 16.80% |
| 2 | Oct 2024 | 74 | 10.53% | 6.41% | **16.94%** |
| 3 | Nov 2024 | 64 | 10.13% | 3.38% | 13.51% |
| 4 | Sep 2024 | 47 | 8.19% | 3.13% | 11.32% |

December has the most raw plan changes (84) but October has the highest total movement *rate* (16.94%) — more volatile on a per-account basis. Both months signal maximum instability in the pre-launch window. All top 4 highest-movement months are in H2 2024.

### 5.5 Movement Type vs Churn Rate (H3 Refuted)

| Movement Type | Accounts | Churn Rate | Avg Months to First Churn | Avg Churn Events |
|---|---|---|---|---|
| Downgrade only | 62 | 72.6% | 4.5 | 1.18 |
| Upgrade only | 189 | 72.0% | 4.8 | 1.34 |
| Both directions | 94 | 71.3% | 4.1 | 1.12 |
| No movement | 155 | **67.1%** | 4.0 | 1.08 |

The gap between any movement type and no-movement is only ~5 percentage points. Plan movement at the account level is not a meaningful predictor of churn. All movement types cluster between 71–73% churn rate.

### 5.6 Downgrade-to-Churn Analysis (H3 Refuted)

| Preceding Downgrade | Churned Accounts | % of Churns | Avg Months to Churn | Avg Churn Events |
|---|---|---|---|---|
| FALSE | 327 | 88.4% | 4.0 | 2.06 |
| TRUE | 43 | **11.6%** | **4.9** | 1.94 |

Only 11.6% of churn events were preceded by a downgrade. Accounts with a preceding downgrade actually survived **longer** before churning (4.9 months vs 4.0 months) and had slightly fewer churn events (1.94 vs 2.06).

**Interpretation:** Downgrading may be a stabilization behavior, not an exit signal. Accounts reducing spend may be right-sizing their commitment to a level they can sustain rather than preparing to leave. This refutes the hypothesis and has a direct implication for Step 25 — the `preceding_downgrade_flag` should not be heavily weighted in the multi-factor churn risk model. Low feature usage and high support tickets will be stronger predictors.

### 5.7 Key Insights — Step 18

- Upgrade rate stable at ~10% — upsell motion is working
- Downgrade rate tripled in 2024: 2.42% (Jan) → 6.60% (Dec) — contraction pressure building
- Net expansion MRR collapsed 71% in December despite all-time high upgrade volume
- July 2024: first revenue contraction month — early warning signal of what December would bring
- December 2024: high-value accounts downgrading (avg $4,059 vs $3,141 upgrading) — quality compression
- Downgrade ≠ churn signal — downgraders survive 0.9 months longer than non-downgraders
- December 2024 is peak plan instability: 84 total changes, 16.80% total movement rate
- `preceding_downgrade_flag` should carry low weight in Step 25 multi-factor model

---

## 6. Cross-Step Insights

These are connections across all three steps that are invisible when any one step is read in isolation.

**6.1 — The Channel Quality → Revenue Quality Link**

Step 16 shows ads delivers the lowest churn rate (60.2%) and longest survival before first churn (5.1 months). Step 17 shows ARPU is growing 9.2x. Combining these: if ads customers survive longer and generate more revenue per account over time, the decline in ads channel share (from 52% in June 2024 to 12% in December 2024) is not just a churn problem — it is a future ARPU problem. Worse-quality cohorts joining through organic will have lower lifetime expansion potential even if they don't churn immediately.

**6.2 — Acquisition Volatility Feeding Revenue Concentration**

Step 16 shows signup growth is episodic — large spikes followed by declines. Step 17 shows top accounts drive disproportionate MRR through subscription accumulation. When acquisition is volatile and unreliable, the business becomes increasingly dependent on existing high-value accounts to sustain revenue growth. The concentration risk in Step 17 is a downstream consequence of the acquisition inconsistency in Step 16.

**6.3 — Plan Degradation Is Multi-Front**

Step 17 shows Basic dying and Pro peaking and declining. Step 18 shows the downgrade rate tripling through 2024 and high-value accounts leading the downgrades in December. Both steps point to the same structural pressure: accounts are moving down-tier or leaving the lower tiers entirely. The revenue story increasingly has only one plan doing any work.

**6.4 — December 2024 as a Convergence Point**

Three signals from three different steps all peak in December 2024:
- Step 16: Signup volume drops 47%
- Step 17: Basic and Pro revenue declining; Enterprise carrying everything
- Step 18: 84 total plan changes, highest ever; net expansion MRR collapses 71%

December 2024 is not one bad month — it is the convergence of acquisition deterioration, plan-tier hollowing, and expansion engine compression. All three Module 1 analyses confirm the same pre-launch crisis from different angles.

---

## 7. Business Implications for Launch

| Risk | Evidence | Severity |
|---|---|---|
| No repeatable acquisition engine | Volatile signups, no dominant channel, mix degrading | High |
| Channel quality deteriorating | Ads declining, organic surging — 15pp churn rate gap | High |
| Revenue is a single-plan story | Enterprise 98.2% of MRR, Basic dead, Pro declining | Critical |
| Revenue concentration | Top 10% of accounts = 28.1% of MRR, accumulation-driven | Critical |
| Expansion engine compressing | Net expansion MRR -71% in final month | High |
| Revenue masking account instability | MRR +24% while churn = 20.17% in December | Critical |
| Partner channel negative ROI | Worst quality AND worst volume — no redeeming metric | Moderate |
| High-value accounts leading downgrades | Avg downgrade MRR > avg upgrade MRR in Dec 2024 | High |

**One-sentence summary:** The business has built impressive revenue growth on an unstable foundation — a single plan tier, a shrinking quality acquisition channel, extreme revenue concentration, and an expansion engine that nearly stalled in the month before launch.

---

## 8. Recommendations from Module 1

**P1 — Scale ads acquisition aggressively before launch**
Ads has the lowest churn rate (60.2%), highest never-churned proportion (39.8%), and longest time to first churn (5.1 months). It currently represents only ~12% of signups. Identifying what drove the June 2024 ads spike (52% of signups that month) and replicating it should be the first acquisition priority. Every 1% shift from organic to ads reduces blended churn rate by ~0.14 percentage points.

**P2 — Evaluate and reduce partner channel investment**
Partner is last on both quality (75.3% churn) and volume (17.8% of signups). It is the only channel that is simultaneously worst on both dimensions. Without a clear path to improvement, the resource allocated to partner should be reallocated to ads or event channels.

**P3 — Build a Basic and Pro retention floor before launch**
Basic revenue has declined 77.5% from peak. Pro dropped $49,648 in a single month. The lower tiers are not just shrinking proportionally — they are collapsing. Without viable lower-tier plans, the pipeline to Enterprise upgrades disappears. New customers need an entry point that works. Fixing onboarding (Step 29 will quantify the Month 0–1 churn impact) is the mechanism — but the urgency comes from this revenue data.

**P4 — Investigate and address account concentration before launch**
Top 10% of accounts (47 accounts) generate 28.1% of MRR through subscription accumulation. Losing one of the top 5 accounts means losing $75K–$138K overnight. These accounts need dedicated success management, health monitoring, and renewal plans before launch brings new competitive pressure.

**P5 — Stabilize the expansion engine**
The downgrade rate tripled in 2024. Net expansion MRR dropped 71% in December. The upgrade motion works — 10% monthly upgrade rate is healthy — but it is being increasingly cancelled by downgrade pressure from high-value accounts. Understanding what drove the December downgrade spike (cross-reference with Step 24 support analysis and Step 23 usage analysis) is required before the expansion engine can be trusted as a growth lever post-launch.

---

*Module 1 complete. Feeds into: Module 2 (Steps 19–21, Churn Analysis), Phase 5 Insights (Step 29), and Dashboard Page 2 (Revenue & Growth).*
