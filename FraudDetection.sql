--------------------------------------------------
-- DIGITAL PAYMENT FRAUD DETECTION SYSTEM (SIMPLE)
--------------------------------------------------

--------------------------------------------------
-- 1. FULL DATABASE CLEANUP SCRIPT
--------------------------------------------------

SET DEFINE OFF;

BEGIN
   -- Drop Trigger
   EXECUTE IMMEDIATE 'DROP TRIGGER detect_fraud';

   -- Drop View
   EXECUTE IMMEDIATE 'DROP VIEW fraud_transactions';

   -- Drop Procedure
   EXECUTE IMMEDIATE 'DROP PROCEDURE transfer_money';

   -- Drop Function
   EXECUTE IMMEDIATE 'DROP FUNCTION get_balance';

   -- Drop Sequences
   EXECUTE IMMEDIATE 'DROP SEQUENCE txn_seq';
   EXECUTE IMMEDIATE 'DROP SEQUENCE fraud_seq';

   -- Drop Tables (child → parent)
   EXECUTE IMMEDIATE 'DROP TABLE fraud_log CASCADE CONSTRAINTS';
   EXECUTE IMMEDIATE 'DROP TABLE transactions CASCADE CONSTRAINTS';
   EXECUTE IMMEDIATE 'DROP TABLE payment_method CASCADE CONSTRAINTS';
   EXECUTE IMMEDIATE 'DROP TABLE account CASCADE CONSTRAINTS';
   EXECUTE IMMEDIATE 'DROP TABLE users CASCADE CONSTRAINTS';

EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-----------------------------
-- 2. CREATE TABLES
-----------------------------

CREATE TABLE users (
    user_id NUMBER PRIMARY KEY,
    name VARCHAR2(50),
    email VARCHAR2(100),
    mobile VARCHAR2(15)
);

