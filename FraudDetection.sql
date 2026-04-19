--------------------------------------------------
-- DIGITAL PAYMENT FRAUD DETECTION SYSTEM
--------------------------------------------------

-- 1. Removal of all the Objects for Fresh run

SET DEFINE OFF;
BEGIN
   -- Drop Trigger
   EXECUTE IMMEDIATE 'DROP TRIGGER detect_fraud';
   -- Drop View
   EXECUTE IMMEDIATE 'DROP VIEW fraud_transactions';
   EXECUTE IMMEDIATE 'DROP VIEW blocked_accounts';
   -- Drop Procedure
   EXECUTE IMMEDIATE 'DROP PROCEDURE transfer_money';
   EXECUTE IMMEDIATE 'DROP PROCEDURE block_fraud_accounts';
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


   
-- 2. Create Tables
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


-- 3. Sequences
CREATE SEQUENCE txn_seq START WITH 1;
CREATE SEQUENCE fraud_seq START WITH 1;


-- 4. Insert Data

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



-- 5. Trigger for Detecting Fraud
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

    
    -- Payment Method Based Fraud
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

    -- Transaction from Blocked account
    IF v_acc_status = 'BLOCKED' THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'Blocked account used', SYSDATE);
    END IF;

    -- Transaction from Inactive account

    IF v_payment_status = 'INACTIVE' THEN
        INSERT INTO fraud_log (fraud_id, txn_id, reason, fraud_time)
        VALUES (fraud_seq.NEXTVAL, :NEW.txn_id,
        'Inactive payment method', SYSDATE);
    END IF;

END;
/


   
-- 6. Procedure for Transfer
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


-- 7. Function to Get balance
CREATE OR REPLACE FUNCTION get_balance(acc NUMBER)
RETURN NUMBER
IS
    bal NUMBER;
BEGIN
    SELECT balance INTO bal FROM account WHERE account_id = acc;
    RETURN bal;
END;
/

-- 8. Cursor to block account based on number of frauds
CREATE OR REPLACE PROCEDURE block_fraud_accounts
IS
  CURSOR acc_cur IS
    SELECT t.sender_account_id, COUNT(*) fraud_count
    FROM transactions t
    JOIN fraud_log f ON t.txn_id = f.txn_id
    GROUP BY t.sender_account_id;

  v_acc_id NUMBER;
  v_count NUMBER;

BEGIN
  OPEN acc_cur;

  LOOP
    FETCH acc_cur INTO v_acc_id, v_count;
    EXIT WHEN acc_cur%NOTFOUND;

    IF v_count > 1 THEN
      UPDATE account
      SET account_status = 'BLOCKED'
      WHERE account_id = v_acc_id;
      DBMS_OUTPUT.PUT_LINE('Blocked Account: ' || v_acc_id);
    END IF;

  END LOOP;
  CLOSE acc_cur;
  COMMIT;
END;
/


-- 9. View of fraud and block account
CREATE VIEW fraud_transactions AS
SELECT t.txn_id, t.amount, f.reason
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id;


CREATE VIEW blocked_accounts AS
SELECT a.account_id, u.name, a.balance
FROM account a
JOIN users u ON a.user_id = u.user_id
WHERE a.account_status = 'BLOCKED';

SELECT * FROM fraud_transactions;
SELECT * FROM blocked_accounts;



-- 10. Test Transactions
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

BEGIN
  block_fraud_accounts;
END;
/


-- 11. QUERY SET 

-- Account blocked due to cursor
SELECT a.account_id, u.name, COUNT(f.txn_id) AS fraud_count
FROM account a
JOIN users u ON a.user_id = u.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id
WHERE a.account_status = 'BLOCKED'
GROUP BY a.account_id, u.name
HAVING COUNT(f.txn_id) > 1;

-- Rank users based on total transaction amount (Top spenders)
SELECT u.name, SUM(t.amount) AS total_amount,
DENSE_RANK() OVER (ORDER BY SUM(t.amount) DESC) AS rank
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
GROUP BY u.name;

-- Detect sudden spike in transaction amount (Fraud pattern)
SELECT *
FROM (
  SELECT txn_id, sender_account_id, amount,
  LAG(amount) OVER (PARTITION BY sender_account_id ORDER BY txn_time) prev_amt
  FROM transactions
)
WHERE amount > 2 * prev_amt

