## Data Handling Strategy
Raw data is preserved.
All cleaning is performed using derived logic (views/CTEs), not by modifying source tables.

### Accounts Table
No cleaning required.
Data is complete and consistent.

### Subscriptions Table

Observed cases of zero MRR.

Decision:
- Trial users with zero MRR considered valid
- Non-trial zero MRR cases flagged as anomalies
- No rows removed

### Revenue Validation

Checked for zero MRR in non-trial users:

Result: 0 records

Conclusion:
- All zero MRR cases belong to trial users
- Revenue data is consistent and reliable
- No cleaning or flagging required


### Feature Usage Table

Observed duplicate usage_id values with differing row attributes.

Conclusion:
- usage_id is not a reliable unique identifier
- Duplicate IDs represent distinct usage events, not duplicate records

Decision:
- No rows removed
- usage_id not used for aggregation or uniqueness
- Table grain redefined as:
  "one row = one feature usage event per subscription per day"

Impact:
All analysis will rely on aggregation of usage metrics rather than counting IDs

### Primary Key & Constraint Decisions

Primary keys were added only where data supported uniqueness:

- accounts → account_id (valid)
- subscriptions → subscription_id (valid)
- support_tickets → ticket_id (valid)
- churn_events → churn_event_id (valid)

feature_usage:
- usage_id was not unique
- Duplicate IDs with different values observed
- No primary key enforced

Decision:
- Avoided forcing constraints that would require data loss
- Relied on logical grain definition instead

Foreign Keys:
- Referential integrity validated manually
- Constraints can be added optionally

### Support Tickets Table

825 NULL satisfaction scores observed.

Decision:
- Treated as "No Response"
- Retained NULL values
- Not imputed

Reason:
NULL represents meaningful absence of feedback

Note:
Derived fields such as "response_status" will be created during analysis phase when required
