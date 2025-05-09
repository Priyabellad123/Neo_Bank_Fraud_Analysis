SELECT * FROM `trans-invention-438410-b7.neo_bank.transactions` LIMIT 1000;

## Checking for duplicate rows
select transaction_id, count(*)
from `neo_bank.merged_transactions_user`
group by 1
having count(*)>1


# Detecting Fraud
with merged_data as (
select t1.*, birth_year, country, city, u1.created_date as registered_date,
user_settings_crypto_unlocked, plan, attributes_notifications_marketing_push, attributes_notifications_marketing_email, num_contacts, num_referrals, num_successful_referrals
from `neo_bank.transactions` as t1
left join `neo_bank.users` as u1
using (user_id)
)
,
temp_data as (
select user_id, country, city, (extract(YEAR from registered_date) - birth_year) as user_age,amount_usd, transactions_currency,
transactions_type, created_date as transaction_date, ea_merchant_mcc, ea_merchant_city, ea_merchant_country, ea_cardholderpresence
from merged_data
where transactions_state = 'DECLINED'
group by 1,2,3,4,5,6,7,8,9,10,11,12
order by amount_usd desc)

,
fraud_data as(
select *,
case when ea_merchant_country is not null and country = left(ea_merchant_country, 2) then 'Match'
when ea_merchant_country is null and country is not null then 'None'
else 'No match'
end as country_match
from temp_data
where ea_merchant_mcc in (6011, 4829, 5999, 7995, 5967, 7273,6051)
AND ea_cardholderpresence = 'FALSE'
)

select *
from fraud_data
where country_match = 'No match';


####
# 6011 – ATMs & Cash Disbursements → Used for cash withdrawals, which fraudsters exploit using stolen cards.
# 4829 – Money Transfers (e.g., Western Union, PayPal, Revolut, etc.) → Often used for money laundering and fraud.
# 5999 – Miscellaneous & Specialty Retailers → Generic category often misused for fraudulent businesses.
# 7995 – Betting, Casino Gambling, Lotteries → High chargeback rates and potential for money laundering.
# 5967 – Direct Marketing (Inbound Teleservices) → Often associated with scams and deceptive sales tactics.
# 7273 – Dating & Escort Services → Prone to fraudulent transactions and chargebacks.
# 6051 – Non-Bank Financial Institutions (Crypto Exchanges, Wallets, etc.) → High fraud risk due to unregulated money flow.
# 7832 – Motion Picture Theaters → Sometimes used to disguise transactions.
# 7299 – Miscellaneous Personal Services (Tattoo Parlors, Psychic Services, Bail Bonds, etc.) → High risk for fraud.
# 7994 – Video Game Arcades → Occasionally linked to money laundering schemes.#####

############################################################

## Fraudelent Transactions having large amounts within same day
with temp as(
select *, extract(DATE from t1.created_date) as transaction_day
from `neo_bank.transactions` t1
join `neo_bank.users` u1
using (user_id)

)
,
declined_avg as (
select avg(amount_usd) as avg_declined_amount
from `neo_bank.transactions` 
where transactions_state = 'DECLINED'

)

select user_id, transaction_day , sum(amount_usd) as total_declined_amount, count(transaction_day) as day_count
from temp 
where transactions_state = 'DECLINED'
group by 1,2
having total_declined_amount > (select avg_declined_amount from declined_avg) and 
day_count >= 1
order by total_declined_amount, day_count desc;

----------------------------------------------------------
# create table `neo_bank.merged_transactions_user` as (
select t1.*, birth_year, country, city, u1.created_date as registered_date,
user_settings_crypto_unlocked, plan, attributes_notifications_marketing_push, attributes_notifications_marketing_email, num_contacts, num_referrals, num_successful_referrals
from `neo_bank.transactions` as t1
left join `neo_bank.users` as u1
using (user_id);

###############################################################

