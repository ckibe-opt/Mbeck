# The Mbeck Ecosystem: The Operating System for Unorganized Retail

**Date:** February 1, 2026  
**Version:** 1.0.0 (Master Overview)  
**Status:** Strategic Blueprint

---

## 1. Executive Vision

**Mbeck** is not just a Point of Sale (POS) app; it is a **Decentralized Commerce Protocol** designed for the "Next Billion" merchants in emerging markets.

The central thesis of Mbeck is that the future of retail in Africa, LATAM, and SE Asia is not "Cloud First"—it is **"Edge First."** By turning the merchant's smartphone into a self-contained AI Server, Mbeck eliminates the dependency on potentially unstable infrastructure (ISPs, Cloud Servers) and delivers the speed of a modern supermarket to a roadside kiosk.

### The Core Problem: Retail Friction
Legacy retail faces a trilemma:
1.  **Manual Entry:** Types prices is slow and error-prone.
2.  **Barcodes:** Require specific hardware (\$100+ guns) and preregistered UPCs.
3.  **Connectivity:** Cloud POS systems freeze when the internet drops.

### The Mbeck Solution: Visual Intelligence
Mbeck replaces the barcode scanner with the **Camera**. Using a quantized `EfficientNet` neural network running on-device, it recognizes products by their visual signature ("The Red Coke Bottle") in <100ms.

---

## 2. System Architecture: "Heavy Edge, Light Cloud"

The ecosystem is built on a `Local-First` topology.

### A. The Seller Node (The Edge Server)
*   **Role:** The "Brain" of the shop.
*   **Tech:** Android Host running a local HTTP/WebSocket server.
*   **Capability:** Stores the entire Inventory Vector Database locally (`sqflite`). It does not need the internet to process a sale, scan an item, or sync with a local customer.

### B. The Buyer Node (The Edge Client)
*   **Role:** The "Remote" for the customer.
*   **Tech:** Cross-platform (Android/Windows/iOS).
*   **Capability:** Connects directly to the Seller via **mDNS (Bonsoir)** over local WiFi. It allows customers to "Self-Checkout" without standing in line.

### C. The Cloud Layer (The Aggregator)
*   **Role:** The "Bank" and "HQ".
*   **Tech:** Supabase (PostgreSQL).
*   **Capability:** Stores backup logs, enforces RBAC (Role-Based Access Control), and facilitates "Global Graph" training (see Roadmap).

---

## 3. Commercial Strategy & Business Model

> [!NOTE]
> For a detailed breakdown of revenue streams, target segments, and acquisition strategy, see [mbeck_business_model.md](mbeck_business_model.md).

Mbeck monetizes **Trust** and **Efficiency**.

### 3.1 Revenue Streams
1.  **SaaS Subscriptions:**
    *   **Pro (\$10/mo):** For established shops needing Multi-Staff & Cloud Backup.
    *   **Enterprise:** For franchises needing aggregated analytics.
2.  **Fintech Pivot (The Real Prize):**
    *   Using cryptographically verified receipt logs to build **Credit Scores** for SMEs.
    *   Offering **Inventory Financing** (Buy now, pay later) based on predictive sales data.

### 3.2 The Defensive Moat: Visual Data
Mbeck's stickiness comes from its data. Once a shop trains 1,000 items visually, switching to a competitor (who requires manual re-entry) is vanishingly unlikely. The **Visual Knowledge Graph** is a proprietary asset that grows stronger with every scan.

---

## 4. Current State & Limitations

We are in **V1 Production** with validated core features.

*   ✅ **Production Ready:** Offline Sales, AI Scanning (Good Light), P2P Digital Receipts, Local Discovery.
*   ⚠️ **Limitations:**
    *   **The "10k Wall":** Vector search slows down after 10,000 items per shop.
    *   **Low Light:** Camera recognition struggles in dark bars/clubs.
    *   **Cloud Sync:** Conflict resolution is basic ("Last Write Wins"); not yet suitable for large 50-branch franchises.

---

## 5. Strategic Roadmap

### Phase 1: The Single Shop (Current)
Dominate the "Kiosk" market. Perfect the Offline UX. Build the "Viral Loop" via WhatsApp Receipts.

### Phase 2: The Enterprise Chain (Next 6-12 Months)
Implement **Vector Clocks** and **CRDTs** for conflict-free multi-device sync. Enable "HQ" dashboards for franchise owners.

### Phase 3: The Global Graph (Long Term)
"One Photo, Everywhere."
*   If Shop A trains "Tusker Beer," Shop B downloads the vector signature instantly.
*   The system evolves from "Self-Learning" to "Crowd-Sourced Intelligence," reducing onboarding time to near zero.

---

## 6. Conclusion

Mbeck is positioning itself as the **Operating System for the Informal Economy**. By respecting the constraints of the environment (offline, low-end hardware) but leveraging the power of modern AI (Computer Vision), it creates a bridge between the street-side vendor and the global digital financial system.
