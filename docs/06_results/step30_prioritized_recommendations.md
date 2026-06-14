# Step 30 — Prioritized Recommendations
**RavenStack SaaS Pre-Launch Analysis**
**Role:** Product Analyst
**Phase:** 5 — Insight & Decision Layer
**Status:** Complete
**Last Updated:** 2026-05-13

---

## Document Purpose

This document translates the ten key insights from Step 29 into a prioritized, actionable recommendation set. Each recommendation is scoped, assigned a priority tier, tied to specific evidence, and paired with a measurable success metric so impact can be tracked after implementation.

Recommendations are organized by time horizon — what must happen before launch, what must happen in the first 90 days post-launch, and what represents the medium-term structural fix. Within each horizon, recommendations are ordered by expected impact.

---

## Prioritization Framework

Each recommendation is scored across three dimensions:

**Impact:** How much does this move the needle on the core metric (churn rate or MRR stability)?
**Speed:** How quickly can this be implemented before or shortly after launch?
**Evidence strength:** How directly does the data support this action vs inference?

| Tier | Definition |
|---|---|
| P0 — Pre-launch critical | Must be done before public launch. Not doing this increases launch risk materially. |
| P1 — First 30 days | High impact, implementable within the first month post-launch. |
| P2 — First 90 days | Important structural improvements requiring more planning or resource. |
| P3 — Medium-term | Strategic changes with longer implementation cycles but necessary for long-term health. |

---

## Pre-Launch Recommendations (P0)

### R1 — Deploy the Risk Model as a CS Action Queue Before Launch
**Priority:** P0
**Tied to:** Insight 9 (risk model), Insight 1 (revenue masking)
**Target:** 135 accounts (1 high-risk + 134 medium-risk) holding $2.68M MRR

**What to do:**
Connect `analysis_churn_risk_scores` directly to the CS team's workflow. Sort by risk_score descending, filter to medium and high tiers, and assign each account a CS owner before launch day. The `recommended_action` column already encodes the specific intervention per account — no additional analysis required. Execution is the only remaining step.

Special handling for two accounts regardless of tier:
- A-0f6450 (87.5 score, $23,800, zero usage + escalation): immediate activation call — this account has paid for the product and never used it while simultaneously generating escalated support tickets
- A-c58f49 (66.3 score, $70,980 Enterprise, escalation): executive-level relationship check-in — highest revenue exposure in the top-risk cohort despite medium-tier classification

**Why before launch:** Post-launch brings new accounts and new urgency. The window to save these 135 accounts before they experience launch disruption is now. Churn from this cohort immediately post-launch would be attributed to launch quality issues rather than pre-existing risk, making it harder to diagnose and respond to.

**Success metric:** 30-day retention rate for medium+high risk accounts post-intervention vs control group (low-risk accounts). Target: reduce churn rate from historical 70.1% to below 60% for the intervened cohort within 90 days.

---

### R2 — Fix the Escalation Resolution Pipeline Before Launch
**Priority:** P0
**Tied to:** Insight 8 (support — escalation is the only confirmed churn signal)
**Target:** Escalated accounts — 75.8% churn rate vs 69.3% for non-escalated (+6.5pp gap)

**What to do:**
Implement a mandatory escalation follow-up protocol: within 48 hours of an escalated ticket closing, a CS representative (not the support agent) contacts the account to confirm resolution satisfaction. This is not a CSAT survey — it is a human contact that acknowledges the escalation happened, confirms the issue is resolved, and offers a specific next step (a call, a feature walkthrough, or a credit if appropriate).

Additionally, review the current escalation backlog. Any account with an open or recently closed escalation that has not received a follow-up call should be contacted before launch. The `analysis_support_account_level` view identifies all accounts with `has_escalation = TRUE` — 91 accounts total, 75.8% of whom have already churned at least once.

