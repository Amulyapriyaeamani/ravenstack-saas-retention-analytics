# Data Validation Log

---

## Row Count Validation

| Table            | Expected | Actual | Status |
|------------------|----------|--------|--------|
| accounts         | 500      | 500    | PASS   |
| subscriptions    | 5000     | 5000   | PASS   |
| feature_usage    | 25000    | 25000  | PASS   |
| support_tickets  | 2000     | 2000   | PASS   |
| churn_events     | 600      | 600    | PASS   |

---

## Primary Key Validation

| Table           | Column           | Status |
|----------------|------------------|--------|
| accounts       | account_id        | PASS   |
| subscriptions  | subscription_id   | PASS   |
| feature_usage  | usage_id          | FAIL (duplicates found) |
| support_tickets| ticket_id         | PASS   |
| churn_events   | churn_event_id    | PASS   |

---

## Data Type Validation

| Table            | Column              | Issue |
|------------------|--------------------|-------|
| support_tickets  | satisfaction_score  | Expected INT, found decimal values |

Action:
- Changed data type to NUMERIC

---

## Notes

- feature_usage contains duplicate usage_id values (intentional dataset behavior)
- Data integrity will be handled in cleaning phase

## Referential Integrity Check

All foreign key relationships validated before constraint creation.

Result:
- No orphan records found
- Safe to enforce foreign key constraints

Action:
Foreign keys added across all tables except primary key on feature_usage (due to duplicates)

## Surface Level Cleaning

### Accounts
Nulls: 0  
Duplicates: 0  
Issues: None  

### Subscriptions
Nulls: 0  
Date Issues: 0  
Revenue Range: 0 – 33830  
Issues: MRR = 0 present (needs investigation)

### Feature Usage
Nulls: 0  
Duplicates: 21 (controlled duplicates)  
Logical Issues: None  

### Support Tickets
Nulls: 825 (satisfaction_score)  
Time Issues: None  
Insight: Likely non-response, not data error  

### Churn Events
Nulls: 0  
Refund Range: 0 – 392.92  
Issues: None

## Data Integrity Validation (Step 7)

### 1. Referential Integrity Checks

| Relationship                          | Result |
|--------------------------------------|--------|
| subscriptions → accounts             | PASS   |
| feature_usage → subscriptions        | PASS   |
| support_tickets → accounts           | PASS   |
| churn_events → accounts              | PASS   |

No orphan records were found across any tables.

---

### 2. Primary Key & Null Validation

| Table             | Null IDs | Duplicate IDs |
|------------------|----------|---------------|
| accounts         | 0        | 0             |
| subscriptions    | 0        | 0             |
| feature_usage    | 0        | 21 duplicates |
| support_tickets  | 0        | 0             |
| churn_events     | 0        | 0             |

---

### 3. Cross-Table Business Logic Validation

#### A. Account churn_flag vs churn_events

- Accounts marked churned but no churn event → **35**
- Churn events where account not marked churned → **465**

#### B. Subscription churn vs account churn

- Mismatched churn flags → **370**

---

### 4. Other Logical Consistency Checks

| Check                          | Result |
|--------------------------------|--------|
| Trial users generating revenue | 0 (PASS) |
| Churned without end_date       | 0 (PASS) |

---

### 5. Key Findings

- Significant inconsistency in churn definitions across tables
- accounts.churn_flag is not aligned with churn_events
- subscriptions.churn_flag also inconsistent with account-level churn

---

### 6. Final Decision

**churn_events table will be used as the single source of truth for churn analysis**

Reason:
- Event-level granularity
- Contains churn timing, reasons, and financial impact
- More reliable than aggregated flags

---

### 7. Notes

- Dataset is structurally clean but logically inconsistent in business definitions
- No structural issues (joins safe)
- Business logic needs to be defined explicitly during analysis

### Churn Accuracy Analysis

Total churned accounts (from churn_events): 352  
Correctly flagged in accounts: 75  
Missed churn cases: 277  

Accuracy of accounts.churn_flag ≈ 21%

Conclusion:
accounts.churn_flag is highly unreliable and under-reports churn significantly.
