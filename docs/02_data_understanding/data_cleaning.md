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