**Why before launch:** Escalation is the only support signal that correlates with churn in the data. Launching with an unresolved escalation backlog means the highest-frustration accounts enter the launch period without acknowledgment. This is the highest-probability support-to-churn pathway.

**Success metric:** Track churn rate for escalated accounts over the 90 days post-intervention. Baseline is 75.8%. Target is below 70% (bringing escalated accounts in line with the non-escalated population).

---

### R3 — Implement a Structured Month 1 Value Demonstration Program
**Priority:** P0
**Tied to:** Insight 5 (Month 1 is the highest-leverage window), Insight 7 (no feature critical mass)
**Target:** All new accounts — 36.4% of all lifetime churns happen in months 0–1

**What to do:**
Design and implement a 30-day onboarding sequence with one specific goal: create a measurable, articulable value moment before the first renewal decision. The sequence has three components:

**Day 1–3 — Activation:** Every new account is automatically enrolled in a guided setup experience centered on the three core features with the strongest retention correlation: feature_3, feature_21, and feature_39 (adopter churn rates 46.7%, 53.8%, 56.3% respectively — all beta features currently at <3.5% adoption). These are not introduced as "beta" — they are introduced as the product's most powerful capabilities.

**Day 7–14 — Value checkpoint:** An automated in-product prompt asks the account to identify one specific outcome they are trying to achieve. This is stored and used to personalize the Day 21 touchpoint. If the account has not used any feature by Day 7, this triggers a CS outreach (activation call — not a support ticket).

**Day 21 — Outcome review:** CS sends a one-question email: "Has [product] helped you achieve [stated outcome]?" If yes — the account has articulated value and is significantly less likely to churn at Month 1 renewal. If no — CS has 9 days to recover the account before the renewal decision.

**Why before launch:** This program needs to be operational on Day 1 of public launch. New cohorts entering post-launch are even faster-churning than the December 2024 cohort (avg 2.0 months to first churn). Without an active value demonstration program, the post-launch cohort quality will continue to deteriorate.

**Success metric:** Month 1 survival rate for cohorts onboarded with the program vs historical baseline. Historical 2024 cohort avg Month 1 survival: 67.0%. Target: above 78% (matching the 2023 cohort benchmark before deterioration began).

---

### R4 — Reallocate Acquisition Budget to Restore Ads Channel Share to Minimum 30%
**Priority:** P0
**Tied to:** Insight 3 (acquisition quality drives churn), Insight 6 (cohort quality deterioration)
**Target:** Ads channel currently ~12% of signups, was 52% in June 2024

**What to do:**
Investigate what drove the June 2024 ads spike (52.4% of signups that month — the highest ads concentration in the dataset and the period immediately before the churn acceleration began in the same month). If the spike was driven by a specific campaign, keyword set, or creative, that playbook should be reactivated for launch.

Simultaneously, reduce partner channel spend as a proportion of acquisition budget. Partner is the worst-performing channel on every metric — highest churn rate (75.3%), lowest never-churned rate (24.7%), worst reactivation rate (88.1%), worst survival rank — while also generating the fewest signups (17.8% of total). It is the only channel that is simultaneously worst on both quality and volume dimensions.

Target channel mix for launch period: ads ≥ 30%, event ≥ 20%, partner ≤ 10%.

**Why before launch:** Channel mix at launch determines the quality of the inaugural public cohorts. Post-launch cohorts will be scrutinized by investors and leadership. A launch cohort with 60.2% churn rate (ads) looks dramatically different from one with 75.3% (partner) when Month 1 metrics are reported. The window to set the channel mix before launch cohorts are measured is the pre-launch period.

**Success metric:** First three post-launch cohort Month 3 survival rate. Historical baseline for mixed channel: ~52% at Month 3 for 2024 cohorts. Target with ads-dominant mix: above 62% (matching 2023 early cohort quality).

---

## First 30 Days Post-Launch Recommendations (P1)

