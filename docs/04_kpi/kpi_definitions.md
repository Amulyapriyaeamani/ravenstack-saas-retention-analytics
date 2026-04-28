# KPI Definitions — RavenStack Pre-Launch Analysis
**Project:** RavenStack SaaS Pre-Launch Performance Analysis  
**Role:** Product Analyst  
**Step:** 11 — KPI Definition  
**Status:** Finalized  

---

## Table of Contents
1. [Churn & Retention](#-churn--retention)
2. [Feature Adoption & Engagement](#-feature-adoption--engagement)
3. [Support Experience](#-support-experience)
4. [Revenue](#-revenue)
5. [Master Decision Log](#master-decision-log)

---

## 🔴 Churn & Retention

---

### Churn Rate (Monthly)

```
- Definition: % of active accounts (trial + paid) at start of month who churned 
              during that month

- Numerator: COUNT(DISTINCT account_id) from churn_events where churn_date falls 
             in month M. If an account has multiple churn events in the same month 
             (reactivation cycle), count it once.

- Denominator: COUNT(DISTINCT account_id) with at least one active subscription 
               (trial + paid) on 1st of month M

- Tables: churn_events, subscriptions

- Time logic: start_date <= first day of M AND (end_date IS NULL OR end_date >= 
              first day of M)

- Note: Accounts are counted once even if multiple subscriptions exist, ensuring 
        churn is measured at customer level.
```

---

### Retention Rate (Monthly)

```
- Definition: % of active accounts at the start of a month that remain active 
              (i.e., do not churn) throughout that month

- Numerator: COUNT(DISTINCT account_id) of accounts that had at least one active 
             subscription at start of month M AND did NOT have a churn_event 
             during month M

- Denominator: COUNT(DISTINCT account_id) with at least one active subscription 
               on 1st of month M

- Tables: churn_events, subscriptions

- Time logic: Same as churn rate

- Note: Retention Rate complements churn rate and is defined independently for 
        clarity, even though mathematically Retention = 1 - Churn Rate
```

---

## 🟣 Feature Adoption & Engagement

---

### Feature Adoption Rate

```
- Definition: % of active accounts that used a specific feature during a period,
              where usage is tied to an active subscription in that same period

- Numerator: COUNT(DISTINCT s.account_id)
             FROM feature_usage f
             JOIN subscriptions s ON f.subscription_id = s.subscription_id
             WHERE feature_name = F
             AND usage_date falls within period
             AND s.start_date <= period_end
             AND (s.end_date IS NULL OR s.end_date >= period_start)

- Denominator: COUNT(DISTINCT account_id) of accounts with at least one active 
               subscription during the same period
               (start_date <= period_end AND (end_date IS NULL OR 
               end_date >= period_start))

- Tables: feature_usage → subscriptions → accounts

- Time logic: usage_date falls within period; subscription active during same 
              period using start_date/end_date logic; both conditions must be 
              satisfied simultaneously

- Note: Numerator and denominator use identical subscription activity logic 
        to ensure population alignment. Usage and subscription activity are 
        aligned at the monthly level. Exact day-level overlap is not enforced 
        due to dataset granularity, but this approximation is acceptable for 
        period-based analysis.
```

---

### Active Users (Monthly)

```
- Definition: Accounts with at least one active subscription during the month 
              AND at least one feature usage event within that same monthly window

- Numerator: N/A — this is a count, not a ratio

- Denominator: N/A

- Tables: subscriptions → feature_usage → accounts

- Time logic: subscription active during month M (start_date <= last day of M 
              AND (end_date IS NULL OR end_date >= first day of M));
              usage_date falls within month M
```

---

## 🟡 Support Experience

---

### Average Resolution Time

```
- Definition: Average hours taken to close a support ticket

- Numerator: SUM(resolution_time_hours) for closed tickets in period

- Denominator: COUNT(ticket_id) where closed_at IS NOT NULL in period

- Tables: support_tickets

- Time logic: closed_at falls within the analysis period

- Note: Only closed tickets are included to ensure resolution_time_hours is valid
```

---

### CSAT Score (Monthly)

```
- Definition: Average customer satisfaction score for resolved tickets, 
              excluding non-responses

- Numerator: SUM(satisfaction_score) where satisfaction_score IS NOT NULL

- Denominator: COUNT(ticket_id) where satisfaction_score IS NOT NULL

- Tables: support_tickets

- Time logic: closed_at falls within the analysis period

- Note: Only closed tickets included. NULLs excluded as they represent 
        non-response, not missing data (documented in Step 10).
        Track Response Rate separately =
        COUNT(non-null scores) / COUNT(all tickets)
```

---

## 🟢 Revenue

---

### MRR (Monthly)

```
- Definition: Total monthly recurring revenue from all active paid subscriptions 
              during a given month

- Numerator: N/A — this is a SUM, not a ratio

- Denominator: N/A

- Tables: subscriptions

- Time logic: start_date <= last day of M AND (end_date IS NULL OR end_date >= 
              first day of M) AND is_trial = FALSE
```

---

### ARPU (Monthly)

```
- Definition: Average revenue generated per active paid account in a given month

- Numerator: MRR for month M (paid subscriptions only)

- Denominator: COUNT(DISTINCT account_id) of active paid accounts in month M

- Tables: subscriptions

- Time logic: Same active subscription logic as MRR
```

---

### Upgrade Rate (Monthly)

```
- Definition: % of active paid accounts that upgraded their plan in a given month

- Numerator: COUNT(DISTINCT account_id) where upgrade_flag = TRUE and 
             start_date falls within month M

- Denominator: COUNT(DISTINCT account_id) of active paid accounts in month M

- Tables: subscriptions, accounts

- Time logic: upgrade_flag = TRUE AND start_date falls within month M

- Note: Due to dataset limitations, upgrade timing is approximated using 
        subscription start_date. In a production system this would use a 
        dedicated plan change event timestamp. Denominator includes all active 
        paid accounts during the month; numerator may include accounts that 
        initiated new subscriptions in the same month. This is acceptable given 
        dataset structure but may slightly inflate rates.
```

---

### Downgrade Rate (Monthly)

```
- Definition: % of active paid accounts that downgraded their plan in a given month

- Numerator: COUNT(DISTINCT account_id) where downgrade_flag = TRUE and 
             start_date falls within month M

- Denominator: COUNT(DISTINCT account_id) of active paid accounts in month M

- Tables: subscriptions, accounts

- Time logic: downgrade_flag = TRUE AND start_date falls within month M

- Note: Due to dataset limitations, downgrade timing is approximated using 
        subscription start_date. In a production system this would use a 
        dedicated plan change event timestamp. Denominator includes all active 
        paid accounts during the month; numerator may include accounts that 
        initiated new subscriptions in the same month. This is acceptable given 
        dataset structure but may slightly inflate rates.
```

---

### Revenue Churn Rate (Monthly)

```
- Definition: % of MRR lost due to accounts that churned during a given month,
              measured using their MRR at the start of that month

- Numerator: SUM of total MRR per account (aggregated across all active 
             subscriptions at start of month M) for accounts that churned 
             during month M (is_trial = FALSE).
             Aggregation order: first sum mrr_amount per account across 
             all their active subscriptions, then sum across churned accounts.

- Denominator: Total MRR from all active paid subscriptions at start of month M

- Tables: subscriptions, churn_events

- Time logic: MRR at start = subscriptions active on 1st of month M;
              churned accounts = churn_date falls within month M

- Note: MRR is measured at start of month, before churn occurs. Measuring 
        after churn would return zero — making the metric meaningless.
        Only accounts contributing positive MRR at the start of the month 
        are considered in both numerator and denominator, preventing 
        confusion around zero-MRR and trial accounts.
```

---

## Master Decision Log

| Decision | Reason |
|---|---|
| Churn measured at account level | Accounts counted once even with multiple subscriptions |
| Churn Rate includes trial users | Captures full funnel drop-off; paid churn defined separately |
| COUNT(DISTINCT account_id) throughout | Prevents double-counting across reactivation cycles |
| Retention Rate defined independently | Clarity and interpretability; not just "1 - Churn Rate" |
| Feature Adoption numerator + denominator aligned | Same subscription activity logic prevents population mismatch |
| Feature Adoption uses monthly approximation | Exact day-level overlap not enforced; acceptable for period-based analysis |
| Active Users uses monthly window | Subscription and usage aligned to same period |
| Upgrade/Downgrade uses start_date as proxy | No dedicated plan change timestamp in dataset; limitation documented |
| Upgrade/Downgrade rate may slightly inflate | New subscriptions in same month included; acceptable given dataset structure |
| Revenue Churn aggregates per account first | Prevents double-counting accounts with multiple active subscriptions |
| Revenue Churn uses MRR at start of month | Post-churn MRR = zero, making the metric meaningless |
| Revenue Churn excludes zero-MRR accounts | Prevents confusion around trial and zero-MRR accounts |
| CSAT excludes NULLs | Non-response not missing data — documented in Step 10 |
