# Mbeck Ecosystem: Technical Deep Dive & System Connectivity

**Date:** February 5, 2026  
**Status:** Current State Documentation (v1.1.0)

---

## 1. Overview: The "Heavy Edge, Light Cloud" Philosophy

The Mbeck system is a decentralized commerce protocol designed for offline-first retail environments. It shifts the primary computational and storage burden from a centralized cloud to the **Seller Node** (the merchant's device), which functions as a high-performance local server.

### The Problem it Solves
- **Connectivity Gaps:** Eliminates dependency on the internet for core retail operations.
- **Hardware Friction:** Replaces expensive barcode scanners with high-speed AI-powered visual recognition.
- **Latency:** Achieves <200ms "Scan-to-Match" performance by keeping inference and data on the local network.

---

## 2. The Seller Node: Technical Architecture

The Seller Node is the "Brain" of the shop. It is a Flutter-based application running on Android (primary) or Windows.

### 2.1 AI Perception Pipeline (`AIScannerService`)
Mbeck's differentiating factor is its visual recognition engine.
- **Model:** Quantized `EfficientNet-Lite0` neural network.
- **Input:** 224x224 RGB image tensors.
- **Inference:** Uses `tflite_flutter`. On compatible hardware (Pixel, high-end Samsung), it utilizes NPU/GPU delegates for sub-100ms inference.
- **Feature Vector:** The model produces a **1280-dimensional float vector** representing the visual signature of the product.
- **Normalization:** Vectors are L2-normalized to ensure consistent cosine similarity calculations.

### 2.2 Learning & Optimization
- **EMA Refinement:** Uses Exponential Moving Average ($\alpha = 0.95$) to refine an item's visual centroid over time as more scans are performed.
- **Collision Resolution:** When two items look similar (e.g., Small vs. Large Coke), the system uses **Contextual Scoring**:
    - **Category matching:** Weighting items in the same category higher.
    - **Stock levels:** Prioritizing in-stock items.
    - **Temporal peak:** Boosting items like "Beverages" during morning hours.
- **Visual Memory:** Supports "Extra Memory" slots per item to handle different angles or lighting conditions that a single centroid might not capture.

### 2.3 The Local Server
The Seller app hosts a background web server (built with `shelf`) that listens for Buyer connections.
- **Discovery:** Broadcasts its presence using **mDNS (Bonsoir)** under the service type `_mbeck-pos._tcp`.
- **Database:** Uses `sqflite` (SQLite) with Write-Ahead Logging (WAL) for concurrent reads by the UI and server.

---

## 3. The Buyer Node: Client Architecture

The Buyer Node is a lightweight client designed to interface directly with any Seller Node on the same local network.

### 3.1 P2P Connection Flow
1. **Discovery:** The Buyer scans the local network for `_mbeck-pos._tcp` services.
2. **Handshake:** Connects via HTTP to `GET /info` to retrieve shop name, currency, and theme.
3. **Vector Sync:** Calls `GET /api/v1/vectors` to download the entire shop's visual knowledge graph (IDs, names, prices, and 1280-dim vectors).

### 3.2 Decentralized AI Matching (`LanVectorService`)
One of Mbeck's most advanced features is that **scanning happens on the Buyer's device**, but the AI intelligence is provided by the Seller.
- The Buyer app runs the same AI model as the Seller.
- When a Buyer scans an item, their device generates a feature vector.
- Instead of sending the photo to the Seller, the Buyer's device compares the vector locally against the downloaded shop graph using **Cosine Similarity**.
- **Adaptive Cutoff:** The system shows all matches within 10% of the top score, provided the similarity is above **0.60**.

---

## 4. Connectivity & API Protocol

The "Connection" between Buyer and Seller is a custom REST-over-HTTP protocol optimized for low latency.

| Endpoint | Method | Purpose |
| :--- | :--- | :--- |
| `/info` | `GET` | Initial handshake: Shop identity, peer-to-peer capability check. |
| `/api/v1/vectors` | `GET` | Bulk export of the shop's AI knowledge graph for local matching on the Buyer device. |
| `/cart/checkout` | `POST` | Submits a cart for processing. The Seller validates prices and signs the transaction. |
| `/api/v1/theme` | `GET` | Syncs the Seller's custom colors/styles to the Buyer app for a branded experience. |

### Security & Integrity
- **HMAC Signatures:** Transactions are signed with a shop-specific secret key using `HMAC-SHA256`. This prevents Buyers from tampering with receipts or prices.
- **Verification:** The Seller re-computes the hash upon submission to ensure the integrity of the data.

---

## 5. Summary of System Roles

| Feature | Seller Role | Buyer Role |
| :--- | :--- | :--- |
| **Inventory** | Authoritative Source (Master DB) | Local Cache (Vectors Only) |
| **AI Model** | Training & Centroid Refinement | Inference & Local Matching |
| **Discovery** | Broadcaster (mDNS) | Listener/Resolver |
| **Payments** | Ledger Entry & Signature | Cart Assembly & Receipt Storage |
| **Cloud** | Periodic Sync to Supabase | Auth & Reviews Only |

---

## 6. Conclusion

The Mbeck ecosystem represents a shift toward **Local-First AI**. By enabling the Seller to broadcast their product intelligence (vectors) and the Buyer to perform local matching, the system achieves "Google Lens for Retail" speed without needing a single byte of internet data for the checkout journey.