### R5 — Create a Dedicated Customer Success Program for the Top 10% of Accounts by MRR
**Priority:** P1
**Tied to:** Insight 4 (Enterprise concentration risk), Insight 9 (risk model)
**Target:** 47 accounts generating 28.1% of MRR ($2.39M)

**What to do:**
The top 47 accounts by MRR are identified in `analysis_revenue_concentration`. Each holds between $50,801 and $138,060 in current MRR accumulated through multiple simultaneous subscriptions — not single large contracts. Losing one account is not losing one contract; it is losing an entire subscription portfolio.

Assign each of the top 47 accounts a named CS owner (not a shared queue). The owner's mandate is:
- Monthly check-in call (not an automated survey)
- Awareness of all support tickets the account raises — CS owner is notified within 24 hours of any ticket submission
- Quarterly business review that connects product usage to the account's stated business objectives
- Early warning flagging: if the account's MRR decreases (downgrade) or ticket volume spikes, CS owner receives an automatic alert within 24 hours

Additionally, the A-d4e0d4 anomaly (Basic entry plan, joined October 2024, accumulated $138,060 MRR in 2 months across 10 subscriptions) should be investigated immediately. This is either the fastest genuine account expansion in the dataset or a data artifact. If genuine, this account is proof that rapid high-value expansion is possible and should be understood as a model for CS-driven expansion.

**Success metric:** MRR retention rate for top 47 accounts at 90 days post-launch. Target: 95%+ MRR retention (no more than 2 of 47 accounts churning or materially downgrading in the first quarter post-launch).

---

### R6 — Establish Support Resolution Time Below 30 Hours as a Hard Operational Target
**Priority:** P1
**Tied to:** Insight 8 (support structural deficit), Insight 2 (no KPI has ever reached benchmark)
**Target:** Current avg resolution 35.9 hours vs 24-hour benchmark — reduce to 30 hours as first milestone

**What to do:**
The 24-hour benchmark is the industry standard but represents a 33% improvement from current performance. A more achievable 90-day target is 30 hours (a 16% improvement), with a 6-month target of 24 hours.

Specific operational changes to get from 35.9 to 30 hours:
- Triage optimization: review the priority classification accuracy. The data shows 16–29 urgent tickets per month alongside 11–30 low-priority tickets. If urgent tickets are not being resolved in under 4 hours, the triage system is not functioning. Check whether high/urgent tickets are being resolved faster than medium/low (the Step 24 priority matrix should reveal this).
- First response time: currently 81.5–98.3 minutes vs 60-minute benchmark. This is addressable through staffing schedule alignment — if most tickets arrive outside of peak coverage hours, a scheduling adjustment alone could close most of the first-response gap without adding headcount.
- CSAT response rate: 58.75% of closed tickets have a CSAT response. The 41.25% non-response rate represents the most dissatisfied accounts who chose not to rate — prioritizing follow-up for non-respondents within 48 hours of ticket closure can surface hidden dissatisfaction before it becomes churn.

**Success metric:** Monthly avg resolution time below 30 hours within 30 days of launch. CSAT response rate above 65% within 60 days. First response time below 75 minutes within 30 days.

---

### R7 — Surface the Three High-Retention Beta Features in All Onboarding Touchpoints
**Priority:** P1
**Tied to:** Insight 10 (hidden retention anchors), Insight 7 (feature sprawl)
**Target:** feature_3 (46.7% adopter churn), feature_21 (53.8%), feature_39 (56.3%)

**What to do:**
Remove the "beta" label from feature_3, feature_21, and feature_39 in the product interface. These features have error rates on par with GA features (confirmed in Step 22 — beta error rate 0.0517 vs GA 0.0540). The "beta" label is suppressing adoption without any quality justification.

Add all three features to the default onboarding checklist — the first-run experience that guides new accounts through the product. Currently, onboarding presumably surfaces the most-used features. Based on the retention data, it should surface the features whose adopters survive longest, not the ones most accounts happen to click first.

