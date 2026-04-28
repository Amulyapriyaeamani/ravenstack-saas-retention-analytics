## Step 9: Data Dictionary (Final – Validated)

This section defines the meaning, business relevance, and analytical usage of each column across all tables.

---

## 🔷 1. accounts (Customer Dimension)

| Column | Meaning / Description | Business Relevance | Usage |
|--------|---------------------|-------------------|-------|
| account_id | Unique customer (primary key) | Core entity across all tables | Primary join key across all tables |
| account_name | Fictional company name | Identification only | Not used in analysis |
| industry | SaaS vertical (e.g., DevTools, EdTech) | Identifies industry-level patterns | Churn & revenue segmentation |
| country | ISO-2 country code | Enables geographic analysis | Regional performance & churn |
| signup_date | Account creation date | Defines customer cohorts | Cohort & retention analysis |
| referral_source | Acquisition channel | Measures marketing effectiveness | Growth & conversion analysis |
| plan_tier | Initial plan (Basic, Pro, Enterprise) | Entry-level segmentation | Plan-based churn & upgrades |
| seats | Licensed user count | Proxy for company size | Revenue & usage scaling |
| is_trial | Currently trialing | Separates trial vs paid users | Conversion funnel analysis |
| churn_flag | Churned at any point | Inconsistent with churn_events | ❌ Not used as source of truth |

---

## 🔶 2. subscriptions (Revenue Fact)

| Column | Meaning / Description | Business Relevance | Usage |
|--------|---------------------|-------------------|-------|
| subscription_id | Unique subscription (primary key) | Identifies billing records | Join with feature_usage |
| account_id | Links to accounts.account_id | Connects revenue to customers | Join with accounts |
| start_date | Subscription start date | Defines lifecycle start | Time-based revenue analysis |
| end_date | Nullable for active plans | NULL = active, non-null = ended | Active user & churn logic |
| plan_tier | Plan at time of billing | Tracks plan movement | Revenue segmentation |
| seats | Licensed seats | Revenue scaling factor | ARPU & expansion analysis |
| mrr_amount | Monthly revenue | Core revenue metric | MRR calculation |
| arr_amount | Annual revenue | Long-term revenue metric | Revenue trend analysis |
| is_trial | Trial status | Identifies non-paying users | Conversion analysis |
| upgrade_flag | Plan upgraded mid-cycle | Growth indicator | Upgrade funnel analysis |
| downgrade_flag | Plan downgraded mid-cycle | Risk indicator | Pre-churn behavior |
| churn_flag | True if ended | Not fully reliable | Used cautiously (not source of truth) |
| billing_frequency | Monthly or annual | Billing pattern insight | Revenue modeling |
| auto_renew_flag | Auto-renew enabled | Retention indicator | Churn risk proxy |

---

## 🔶 3. feature_usage (Product Usage Fact)

| Column | Meaning / Description | Business Relevance | Usage |
|--------|---------------------|-------------------|-------|
| usage_id | Unique usage event (as per dataset) | Identifier only | ❌ Not reliable (duplicates exist, not used for aggregation) |
| subscription_id | Links to subscriptions.subscription_id | Connects usage to revenue | Join with subscriptions |
| usage_date | Date of usage | Time-based engagement | DAU & usage trends |
| feature_name | Feature used | Product adoption insight | Feature adoption analysis |
| usage_count | Event frequency | Engagement intensity | Usage intensity metrics |
| usage_duration_secs | Time spent | Depth of engagement | Engagement quality analysis |
| error_count | Errors encountered | Product quality indicator | UX & reliability analysis |
| is_beta_feature | Experimental feature flag | Product experimentation | Beta adoption analysis |

---

## 🔶 4. support_tickets (Support Fact)

| Column | Meaning / Description | Business Relevance | Usage |
|--------|---------------------|-------------------|-------|
| ticket_id | Unique ticket | Event tracking | Join reference |
| account_id | Links to accounts.account_id | Connects support to user | Join with accounts |
| submitted_at | Ticket creation time | Start of issue lifecycle | Support load analysis |
| closed_at | Ticket resolution time | End of lifecycle | Resolution analysis |
| resolution_time_hours | Time to resolve | Core support KPI | Efficiency measurement |
| priority | Ticket severity | Operational importance | Workload segmentation |
| first_response_time_minutes | Time to first response | Customer experience metric | Support quality |
| satisfaction_score | Rating (1–5, NULL = no response) | Measures support quality | CSAT analysis |
| escalation_flag | Whether escalated | Indicates complexity | Risk & churn signal |

---

## 🔶 5. churn_events (Outcome Fact — Source of Truth)

| Column | Meaning / Description | Business Relevance | Usage |
|--------|---------------------|-------------------|-------|
| churn_event_id | Unique churn record | Event tracking | Primary churn table |
| account_id | Links to accounts.account_id | Connects churn to customer | Join with accounts |
| churn_date | Date of churn | Defines churn timing | Time-based churn analysis |
| reason_code | Reason for churn | Root cause insight | Churn driver analysis |
| refund_amount_usd | Refund issued | Financial impact | Revenue loss analysis |
| preceding_upgrade_flag | Upgrade before churn | Indicates instability | Behavioral analysis |
| preceding_downgrade_flag | Downgrade before churn | Strong churn signal | Risk modeling |
| is_reactivation | Previously churned user | Lifecycle complexity | Reactivation analysis |
| feedback_text | Customer feedback | Qualitative insight | Optional (text/NLP analysis) |

---

## 🧠 Key Data Quality Notes (Critical)

- usage_id → Not unique → not used for aggregation  
- accounts.churn_flag → inconsistent → ignored  
- subscriptions.churn_flag → partially reliable → not source of truth  
- churn_events → ✅ source of truth for churn  
- end_date IS NULL → active subscription  
- satisfaction_score IS NULL → no response (not missing data)

# 🧠 Key Insights from Data Dictionary

1. **accounts is the central dimension**
2. **Multiple fact tables represent different behaviors:**
   - subscriptions → revenue
   - feature_usage → engagement
   - support_tickets → experience
   - churn_events → outcome
3. **churn_events selected as source of truth**
4. Some fields require caution:
   - churn_flag (accounts, subscriptions) → inconsistent
   - satisfaction_score → meaningful NULLs
   - usage_id → duplicates exist

---

# 🧠 Analyst Takeaway

This dataset enables **cross-functional analysis**, not just isolated metrics:

- Usage → Churn
- Support → Churn
- Revenue → Churn

Understanding columns at this level ensures:
- Correct KPI definitions
- Accurate joins
- Reliable insights
