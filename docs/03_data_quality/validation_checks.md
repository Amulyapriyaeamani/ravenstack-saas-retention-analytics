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