In email onboarding sequences, include a dedicated "hidden capability" email at Day 10 that showcases one of the three features with a specific use-case demonstration. Day 10 is chosen because it sits between the Day 7 activation checkpoint and the Day 21 outcome review — giving the account a discovery moment before the outcome assessment.

**Success metric:** Combined adoption rate for feature_3 + feature_21 + feature_39 to exceed 10% within 60 days of launch (up from current ~3%). Monitor Month 1 survival rate for accounts that activated at least one of the three features vs those that did not.

---

## First 90 Days Post-Launch Recommendations (P2)

### R8 — Rebuild the Basic and Pro Plan Value Proposition
**Priority:** P2
**Tied to:** Insight 4 (Enterprise concentration risk), Insight 3 (acquisition quality)
**Target:** Basic MRR at -77.5% from peak; Pro peaked November 2024, dropping; 2024 cohorts cite budget +6.4pp, pricing +5.3pp as churn reasons

**What to do:**
The Basic and Pro plans are dying because their price-to-value ratio has become misaligned as the product scaled toward Enterprise. Two possible interventions depending on strategic direction:

**Option A — Tiered feature access redesign:** Make the lower tiers genuinely valuable by gating specific high-retention features behind paid tiers, creating a natural upgrade path. Currently, the flat feature adoption distribution (2–5% across all 40 GA features for all tiers) suggests no meaningful feature differentiation between plans. If feature_3, feature_21, and feature_39 are the highest-retention features, restricting their full functionality to Pro and Enterprise creates both upgrade motivation and a clear value proposition for each tier.

**Option B — Pricing restructure:** The 2024 cohort shift toward budget and pricing as churn reasons (budget +6.4pp, pricing +5.3pp vs 2023 cohorts) indicates the current pricing does not match the value perception of the acquisition cohorts being reached through organic and other channels. A usage-based or seat-based component for the Basic tier — where accounts pay proportionally to their actual use — reduces the price shock at Month 1 renewal because accounts that used the product less pay less, and accounts that used it heavily have demonstrated value before renewal.

**Do not attempt both simultaneously.** Pick one direction, implement it cleanly, and measure the effect on Basic and Pro plan retention rates over 90 days.

**Success metric:** Basic and Pro plan absolute MRR stabilization within 90 days (halt the decline). Month 1 survival rate for Basic plan accounts above 70% (current 2024 cohort avg: 67.0%).

---

### R9 — Conduct Exit Interviews for Every Enterprise Churn Event
**Priority:** P2
**Tied to:** Insight 4 (Enterprise concentration), Module 2 (Enterprise unknown churn 17.7% — highest of any plan-reason combination)
**Target:** Enterprise accounts citing "unknown" reason — 17.7% of Enterprise churns, highest of any plan-reason combination

**What to do:**
Implement a mandatory exit interview protocol for every Enterprise account churn event — including reactivations. The interview is not automated. It is a 20-minute call conducted by a senior CS representative or account executive within 7 days of the churn event, with a structured set of five questions:
1. What was the primary reason you decided to stop at this time?
2. Was there a specific event or experience that triggered the decision?
3. What would the product have needed to do differently to retain you?
4. Are you evaluating alternatives? If so, what is drawing you to them?
5. Under what conditions would you consider returning?

The "unknown" churn reason is disproportionately concentrated in Enterprise accounts because Enterprise accounts have more sophisticated evaluation processes and less willingness to provide qualitative feedback through standard channels. The exit interview converts this unknown signal into product intelligence.

Store all interview responses in a structured format that can be analyzed quarterly. After 20 interviews, pattern-match the responses against the six standard churn reason codes to identify whether "unknown" represents a seventh unmapped reason category.