select transactions_type,ea_merchant_country, country, sum(amount_usd) as amount, count(distinct user_id) as count
from `neo_bank.merged_transactions_user`
where transactions_state= 'DECLINED'
group by 1,2,3
order by amount desc;
## Transfer type is having high declined amount 
## CARD payment has many declined transaction count 

#######################################################################

with temp as(
select 
user_id,
created_date,
transactions_state,
amount_usd,
lag(transactions_state) over (partition by user_id order by created_date) as previous_state
from `neo_bank.transactions`
)

select *
from temp
where transactions_state = 'COMPLETED'
AND previous_state = 'DECLINED';


WITH temp AS (
    SELECT 
        user_id,
        created_date,
        transactions_state,
        amount_usd,
        LAG(transactions_state, 1) OVER (PARTITION BY user_id ORDER BY created_date) AS prev_state_1,
        LAG(transactions_state, 2) OVER (PARTITION BY user_id ORDER BY created_date) AS prev_state_2,
        LAG(transactions_state, 3) OVER (PARTITION BY user_id ORDER BY created_date) AS prev_state_3,
        LAG(transactions_state, 4) OVER (PARTITION BY user_id ORDER BY created_date) AS prev_state_4
    FROM `neo_bank.transactions`
)

SELECT *
FROM temp
WHERE transactions_state = 'DECLINED'
AND (prev_state_1 = 'DECLINED' AND prev_state_2 = 'DECLINED' AND prev_state_3 = 'DECLINED' AND prev_state_4 = 'DECLINED')  -- Looking for 4 previous failed attempts
ORDER BY user_id, created_date;

######## Finding out decline ratio


WITH user_decline_ratio AS (
    SELECT 
        user_id,
        COUNT(CASE WHEN transactions_state = 'DECLINED' THEN 1 END) AS declined_count,
        COUNT(*) AS total_transactions,
        COUNT(CASE WHEN transactions_state = 'DECLINED' THEN 1 END) * 1.0 / COUNT(*) AS decline_ratio
    FROM `neo_bank.transactions`
    GROUP BY user_id
)

SELECT user_id,declined_count, total_transactions, round(decline_ratio, 2) as decline_ratio
FROM user_decline_ratio
WHERE decline_ratio > 0.7;



# create or replace table `neo_bank.merged_transactions_user` as

select *
from `neo_bank.merged_transactions_user`;

select *, 
extract(YEAR from registered_date) - birth_year as user_age
from `neo_bank.merged_transactions_user`;

select transactions_type, count( case when ea_merchant_mcc is null then 1 end) as null_count,
round(count( case when ea_merchant_mcc is null then 1 end)*100/(select count(*) from `neo_bank.merged_transactions_user`), 2) as percentage_null
from `neo_bank.merged_transactions_user`
group by 1 
order by null_count desc;

# Fraud detection Classification Automation

create or replace table `neo_bank.fraud_detection` as
select *,
case
  WHEN (ea_merchant_mcc IS NULL 
      AND transactions_type NOT IN ('TRANSFER', 'TOPUP', 'EXCHANGE', 'FEE') 
      AND amount_usd > 50) THEN 1

WHEN transactions_state = 'DECLINED' 
         AND COUNT(*) OVER (PARTITION BY user_id ORDER BY created_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) >= 3
         AND transactions_type NOT IN ('TRANSFER', 'TOPUP', 'EXCHANGE') 
         AND amount_usd > 50
    THEN 1

when ea_merchant_country is not null 
and country <> left(ea_merchant_country, 2) 
AND transactions_type IN ('CARD_PAYMENT', 'ATM') 
AND amount_usd > 50
then 1

  WHEN COALESCE(ea_cardholderpresence, 'FALSE') = 'FALSE' 
         AND direction = 'OUTBOUND' 
         AND amount_usd > 50
         AND ea_merchant_mcc IN (4829, 5967, 7273, 7995, 6051,4111, 4814,  5962 ) 
    THEN 1