CREATE TABLE account (
    account_id NUMBER PRIMARY KEY,
    user_id NUMBER,
    balance Decimal(12,2) CHECK (balance >= 0),
    Account_status VARCHAR2(20) DEFAULT 'ACTIVE',
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE payment_method (
    payment_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    method_type VARCHAR2(20) NOT NULL,
    Payment_status VARCHAR2(20),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE transactions (
    txn_id NUMBER PRIMARY KEY,
    sender_account_id NUMBER NOT NULL,
    receiver_account_id NUMBER NOT NULL,
    payment_id NUMBER NOT NULL,
    amount DECIMAL (12,2) NOT NULL,
    txn_status VARCHAR2(20),
    txn_time DATE,
    FOREIGN KEY (sender_account_id) REFERENCES account(account_id),
    FOREIGN KEY (receiver_account_id) REFERENCES account(account_id),
    FOREIGN KEY (payment_id) REFERENCES payment_method(payment_id)
);

CREATE TABLE fraud_log (
    fraud_id NUMBER PRIMARY KEY,
    txn_id NUMBER NOT NULL,
    reason VARCHAR2(100),
    fraud_time DATE,
    case_status varchar(20) Default 'Pending',
    FOREIGN KEY (txn_id) REFERENCES transactions(txn_id)
);

-----------------------------
-- 3. SEQUENCES
-----------------------------
CREATE SEQUENCE txn_seq START WITH 1;
CREATE SEQUENCE fraud_seq START WITH 1;

-----------------------------
-- 4. INSERT DATA (AUTO)
-----------------------------

-- USERS
BEGIN
  FOR i IN 1..150 LOOP
    INSERT INTO users VALUES (
      i,
      'User_'||i,
      'user'||i||'@gmail.com',
      '9'||LPAD(i,9,'0')
    );
  END LOOP;
END;
/


-- ACCOUNT
BEGIN
  FOR i IN 1..150 LOOP
    INSERT INTO account VALUES (
      100+i,
      i,
      
      CASE 
        WHEN MOD(i,10)=0 THEN 5000         -- Very low
        WHEN MOD(i,7)=0 THEN 20000         -- Low
        WHEN MOD(i,5)=0 THEN 2000000       -- MAX = 2000000
        ELSE 50000 + i*10000               -- Normal growing
      END,
      
      CASE 
        WHEN MOD(i,12)=0 THEN 'BLOCKED'
        ELSE 'ACTIVE'
      END
    );
  END LOOP;
END;
/

-- PAYMENT METHOD
BEGIN
  FOR i IN 1..150 LOOP
    INSERT INTO payment_method VALUES (
      200+i,
      i,
      
      CASE 
        WHEN MOD(i,5)=0 THEN 'CREDIT_CARD'
        WHEN MOD(i,4)=0 THEN 'DEBIT_CARD'
        WHEN MOD(i,3)=0 THEN 'NET_BANKING'
        WHEN MOD(i,2)=0 THEN 'WALLET'
        ELSE 'UPI'
      END,
      
      CASE 
        WHEN MOD(i,8)=0 THEN 'INACTIVE'
        ELSE 'ACTIVE'
      END
    );
  END LOOP;
END;
/

SELECT * FROM USERS;
SELECT * FROM ACCOUNT;
SELECT * FROM PAYMENT_METHOD;
SELECT * FROM TRANSACTIONS;
SELECT * FROM FRAUD_LOG;
-----------------------------
-- 5. TRIGGER (FRAUD DETECTION)
-----------------------------
CREATE OR REPLACE TRIGGER detect_fraud
AFTER INSERT ON transactions
FOR EACH ROW
DECLARE
    v_acc_status account.Account_status%TYPE;
    v_payment_status payment_method.Payment_status%TYPE;
    v_method payment_method.method_type%TYPE;
BEGIN

    SELECT Account_status INTO v_acc_status
    FROM account
    WHERE account_id = :NEW.sender_account_id;

    SELECT method_type, Payment_status
    INTO v_method, v_payment_status
    FROM payment_method
    WHERE payment_id = :NEW.payment_id;

    --------------------------------------------------
    -- PAYMENT METHOD BASED FRAUD
    --------------------------------------------------

    IF (v_method = 'UPI' AND :NEW.amount > 100000) THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'UPI > 1 Lakh', SYSDATE);
    END IF;

    IF (v_method IN ('CREDIT_CARD','DEBIT_CARD') AND :NEW.amount > 1000000) THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'Card > 10 Lakh', SYSDATE);
    END IF;

    IF (v_method = 'NET_BANKING' AND :NEW.amount > 1800000) THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'Net Banking > 18 Lakh', SYSDATE);
    END IF;

    IF (v_method = 'WALLET' AND :NEW.amount > 10000) THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'Wallet > 10K', SYSDATE);
    END IF;

    --------------------------------------------------
    -- BLOCKED ACCOUNT
    --------------------------------------------------

    IF v_acc_status = 'BLOCKED' THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'Blocked account used', SYSDATE);
    END IF;

    --------------------------------------------------
    -- INACTIVE PAYMENT METHOD
    --------------------------------------------------

    IF v_payment_status = 'INACTIVE' THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'Inactive payment method', SYSDATE);
    END IF;

END;
/
-----------------------------
-- 6. PROCEDURE (TRANSFER)
-----------------------------
CREATE OR REPLACE PROCEDURE transfer_money(
    s_acc NUMBER,
    r_acc NUMBER,
    amt NUMBER,
    p_id NUMBER  
)
IS
    v_balance NUMBER;
BEGIN
    -- Get sender balance
    SELECT balance INTO v_balance
    FROM account
    WHERE account_id = s_acc;

    -- Check sufficient balance
    IF v_balance < amt THEN
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient Balance');
    END IF;

    -- Deduct from sender
    UPDATE account 
    SET balance = balance - amt 
    WHERE account_id = s_acc;

    -- Add to receiver
    UPDATE account 
    SET balance = balance + amt 
    WHERE account_id = r_acc;

    -- Insert transaction (NOW DYNAMIC)
    INSERT INTO transactions VALUES (
        txn_seq.NEXTVAL,
        s_acc,
        r_acc,
        p_id,   
        amt,
        'SUCCESS',
        SYSDATE
    );

    COMMIT;
END;
/
-----------------------------
-- 7. FUNCTION (GET BALANCE)
-----------------------------
CREATE OR REPLACE FUNCTION get_balance(acc NUMBER)
RETURN NUMBER
IS
    bal NUMBER;
