## Date: 26/04/2026

## Step: 1 – Define Role

### Goal Today:
Establish project context and analyst role

### Work Done:
Defined my role as a Product Analyst at RavenStack focusing on pre-launch performance analysis.

### Key Understanding:
This project simulates a real-world SaaS analytics scenario where I am responsible for identifying drivers of churn, retention, and revenue.

### Next Step:
Define business objective

## Step: 2 – Define Business Objective

### Goal Today:
Define the core business problem and objective

### Work Done:
Defined the main objective as analyzing churn, retention, and revenue drivers using pre-launch SaaS data.

### Key Understanding:
The focus is not just analysis but identifying actionable insights that can improve business outcomes before launch.

### Next Step:
Define sub-goals

## Step: 3 – Define Sub-Goals

### Goal Today:
Break down the main objective into actionable analytical sub-goals

### Work Done:
Defined four key sub-goals: churn reduction, feature adoption, support improvement, and revenue optimization, each linked to specific analysis areas.

### Key Understanding:
Each sub-goal connects directly to a business problem and will guide the analysis modules.

### Next Step:
Define success metrics (KPIs)

## Step: 4 – Define KPIs

### Goal Today:
Define success metrics aligned with business objectives

### Work Done:
Defined core KPIs across churn, usage, support, and revenue including churn rate, retention rate, MRR, ARPU, feature adoption, and support metrics.

### Key Understanding:
KPIs must directly reflect business success and will guide all further analysis.

### Next Step:
Load data into SQL and begin data validation

## Step 1–4: Strategic Foundation

Defined role as Product Analyst at RavenStack and established business objective to improve retention and revenue before public launch.

Identified key sub-goals:
- Reduce churn
- Increase feature adoption
- Improve support experience
- Optimize revenue

Defined KPIs aligned with each objective.

---

## Step 5: Data Loading & Schema Setup

### Work Done
- Created database schema using SQL script (00_create_tables.sql)
- Defined tables with primary keys
- Loaded all 5 datasets into PostgreSQL using COPY command
- Verified row counts for all tables

### Row Count Validation
- accounts → 500
- subscriptions → 5000
- feature_usage → 25000
- support_tickets → 2000
- churn_events → 600

---

## Issues Encountered & Decisions

### 1. Duplicate Primary Key Issue (feature_usage)
- Encountered duplicate `usage_id` values
- Dropped primary key constraint temporarily to allow full data ingestion

**Insight:**
Real-world datasets often contain duplicate or inconsistent identifiers.

---

### 2. Data Type Mismatch (support_tickets)
- `satisfaction_score` defined as INTEGER but dataset contained decimal values (e.g., 4.0)
- Updated column type to NUMERIC

**Insight:**
Schema should adapt to real-world data, not assumptions.

---

## Key Learnings
- Data ingestion is not trivial and requires validation
- Real-world data often contains inconsistencies
- Proper schema design and flexibility are critical

---

## Next Step
Initial data cleaning and validation (Step 6)

## Step 5.5: Relationship Validation & Enforcement

Validated all relationships using LEFT JOIN checks.

Findings:
- No orphan records
- No null IDs
- Minimal duplicates (only in feature_usage)

Decision:
- Enforced foreign key constraints across tables
- Delayed primary key enforcement for feature_usage due to duplicates

Insight:
Dataset is structurally clean, enabling reliable cross-table analysis.

## Date: 27/04/2026

## Step 6: Initial Data Cleaning – Observations

Most tables were structurally clean with no nulls or logical inconsistencies.

### Key findings:
- Feature usage contains controlled duplicate IDs (21 cases)
- Support tickets have significant nulls in satisfaction_score (~40%)
- Subscriptions include zero MRR values requiring further investigation

### Insight:
Not all data issues are errors—some reflect real business behavior (e.g., missing satisfaction scores).

## Step 7: Data Integrity Validation (Critical)

Performed comprehensive validation to ensure consistency across tables before analysis.

### What was validated:
- Referential integrity across all relationships
- Primary key uniqueness and null checks
- Cross-table business logic consistency
- Subscription lifecycle logic
- Trial vs revenue alignment

---

### Key Findings:

1. Structural Integrity:
All tables passed referential integrity checks with no orphan records.

2. Primary Key Validation:
All tables had unique and non-null identifiers except feature_usage, which contained 21 duplicate usage_id values.

3. Major Insight — Churn Inconsistency:

Significant inconsistencies observed across churn definitions:

- 35 accounts marked churned without corresponding churn events
- 465 churn events not reflected in account churn_flag
- 370 mismatches between subscription and account churn flags

---

### Interpretation:

Churn is represented differently across tables:
- accounts.churn_flag (aggregated flag)
- subscriptions.churn_flag (subscription-level)
- churn_events (event-level data)

These definitions are not aligned.

---

### Decision:

churn_events table selected as the single source of truth for churn analysis.

---

### Reasoning:

- Provides event-level granularity
- Includes churn timing and reason
- More reliable than aggregated flags
- Enables deeper behavioral analysis

---

### Key Insight:

Real-world datasets often contain conflicting business logic across systems.  
An analyst must evaluate and define a consistent source of truth before proceeding.

---

### Next Step:

Proceed to relationship mapping and analytical data modeling (Step 8)

## Additional Analysis:

Compared distinct churned accounts from churn_events with account-level churn flags.

### Findings:
- Total churned accounts: 352
- Correctly flagged in accounts: 75
- Accuracy: ~21%

### Insight:
Account-level churn flags significantly under-report churn and are not reliable for analysis.

### Decision reinforced:
churn_events will be used as the source of truth.

## Step 8: Relationship Mapping & Data Model Understanding

