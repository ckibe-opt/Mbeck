# Mbeck Security Analysis: Threat Model & Defense Strategy

**Date:** February 1, 2026  
**Version:** 1.0.0 (Security Audit)  
**Status:** Architecture Validation

---

## 1. The Security Philosophy: "Trust No One (Except the Device)"

The classic Cloud security model ("Trust the Server") does not apply here because the "Server" is an Android phone that can be stolen, rooted, or manipulated.

**Core Principle:** The Seller's Device is the "Root of Trust" for the Shop, but the Cloud is the "Root of Truth" for the Franchise.

---

## 2. Threat Landscape (Attack Vectors)

We categorize threats based on the STRIDE model.

| Threat | Description in Mbeck Context | Severity | Likelihood |
| :--- | :--- | :--- | :--- |
| **Spoofing** | A malicious actor broadcasts as "Mbeck Shop" on the same WiFi to steal Buyer data. | High | Low (Requires physical proximity) |
| **Tampering** | A Buyer modifies the `receipt` JSON on their phone to claim they bought 10 items instead of 2. | Medium | High |
| **Repudiation** | A Shop Clerk sells an item for Cash but deletes the transaction record to pocket the money. | Critical | Medium |
| **Information Disclosure** | A thief steals the Seller's phone and dumps the `inventory.db` to see cost prices. | High | Low |
| **Denial of Service** | A competitor floods the Shop's WiFi with mDNS packets, freezing the Seller App. | Low | Low |
| **Elevation of Privilege** | A Staff member finds a way to access "Manager Only" finance screens. | Critical | Medium |

---

## 3. Defense Mechanisms (Strengths)

### 3.1 Digital Receipts & Cryptographic Integrity
To prevent **Tampering**, every receipt issued is signed.
*   **Mechanism:** `HMAC-SHA256(SecretKey, ReceiptData)`.
*   **Defense:** If a Buyer changes "Price: 500" to "Price: 50", the Hash recalculation will fail validation on the Seller's device during a return/audit.

### 3.2 Role-Based Access Control (RBAC)
To prevent **Repudiation** by staff.
*   **Strict Mode:** Staff cannot "Delete" transactions. They can only "Refund" (which creates a negative transaction record).
*   **Audit Trail:** Every action (Login, Sale, Refund) is logged with `user_id` and `timestamp`.
*   **Cloud Sync:** Logs are pushed to Supabase periodically. Even if the local DB is wiped, the Cloud Log remains (once synced).

### 3.3 Data Sovereignty (Privacy Strength)
*   **Benefit:** Customer data (Purchase History) lives on *their* phone (Buyer App) and the Shop's phone (Seller App). It is not aggregated in a central "Big Tech" database by default.
*   **Compliance:** Naturally aligns with Data Localization laws since data stays within the jurisdiction (on the device).

---

## 4. Current Vulnerabilities & Mitigations

### 4.1 Vulnerability: The "Open WiFi" Problem
*   **Risk:** The protocol currently uses HTTP over local LAN. Anyone on the WiFi with Wireshark can see the JSON traffic (product names, prices).
*   **Mitigation (Phase 2):** Implement **mTLS (Mutual TLS)**.
    *   Seller App generates a Self-Signed Cert.
    *   Buyer App pins this cert upon first pairing.
    *   All traffic becomes encrypted (HTTPS).

### 4.2 Vulnerability: Physical Device Compromise (Rooting)
*   **Risk:** If the Seller's Android device is Rooted, the `sqflite` database file is accessible. An attacker could modify the `stock` counts directly via SQL injection tools.
*   **Mitigation (Phase 2):** **SQLCipher**.
    *   Encrypts the entire SQLite database file with AES-256.
    *   The Key is derived from user entry (PIN/Password) on startup + Android Keystore salt.
    *   Without the PIN, the extracted `.db` file is garbage.

### 4.3 Vulnerability: AI Poisoning (Adversarial Attacks)
*   **Risk:** A malicious user trains the AI on a "Toyota" but labels it "Mercedes".
*   **Mitigation (Phase 3):**
    *   **Consensus Mechanism:** If 50 shops identify Vector X as "Toyota" and 1 shop says "Mercedes," the 1 shop is flagged as an outlier (anomaly detection).
    *   **Trust Score:** New shops have low "Training Weight." Verified shops have high weight.

---

## 5. Compliance & Regulatory Review

### 5.1 GDPR / Data Protection Act (Kenya)
*   **Right to serve:** Users own their data.
*   **Right to Erasure:**
    *   *Buyer:* "Delete my data" -> Wipes local DB.
    *   *Seller:* "Delete customer X" -> Anonymizes the receipt log (keeps the financial total, wipes the name/phone).

## 6. Conclusion

Mbeck's security model trades **Centralized Hardening** for **Decentralized Resilience**. While it introduces new vectors (physical theft), it eliminates the single biggest risk in modern retail: **The Central Database Breach**. By distributing data across thousands of devices, the "Blast Radius" of any single compromise is contained to one shop, not the entire ecosystem.