BEGIN
    SELECT balance INTO bal FROM account WHERE account_id = acc;
    RETURN bal;
END;
/

-----------------------------
-- 8. VIEW
-----------------------------
CREATE VIEW fraud_transactions AS
SELECT t.txn_id, t.amount, f.reason
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id;

SELECT * FROM fraud_transactions;
-----------------------------
-- 9. TEST DATA (TRANSACTIONS)
-----------------------------
BEGIN
  transfer_money(101,102,50000,201); -- insert transaction but not a fraud
END;
/

BEGIN
  transfer_money(105,106,150000,201); -- UPI Fraud
END;
/

BEGIN
  transfer_money(105,106,1200000,205); -- Card Fraud
END;
/

BEGIN
  transfer_money(112,113,5000,201); -- Blocked Account
END;
/

BEGIN
  transfer_money(104,105,20000,202); -- Wallet fraud
END;
/

BEGIN
  transfer_money(115,111,1900000,203); -- Net Banking Fraud 
END;
/

BEGIN
  transfer_money(105,106,5000,264); -- Inactive account
END;
/

SELECT * FROM TRANSACTIONS;
SELECT * FROM FRAUD_LOG;

SELECT * FROM fraud_transactions;
--------------------------------------------------
--QUERIES
--------------------------------------------------

--------------------------------------------------
-- 1. Total Successful Transaction Amount
--------------------------------------------------
SELECT SUM(amount) AS total_success_amount
FROM transactions
WHERE txn_status = 'SUCCESS';

--------------------------------------------------
-- 2. Average Transaction Amount
--------------------------------------------------
SELECT AVG(amount) AS avg_amount FROM transactions;

--------------------------------------------------
-- 3. Top 5 Highest Transactions
--------------------------------------------------
SELECT * FROM transactions
ORDER BY amount DESC
FETCH FIRST 5 ROWS ONLY;

--------------------------------------------------
-- 4. Users with Highest Balance
--------------------------------------------------
SELECT u.name, a.balance
FROM users u
JOIN account a ON u.user_id = a.user_id
WHERE a.balance = (SELECT MAX(balance) FROM account);

--------------------------------------------------
-- 5. Total Transactions per User
--------------------------------------------------
SELECT u.name, COUNT(t.txn_id) AS total_txn
FROM users u
JOIN account a ON u.user_id = a.user_id
LEFT JOIN transactions t ON a.account_id = t.sender_account_id
GROUP BY u.name;

--------------------------------------------------
-- 6. Users with No Transactions
--------------------------------------------------
SELECT u.name
FROM users u
WHERE NOT EXISTS (
    SELECT 1 FROM account a
    JOIN transactions t ON a.account_id = t.sender_account_id
    WHERE a.user_id = u.user_id
);

--------------------------------------------------
-- 7. Fraud Transactions with Details
--------------------------------------------------
SELECT t.txn_id, t.amount, f.reason
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id;

--------------------------------------------------
-- 8. Fraud Count per User
--------------------------------------------------
SELECT u.name, COUNT(f.fraud_id) AS fraud_count
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY u.name;

--------------------------------------------------
-- 9. Most Frequent Fraud Reason
--------------------------------------------------
SELECT reason
FROM fraud_log
GROUP BY reason
ORDER BY COUNT(*) DESC
FETCH FIRST 1 ROW ONLY;

--------------------------------------------------
-- 10. High Risk Users (>2 frauds)
--------------------------------------------------
SELECT u.name, COUNT(*) AS frauds
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY u.name
HAVING COUNT(*) > 2;

--------------------------------------------------
-- 11. Sender & Receiver Details
--------------------------------------------------
SELECT t.txn_id, u1.name AS sender, u2.name AS receiver, t.amount
FROM transactions t
JOIN account a1 ON t.sender_account_id = a1.account_id
JOIN users u1 ON a1.user_id = u1.user_id
JOIN account a2 ON t.receiver_account_id = a2.account_id
JOIN users u2 ON a2.user_id = u2.user_id;

--------------------------------------------------
-- 12. Transactions Above Average
--------------------------------------------------
SELECT * FROM transactions
WHERE amount > (SELECT AVG(amount) FROM transactions);