-- Running total of transactions per account (Balance flow analysis)
SELECT sender_account_id, txn_time, amount,
SUM(amount) OVER (PARTITION BY sender_account_id ORDER BY txn_time) running_total
FROM transactions;

-- Fraud contribution percentage per user
SELECT u.name, SUM(t.amount) AS fraud_amt,
ROUND(100 * SUM(t.amount) / (SELECT SUM(amount) FROM transactions),2) AS percentage
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY u.name;

-- Top 3 highest transactions for each payment method
SELECT * FROM (
SELECT t.*, pm.method_type,
ROW_NUMBER() OVER (PARTITION BY pm.method_type ORDER BY amount DESC) rn
FROM transactions t
JOIN payment_method pm ON t.payment_id = pm.payment_id
) WHERE rn <= 3;

-- Transactions greater than user's own average transaction
SELECT * FROM transactions t
WHERE amount > (
SELECT AVG(amount)
FROM transactions
WHERE sender_account_id = t.sender_account_id
);

-- Identify highly active accounts in last 2 days
SELECT sender_account_id, COUNT(*) txn_count
FROM transactions
WHERE txn_time > SYSDATE - 2
GROUP BY sender_account_id
HAVING COUNT(*) > 3;

--  Fraud ratio per payment method
SELECT pm.method_type,
ROUND(COUNT(f.txn_id) * 100.0 / COUNT(t.txn_id), 2) AS fraud_ratio
FROM transactions t
LEFT JOIN fraud_log f ON t.txn_id = f.txn_id
JOIN payment_method pm ON t.payment_id = pm.payment_id
GROUP BY pm.method_type;

--  Detect circular transactions (A → B → A)
SELECT t1.sender_account_id, t1.receiver_account_id
FROM transactions t1
JOIN transactions t2
ON t1.sender_account_id = t2.receiver_account_id
AND t1.receiver_account_id = t2.sender_account_id;


-- Accounts consistently making high-value transactions
SELECT sender_account_id
FROM transactions
GROUP BY sender_account_id
HAVING MIN(amount) > 50000;

--First and last transaction of each account
SELECT sender_account_id,
MIN(txn_time) first_txn,
MAX(txn_time) last_txn
FROM transactions
GROUP BY sender_account_id;

--Accounts with multiple frauds in last 24 hours
SELECT sender_account_id, COUNT(*) frauds
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id
WHERE txn_time >= SYSDATE - 1
GROUP BY sender_account_id
HAVING COUNT(*) > 2;

--Users whose transaction volume exceeds account balance
SELECT u.name, a.balance, SUM(t.amount) total_txn
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
GROUP BY u.name, a.balance
HAVING SUM(t.amount) > a.balance;

--Users with single high-value transaction
SELECT sender_account_id
FROM transactions
GROUP BY sender_account_id
HAVING COUNT(*) = 1 AND MAX(amount) > 100000;

-- 15. Most risky sender-receiver pair (max fraud count)
SELECT sender_account_id, receiver_account_id, COUNT(*) frauds
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY sender_account_id, receiver_account_id
ORDER BY frauds DESC FETCH FIRST 1 ROW ONLY;

-- Percentile ranking of transactions
SELECT txn_id, amount,
PERCENT_RANK() OVER (ORDER BY amount) pr
FROM transactions;

--Users whose fraud amount exceeds normal transaction amount
SELECT u.name
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
LEFT JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY u.name
HAVING SUM(CASE WHEN f.txn_id IS NOT NULL THEN amount ELSE 0 END) >
SUM(CASE WHEN f.txn_id IS NULL THEN amount ELSE 0 END);

-- Detect back-to-back transactions within 1 hour
SELECT *
FROM (
  SELECT txn_id, sender_account_id, txn_time,
  txn_time - LAG(txn_time) OVER (PARTITION BY sender_account_id ORDER BY txn_time) gap
  FROM transactions
)
WHERE gap < 1/24;

--  Daily fraud trend analysis
SELECT TRUNC(fraud_time), COUNT(*)
FROM fraud_log
GROUP BY TRUNC(fraud_time)
ORDER BY TRUNC(fraud_time);