**Success metric:** Reduce Enterprise unknown churn proportion from 17.7% to below 12% within 6 months (by converting unknown exits into known reasons through interview completion). Secondary metric: one actionable product or pricing change directly traceable to exit interview findings within the first quarter.

---

### R10 — Investigate and Replicate the March 2024 Acquisition Spike
**Priority:** P2
**Tied to:** Insight 3 (acquisition quality), Step 16 findings
**Target:** March 2024 showed +107.69% MoM signup growth (13 → 27 accounts) — largest single-month jump in dataset

**What to do:**
March 2024 is an unexplained anomaly with a specific characteristic worth understanding: ads accounted for 38.5% of signups that month (vs ~18% typical), suggesting a campaign-driven spike. If a specific ads campaign, keyword set, creative type, or targeting change drove March 2024's performance, identifying and replicating it for launch is the highest-ROI acquisition investment available.

Investigation steps:
1. Pull ad campaign data for February–March 2024 and identify what changed — new creative, new audience, new keyword, new platform, or increased budget
2. Calculate March 2024 cohort 3-month survival rate vs surrounding months (to confirm the quality of the signups alongside the volume)
3. If the cohort quality is comparable and the campaign element is identifiable, use it as the launch campaign template

If March 2024 was a one-time event driven by an identifiable external factor (a conference, a partnership announcement, a media mention), evaluate whether that factor can be engineered for launch week.

**Success metric:** Launch week signup volume above 30 accounts (matching the March 2024 peak) with ads channel representing ≥35% of signups.

---

## Medium-Term Structural Recommendations (P3)

### R11 — Migrate from Reactivation Dependency to First-Churn Prevention as the Core Retention Strategy
**Priority:** P3
**Tied to:** Insight 6 (reactivation gap), Insight 1 (structural hollowing)
**Target:** Reactivation gap reaches 70.59pp at Month 23 — 65.2% of all accounts are cyclical churners

**What to do:**
The current implicit retention model relies on reactivation to maintain the active base. This is a reactive and expensive strategy — each churn and reactivation cycle costs CS time, revenue-gap periods, and customer relationship capital. The medium-term goal is to shift the primary retention investment from post-churn recovery to pre-churn prevention.

This requires three things that do not currently exist:
1. **A leading indicator dashboard:** Currently, no behavioral signal reliably predicts churn before it happens. The medium-term product and data investment is identifying a metric that does — whether that is a specific in-product action, a support interaction pattern, or a usage velocity change. This requires a larger dataset than the current 24 months and a holdout validation methodology.
2. **A reactivation cost accounting system:** Make the cost of each churn-reactivation cycle visible. Every time an account churns and returns, there is a revenue gap, a CS effort cost, and a reactivation incentive cost (often implicit in the account restart terms). Quantifying this per cycle makes the ROI of pre-churn prevention concrete and compelling for resource allocation decisions.
3. **A product stickiness investment:** The feature sprawl analysis (Insight 7) shows no feature has critical mass. The medium-term product strategy should concentrate on making 5–8 features deeply indispensable rather than expanding the feature set. Adoption depth in a small feature core creates switching cost that reactivation-based models do not.

**Success metric:** 2-year post-launch target — reduce the reactivation gap from its current trajectory toward a stable 30pp or below (meaning fewer than 30% of active accounts at Month 12 have churned and returned). This is a 3-year goal, not a 90-day one.

---

### R12 — Develop a Germany Market Strategy as a Product-Market Fit Template
**Priority:** P3
**Tied to:** Insight 3 (acquisition quality), Step 20 (Germany: 56.0% churn — 14.4pp below overall average)
**Target:** Germany: 25 accounts, 56.0% churn rate, 44.0% never-churned, 7.4 months avg survival

**What to do:**
Germany is the strongest geographic market in the dataset by a significant margin — 14.4pp better than the overall average, 21.6pp better than the UK, and 80% longer average survival before first churn (7.4 months vs 4.1 months for the US). This is not a volume story (25 accounts), but it is a product-market fit signal that no other geography matches.

