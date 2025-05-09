 # Fraud Detection in Financial Transactions

## Project Overview

This project focuses on detecting fraudulent transactions within a financial dataset. The aim is to develop an efficient fraud detection system using various data analysis techniques, including machine learning models, SQL-based rules, and outlier detection algorithms.

The goal is to identify potential fraudulent transactions based on features such as transaction amount, user location, transaction type, and more. The final objective is to provide business recommendations for minimizing fraud risks.

## Dataset Information

The dataset contains information about financial transactions, user behavior, and associated features. It includes various aspects such as:

- **Users**: Data about the users making transactions (e.g., demographics, behavior).
- **Transactions**: Detailed records of each financial transaction, including amount, location, time, and transaction type.
- **Fraud Flag**: A flag indicating whether a transaction was fraudulent.

### Key Features

1. **Users Table**:
   - `user_id`: Unique identifier for each user.
   - `country`: The user's country of residence.
   - `city`: The user's city of residence.
   - `account_type`: Type of user account (e.g., personal, business).

2. **Transactions Table**:
   - `transaction_id`: Unique identifier for each transaction.
   - `transaction_type`: Type of the transaction (e.g., purchase, withdrawal).
   - `transaction_amount`: The amount of money involved in the transaction.
   - `transaction_location`: Location where the transaction was made.
   - `device_type`: Type of device used for the transaction (e.g., mobile, desktop).
   - `fraud_flag`: Flag indicating if the transaction was fraudulent (1 for fraud, 0 for legit).

3. **Other Features**:
   - `transaction_time`: Timestamp of the transaction.
   - `merchant_category`: Type of merchant where the transaction was made.
   - `user_device`: Device used for the transaction.
   - `payment_method`: Payment method used (e.g., credit card, debit card).

## Key Analysis Goals

1. **Transaction Anomalies**:
   - Identify transactions that deviate from typical patterns, such as large amounts or unusual locations.

2. **Outlier Detection**:
   - Use machine learning models (e.g., Isolation Forest, Local Outlier Factor) to identify outliers that could indicate fraudulent transactions.

3. **Fraudulent Behavior**:
   - Examine user and transaction characteristics to pinpoint common features among fraudulent transactions.

4. **Correlation Analysis**:
   - Investigate relationships between different features (e.g., transaction amount vs. fraud likelihood, user location vs. fraud).

5. **Feature Engineering**:
   - Create new features that might improve the accuracy of fraud detection models, such as transaction frequency or location-based metrics.

## Technologies Used

- **Python** (Pandas, NumPy, Scikit-learn, Matplotlib, Seaborn)
- **SQL** for querying and aggregating transaction data
- **Machine Learning** (XGBoost, Isolation Forest, LOF) for fraud detection
- **Git** and **GitHub** for version control

## How to Run the Project

1. Clone this repository to your local machine:
   ```bash
   git clone https://github.com/your-username/fraud-detection.git