Mapped all table relationships and defined the structure of the dataset.

### Key Learnings:

- accounts is the central entity representing customers
- subscriptions, feature_usage, support_tickets, and churn_events represent different behavioral layers
- The dataset is event-driven with multiple fact tables

---

### Business Understanding:

Defined the user journey as:

Signup → Subscription → Usage → Support → Churn

---

### Analytical Impact:

- Established correct join paths for analysis
- Identified grain differences across tables
- Prevented potential data duplication issues

---

### Insight:

This is not a simple dataset—it reflects a real-world SaaS system where different data sources capture different aspects of user behavior.

Effective analysis requires connecting these signals rather than analyzing them in isolation.

## Step 9: Data Dictionary Creation

Developed a detailed column-level data dictionary for all tables.

### Focus:
- Business meaning of each column
- Relevance to analysis and KPIs
- Identification of unreliable fields

---

### Key Learnings:

- Not all columns are usable (e.g., churn_flag inconsistency)
- Some nulls are meaningful (e.g., satisfaction_score)
- Different tables capture different aspects of user behavior

---

### Impact:

This step ensures:
- Accurate KPI definitions
- Correct analytical joins
- Strong business interpretation of data

---

### Insight:

Understanding columns deeply is critical—analysis quality depends more on interpretation than SQL complexity.

## Date:  2026-04-28 
## Step 10: Deep Data Cleaning & Validation Completed

### What I Did
- Performed deep data validation across all 5 tables
- Checked business logic consistency (subscriptions, churn, support, usage)
- Identified and handled data quality issues instead of blindly cleaning

### Key Findings

1. **Feature Usage Table**
   - Found duplicate `usage_id` values with different records
   - Identified that `usage_id` is NOT a reliable primary key
   - Redefined table grain as:
     → one row = one feature usage event

2. **Churn Data Inconsistency**
   - Significant mismatch between `accounts.churn_flag` and `churn_events`
   - `churn_events` identified as source of truth for churn

3. **Support Data**
   - `satisfaction_score` has 825 NULL values
   - Interpreted as "no response", not missing data

4. **Subscriptions**
   - `end_date IS NULL` correctly represents active subscriptions

5. **Outlier Analysis**
   - No abnormal or unrealistic outliers found
   - Extreme values represent real scenarios (power users, enterprise accounts)

---

### Decisions Taken

- Did NOT delete or modify raw data unnecessarily
- Avoided forcing primary keys where data didn’t support it
- Defined business logic instead of “fixing” data blindly
- Preserved real-world imperfections for analysis

---

### Key Learning

This step was not about cleaning data —  
It was about **understanding the business reality behind the data**.

Learned to:
- Question data instead of trusting it blindly
- Differentiate between data errors vs real behavior
- Think like a Product Analyst, not just a SQL user

---

### Status

✅ Data is now analysis-ready  
➡️ Ready to move to KPI definition (Step 11)

## Step 11: KPI Definitions

**Date:** 28/04/2026  

---

## What I Did

- Defined all core business KPIs across:
  - Churn & Retention
  - Feature Adoption & Engagement
  - Support Experience
  - Revenue
- Standardized KPI structure with:
  - Definition
  - Numerator & Denominator
  - Tables used
  - Time logic
  - Notes / assumptions
- Ensured consistent **account-level aggregation** across all metrics
- Aligned KPI definitions with cleaned and validated dataset (Steps 6–10)
- Created a **Master Decision Log** documenting all assumptions and trade-offs
- Incorporated handling for:
  - Multiple subscriptions per account
  - Reactivation cycles
  - Trial vs paid user logic
  - Null handling (CSAT, churn reasons)
  - Data limitations (e.g., missing event timestamps)

---

## Key Findings

- `churn_events` is the only reliable source of churn → account-level churn_flag is inconsistent
- Multiple subscriptions per account require strict use of `COUNT(DISTINCT account_id)`
- Trial users exist in large numbers and must be handled differently across KPIs:
  - Included in behavioral metrics (churn, usage)
  - Excluded from revenue metrics
- Feature usage data is at **subscription level**, requiring joins to map to accounts
- No timestamp available for upgrade/downgrade events → approximation required
- Monthly granularity is necessary due to lack of day-level alignment across datasets
- Zero-MRR subscriptions are exclusively trial users → safe to exclude from revenue KPIs

---

## Decisions Taken

- Churn and retention measured at **account level**, not subscription level
- Churn Rate includes **trial + paid users** to capture full funnel drop-off
- Revenue metrics include **only paid subscriptions**
- Feature Adoption numerator and denominator use **identical subscription activity filters**
- Active Users defined as:
  - Active subscription + at least one usage event in same month
- Upgrade/Downgrade timing approximated using **subscription start_date**
- Revenue Churn calculated using **MRR at start of month**
- MRR aggregated at **account level before churn calculation**
- CSAT excludes NULL values (treated as non-response, not missing data)
- Monthly window used for all time-based KPIs (acceptable approximation)

---

## Key Learning

- KPI definitions are not just formulas — they require **business context + data awareness**
- Choosing the correct **unit of analysis (account vs subscription)** is critical
- Misaligned numerator and denominator can silently break metrics
- Handling **real-world data issues** (missing timestamps, inconsistent flags) is part of analysis
- Clear documentation of assumptions improves:
  - Interpretability
  - Reproducibility
  - Interview communication
- Revenue-based metrics must always consider **timing (before vs after churn)**

---

## Status

- KPI definitions completed and standardized  
- Business logic aligned with dataset constraints  
- All assumptions documented  
- Ready to move to **Step 12: SQL Implementation**

---
