# RavenStack — SaaS Pre-Launch Performance Analysis

> A full-stack SQL analytics project analyzing 24 months of synthetic pre-launch SaaS data across 500 accounts, 5,000 subscriptions, 25,000 feature usage events, 2,000 support tickets, and 600 churn events — built across a 4-layer SQL architecture with 41 views, 28 analytical steps, and a full Phase 5 insight and decision layer.

---

## The Business Problem

RavenStack is a stealth-mode B2B SaaS startup preparing for public launch. Before going live, leadership needs to understand the health of the existing customer base — not just the headline MRR number, but the structural dynamics underneath it.

The data tells a story that the revenue chart alone cannot:

- MRR grew **2,291×** in 24 months — from $4,684 to $10,734,251
- **70.4%** of all 500 accounts churned at least once
- December 2024 hit a **20.17% monthly churn rate** — 96 accounts lost in a single month
- 2024 cohorts are churning **3.6× faster** than 2023 cohorts
- The retention matrix makes 2024 look like an improvement — the survival curve proves it is not

This project answers the question leadership actually needed answered: *Is the business ready for launch, and what must change before it is?*

---

## Project Architecture

```
ravenstack-analysis/
│
├── data/
│   └── synthetic_dataset/
│       ├── accounts.csv            # 500 accounts
│       ├── subscriptions.csv       # 5,000 subscription records
│       ├── feature_usage.csv       # 25,000 usage events
│       ├── support_tickets.csv     # 2,000 tickets
│       └── churn_events.csv        # 600 churn events
│
├── sql/
│   ├── 00_schema_setup.sql
│   │
│   ├── base_layer/
│   │   ├── 01_base_accounts.sql
│   │   ├── 02_base_active_monthly.sql
│   │   ├── 03_base_mrr_monthly.sql
│   │   ├── 04_base_churn_monthly.sql
│   │   └── 05_base_feature_usage_monthly.sql
│   │
│   ├── kpi_layer/
│   │   ├── 06_kpi_churn_rate.sql
│   │   ├── 07_kpi_retention_rate.sql
│   │   ├── 08_kpi_mrr_growth.sql
│   │   ├── 09_kpi_active_users.sql
│   │   ├── 10_kpi_feature_adoption.sql
│   │   ├── 11_kpi_revenue_churn_rate.sql
│   │   ├── 12_kpi_upgrade_downgrade.sql
│   │   └── 13_kpi_support_metrics.sql
│   │
│   ├── cohort_layer/
│   │   ├── 14_cohort_base.sql
│   │   ├── 15_cohort_retention_matrix.sql
│   │   └── 15_cohort_survival_curve.sql
│   │
│   └── analysis_layer/
│       ├── 16_17_18_user_revenue_analysis.sql
│       ├── 19_20_21_churn_analysis.sql
│       ├── 22_23_feature_usage_analysis.sql
│       ├── 24_support_impact_analysis.sql
│       ├── 25_multi_factor_churn_model.sql
│       ├── 26_lifecycle_journey_analysis.sql
│       ├── 27_cohort_retention_analysis.sql
│       └── 28_beta_feature_impact.sql
│
└── docs/
    ├── phase4_advanced_analysis.md
    ├── phase5_key_insights.md
    ├── phase5_recommendations.md
    ├── phase5_business_impact.md
    └── project_story.md
```

---

## Dataset

Fully synthetic dataset sourced from Kaggle, created by **River @ Rivalytics** and distributed under a permissive MIT-like license. Used here for learning and portfolio purposes with full credit to the original author. No real customer data used anywhere.

