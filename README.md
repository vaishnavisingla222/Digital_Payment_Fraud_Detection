# 💳 Digital Payment Fraud Detection System (SQL-Based)

This project is a database-driven fraud detection system designed to simulate real-world digital payment environments. It focuses on identifying suspicious transactions using SQL triggers, procedures, cursors, and analytical queries.

## 🚀 Features

* Simulates users, accounts, payment methods, and transactions with **150+ synthetic records**
* Implements **real-time fraud detection** using database triggers
* Supports multiple payment methods:

  * UPI
  * Wallet
  * Credit/Debit Card
  * Net Banking
* Detects fraud based on:

  * High transaction amount thresholds
  * Blocked accounts
  * Inactive payment methods
* Automatically **blocks accounts** based on repeated fraudulent activity
* Maintains a **fraud_log table** for audit and investigation
* Includes **50+ analytical SQL queries** for insights and reporting

## 📊 Fraud Detection Logic

Fraud is automatically detected when:

* UPI transactions exceed ₹1,00,000
* Wallet transactions exceed ₹10,000
* Card transactions exceed ₹10,00,000
* Net banking transactions exceed ₹18,00,000
* Transactions involve blocked accounts
* Payment methods are inactive

All suspicious transactions are logged in the **fraud_log** table using triggers.

## 📁 Database Components

* **Tables**: users, account, payment_method, transactions, fraud_log
* **Trigger**: `detect_fraud` — automatically logs suspicious transactions
* **Procedure**: `transfer_money` — manages transaction execution (debit, credit, validation)
* **Function**: `get_balance` — retrieves account balance
* **Cursor**: `block_fraud_accounts` — blocks accounts with fraud count greater than a defined threshold
* **Views**:

  * `fraud_transactions` — quick fraud reporting
  * `blocked_accounts` — list of blocked accounts

## 📈 Insights & Analysis

The system includes 50+ SQL queries to analyze:

* Transaction trends
* Fraud patterns
* High-risk users
* Payment method usage
* System-wide financial insights

## 🎯 Purpose

This project demonstrates how relational database systems and SQL can be used to design a rule-based fraud detection system while ensuring data integrity, consistency, and efficient querying.

## 🚀 Future Enhancements

* Integration with Machine Learning models for predictive fraud detection
* Real-time monitoring dashboard
* Advanced anomaly detection techniques

---

💡 *This project highlights practical implementation of DBMS concepts such as normalization, ACID properties, triggers, and transaction management in a real-world financial use case.*
