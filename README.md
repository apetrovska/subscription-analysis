# Subscription Revenue & Cohort Analysis

**Tools:** Google BigQuery (Standard SQL), Tableau Public  
**Dataset:** Mobile app subscription data (anonymized test assignment)

---

**[View SQL Queries](https://github.com/apetrovska/subscription-analysis/blob/main/subscription_analysis.sql)**

SQL Techniques Used

- `UNNEST(GENERATE_ARRAY())` to reconstruct payment timelines from aggregated data
- CTEs for multi-step cohort logic
- `DATE_ADD` / `DATE_DIFF` for period calculations
- Conditional aggregation with `CASE WHEN`
- Cohort labeling with `EXTRACT(QUARTER/YEAR)`

---

## Tableau Dashboard

Interactive dashboard built on the same dataset:  
[View on Tableau Public](https://public.tableau.com/views/SubscriptionRevenueCohortAnalysis/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link)
---

## Context

A mobile app offers two subscription types:

| Type | First Payment | Rebill | Billing Cycle |
|---|---|---|---|
| Trial | $6.99 | $29.99 | Monthly |
| Non-trial | $40.00 | $40.00 | Quarterly |

Each user record contains: subscription type, first payment date, and total number of rebills. The full payment timeline is not stored directly - it was reconstructed using `UNNEST(GENERATE_ARRAY())` to expand each user row into individual payment events.

---

## Analysis Overview

### Revenue Analysis
- Total revenue from trial vs. non-trial subscribers
- Revenue breakdown by renewal segment
- Average revenue per user (controlling for segment size)

### LTV Analysis
- Average LTV by subscription type
- Average number of renewals by subscription type

### Time-Based Analysis
- **Quarterly revenue**: reconstructed from first payment date + renewal count
- **Cohort revenue analysis**: users grouped by acquisition quarter, revenue tracked across subsequent billing periods

---

## Key Findings

- Trial users generate significantly higher LTV: they average ~8 monthly rebills at $29.99, compared to most non-trial users who churn after the first payment
- Revenue is highly concentrated in early cohorts with high trial conversion
- Cohort analysis reveals retention patterns not visible in aggregate revenue totals

---

## Files

| File | Description |
|---|---|
| `subscription_analysis.sql` | All queries with inline comments |
