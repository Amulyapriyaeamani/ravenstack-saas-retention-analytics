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
