-- ============================================================
-- Subscription Revenue & Cohort Analysis
-- Dataset: Mobile app subscription test data set (https://docs.google.com/spreadsheets/d/e/2PACX-1vRZvhW8R1PMolZ1Jv-d5qDIrAVXfFSjauKIKeQuS5CUv7Ufxv-W2dCX81w4pt8AE0RoHCHOZwhiseXz/pubhtml)
-- Tool: Google BigQuery
-- ============================================================
-- Context:
-- Each user record contains:
--   is_trial (0 = trial subscription, 1 = non-trial)
--   first_event_date (date of first payment)
--   subscription_renewal_amount (number of rebills after the first payment)
--
-- Pricing:
--   Trial users:     first payment $6.99, each rebill $29.99 (monthly)
--   Non-trial users: all payments $40.00 (quarterly)
-- ============================================================


-- ============================================================
-- 1: Total revenue from trial subscribers
-- ============================================================
-- Revenue per trial user = $6.99 (first payment) + rebill_count * $29.99
-- Aggregated across all trial users

SELECT 
    SUM(6.99 + (subscription_renewal_amount * 29.99)) AS total_revenue_trial
FROM `test.subscriptions_data.subscriptions`
WHERE is_trial = 0;
-- Result: $1,617,981.66


-- ============================================================
-- 2a: Distribution of users by number of renewals
-- ============================================================

SELECT 
    COUNT(user_id)                AS number_of_users,
    subscription_renewal_amount   AS number_of_renewals
FROM `test.subscriptions_data.subscriptions`
GROUP BY subscription_renewal_amount
ORDER BY subscription_renewal_amount ASC;


-- ============================================================
-- 2b: Revenue by renewal segment (trial users only)
-- ============================================================

-- Sanity check: verify whether trial users with 0 renewals exist
SELECT 
    COUNT(*) AS users,
    is_trial
FROM `test.subscriptions_data.subscriptions`
WHERE is_trial = 0 AND subscription_renewal_amount = 0
GROUP BY is_trial;

-- Total revenue per renewal segment (trial users only)
SELECT 
    subscription_renewal_amount AS number_of_renewals,
    SUM(6.99 + (subscription_renewal_amount * 29.99)) AS total_revenue
FROM `test.subscriptions_data.subscriptions`
WHERE is_trial = 0
GROUP BY subscription_renewal_amount
ORDER BY subscription_renewal_amount ASC;


-- ============================================================
-- 2c: Trial vs non-trial comparison
-- ============================================================

-- Total revenue: trial vs non-trial
SELECT
    is_trial, 
    CASE 
        WHEN is_trial = 0 THEN SUM(6.99 + (subscription_renewal_amount * 29.99))
        WHEN is_trial = 1 THEN SUM(40 + (subscription_renewal_amount * 40)) 
    END AS total_revenue
FROM `test.subscriptions_data.subscriptions`
GROUP BY is_trial, subscription_renewal_amount
ORDER BY subscription_renewal_amount ASC;

-- User distribution: trial vs non-trial
SELECT 
    is_trial,
    COUNT(user_id) AS number_of_users
FROM `test.subscriptions_data.subscriptions`
GROUP BY is_trial;

-- Average revenue per user by renewal segment
-- (more meaningful comparison than total revenue, accounts for segment size)
SELECT 
    subscription_renewal_amount AS number_of_renewals,
    AVG(6.99 + (subscription_renewal_amount * 29.99)) AS avg_revenue_per_user
FROM `test.subscriptions_data.subscriptions`
GROUP BY subscription_renewal_amount;


-- ============================================================
-- 3a: Quarterly revenue
-- ============================================================
-- Approach: reconstruct the full payment timeline for each user
-- using first_event_date + subscription_renewal_amount
-- UNNEST(GENERATE_ARRAY()) expands each user row into one row per payment

WITH payments AS (
    SELECT
        user_id,
        is_trial,
        first_event_date,
        subscription_renewal_amount,
        rebill_number,
        -- Reconstruct payment date for each rebill
        CASE
            WHEN is_trial = 0 THEN 
                DATE_ADD(first_event_date, INTERVAL 7 + (rebill_number * 30) DAY)  -- trial: 7-day trial, then monthly
            WHEN is_trial = 1 THEN 
                DATE_ADD(first_event_date, INTERVAL (rebill_number * 90) DAY)      -- non-trial: quarterly
        END AS payment_date,
        -- Payment amount per rebill
        CASE
            WHEN is_trial = 0 AND rebill_number = 0 THEN 6.99   -- trial first payment
            WHEN is_trial = 0 AND rebill_number > 0 THEN 29.99  -- trial rebill
            WHEN is_trial = 1 THEN 40.00                        -- non-trial (all payments)
        END AS payment_amount
    FROM `test.subscriptions_data.subscriptions`,
    UNNEST(GENERATE_ARRAY(0, subscription_renewal_amount)) AS rebill_number
)

SELECT
    CONCAT('Q', EXTRACT(QUARTER FROM payment_date), ' ', 
           EXTRACT(YEAR FROM payment_date))   AS period,
    is_trial,
    SUM(payment_amount) AS quarterly_revenue
FROM payments
GROUP BY period, is_trial
ORDER BY MIN(payment_date);


-- ============================================================
-- 3b: Cohort revenue analysis
-- ============================================================
-- Users are grouped into cohorts by the quarter of their first payment
-- For each cohort, revenue is tracked across subsequent billing periods

WITH payments AS (
    SELECT
        user_id,
        is_trial,
        first_event_date,
        subscription_renewal_amount,
        rebill_number,
        CASE
            WHEN is_trial = 0 THEN 
                DATE_ADD(first_event_date, INTERVAL 7 + (rebill_number * 30) DAY)
            WHEN is_trial = 1 THEN 
                DATE_ADD(first_event_date, INTERVAL (rebill_number * 90) DAY)
        END AS payment_date,
        CASE
            WHEN is_trial = 0 AND rebill_number = 0 THEN 6.99
            WHEN is_trial = 0 AND rebill_number > 0 THEN 29.99
            WHEN is_trial = 1 THEN 40.00
        END AS payment_amount
    FROM `test.subscriptions_data.subscriptions`,
    UNNEST(GENERATE_ARRAY(0, subscription_renewal_amount)) AS rebill_number
),

cohorts AS (
    SELECT
        *,
        -- Cohort = quarter of the user's first payment
        CONCAT('Q', EXTRACT(QUARTER FROM first_event_date), ' ',
               EXTRACT(YEAR FROM first_event_date))       AS cohort,
        -- Months elapsed from first payment to each subsequent payment
        DATE_DIFF(payment_date, first_event_date, MONTH)  AS periods_since_start
    FROM payments
)

SELECT
    cohort,
    is_trial,
    periods_since_start,
    SUM(payment_amount) AS total_revenue
FROM cohorts
GROUP BY cohort, periods_since_start, is_trial
ORDER BY cohort, periods_since_start;


-- ============================================================
-- 3c: Average LTV by subscription type
-- ============================================================
-- LTV per user = sum of all their payments over the entire subscription lifetime
-- Average LTV = AVG(individual user LTV) across all users in segment

SELECT
    is_trial,
    AVG(
        CASE 
            WHEN is_trial = 0 THEN 6.99 + (subscription_renewal_amount * 29.99)
            WHEN is_trial = 1 THEN 40 + (subscription_renewal_amount * 40)
        END 
    ) AS avg_ltv 
FROM `test.subscriptions_data.subscriptions`
GROUP BY is_trial
ORDER BY avg_ltv ASC;


-- ============================================================
-- 3d: Average number of renewals by subscription type
-- ============================================================

SELECT 
    is_trial,
    AVG(subscription_renewal_amount) AS avg_renewals
FROM `test.subscriptions_data.subscriptions`
GROUP BY is_trial;

-- Key finding: most non-trial users churn after the first payment
-- Trial users average 8 renewals at $29.99 each, generating significantly higher LTV
