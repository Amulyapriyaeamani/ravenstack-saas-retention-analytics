## Step 8: Data Model & Relationship Mapping

### 1. Overview

The dataset represents a SaaS product (RavenStack) and captures the full customer lifecycle from signup to churn.

The data is structured around a central entity (accounts) with multiple related tables capturing different aspects of user behavior.

---

### 2. Schema Type

The dataset follows a **hybrid star schema with event-driven fact tables**.

- A central dimension-like table (accounts)
- Multiple fact tables capturing different business processes
- No single central fact table

This structure reflects a real-world analytical system rather than a simplified warehouse model.

---

### 3. Table Relationships

#### Relationship Structure:

accounts (1)  
→ subscriptions (many)  
→ feature_usage (many)

accounts (1)  
→ support_tickets (many)

accounts (1)  
→ churn_events (many)

---

### 4. Table Roles (Fact vs Dimension)

#### Dimension Table

**accounts**
- Primary entity (customer/company)
- Contains descriptive attributes:
  - industry
  - country
  - referral_source
  - plan_tier
- Used for segmentation and grouping

---

#### Fact Tables

**subscriptions (Revenue Fact)**
- Tracks billing lifecycle
- Contains MRR, ARR, plan changes
- Time-based (start_date, end_date)

**feature_usage (Product Usage Fact)**
- High-volume event table
- Captures product interactions
- Metrics:
  - usage_count
  - usage_duration_secs
  - error_count

**support_tickets (Support Fact)**
- Captures support interactions
- Metrics:
  - resolution_time
  - satisfaction_score
  - escalation_flag

**churn_events (Outcome Fact)**
- Represents churn events
- Contains:
  - churn_date
  - reason_code
  - refund_amount

---

### 5. Data Grain (CRITICAL)

| Table             | Grain |
|------------------|------|
| accounts         | 1 row per account |
| subscriptions    | multiple per account |
| feature_usage    | multiple per subscription per day |
| support_tickets  | multiple per account |
| churn_events     | multiple per account |

---

### 6. Business Flow (User Journey)

The dataset represents the following lifecycle:

Signup → Subscription → Product Usage → Support Interaction → Churn / Retention

---

### 7. Analytical Join Paths

#### Core Joins:

- Revenue Analysis:
  accounts → subscriptions

- Product Usage Analysis:
  accounts → subscriptions → feature_usage

- Churn Analysis:
  accounts → churn_events

- Usage vs Churn:
  accounts → subscriptions → feature_usage → churn_events

- Support vs Churn:
  accounts → support_tickets → churn_events

---

### 8. Key Analytical Insight

This is a **multi-fact dataset**, not a single-fact warehouse.

Each fact table represents a different stage of the customer lifecycle:

- subscriptions → revenue behavior
- feature_usage → engagement behavior
- support_tickets → experience
- churn_events → outcome

---

### 9. Important Considerations

- Data must be joined carefully due to different grains
- Aggregation is required before combining fact tables
- Incorrect joins can lead to duplication and misleading metrics

Example:
Do NOT directly join accounts with feature_usage without going through subscriptions.

---

### 10. Analyst Takeaway

Understanding the data model is critical before analysis.

All insights in this project will follow the business flow:
Problem → Behavior → Outcome

Rather than analyzing tables independently, the focus is on connecting:
- usage → churn
- support → churn
- revenue → churn