-- Fraud reason distribution percentage
SELECT reason,
COUNT(*) * 100 / (SELECT COUNT(*) FROM fraud_log) AS fraudPercentage
FROM fraud_log
GROUP BY reason;

-- Users using multiple payment methods and involved in fraud
SELECT user_id
FROM payment_method
GROUP BY user_id
HAVING COUNT(DISTINCT method_type) > 2
AND user_id IN (
SELECT a.user_id
FROM account a
JOIN transactions t ON a.account_id = t.sender_account_id
JOIN fraud_log f ON t.txn_id = f.txn_id
);

--  Rolling average of last 3 transactions
SELECT txn_id, amount,
AVG(amount) OVER (ORDER BY txn_time ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
FROM transactions;

-- Detect outlier transactions using statistical method
SELECT txn_id, amount
FROM transactions
WHERE amount > (
SELECT AVG(amount) + 2*STDDEV(amount) FROM transactions
);

--  Accounts sending to many unique receivers
SELECT sender_account_id
FROM transactions
GROUP BY sender_account_id
HAVING COUNT(DISTINCT receiver_account_id) > 5;

-- Fraud density per account
SELECT sender_account_id,
ROUND(COUNT(f.txn_id) / COUNT(*)) AS fraud_density
FROM transactions t
LEFT JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY sender_account_id;

--  Longest time gap between transactions per account
SELECT sender_account_id,
MAX(txn_time - LAG(txn_time) OVER (PARTITION BY sender_account_id ORDER BY txn_time))
FROM transactions;

-- Accounts showing increasing transaction trend
SELECT sender_account_id
FROM (
SELECT sender_account_id, amount,
LAG(amount) OVER (PARTITION BY sender_account_id ORDER BY txn_time) prev
FROM transactions
)
WHERE amount > prev
GROUP BY sender_account_id;

-- Peak transaction hour
SELECT EXTRACT(HOUR FROM txn_time) hr, COUNT(*)
FROM transactions
GROUP BY EXTRACT(HOUR FROM txn_time)
ORDER BY COUNT(*) DESC FETCH FIRST 1 ROW ONLY;

--  Top 5% highest transactions
SELECT * FROM (
SELECT t.*, NTILE(20) OVER (ORDER BY amount DESC) bucket
FROM transactions t
)
WHERE bucket = 1;

--  Fraud score calculation per user (composite risk metric)
SELECT u.name,
COUNT(f.txn_id)*2 + SUM(t.amount)/100000 AS fraud_score
FROM users u
JOIN account a ON u.user_id = a.user_id
JOIN transactions t ON a.account_id = t.sender_account_id
LEFT JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY u.name
ORDER BY fraud_score DESC;

-- Classify transactions into risk categories
SELECT txn_id, amount,
CASE 
  WHEN amount > 1000000 THEN 'HIGH'
  WHEN amount > 100000 THEN 'MEDIUM'
  ELSE 'LOW'
END risk_level
FROM transactions;

--  Find users with continuous transactions (3 in a row)
SELECT sender_account_id
FROM (
SELECT sender_account_id,
ROW_NUMBER() OVER (PARTITION BY sender_account_id ORDER BY txn_time) rn
FROM transactions
)
GROUP BY sender_account_id
HAVING COUNT(*) >= 3;

--  CTE: Total debit vs credit per account
WITH txn_flow AS (
SELECT sender_account_id acc, SUM(amount) debit, 0 credit FROM transactions GROUP BY sender_account_id
UNION ALL
SELECT receiver_account_id, 0, SUM(amount) FROM transactions GROUP BY receiver_account_id
)
SELECT acc, SUM(debit) total_debit, SUM(credit) total_credit
FROM txn_flow
GROUP BY acc;

--  Detect accounts with zero balance but high transactions
SELECT a.account_id
FROM account a
JOIN transactions t ON a.account_id = t.sender_account_id
WHERE a.balance = 0
GROUP BY a.account_id
HAVING SUM(t.amount) > 100000;

-- Users whose last transaction was fraud
SELECT sender_account_id
FROM (
SELECT t.*, ROW_NUMBER() OVER (PARTITION BY sender_account_id ORDER BY txn_time DESC) rn
FROM transactions t
)
WHERE rn = 1
AND txn_id IN (SELECT txn_id FROM fraud_log);

--Accounts with decreasing transaction pattern
SELECT sender_account_id
FROM (
SELECT sender_account_id, amount,
LAG(amount) OVER (PARTITION BY sender_account_id ORDER BY txn_time) prev
FROM transactions
)
WHERE amount < prev
GROUP BY sender_account_id;

-- Find duplicate transaction amounts for same user
SELECT sender_account_id, amount, COUNT(*)
FROM transactions
GROUP BY sender_account_id, amount
HAVING COUNT(*) > 1;

-- Highest fraud amount per user
SELECT sender_account_id, MAX(amount)
FROM transactions
WHERE txn_id IN (SELECT txn_id FROM fraud_log)
GROUP BY sender_account_id;

--Compare weekday vs weekend transactions
SELECT CASE 
WHEN TO_CHAR(txn_time,'DY') IN ('SAT','SUN') THEN 'WEEKEND'
ELSE 'WEEKDAY' END type,
COUNT(*)
FROM transactions
GROUP BY CASE 
WHEN TO_CHAR(txn_time,'DY') IN ('SAT','SUN') THEN 'WEEKEND'
ELSE 'WEEKDAY' END;

-- Detect accounts interacting with many fraud users
SELECT sender_account_id
FROM transactions
WHERE receiver_account_id IN (
SELECT sender_account_id
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id
)
GROUP BY sender_account_id;

--  Median transaction amount
SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount)
FROM transactions;

