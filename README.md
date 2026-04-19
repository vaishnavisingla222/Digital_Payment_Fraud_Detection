# 💳 Digital Payment Fraud Detection System (SQL-Based)

This project is a database-driven fraud detection system designed to simulate real-world digital payment environments. It focuses on identifying suspicious transactions using SQL triggers, cursors, procedures, and analytical queries.

## 🚀 Features

- Simulates users, accounts, payment methods, and transactions  
- Implements real-time fraud detection using database triggers  
- Supports multiple payment methods:
  - UPI
  - Wallet
  - Credit/Debit Card
  - Net Banking  
- Detects fraud based on:
  - High transaction amount thresholds
  - Blocked accounts
  - Inactive payment methods
- Block account based on number of frauds
- Maintains a separate fraud log for audit and investigation  
- Includes 50+ analytical SQL queries for insights and reporting  

## 🧠 Key Concepts Used

- SQL (Oracle)
- Joins, Subqueries, Aggregations
- Triggers (Event-driven fraud detection)
- Stored Procedures & Functions
- Views for simplified reporting

## 📊 Fraud Detection Logic

Fraud is detected automatically when:
- UPI transactions exceed ₹1,00,000  
- Wallet transactions exceed ₹10,000  
- Card transactions exceed ₹10,00,000  
- Net banking transactions exceed ₹18,00,000  
- Transactions involve blocked accounts  
- Payment methods are inactive  

## 📁 Database Components

- **Tables**: users, account, payment_method, transactions, fraud_log  
- **Trigger**: detect_fraud (automatically logs suspicious transactions)  
- **Procedure**: transfer_money (handles transaction flow)  
- **Function**: get_balance (retrieves account balance)
- **Cursors**: block_fraud_accounts (block account with more tha a specific ammount of frauds)
- **View**: fraud_transactions (quick fraud reporting), blocked_accounts (all the blocked accounts)

## 📈 Insights & Analysis

The project includes ~50 SQL queries to analyze:
- Transaction trends  
- Fraud patterns  
- High-risk users  
- Payment method usage  
- System-wide financial insights  

## 🎯 Purpose

This project demonstrates how database systems can be used to build a rule-based fraud detection system and analyze financial data efficiently.

## 🚀 Future Enhancements

- Integration with Machine Learning models for predictive fraud detection  
- Real-time monitoring dashboard  
- Advanced anomaly detection techniques  

---

💡 *This project is ideal for learning SQL, database design, and real-world financial fraud detection concepts.*
