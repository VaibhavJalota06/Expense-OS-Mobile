# 📄 Official Expense OS Export Template & Data Standard

This document defines the official **Executive Export Template Standard** for Expense OS. Use this guide whenever exporting user data from Supabase or generating reports from the application.

---

## 🎯 **Official Template Specification**

### 1. **Header Metadata Section**
```csv
"=== EXPENSE OS — EXECUTIVE FINANCIAL STATEMENT & AUDIT REPORT ==="
"User Account:","{USER_EMAIL_OR_ID}"
"Base Currency:","{CURRENCY_CODE} ({CURRENCY_SYMBOL})"
"Monthly Budget Cap:","{CURRENCY_SYMBOL}{MONTHLY_BUDGET}"
"Export Date:","{YYYY-MM-DD}"
""
```

### 2. **Detailed Transactions Ledger Table**
```csv
"=== DETAILED TRANSACTIONS LEDGER ==="
"Date","Category","Description","Payment Method","Amount ({CURRENCY_CODE})"
"{YYYY-MM-DD}","{CATEGORY_NAME}","{ITEM_DESCRIPTION}","{PAYMENT_METHOD}","{AMOUNT}"
```

### 3. **Recurring Bills & Subscriptions Table**
```csv
"=== RECURRING BILLS & SUBSCRIPTIONS ==="
"Bill Name","Category","Monthly Cost ({CURRENCY_CODE})","Next Billing Date"
"{BILL_NAME}","{CATEGORY_NAME}","{AMOUNT}","{YYYY-MM-DD}"
```

### 4. **Extra Income Streams Table**
```csv
"=== EXTRA INCOME STREAMS ==="
"Income Source","Category","Amount ({CURRENCY_CODE})","Date Received"
"{SOURCE_NAME}","{CATEGORY_NAME}","{AMOUNT}","{YYYY-MM-DD}"
```

---

## 🛠️ **Supabase Admin Export Commands**

To export all users' data directly from **Supabase Dashboard**:

1. Go to **Supabase Dashboard** ➔ **Table Editor**.
2. Select **`vw_admin_all_user_expenses`** for all expenses across all users formatted into clean Excel rows.
3. Select **`vw_admin_user_summaries`** for an overview of all active user accounts and counts.
4. Click **Export CSV**!

---

## 🔒 **Data Privacy Notice**
All exports contain confidential financial records. Keep exported files securely stored.
