# myShop: AI-Powered Offline POS

**Version:** 1.0.0+1

myShop (formerly Mbeck enterprise) is a sophisticated, offline-first Point of Sale (POS) and inventory management solution. Specifically engineered for retail shops and mobile money (M-Pesa) agents, it addresses the challenges of low-connectivity environments by providing high-speed local data persistence, advanced financial reconciliation, and a pioneering AI-driven visual product recognition engine.

The core value proposition lies in its ability to turn entry-level Android devices into powerful business analytical tools without the need for cloud subscriptions or active internet connectivity.

# Key Features

## 🤖 AI-Powered Visual Recognition
The defining feature of myShop is its visual matching engine. Unlike standard barcode scanners, myShop utilizes computer vision to identify products based on their physical branding and packaging.

*   **Model:** Uses a quantized `EfficientNet-Lite0` TFLite model for feature extraction.
*   **Process:** Images are resized to 224x224, and the model generates a 1280-dimension feature vector.
*   **Matching:** Cosine Similarity is used to measure the angular distance between a live scan and stored inventory vectors, finding the closest match.
*   **Training:** A "Global AI Training" mechanism uses a triple-crop analysis to create a stable "Master Centroid" for each product, improving recognition from multiple angles.

## 💰 Financial Management & Accounting
myShop provides a dual-layer financial tracking system designed to eliminate "lost money" through rigorous reconciliation and profit analysis.

*   **Profit Engine:** Calculates net profit at the transaction level: `(Selling Price - Discount) - Buying Cost`.
*   **Reconciliation:** A digital ledger to balance physical cash and digital balances (M-Pesa, Banks). It supports inline math for quick tallies.
*   **Disparity Tracking:** Automatically highlights surpluses or shortages by comparing expected totals with actual counts.

## 🛡️ Security & Anti-Fraud
*   **Digital Receipt Verification:** To prevent fake payment messages, myShop generates a unique security signature for every sale based on the timestamp and total amount. An employee can use the "Verify Receipt" tool to confirm a receipt's authenticity by checking its Ref Code and Signature against the secure database log.

## 📦 Inventory & Customer Management
*   **Visual Stock:** Attach multiple photos to items, and train the AI to recognize them from different angles.
*   **Stock Control:** Manage stock levels, get restock analysis, and easily add new inventory.
*   **CRM:** Maintain customer profiles with contact details and import them in bulk via CSV.

# ⚙️ Technical Architecture
The application is built on the Flutter framework, prioritizing low-latency performance on low-end hardware.

*   **Framework:** Flutter (Dart)
*   **Database:** `sqflite` (local SQLite) for all data persistence. The schema is versioned and includes tables for `inventory`, `inventory_vectors`, and `txn`.
*   **AI:** `tflite_flutter` for running the `EfficientNet-Lite0` model.
*   **Performance:** Optimized for low-end chipsets like the Unisoc T615, using EMA for vector refinement and batch restraints during AI training to prevent thermal throttling.

# 🚀 Getting Started

## Prerequisites
*   Flutter SDK
*   Android Device or Emulator (Min SDK 21)

## Installation
1.  Clone the repository:
    ```sh
    git clone <repository-url>
    ```
2.  Navigate to the project directory:
    ```sh
    cd Mbeckapp_Final
    ```
3.  Install dependencies:
    ```sh
    flutter pub get
    ```
4.  Run the app:
    ```sh
    flutter run
    ```

## Building for Release
To generate a release APK:
```sh
flutter build apk
```
The output will be located at `build/app/outputs/flutter-apk/app-release.apk`.

# 📄 License
Copyright © 2026. All Rights Reserved.

This software is proprietary. Unauthorized copying, modification, distribution, or use of this software is strictly prohibited without prior written permission from the copyright holder.