--------------------------------------------------
-- 13. Accounts Below Average Balance
--------------------------------------------------
SELECT * FROM account
WHERE balance < (SELECT AVG(balance) FROM account);

--------------------------------------------------
-- 14. Daily Transaction Count
--------------------------------------------------
SELECT TRUNC(txn_time), COUNT(*)
FROM transactions
GROUP BY TRUNC(txn_time);

--------------------------------------------------
-- 15. Transactions by Payment Method
--------------------------------------------------
SELECT pm.method_type, COUNT(*)
FROM transactions t
JOIN payment_method pm ON t.payment_id = pm.payment_id
GROUP BY pm.method_type;

--------------------------------------------------
-- 16. Total Amount per Payment Method
--------------------------------------------------
SELECT pm.method_type, SUM(t.amount)
FROM transactions t
JOIN payment_method pm ON t.payment_id = pm.payment_id
GROUP BY pm.method_type;

--------------------------------------------------
-- 17. Failed Transactions
--------------------------------------------------
SELECT * FROM transactions WHERE txn_status = 'FAILED';

--------------------------------------------------
-- 18. Pending Transactions
--------------------------------------------------
SELECT * FROM transactions WHERE txn_status = 'PENDING';

--------------------------------------------------
-- 19. Blocked Accounts
--------------------------------------------------
SELECT * FROM account WHERE Account_status = 'BLOCKED';

--------------------------------------------------
-- 20. Inactive Payment Methods
--------------------------------------------------
SELECT * FROM payment_method WHERE Payment_status = 'INACTIVE';

--------------------------------------------------
-- 21. Transactions in Last 7 Days
--------------------------------------------------
SELECT * FROM transactions
WHERE txn_time >= SYSDATE - 7;

--------------------------------------------------
-- 22. Rank Transactions by Amount
--------------------------------------------------
SELECT txn_id, amount,
RANK() OVER (ORDER BY amount DESC) AS rank_amt
FROM transactions;

--------------------------------------------------
-- 23. Running Total of Transactions
--------------------------------------------------
SELECT txn_id, amount,
SUM(amount) OVER (ORDER BY txn_time) AS running_total
FROM transactions;

--------------------------------------------------
-- 24. Top 3 Users by Transaction Amount
--------------------------------------------------
SELECT * FROM (
    SELECT u.name, SUM(t.amount) total_amt
    FROM users u
    JOIN account a ON u.user_id = a.user_id
    JOIN transactions t ON a.account_id = t.sender_account_id
    GROUP BY u.name
    ORDER BY total_amt DESC
)
WHERE ROWNUM <= 3;

--------------------------------------------------
-- 25. Fraud Transactions (View)
--------------------------------------------------
SELECT * FROM fraud_transactions;

--------------------------------------------------
-- 26. Transactions Between Range
--------------------------------------------------
SELECT * FROM transactions
WHERE amount BETWEEN 10000 AND 50000;

--------------------------------------------------
-- 27. Users Using Multiple Payment Methods
--------------------------------------------------
SELECT user_id, COUNT(DISTINCT method_type)
FROM payment_method
GROUP BY user_id
HAVING COUNT(DISTINCT method_type) > 1;

--------------------------------------------------
-- 28. Accounts with High Activity (>10 transactions)
--------------------------------------------------
SELECT sender_account_id, COUNT(*)
FROM transactions
GROUP BY sender_account_id
HAVING COUNT(*) > 10;

--------------------------------------------------
-- 29. Latest Transaction per User
--------------------------------------------------
SELECT * FROM (
    SELECT t.*, ROW_NUMBER() OVER (PARTITION BY sender_account_id ORDER BY txn_time DESC) rn
    FROM transactions t
)
WHERE rn = 1;

--------------------------------------------------
-- 30. Suspicious Pattern (High Amount + Failed)
--------------------------------------------------
SELECT * FROM transactions
WHERE amount > 50000 AND txn_status = 'FAILED';

--------------------------------------------------
-- 31. Total Fraud Amount
--------------------------------------------------
SELECT SUM(t.amount)
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id;

--------------------------------------------------
-- 32. Fraud Percentage
--------------------------------------------------
SELECT 
  (COUNT(f.txn_id) * 100.0 / COUNT(t.txn_id))