-- Identify users with no fraud but high volume
SELECT sender_account_id
FROM transactions
GROUP BY sender_account_id
HAVING COUNT(*) > 5
AND sender_account_id NOT IN (
SELECT sender_account_id
FROM transactions t
JOIN fraud_log f ON t.txn_id = f.txn_id
);

--- Transactions close to max value (top 10%)
SELECT *
FROM transactions
WHERE amount > 0.9 * (SELECT MAX(amount) FROM transactions);

--  Find accounts sending same amount repeatedly in short time
SELECT sender_account_id, amount
FROM transactions
GROUP BY sender_account_id, amount
HAVING COUNT(*) > 3;

--  Accounts involved in both sending and receiving fraud
SELECT DISTINCT t1.sender_account_id
FROM transactions t1
JOIN fraud_log f1 ON t1.txn_id = f1.txn_id
JOIN transactions t2 ON t1.sender_account_id = t2.receiver_account_id
JOIN fraud_log f2 ON t2.txn_id = f2.txn_id;

-- Detect accounts with increasing frequency of transactions
SELECT sender_account_id
FROM transactions
GROUP BY sender_account_id
HAVING COUNT(*) > (
SELECT AVG(cnt)
FROM (
SELECT COUNT(*) cnt FROM transactions GROUP BY sender_account_id
));

--  Compare average fraud vs normal transaction amount
SELECT 
AVG(CASE WHEN f.txn_id IS NOT NULL THEN amount END) fraud_avg,
AVG(CASE WHEN f.txn_id IS NULL THEN amount END) normal_avg
FROM transactions t
LEFT JOIN fraud_log f ON t.txn_id = f.txn_id;

-- Accounts with maximum outgoing minus incoming difference
WITH flow AS (
SELECT sender_account_id acc, SUM(amount) debit, 0 credit FROM transactions GROUP BY sender_account_id
UNION ALL
SELECT receiver_account_id, 0, SUM(amount) FROM transactions GROUP BY receiver_account_id
)
SELECT acc, SUM(debit)-SUM(credit) net_outflow
FROM flow
GROUP BY acc
ORDER BY net_outflow DESC;

-- Detect suspicious micro-transactions (many small transfers)
SELECT sender_account_id
FROM transactions
WHERE amount < 100
GROUP BY sender_account_id
HAVING COUNT(*) > 5;

-- Final risk scoring with multi-factor logic
SELECT sender_account_id,
COUNT(f.txn_id)*3 +
SUM(CASE WHEN amount > 100000 THEN 2 ELSE 1 END) AS risk_score
FROM transactions t
LEFT JOIN fraud_log f ON t.txn_id = f.txn_id
GROUP BY sender_account_id
ORDER BY risk_score DESC;

--------------------------------------------------
-- END OF PROJECT 
--------------------------------------------------
