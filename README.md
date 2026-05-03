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

---

## 🔄 Flow of the Project

1. **Initial Setup (Empty Transaction System)**

   * Tables `transactions` and `fraud_log` are initially empty.
   * Only base data exists in:

     * `users`
     * `account`
     * `payment_method`
   * Sequences (`txn_seq`, `fraud_seq`) are initialized but no records are generated yet.

2. **User & Account Data Creation**

   * Users are inserted into the `users` table.
   * Each user is linked to:

     * an `account` (with balance and status)
     * a `payment_method` (UPI, card, wallet, etc.)

3. **Transaction Initiation**

   * A transaction is triggered using the `transfer_money` procedure.
   * The procedure performs:

     * Balance check from `account` table
     * Deduction from sender account
     * Addition to receiver account

4. **Transaction Record Creation**

   * A new record is inserted into the `transactions` table using `txn_seq`.
   * Fields updated:

     * `txn_id` (auto-generated)
     * sender and receiver account IDs
     * amount, status, and time

5. **Automatic Fraud Detection (Trigger Execution)**

   * After insertion, a trigger (`detect_fraud`) automatically runs.
   * It checks:

     * transaction amount thresholds
     * account status
     * payment method status

6. **Fraud Logging (Conditional Update)**

   * If fraud is detected:

     * A new record is inserted into `fraud_log` using `fraud_seq`
     * Fields updated:

       * `fraud_id`
       * `txn_id` (linked to transactions)
       * reason, fraud_time, case_status
   * If no fraud → `fraud_log` remains unchanged

7. **Post-Processing Using Cursor**

   * The `block_fraud_accounts` cursor analyzes `fraud_log`
   * If an account exceeds a fraud threshold:

     * Its status in `account` table is updated to **BLOCKED**

8. **Final State of System**

   * `account` → balances updated, some accounts blocked
   * `transactions` → contains all transaction history
   * `fraud_log` → contains only suspicious transactions
   * `users` and `payment_method` remain mostly unchanged

9. **Analysis & Reporting**

   * SQL queries and views (`fraud_transactions`, `blocked_accounts`)
     are used to extract insights and monitor system behavior

---

## 📊 Fraud Detection Logic

Fraud is automatically detected when:

* UPI transactions exceed ₹1,00,000
* Wallet transactions exceed ₹10,000
* Card transactions exceed ₹10,00,000
* Net banking transactions exceed ₹18,00,000
* Transactions involve blocked accounts
* Payment methods are inactive

All suspicious transactions are logged in the **fraud_log** table using triggers.

---

## 📁 Database Components

* **Tables**: users, account, payment_method, transactions, fraud_log
* **Trigger**: `detect_fraud` — automatically logs suspicious transactions
* **Procedure**: `transfer_money` — manages transaction execution
* **Function**: `get_balance` — retrieves account balance
* **Cursor**: `block_fraud_accounts` — blocks accounts with fraud count above threshold
* **Views**:

  * `fraud_transactions` — quick fraud reporting
  * `blocked_accounts` — list of blocked accounts

---

## 📈 Insights & Analysis

The system includes 50+ SQL queries to analyze:

* Transaction trends
* Fraud patterns
* High-risk users
* Payment method usage
* System-wide financial insights

---

## 🎯 Purpose

This project demonstrates how relational database systems and SQL can be used to design a rule-based fraud detection system while ensuring data integrity, consistency, and efficient querying.

---

## 🚀 Future Enhancements

* Integration with Machine Learning models for predictive fraud detection
* Real-time monitoring dashboard
* Advanced anomaly detection techniques

---


## 👩‍💻 Author
Vaishnavi Singla, Siya Garg, Nehmat Kaushal

---

💡 *This project highlights practical implementation of DBMS concepts such as normalization, ACID properties, triggers, and transaction management in a real-world financial use case.*
