# Mbeck Ecosystem — Technical Policy & Execution Plan (V2.0)

## Purpose
This document defines the **non-negotiable product, legal, and architectural constraints** for the Mbeck Ecosystem.
An autonomous coding agent MUST follow this document exactly.
If ambiguity arises, the agent must **STOP** and request human input.

---

## 1. Core Philosophy: "Heavy Edge, Light Cloud"

### 1.1 Decentralized Autonomy
- Mbeck is a **Local-First** commerce protocol.
- The Seller device is a micro-server. Core commerce (Cart, Checkout, Inventory) MUST function without internet.
- P2P interaction (Buyer-Seller) uses mDNS (Bonsoir) and local WiFi.

### 1.2 Visual Intelligence
- Mbeck uses Computer Vision (AI) as the primary entry point for commerce.
- AI Visual Vectors are treated as **Proprietary Knowledge Graph** data.
- Recognition happens on-device; raw images are never uploaded to the cloud for inference.

---

## 2. Legal & Regulatory Position (LOCKED)

### 2.1 Role Definition
- MbeckApp is **NOT a lender**.
- MbeckApp is a **Behavioral Risk Signal Provider** and **Connectivity Layer**.
- Mbeck facilitates the relationship between merchants and third-party financial institutions.

### 2.2 Prohibited Actions
- Holding users' funds.
- Disbursing loans from Mbeck accounts.
- Calculating or displaying "Interest Rates" (use "Partner Fees" or "Service Costs" if provided by partners).
- Displaying "Loan Approved" language.

### 2.3 Required Terminology (Regulatory Compliance)
- **Allowed:** “Your shop activity may qualify you for partner financing”, “Partner Eligibility Signal”, “Based on recorded business behavior”, “Eligibility is determined by third-party lenders”.
- **Disallowed:** “Loan approved”, “We lend”, “Guaranteed credit”, “You are eligible for a loan”.

---

## 3. User Consent & Data Privacy

### 3.1 Explicit Consent Model
- Consent is requested **ONLY** when the user opens the **Financing/Credit** section.
- Users must explicitly agree to share behavior signals with partners.

### 3.2 Audit Trail
- Every consent action MUST emit `CREDIT_CONSENT_GRANTED` or `CREDIT_CONSENT_REVOKED` events to the append-only ledger.

### 3.3 Data Scope
- **Shared:** Aggregated trust scores, consistency metrics, volume indicators.
- **Never Shared:** Customer PII, raw transaction line items, AI Visual Vectors, raw images.

---

## 4. Business Day & Operational Integrity

### 4.1 Day Boundary
- The Business Day runs from **05:00 → 04:59** (Local Time).
- All daily aggregations (sales, trust scores) must respect this boundary.

### 4.2 Cash Count & Disparity
- **Grace Period:** Cash counts are allowed until **07:00** for the previous business day.
- **Tolerance:**
  - ≤ KSh 300 → Ignored.
  - KSh 301–1,000 → Soft penalty (flagged in analytics).
  - > KSh 1,000 → Hard penalty (affects Trust Score).
- **Disqualification:** ≥ 3 shortages over KSh 5,000 within 30 days flags the account for partner review.

---

## 5. Transaction Integrity

### 5.1 Immutable Ledger
- Transactions (Sales) are **NEVER** deleted.
- Errors are corrected via `SALE_REFUND` or `INVENTORY_ADJUSTMENT` events.
- Frequent adjustments or refunds reduce the "Reliability Score".

### 5.2 Cryptographic Proof
- Every transaction MUST be signed on-device (HMAC-SHA256).
- Receipts are verifiable by the Buyer app.

---

## 6. Hard Stop Conditions (Agent MUST HALT)

If any of the following appear, **STOP immediately**:
- Implementation of interest/loan calculation logic.
- Direct money transfer/disbursement features from Mbeck.
- Bypassing the local-first "No Internet" requirement.
- Sharing raw PII or AI vectors with third parties.

---

## 7. Human Intervention Gates

Agent must pause and request approval at:
1. Modification of the Trust Score algorithm.
2. Changes to any regulatory wording in the UI.
3. First real external partner API integration.
4. Changes to the cryptographic signing process.

---

## End of Document
