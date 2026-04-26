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
