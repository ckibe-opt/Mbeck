# Operational Risk Analytics – System Overview & Tradeoffs

## Purpose of This Document

This document explains **how the operational risk analytics system works** and the **design tradeoffs** made. It is intended for **Microfinance Institutions (MFIs)** and other financial partners to understand the reliability, scope, and limitations of the exported data.

The data is exposed via a **read-only SQL view** used strictly for **admin/dashboard export**.

---

## High-Level System Overview

The system evaluates shop-level operational behavior using **transactional events** and **credit profile metadata**. The goal is to provide MFIs with a **lightweight, explainable risk signal** based on real operational activity rather than self-reported data.

### Core Data Sources

1. **credit_profiles**

   * One row per shop
   * Stores relatively stable attributes
   * Examples:

     * Risk index
     * Current status
     * Last audit / evaluation timestamp

2. **events**

   * Append-only operational event log
   * High-frequency, time-series data
   * Examples:

     * Sales
     * Cash discrepancies
     * Operational actions

---

## Analytics Window (30-Day Rolling Period)

All computed metrics are based on the **last 30 days** of activity.

### Why 30 Days?

* Captures **recent behavior**, not historical noise
* Aligns with common credit review cycles
* Reduces impact of outdated operational patterns

This window is recalculated dynamically whenever the view is queried.

---

## Metrics Explained

### 1. Shop Identifier (`shop_id`)

* Unique identifier for each shop
* Ensures one-row-per-shop output

---

### 2. Risk Index (`risk_index`)

* Sourced directly from `credit_profiles`
* Represents the system’s latest internal risk assessment
* May incorporate additional offline or manual evaluations

**Tradeoff:**

* Not recalculated in real time
* Prioritizes stability over volatility

---

### 3. Status (`status`)

* Operational or credit state of the shop
* Example values: active, suspended, under_review

**Tradeoff:**

* Explicit state makes decisions explainable
* Avoids black-box scoring only

---

### 4. Active Days (Last 30 Days)

**Definition:**

* Count of distinct calendar days where the shop recorded *any* event

**What it signals:**

* Operational consistency
* Regular engagement with the system

**Why not total events?**

* Prevents inflation by high-frequency but low-quality activity
* A single day with many events still counts as one active day

---

### 5. Average Daily Sales (Last 30 Days)

**Definition:**

* Total value of SALE events over 30 days
* Divided by number of active days

**Why average per active day?**

* Fair comparison between shops with different operating schedules
* Prevents penalizing shops that are legitimately inactive on some days

**Edge Case Handling:**

* If a shop has 0 active days, the value returns **0** (safe division)

**Tradeoff:**

* Does not distinguish between low-volume and high-volume days
* Optimized for trend detection, not revenue forecasting

---

### 6. Cash Accuracy Rate

**Definition:**

* Starts at 100%
* Each detected cash discrepancy reduces score by 5 points
* Lower bound capped at 0%

**What it measures:**

* Cash handling discipline
* Frequency of reconciliation issues

**Why penalty-based instead of ratio-based?**

* Easier to explain
* Easier to audit
* Encourages operational discipline

**Tradeoff:**

* Treats all discrepancies equally
* Severity-based weighting can be added later if needed

---

### 7. Last Audit Date

* Pulled from `credit_profiles.last_evaluated`
* Indicates when the shop was last formally reviewed

**Why included?**

* Helps MFIs assess data freshness
* Supports manual underwriting workflows

---

## Security & Access Model

### Read-Only View

* The analytics are exposed through a **SQL VIEW**
* No write access
* No direct table exposure

### Restricted Permissions

* **Not accessible** to:

  * Anonymous users
  * Authenticated application users
* Available only to:

  * Admin dashboards
  * Approved data export pipelines

**Tradeoff:**

* Reduced flexibility for third parties
* Strong protection against data leakage

---

## Design Tradeoffs Summary

| Decision                  | Benefit               | Tradeoff                  |
| ------------------------- | --------------------- | ------------------------- |
| 30-day rolling window     | Recent, relevant data | Ignores long-term history |
| One row per shop          | Simple integration    | Less granular             |
| Penalty-based accuracy    | Explainable           | Less nuanced              |
| Read-only SQL view        | Secure & auditable    | Limited customization     |
| Event-day activity metric | Fairness              | Loses intraday detail     |

---

## What MFIs Should Take Away

* The system prioritizes **explainability over complexity**
* Metrics are **behavior-driven**, not self-reported
* Data reflects **recent operational reality**
* Scores are designed for **risk screening**, not final credit decisions

MFIs are encouraged to combine this data with:

* On-site audits
* Financial statements
* Historical repayment behavior

---

## Future Extensions (Optional)

* Longer-term trend views (90d / 180d)
* Weighted discrepancy severity
* Seasonality-aware sales normalization
* API-based partner access with scoped permissions

---

**End of Document**
