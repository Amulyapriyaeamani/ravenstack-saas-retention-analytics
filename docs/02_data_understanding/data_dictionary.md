## Step 9: Data Dictionary (Column-Level Understanding)

This section defines the meaning, business relevance, and analytical usage of each column across all tables.

---

# 🔷 1. accounts (Customer Dimension)

| Column | Meaning | Business Relevance | Usage |
|--------|--------|------------------|-------|
| account_id | Unique identifier for each customer account | Primary entity across all tables | Joins across all tables |
| account_name | Name of the company | Identification only | Not used in analysis |
| industry | Industry category of customer | Helps identify high/low churn industries | Churn segmentation |
| country | Country of the customer | Enables geographic performance analysis | Regional churn & growth |
| signup_date | Date customer joined platform | Enables cohort and retention analysis | Cohort creation |
| referral_source | Acquisition channel | Measures effectiveness of marketing channels | Growth & conversion analysis |
| plan_tier | Initial subscription plan | Entry-level segmentation | Plan-based churn & upgrades |
| seats | Number of licensed users | Proxy for company size | Revenue & usage scaling |
| is_trial | Whether account is in trial | Distinguishes trial vs paid behavior | Conversion funnel analysis |
| churn_flag | Account-level churn indicator | Inconsistent with churn_events | NOT USED (documented inconsistency) |

---

# 🔶 2. subscriptions (Revenue Fact)

| Column | Meaning | Business Relevance | Usage |
|--------|--------|------------------|-------|
| subscription_id | Unique subscription record | Identifies billing instances | Join with feature_usage |
| account_id | Customer reference | Links revenue to customer | Join with accounts |
| start_date | Subscription start date | Defines revenue lifecycle | Time-based revenue analysis |
| end_date | Subscription end date | Indicates churn/inactivity | Churn timing validation |
| plan_tier | Plan at time of billing | Tracks plan changes | Revenue segmentation |
| seats | Number of seats in subscription | Revenue scaling factor | ARPU & expansion analysis |
| mrr_amount | Monthly recurring revenue | Core revenue metric | MRR calculation |
| arr_amount | Annual recurring revenue | Long-term revenue view | Revenue trend analysis |
| is_trial | Trial status for subscription | Identifies non-paying users | Conversion analysis |
| upgrade_flag | Indicates plan upgrade | Growth signal | Upgrade funnel |
| downgrade_flag | Indicates plan downgrade | Risk signal | Pre-churn behavior |
| churn_flag | Subscription-level churn | Not consistent globally | Used cautiously |
| billing_frequency | Monthly or annual billing | Revenue pattern | Revenue modeling |
| auto_renew_flag | Auto-renew enabled | Retention indicator | Churn risk proxy |

---

# 🔶 3. feature_usage (Product Usage Fact)

| Column | Meaning | Business Relevance | Usage |
|--------|--------|------------------|-------|
| usage_id | Unique usage event ID | Event tracking | Deduplication required |
| subscription_id | Subscription reference | Links usage to revenue | Join with subscriptions |
| usage_date | Date of usage | Time-based engagement | DAU / trends |
| feature_name | Feature being used | Identifies product adoption | Feature adoption analysis |
| usage_count | Number of times feature used | Engagement intensity | Usage intensity metric |
| usage_duration_secs | Time spent using feature | Depth of engagement | Engagement quality |
| error_count | Number of errors encountered | Product quality indicator | UX issue detection |
| is_beta_feature | Whether feature is experimental | Measures beta adoption | Product experimentation |

---

# 🔶 4. support_tickets (Support Fact)

| Column | Meaning | Business Relevance | Usage |
|--------|--------|------------------|-------|
| ticket_id | Unique support ticket | Event tracking | Join reference |
| account_id | Customer reference | Links support to user | Join with accounts |
| submitted_at | Ticket creation time | Start of issue lifecycle | Support load analysis |
| closed_at | Ticket resolution time | End of issue lifecycle | Resolution analysis |
| resolution_time_hours | Time to resolve issue | Key support KPI | Efficiency measurement |
| priority | Ticket severity level | Operational importance | Workload segmentation |
| first_response_time_minutes | Time to first response | Customer experience metric | Support quality |
| satisfaction_score | Customer rating (1–5) | Measures support quality | CSAT analysis (NULL = no response) |
| escalation_flag | Whether ticket escalated | Indicates complexity | Risk indicator |

---

# 🔶 5. churn_events (Outcome Fact — Source of Truth)

| Column | Meaning | Business Relevance | Usage |
|--------|--------|------------------|-------|
| churn_event_id | Unique churn record | Event tracking | Primary churn table |
| account_id | Customer reference | Links churn to user | Join with accounts |
| churn_date | Date of churn | Defines churn timing | Time-based churn analysis |
| reason_code | Reason for churn | Root cause of churn | Churn driver analysis |
| refund_amount_usd | Refund issued | Financial impact | Revenue loss analysis |
| preceding_upgrade_flag | Upgrade before churn | Indicates instability | Behavioral analysis |
| preceding_downgrade_flag | Downgrade before churn | Strong churn signal | Risk modeling |
| is_reactivation | Previously churned user | Lifecycle complexity | Reactivation analysis |
| feedback_text | Customer feedback | Qualitative insight | Optional (text analysis) |

---

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