WHEN transactions_state = 'DECLINED' 
         AND transactions_type = 'TRANSFER' 
         AND amount_usd > 50 
         AND COUNT(*) OVER (
              PARTITION BY user_id 
              ORDER BY UNIX_SECONDS(created_date) 
              RANGE BETWEEN 86400 PRECEDING AND CURRENT ROW
         ) >= 2
    THEN 1
else 0

end as is_fraud

from neo_bank.merged_transactions_user




select user_id, created_date, count(*) over(partition by user_id order by created_date rows between 2 preceding and current row)
from `neo_bank.merged_transactions_user`
order by user_id, created_date 







SELECT user_id, COUNT(*) AS cross_border_txn_count
FROM `neo_bank.fraud_detection`
WHERE ea_merchant_country IS NOT NULL AND ea_merchant_country != country
GROUP BY user_id
ORDER BY cross_border_txn_count DESC;


WITH fraud_flags AS (
    SELECT 
        transaction_id,
        user_id,
        amount_usd,
        transactions_type,
        transactions_state,
        ea_merchant_country,
        direction,
        created_date,

        -- 🚨 Declined Transactions in the last 5 days (for meaningful amounts)
        COUNTIF(transactions_state = 'DECLINED' AND amount_usd > 10) OVER (
            PARTITION BY user_id 
            ORDER BY UNIX_SECONDS(created_date) 
            RANGE BETWEEN 432000 PRECEDING AND CURRENT ROW  -- 5 days
        ) AS declined_txn_5d,

        -- 🏧 ATM Transactions in the last 3 days
        COUNTIF(transactions_type = 'ATM' AND amount_usd > 10) OVER (
            PARTITION BY user_id 
            ORDER BY UNIX_SECONDS(created_date) 
            RANGE BETWEEN 259200 PRECEDING AND CURRENT ROW  -- 3 days
        ) AS atm_txn_3d,

        -- 🌍 Improved Cross-Border Transaction Count in the last 90 days
        COUNTIF(
            ea_merchant_country IS NOT NULL 
            AND country <> LEFT(ea_merchant_country, 2) 
            AND amount_usd > 10  -- Ignore small transactions
        ) OVER (
            PARTITION BY user_id
            ORDER BY UNIX_SECONDS(created_date)
            RANGE BETWEEN 7776000 PRECEDING AND CURRENT ROW  -- 90 days
        ) AS cross_border_txn_90d

    FROM neo_bank.merged_transactions_user
)

SELECT 
    transaction_id,
    user_id,
    amount_usd,
    transactions_type,
    transactions_state,
    ea_merchant_country,
    direction,
    created_date,

    -- ✅ Updated Fraud Metrics
    declined_txn_5d,
    atm_txn_3d,
    cross_border_txn_90d,

    -- 🚩 Smarter Fraud Detection Logic
    CASE 
        -- 🚨 25+ Declined transactions in 5 days (not minor amounts)
        WHEN declined_txn_5d >= 25 THEN 1

        -- 🌍 Cross-border fraud (only if there’s a **sudden spike**)
        WHEN cross_border_txn_90d >= 10 
             AND cross_border_txn_90d > (
                 SELECT AVG(sub_fc.cross_border_txn_90d) * 2  -- More aggressive threshold
                 FROM fraud_flags AS sub_fc 
                 WHERE sub_fc.user_id = fraud_flags.user_id
             ) 
        THEN 1

        -- 🏧 ATM Fraud: 8+ ATM transactions in 3 days
        WHEN transactions_type = 'ATM' AND atm_txn_3d >= 8 THEN 1

        -- 🔥 High-risk outbound transactions (excluding small ones)
        WHEN transactions_type IN ('TRANSFER', 'WIRE_TRANSFER') 
             AND direction = 'OUTBOUND' 
             AND amount_usd > 5000 THEN 1

        -- ❌ Avoid flagging small transfers
        WHEN transactions_type IN ('TRANSFER', 'EXCHANGE') AND amount_usd < 50 THEN 0

        -- ❌ Do not flag inbound transactions unless part of another fraud pattern
        WHEN direction = 'INBOUND' THEN 0

        ELSE 0
    END AS is_fraud