**Source:** [Kaggle — River @ Rivalytics](https://www.kaggle.com/) *(replace with direct dataset URL)*
**License:** MIT-like — free to use for learning, research, and portfolio purposes with attribution

| Table | Rows | Key Columns |
|---|---|---|
| `accounts` | 500 | account_id, signup_date, industry, country, referral_source, plan_tier |
| `subscriptions` | 5,000 | account_id, plan_tier, mrr_amount, start_date, end_date, is_trial |
| `feature_usage` | 25,000 | account_id, feature_name, usage_date, usage_count, is_beta_feature |
| `support_tickets` | 2,000 | account_id, priority, resolution_time_hours, satisfaction_score, escalation_flag |
| `churn_events` | 600 | account_id, churn_date, churn_reason, preceding_downgrade_flag |

**Coverage:** January 2023 – December 2024 (24 months)
**Industries:** HealthTech, FinTech, Cybersecurity, EdTech, DevTools
**Countries:** US, UK, Germany, Canada, India, Australia
**Plan tiers:** Basic, Pro, Enterprise
**Features:** 40 total — 24 GA + 16 beta

---

## SQL Architecture — 4 Layers, 41 Views

The project follows a strict layered architecture. Every layer reads only from the layer below it. No analysis view ever queries a raw table directly.

```
Raw Tables (5)
     ↓
Layer 1 — Base Views (5)      Clean, typed, monthly grain
     ↓
Layer 2 — KPI Views (8)       Monthly business metrics + benchmarks
     ↓
Layer 3 — Cohort Views (3)    Retention matrix + survival curve
     ↓
Layer 4 — Analysis Views (27) Deep analysis + risk model
```

### Layer 1 — Base Layer (5 views)

Cleans raw tables, standardizes data types, derives calculated fields, and creates a reliable monthly grain across all 5 source tables. Everything downstream reads from these — never raw tables.

| View | Purpose |
|---|---|
| `base_accounts` | Cleaned account spine with derived attributes |
| `base_active_monthly` | Monthly active account population |
| `base_mrr_monthly` | Monthly MRR by account and plan |
| `base_churn_monthly` | Monthly churn events with preceding downgrade flag |
| `base_feature_usage_monthly` | Monthly feature usage with GA/beta classification |

### Layer 2 — KPI Layer (8 views)

Computes monthly business KPIs with benchmark comparisons, reliability flags, MoM change calculations, and classification tiers. Feeds dashboard KPI cards and trend charts.

| View | Key Metric |
|---|---|
| `kpi_monthly_churn_rate` | Monthly churn rate % with benchmark gap and reliability flag |
| `kpi_monthly_retention_rate` | Monthly retention rate % |
| `kpi_monthly_mrr_growth` | Total MRR, ARPU, MoM growth, plan breakdown |
| `kpi_monthly_active_users` | Active account count, new vs returning split |
| `kpi_monthly_feature_adoption` | Per-feature adoption rates, breadth, depth |
| `kpi_monthly_revenue_churn_rate` | Revenue churn rate % with benchmark |
| `kpi_monthly_upgrade_downgrade` | Upgrade/downgrade counts and MRR impact |
| `kpi_monthly_support_metrics` | CSAT, resolution time, escalation rate, response time |

### Layer 3 — Cohort Layer (3 views)

The two most analytically important views in the project — the retention matrix and survival curve — plus the cohort base that powers all segmentation.

| View | Purpose |
|---|---|
| `cohort_base` | One row per account with behavioral attributes, churn flags, and cohort month |
| `cohort_retention_matrix` | Retention rate per cohort per month (reactivation-inclusive) |
| `cohort_survival_curve` | First-churn survival rate per cohort per month (true survival) |

The gap between `cohort_retention_matrix` and `cohort_survival_curve` at each month is the **reactivation gap** — the single most important structural finding in the project.

### Layer 4 — Analysis Layer (27 views across 8 steps)

| Step | File | Views Created | Analytical Focus |
|---|---|---|---|
| 16–18 | `user_revenue_analysis.sql` | 7 views | User growth by channel, MRR phases, upgrade/downgrade dynamics |
| 19–21 | `churn_analysis.sql` | 8 views | Churn rate trend, segmentation by plan/industry/country/reason |
| 22–23 | `feature_usage_analysis.sql` | 6 views | Adoption ranking, breadth vs depth, usage vs churn correlation |
| 24 | `support_impact_analysis.sql` | 3 views | Support quality vs churn — monthly and account-level |
| 25 | `multi_factor_churn_model.sql` | 2 views | Multi-signal risk scoring model, account risk queue |
| 26 | `lifecycle_journey_analysis.sql` | 2 views | Signup → subscription → usage → support → churn funnel |
| 27 | `cohort_retention_analysis.sql` | 3 views | Month 1 deep dive, 2023 vs 2024, reactivation gap quantification |
| 28 | `beta_feature_impact.sql` | 2 views | Beta vs GA churn, per-feature retention signals |

---

## SQL Techniques Used

```sql
-- Window functions
LAG(), LEAD(), RANK(), DENSE_RANK(), ROW_NUMBER()
SUM() OVER (PARTITION BY ... ORDER BY ...)
PERCENTILE_CONT() WITHIN GROUP (ORDER BY ...)

-- Conditional aggregation
COUNT(*) FILTER (WHERE condition)
AVG(column) FILTER (WHERE condition)
BOOL_OR(flag) FILTER (WHERE condition)

-- Cohort analysis pattern
DATE_TRUNC('month', signup_date)                          AS cohort_month,
DATE_TRUNC('month', activity_date)                        AS activity_month,
EXTRACT(MONTH FROM AGE(activity_month, cohort_month))     AS months_since_signup

-- Self-join retention matrix
FROM cohort_base cb
LEFT JOIN base_active_monthly bam
    ON  cb.account_id = bam.account_id
    AND bam.month BETWEEN cb.cohort_month
                      AND cb.cohort_month + INTERVAL '23 months'

-- Multi-signal risk scoring with normalization
ROUND(
    (usage_score + support_score + downgrade_score)::NUMERIC
    / 80 * 100, 1
) AS risk_score

-- Survival curve with cumulative churn
SUM(churned_this_month) OVER (
    PARTITION BY cohort_month
    ORDER BY months_since_signup
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
) AS churned_by_month_n
```

---

## Key Findings

### The Master Finding
> Feature usage, CSAT scores, and beta adoption do not predict which accounts churn. High-usage accounts churn at 71.9% — nearly identical to low-usage at 70.5%. The churn crisis is structurally driven by acquisition channel quality and pricing friction, not product experience failures.

### Revenue & Growth

- MRR: $4,684 → $10,734,251 — 2,291× in 24 months
- ARPU: $2,342 → $21,469 — 9.2× growth driven by Enterprise expansion
- Enterprise MRR concentration: 80.1% (Jan 2023) → 98.2% (Dec 2024)
- Basic plan MRR down 77.5% from peak — lower-tier pipeline collapsing
- Top 47 accounts (10%) generate 28.1% of all MRR through subscription accumulation
- Ads channel: 60.2% churn, 39.8% never churned — best quality, declining from 52% → 12% of mix
- Partner channel: 75.3% churn, 23.1% never churned — worst quality

### Churn

- 352 of 500 accounts (70.4%) churned at least once — 79.3% reactivated
- Average monthly churn rate: 11.41% — 2–4× above the 2–5% industry benchmark
- Only 1 of 22 reliable months (Feb 2024, 4.63%) ever reached the benchmark range
- December 2024: 20.17% — 96 accounts lost in a single month
- June 2024: confirmed structural inflection — crossed 10%, never recovered
- All 6 churn reason codes within 3.7pp — no single fixable cause
- Germany: 56.0% churn rate — 14.4pp below average — strongest geographic market
- 2024 cohorts avg 2.0 months to first churn vs 7.2 months for 2023 cohorts

### Feature Usage

- Top feature adoption: 5.05% — less than ¼ of the 20% benchmark lower bound
- Usage does NOT predict churn — high-usage accounts churn at 71.9%, low-usage at 70.5%
- Beta features 4.3× less adopted than GA despite identical usage intensity and error rates
- Beta adoption grew 0% → 16.6% over 24 months
- `feature_3` adopters: 46.7% churn (−23.7pp vs average) — best retention signal in dataset
- `feature_21` adopters: 53.8% churn (−16.6pp)
- `feature_39` adopters: 56.3% churn (−14.1pp)
- All three hidden at <3.5% adoption rate

### Support

- All 22 reliable months classified "poor" or "critical" — benchmark never reached in 24 months
- Avg resolution time: 35.9 hours vs 24-hour benchmark
- Avg CSAT: 3.98 vs 4.5+ benchmark
- CSAT for churned accounts: 3.96 vs never-churned: 3.97 — 0.01 difference, not predictive
- Escalation is the only valid support churn signal: 75.8% vs 69.3% (+6.5pp gap)
- 6–10 ticket accounts (63.2% churn) outperform 3–5 ticket accounts (72.9%) — more tickets = more engagement, not more risk

### Cohort Retention — The Reactivation Paradox

- 2024 cohorts: avg Month 1 retention 91.6% vs 2023 cohorts 52.9% — appears dramatically better
- 2024 cohorts: avg Month 1 survival 67.0% vs 2023 cohorts 89.5% — actually significantly worse
- Reactivation gap grows from 9.62pp (Month 0) to 70.59pp (Month 23) — never stabilizes
- Median survival month: Feb 2023 cohort = Month 20, Dec 2024 cohort = Month 0
- After Month 6, virtually no account permanently exits — the loyal base is resilient once reached

### Multi-Factor Risk Model

- Signals: feature usage (max 40pts) + support intensity + escalation modifier (max 30pts) + preceding downgrade (max 10pts), normalized to 0–100
- 1 high-risk account: A-0f6450 (Pro, $23,800 MRR, score 87.5, zero usage + escalation)
- 134 medium-risk accounts: $2,652,134 MRR
- Total MRR in medium+high risk: $2,675,934
- Every downgrade-flag signal combination: 100% historical churn rate
- Usage + support combination (50% churn): most resilient profile — counterintuitively lower than no-signals (69.6%)
- Model correctly orders survival time: high risk 0.0 months → medium 1.9 months → low 5.3 months

---

## Hypothesis Testing — All 36 Hypotheses

The project tested 36 explicit hypotheses across 8 analytical steps. Results:

| Step | Total Hypotheses | Confirmed | Refuted | Partially Confirmed |
|---|---|---|---|---|
| Step 16–18 (Revenue) | 4 | 2 | 1 | 1 |
| Step 19–21 (Churn) | 4 | 2 | 2 | 0 |
| Step 22–23 (Features) | 5 | 0 | 4 | 1 |
| Step 24 (Support) | 5 | 1 | 4 | 0 |
| Step 25 (Risk model) | 4 | 1 | 1 | 2 |
| Step 26 (Lifecycle) | 4 | 2 | 2 | 0 |
| Step 27 (Cohorts) | 5 | 3 | 2 | 0 |
| Step 28 (Beta) | 5 | 2 | 3 | 0 |
| **Total** | **36** | **13** | **19** | **4** |

The high refutation rate is not a project failure — it is the core analytical finding. The hypotheses that were refuted (usage predicts churn, CSAT predicts churn, beta adoption predicts churn) are the most important results in the project because they redirect attention from behavioral interventions to structural ones.

---

## Phase 5 — Insight & Decision Layer

### Key Insights (Step 29)

Ten insights ranked by strategic importance:

1. Revenue growing while the business hollows out — MRR 2,291× alongside 20.17% churn simultaneously
2. No KPI has ever reached benchmark in 24 months — this is structural, not a recent deterioration
3. Churn is an acquisition quality problem — ads (60.2% churn) declining, partner (75.3%) growing
4. Enterprise concentration is existential — 98.2% MRR, 28.1% from 47 accounts
5. Month 1 is the highest-leverage intervention window — 36.4% of all churns happen in months 0–1
6. The retention matrix improvement is an illusion — the survival curve tells the true story
7. No feature has critical mass — zero switching cost, 5.05% max adoption vs 20% benchmark
8. Support is structural deficit, not causal — escalation is the only confirmed signal (+6.5pp)
9. Risk model identifies $2.68M MRR intervention cohort — not a predictive engine
10. Three beta features are hidden retention anchors at <3.5% adoption

### Recommendations (Step 30)

Twelve recommendations across four priority tiers:

| Tier | Recommendations |
|---|---|
| P0 — Pre-launch | R1: Deploy risk model as CS queue · R2: Fix escalation pipeline · R3: Month 1 value demonstration · R4: Restore ads channel to ≥30% |
| P1 — First 30 days | R5: CS program for top 47 accounts · R6: Resolution time <30 hours · R7: Surface top-3 beta features |
| P2 — First 90 days | R8: Rebuild Basic/Pro value proposition · R9: Exit interviews for Enterprise churn · R10: Investigate March 2024 acquisition spike |
| P3 — Medium term | R11: Shift from reactivation to first-churn prevention · R12: Germany market strategy as PMF template |

### Business Impact (Step 31)

| Recommendation | 12-Month MRR Impact | Confidence |
|---|---|---|
| R1 — Risk model CS deployment | ~$443,000 preserved | Medium |
| R2 — Escalation pipeline fix | $128,000–$215,000 preserved | High |
| R3 — Month 1 value demonstration | $500,000–$700,000 incremental | Medium-high |
| R4 — Ads channel restoration | $140,000–$230,000 incremental | High |
| R5 — Top 47 accounts CS program | $300,000–$550,000 preserved | Medium |
| R6 — Resolution time improvement | $15,000–$30,000 preserved | Low |
| R7 — Beta features in onboarding | $59,000–$95,000 incremental | Medium |
| **Base case total (P0 + P1)** | **~$1,920,000** | |

**90-day MRR at risk (do nothing):** $3.4M–$5.3M
**Target churn rate with P0 implementation:** 11.41% → ~7.5%

---

## Project Story

**Situation:** RavenStack is preparing for public launch after 24 months of private operation — its pre-launch data reveals a business that looks healthy on revenue ($10.7M MRR, 2,291× growth) while silently deteriorating on every customer metric, with December 2024 delivering a 20.17% monthly churn rate and 2024 cohorts churning 3.6× faster than 2023 cohorts.

**Surprising finding:** The three most-monitored product health signals — feature usage intensity, CSAT scores, and beta adoption — do not predict which accounts churn; high-usage accounts churn at nearly the same rate (71.9%) as low-usage accounts (70.5%), proving the churn crisis is structurally driven by acquisition channel quality and pricing friction, not product experience failures.

**Business impact:** Without intervention, $3.4M–$5.3M in MRR is at risk in the first 90 days post-launch — concentrated in 135 medium-to-high-risk accounts — while 98.2% Enterprise MRR concentration means a single large account exit becomes a business-level event.

**Recommendation:** Restore ads channel share to ≥30% of acquisition, deploy the multi-factor risk model as a CS action queue for the 135 at-risk accounts holding $2.68M MRR, and implement a structured Month 1 value demonstration program — together estimated to preserve $1.92M in MRR within 12 months and reduce average monthly churn from 11.41% to approximately 7.5%.

---

## Skills Demonstrated

**SQL & Data Engineering**
- 4-layer analytical architecture — raw tables never queried in analysis
- Window functions: `LAG()`, `LEAD()`, `RANK()`, `SUM() OVER()`, `PERCENTILE_CONT()`
- Cohort analysis: retention matrix and survival curve built from scratch
- Conditional aggregation: `COUNT(*) FILTER (WHERE ...)` throughout
- Multi-signal risk scoring with percentile thresholds and normalization
- Cross-table joins: all 5 source tables joined through account_id spine
- 41 production views with validation blocks in every file

**Analytics & Business Intelligence**
- Churn analysis: rate trending, paid vs trial split, 6-dimension segmentation
- Cohort retention: matrix vs survival curve, reactivation gap quantification
- Revenue analysis: MRR phases, plan mix, concentration risk, upgrade/downgrade dynamics
- Feature analytics: adoption breadth vs depth quadrant, usage-churn correlation
- Risk modeling: multi-factor scoring, tier classification, MRR-at-risk quantification
- Business impact estimation: scenario modeling with documented assumptions and confidence levels

**Analytical Thinking**
- 36 explicit hypothesis tests — 19 refuted, documented honestly
- Master finding articulation across conflicting signals
- Reactivation paradox: identifying where two correct metrics tell opposite stories
- Insight-to-recommendation-to-business-impact causal chain
- Distinguishing structural from behavioral churn drivers

---

## How to Run

### Prerequisites
- PostgreSQL 15+
- pgAdmin or psql CLI

### Setup

```bash
# 1. Clone
git clone https://github.com/yourusername/ravenstack-analysis.git
cd ravenstack-analysis

# 2. Create database
psql -U postgres -c "CREATE DATABASE ravenstack;"

# 3. Run schema
psql -U postgres -d ravenstack -f sql/00_schema_setup.sql

# 4. Load data
psql -U postgres -d ravenstack -c "\copy accounts FROM 'data/synthetic_dataset/accounts.csv' CSV HEADER"
psql -U postgres -d ravenstack -c "\copy subscriptions FROM 'data/synthetic_dataset/subscriptions.csv' CSV HEADER"
psql -U postgres -d ravenstack -c "\copy feature_usage FROM 'data/synthetic_dataset/feature_usage.csv' CSV HEADER"
psql -U postgres -d ravenstack -c "\copy support_tickets FROM 'data/synthetic_dataset/support_tickets.csv' CSV HEADER"
psql -U postgres -d ravenstack -c "\copy churn_events FROM 'data/synthetic_dataset/churn_events.csv' CSV HEADER"

# 5. Build layers in order — do not skip steps or change sequence
psql -U postgres -d ravenstack -f sql/base_layer/01_base_accounts.sql
psql -U postgres -d ravenstack -f sql/base_layer/02_base_active_monthly.sql
psql -U postgres -d ravenstack -f sql/base_layer/03_base_mrr_monthly.sql
psql -U postgres -d ravenstack -f sql/base_layer/04_base_churn_monthly.sql
psql -U postgres -d ravenstack -f sql/base_layer/05_base_feature_usage_monthly.sql

psql -U postgres -d ravenstack -f sql/kpi_layer/06_kpi_churn_rate.sql
psql -U postgres -d ravenstack -f sql/kpi_layer/07_kpi_retention_rate.sql
psql -U postgres -d ravenstack -f sql/kpi_layer/08_kpi_mrr_growth.sql
psql -U postgres -d ravenstack -f sql/kpi_layer/09_kpi_active_users.sql
psql -U postgres -d ravenstack -f sql/kpi_layer/10_kpi_feature_adoption.sql
psql -U postgres -d ravenstack -f sql/kpi_layer/11_kpi_revenue_churn_rate.sql
psql -U postgres -d ravenstack -f sql/kpi_layer/12_kpi_upgrade_downgrade.sql
psql -U postgres -d ravenstack -f sql/kpi_layer/13_kpi_support_metrics.sql

psql -U postgres -d ravenstack -f sql/cohort_layer/14_cohort_base.sql
psql -U postgres -d ravenstack -f sql/cohort_layer/15_cohort_retention_matrix.sql
psql -U postgres -d ravenstack -f sql/cohort_layer/15_cohort_survival_curve.sql

psql -U postgres -d ravenstack -f sql/analysis_layer/16_17_18_user_revenue_analysis.sql
psql -U postgres -d ravenstack -f sql/analysis_layer/19_20_21_churn_analysis.sql
psql -U postgres -d ravenstack -f sql/analysis_layer/22_23_feature_usage_analysis.sql
psql -U postgres -d ravenstack -f sql/analysis_layer/24_support_impact_analysis.sql
psql -U postgres -d ravenstack -f sql/analysis_layer/25_multi_factor_churn_model.sql
psql -U postgres -d ravenstack -f sql/analysis_layer/26_lifecycle_journey_analysis.sql
psql -U postgres -d ravenstack -f sql/analysis_layer/27_cohort_retention_analysis.sql
psql -U postgres -d ravenstack -f sql/analysis_layer/28_beta_feature_impact.sql
```

### Validation

Every SQL file ends with a validation block. After running all layers, spot-check with:

```sql
-- Total accounts should be 500 everywhere
SELECT COUNT(*) FROM cohort_base;                           -- 500
SELECT COUNT(DISTINCT account_id) FROM base_active_monthly; -- 500
SELECT SUM(account_count) FROM analysis_risk_tier_summary;  -- 500

-- MRR should peak in December 2024
SELECT month, total_mrr FROM kpi_monthly_mrr_growth
ORDER BY month DESC LIMIT 3;

-- Churn event counts
SELECT COUNT(*) FROM churn_events;                          -- 600
SELECT COUNT(DISTINCT account_id) FROM cohort_base
WHERE ever_churned = TRUE;                                  -- 352
```

---

## Validation Results

The project passed a 10-point cross-validation check at Step 15 with all checks passing:

| Check | Expected | Result |
|---|---|---|
| Total accounts | 500 | ✅ 500 |
| Total churn events | 600 | ✅ 600 |
| Churned accounts | 352 | ✅ 352 |
| Reactivated accounts | 326 | ✅ 326 (79.3% of churned) |
| Total subscriptions | 5,000 | ✅ 5,000 |
| Total feature usage events | 61,306 | ✅ 61,306 |
| Total support tickets | 2,000 | ✅ 2,000 |
| December 2024 MRR | $10,734,251 | ✅ Matches |
| Risk tier totals | 500 | ✅ 1 + 134 + 365 = 500 |
| CSAT view account sum | 500 | ✅ 500 |

---

## Technical Stack

| Component | Technology |
|---|---|
| Database | PostgreSQL 15 |
| Query language | SQL |
| Documentation | Markdown |
| Dataset | Synthetic — sourced from Kaggle (River @ Rivalytics) |

---

## License

Portfolio demonstration project. The dataset is sourced from Kaggle and was created by **River @ Rivalytics**, distributed under a permissive MIT-like license. Credit and attribution go to the original dataset author. All SQL architecture, analytical methodology, hypothesis design, insight generation, and business impact estimation in this project are original work built on top of that dataset. No proprietary or real customer data used anywhere.

---

## Contact

Built as a portfolio demonstration of end-to-end SQL analytics, cohort analysis, churn modeling, and business impact estimation for a SaaS context.

*Questions about SQL architecture, analytical methodology, or findings? Open an issue.*