FROM transactions t
LEFT JOIN fraud_log f ON t.txn_id = f.txn_id;

--------------------------------------------------
-- 33. Fraud by Payment Method
--------------------------------------------------
SELECT pm.method_type, COUNT(*)
FROM fraud_log f
JOIN transactions t ON f.txn_id = t.txn_id
JOIN payment_method pm ON t.payment_id = pm.payment_id
GROUP BY pm.method_type;

--------------------------------------------------
-- 34. Highest Fraud Transaction
--------------------------------------------------
SELECT *
FROM transactions
WHERE txn_id IN (SELECT txn_id FROM fraud_log)
ORDER BY amount DESC
FETCH FIRST 1 ROW ONLY;

--------------------------------------------------
-- 35. Fraud Senders
--------------------------------------------------
SELECT DISTINCT u.name
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id;

--------------------------------------------------
-- 36. Fraud Receivers
--------------------------------------------------
SELECT DISTINCT u.name
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.receiver_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id;

--------------------------------------------------
-- 37. Total Bank Balance
--------------------------------------------------
SELECT SUM(balance) FROM account;

--------------------------------------------------
-- 38. Accounts with Balance > 1 Lakh
--------------------------------------------------
SELECT * FROM account WHERE balance > 100000;

--------------------------------------------------
-- 39. Active vs Blocked Accounts
--------------------------------------------------
SELECT Account_status, COUNT(*)
FROM account
GROUP BY Account_status;

--------------------------------------------------
-- 40. Payment Method Usage
--------------------------------------------------
SELECT payment_id, COUNT(*)
FROM transactions
GROUP BY payment_id;

--------------------------------------------------
-- 41. Most Used Payment Method
--------------------------------------------------
SELECT *
FROM (
  SELECT pm.method_type, COUNT(*) cnt
  FROM transactions t
  JOIN payment_method pm ON t.payment_id = pm.payment_id
  GROUP BY pm.method_type
  ORDER BY cnt DESC
)
WHERE ROWNUM = 1;

--------------------------------------------------
-- 42. Transactions per Day Sorted
--------------------------------------------------
SELECT TRUNC(txn_time), COUNT(*)
FROM transactions
GROUP BY TRUNC(txn_time)
ORDER BY TRUNC(txn_time);

--------------------------------------------------
-- 43. Recent Fraud (1 Day)
--------------------------------------------------
SELECT *
FROM fraud_log
WHERE fraud_time >= SYSDATE - 1;

--------------------------------------------------
-- 44. Accounts Never Used
--------------------------------------------------
SELECT account_id
FROM account
WHERE account_id NOT IN (
    SELECT sender_account_id FROM transactions
);

--------------------------------------------------
-- 45. Avg Balance of Fraud Users
--------------------------------------------------
SELECT AVG(a.balance)
FROM account a
JOIN transactions t ON a.account_id = t.sender_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id;

--------------------------------------------------
-- 46. Transactions per Payment Status
--------------------------------------------------
SELECT pm.Payment_status, COUNT(*)
FROM transactions t
JOIN payment_method pm ON t.payment_id = pm.payment_id
GROUP BY pm.Payment_status;

--------------------------------------------------
-- 47. Repeated Sender-Receiver Pairs
--------------------------------------------------
SELECT sender_account_id, receiver_account_id, COUNT(*)
FROM transactions
GROUP BY sender_account_id, receiver_account_id
HAVING COUNT(*) > 1;

--------------------------------------------------
-- 48. Largest Transaction per User
--------------------------------------------------
SELECT sender_account_id, MAX(amount)
FROM transactions
GROUP BY sender_account_id;

--------------------------------------------------
-- 49. Fraud Reason Count
--------------------------------------------------
SELECT reason, COUNT(*)
FROM fraud_log
GROUP BY reason;

--------------------------------------------------
-- 50. Transactions with Account Status
--------------------------------------------------
SELECT t.txn_id, t.amount, a.Account_status
FROM transactions t
JOIN account a ON t.sender_account_id = a.account_id;

--------------------------------------------------
-- END OF PROJECT
--------------------------------------------------