The medium-term action is to understand why Germany works:
1. What industries do German accounts come from, and does this match the HealthTech/FinTech industries that show the best churn rates overall?
2. What referral channels bring German accounts? If they are predominantly ads or event, this compounds the acquisition quality signal.
3. What features do German accounts use most, and does this overlap with the high-retention beta features (feature_3, feature_21, feature_39)?
4. Is there a common use case, buyer persona, or decision-maker type among German accounts that explains the fit?

The answers to these questions produce the "ideal customer profile" that marketing, sales, and product can target at launch and beyond. If Germany's performance is replicable — by finding the same buyer type, use case, and channel in other geographies — it represents the clearest path to a structurally lower churn rate through targeted acquisition rather than product investment.

**Success metric:** Define the Germany customer profile within 60 days of launch. Target 10 new accounts matching that profile within 180 days. Monitor their 3-month survival rate as a benchmark for whether the profile is truly predictive.

---

## Recommendation Summary Table

| # | Recommendation | Priority | Insight | Primary Metric | Target |
|---|---|---|---|---|---|
| R1 | Deploy risk model as CS action queue | P0 | 9 | Churn rate of medium+high risk accounts | < 60% within 90 days |
| R2 | Fix escalation resolution pipeline | P0 | 8 | Escalated account churn rate | < 70% (from 75.8%) |
| R3 | Implement Month 1 value demonstration program | P0 | 5, 7 | Month 1 survival rate | > 78% for new cohorts |
| R4 | Restore ads channel share to ≥30% | P0 | 3, 6 | Launch cohort Month 3 survival | > 62% |
| R5 | CS program for top 47 accounts by MRR | P1 | 4, 9 | MRR retention — top 47 accounts | ≥ 95% MRR retained at 90 days |
| R6 | Resolution time below 30 hours | P1 | 8, 2 | Avg resolution time | < 30 hours within 30 days |
| R7 | Surface top-3 beta features in onboarding | P1 | 10, 7 | Combined adoption rate | > 10% within 60 days |
| R8 | Rebuild Basic and Pro value proposition | P2 | 4, 3 | Basic/Pro MRR change | Halt decline within 90 days |
| R9 | Exit interviews for every Enterprise churn | P2 | 4, Insight 2 | Enterprise unknown churn % | < 12% within 6 months |
| R10 | Investigate and replicate March 2024 spike | P2 | 3 | Launch week signups | > 30 with ≥35% ads share |
| R11 | Shift from reactivation to first-churn prevention | P3 | 6, 1 | Reactivation gap at Month 12 | < 30pp by Year 2 |
| R12 | Germany market strategy as PMF template | P3 | 3 | New Germany-profile accounts | 10 accounts in 180 days |

---

## What These Recommendations Are Not

**Not a product roadmap.** The recommendations do not specify which features to build, redesign, or sunset. They specify which existing features to surface (R7), how to structure the onboarding around existing capabilities (R3), and how to investigate product-market fit (R12). Feature-level product decisions require additional customer research beyond this dataset.

**Not a silver bullet.** No single recommendation closes the gap from 11.41% average monthly churn to the 2–5% benchmark range. The gap requires all four P0 recommendations working simultaneously — channel mix, onboarding, escalation, and risk-based CS intervention. Any one alone improves a specific metric but leaves the structural problem partially intact.

**Not a prediction.** Step 25 established that the risk model identifies the direction of risk but cannot precisely predict which accounts will churn. The recommendations are based on the best available evidence, not certainties. Each recommendation includes a success metric — if the metric does not move within the specified timeframe, the recommendation should be re-evaluated.

---

*Step 30 complete. Feeds into: Step 31 (Business Impact Estimation — quantifying the MRR and churn rate impact of implementing these recommendations), Executive Summary dashboard page, and Phase 7 Case Study recommendations section.*