FROM fraud_flags;








CREATE OR REPLACE TABLE `neo_bank.suspicious_detection` AS (
WITH fraud_flags AS (
    SELECT *,
        
        -- 🚨 Count declined transactions in the last 5 days
        COUNTIF(transactions_state = 'DECLINED') OVER (
            PARTITION BY user_id 
            ORDER BY UNIX_SECONDS(created_date)
            RANGE BETWEEN 432000 PRECEDING AND CURRENT ROW  
        ) AS declined_txn_5d,

        -- 🏧 Count ATM transactions in the last 3 days
        COUNTIF(transactions_type = 'ATM') OVER (
            PARTITION BY user_id 
            ORDER BY UNIX_SECONDS(created_date)
            RANGE BETWEEN 259200 PRECEDING AND CURRENT ROW  
        ) AS atm_txn_3d,

        -- 🌍 Count cross-border transactions in the last 90 days
        SUM(
            CASE 
                WHEN ea_merchant_country IS NOT NULL 
                AND country <> LEFT(ea_merchant_country, 2) 
            THEN 1 ELSE 0 END
        ) OVER (
            PARTITION BY user_id
            ORDER BY UNIX_SECONDS(created_date)
            RANGE BETWEEN 7776000 PRECEDING AND CURRENT ROW  
        ) AS cross_border_txn_90d

    FROM `neo_bank.merged_transactions_user`
),

-- 🎯 Compute User-Specific Thresholds
user_avg AS (
    SELECT 
        user_id,
        AVG(amount_usd) AS avg_txn_amount,
        COUNTIF(transactions_state = 'DECLINED') AS past_declined_count, -- ✅ Counting past declined transactions instead
        AVG(cross_border_txn_90d) * 2.5 AS avg_cross_border_threshold  
    FROM fraud_flags
    GROUP BY user_id
)

-- 🚀 Final Fraud Classification
SELECT 
    ff.transaction_id,
    ff.user_id,
    ff.amount_usd,
    ff.transactions_type,
    ff.transactions_state,
    ff.ea_merchant_country,
    ff.direction,
    ff.created_date,

    -- ✅ Only select computed columns once
    ff.declined_txn_5d,
    ff.atm_txn_3d,
    ff.cross_border_txn_90d,
    ua.avg_txn_amount,
    ua.past_declined_count,
    ua.avg_cross_border_threshold,

    -- 🚩 Fraud Detection Logic (Updated)
    CASE 
        -- 🚨 Too many declined transactions, but ignore small ones
        WHEN ff.declined_txn_5d >= 15 AND ff.amount_usd > 10 THEN 1  

        -- 🌍 Cross-border ATM fraud (Dynamic threshold)
        WHEN ff.transactions_type = 'ATM' 
             AND ff.cross_border_txn_90d > ua.avg_cross_border_threshold  
             AND ff.amount_usd > 200  
        THEN 1  

        -- 🏧 ATM fraud: Rapid withdrawals in 3 days
        WHEN ff.transactions_type = 'ATM'  
             AND ff.atm_txn_3d >= 5  
             AND ff.amount_usd > 250  
        THEN 1  

        -- 🔥 Large Transfers (Dynamic threshold increased from 3x → 5x)
        WHEN ff.transactions_type IN ('TRANSFER', 'WIRE_TRANSFER')  
             AND ff.direction = 'OUTBOUND'  
             AND ff.amount_usd > ua.avg_txn_amount * 5  
             AND ff.amount_usd > 500  
             AND ua.past_declined_count > 5  -- ✅ Ensures user has at least 5 past declined transactions before flagging  
        THEN 1  

        -- ✅ Ignore inbound transactions
        WHEN ff.direction = 'INBOUND' THEN 0

        ELSE 0  
    END AS is_fraud

FROM fraud_flags AS ff
LEFT JOIN user_avg AS ua 
ON ff.user_id = ua.user_id
)


    -- ✅ Only select computed columns once

































