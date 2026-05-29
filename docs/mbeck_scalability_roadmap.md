# Mbeck Ecosystem: Scalability & Strategic Roadmap (The Global Graph)

**Date:** February 1, 2026  
**Version:** 1.0.0 (Forward Outlook)  
**Status:** Implementation (Phase 2 Started)

---

## 1. The Enterprise Architecture (Phase 2)

While V1 targets the "Single Shop," Phase 2 is engineered for the "Retail Chain" (Franchises with 10-500 outlets).

### 1.1 Multi-Tenant Hierarchy
The data model expands to support complex ownership structures via **Supabase Row Level Security (RLS)** using a hierarchical approach.

*   **Super Admin (Franchise HQ):** Can view aggregated analytics across ALL branches. Can push "Master Inventory" updates (e.g., price changes) to all nodes.
*   **Regional Manager:** Access to a subset of shops (e.g., "Nairobi Region").
*   **Shop Manager:** Local admin rights for a specific `shop_id`.
*   **Clerk:** Sales-only access to a specific terminal.

### 1.2 The Sync Engine: Vector Clocks & CRDTs
When 50 shops sync inventory, "Last Write Wins" causes data loss. We will migrate to **Conflict-free Replicated Data Types (CRDTs)**.
*   **Scenario:** Shop A updates "Coke" price to 50. Shop B updates "Coke" price to 60. Both are offline.
*   **Resolution:** Instead of overwriting, the Cloud stores *both* operations in a `delta_log`. The Franchise HQ resolves the conflict, or a policy is applied (e.g., "High Price Wins").

---

## 2. The Global Product Knowledge Graph (Phase 3)

The ultimate scalability play is **Shared Intelligence**. Currently, every shop trains its own AI. This is redundant.

### 2.1 "One Photo, Everywhere"
If a shop in Mombasa successfully trains the AI to recognize a "500ml Tusker Cider," that vector signature (centroid) is anonymized and uploaded to the Global Graph.
1.  **Validation:** Cloud models (Server-side TensorFlow) verify the vector isn't "poisoned" (e.g., a photo of a cat labeled as "Cider").
2.  **Propagation:** A new shop in Kisumu downloads the "Beverage Pack."
3.  **Result:** The new shop's AI works *instantly* without training a single item.

### 2.2 The Vector Exchange Protocol
*   **Format:** Protocol Buffers (Proto3) for compact vector transmission.
*   **Bandwidth:** Differential Sync. Only download vector centroids that have shifted by > 5% Euclidean distance.

---

## 3. Database Partitioning & Sharding

As we move from 1,000 shops to 100,000 shops, the Supabase PostgreSQL cluster must scale.

*   **Horizontal Sharding:** Partition data by `Country` or `Region`.
    *   `shops_ke` (Kenya) lives in the `af-south-1` AWS region.
    *   `shops_ng` (Nigeria) lives in `af-west`.
*   **Cold Storage:** Transaction logs older than 1 year are moved to S3/Parquet for Data Warehousing (BigQuery analysis) to keep the active OLTP database light.

---

## 4. Fintech Integration at Scale

Scale unlocks financial products that are impossible for standalone shops.

### 4.1 "Credit as Code"
Algorithmically generated credit lines based on verified inventory turnover.
*   **Input:** Verified Receipt Logs (Cryptographically signed).
*   **Model:** "Shop sells 500 loaves of bread/week with 0% default risk."
*   **Offer:** Auto-approve a supplier loan for 600 loaves.

### 4.2 The "Mbeck Card" (Consumer)
Since we control the Buyer App:
*   **Wallet:** Integrated MPC (Multi-Party Computation) wallet.
*   **Loyalty:** "Universal Points" earned across any Mbeck-powered shop.

---

## 5. Technical Risers (Infrastructure Requirements)

To achieve this roadmap, the following infrastructure upgrades are required:

| Component | Current State | Required State |
| :--- | :--- | :--- |
| **Vector DB** | SQLite Blob (Linear Scan) | **pgvector** (HNSW Index) on Cloud for Global Graph. |
| **CDN** | Standard HTTPS | **Edge Caching** for Product Images (Cloudflare R2). |
| **Compute** | Serverless Functions | **Dedicated Inference Nodes** (GPU) for anti-poisoning validation. |

---

## 6. Conclusion: The Network Effect

Mbeck's defensive moat is not the code—it is the **Network Effect of the Data**.
*   The more shops use Mbeck, the smarter the AI gets (Global Graph).
*   The smarter the AI gets, the easier it is for new shops to join.
*   The more shops join, the more valuable the data becomes to Suppliers and Banks.

This roadmap transforms Mbeck from a "Tool" into an "Ecosystem."
