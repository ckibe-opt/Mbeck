# Debugging Guide: Mbeck Commerce Layer & Connectivity Protocol

This guide outlines the surgical steps an agent or developer should take to verify and debug the **Commerce Layer** (Checkout, Handshake, and Event Sourcing) implemented in the Mbeck Seller App.

---

## 1. Readiness Verification (The "Is it on?" Check)

Before testing endpoints, ensure the server is actually running and reachable.

### 1.1 Check Server Logs
Search the Flutter console logs for the following success markers:
- `🚀 Server running on http://<ip>:8080`
- `📡 Broadcasting service: <ShopName> on port 8080`
- `✅ Background Supabase Initialized`

### 1.2 Verify mDNS (Bonsoir)
If the Buyer app cannot "see" the shop:
- Use a tool like **Service Discovery** (Android/iOS) or `dns-sd -B _mbeck-pos._tcp` (MacOS/Windows) to see if `_mbeck-pos._tcp` is broadcasting.
- Check `lib/server/service_discovery.dart` to ensure the attributes (ID, version) are correctly mapped.

---

## 2. Endpoint Testing (Handshake & Commerce)

You can test these using `curl` or Postman from any device on the SAME local network.

### 2.1 Handshake (GET `/api/v1/info`)
**Goal:** Verify basic connectivity and currency config.
```bash
curl http://<seller-ip>:8080/api/v1/info
```
**Expected Response:**
```json
{
  "name": "Mbeck Shop",
  "currency": "KES",
  "version": "1.0.0"
}
```

### 2.2 Checkout (POST `/api/v1/cart/checkout`)
**Goal:** Process a sale and verify signature integrity.
```bash
curl -X POST http://<seller-ip>:8080/api/v1/cart/checkout \
     -H "Content-Type: application/json" \
     -d '{
       "items": [{"id": 1, "qty": 1}],
       "meta": "Postman-Debug"
     }'
```
**Success Indicators:**
- Response `200 OK` with a `transactionId` (UUID).
- A `signature` (HMAC-SHA256) is returned.
- **Terminal Log:** `✅ API Checkout Success: <uuid> for <amount>`

---

## 3. Storage & State Verification (Database)

If the API returns success, you MUST verify the data actually hit the disk.

### 3.1 Check the Ledger (`events` table)
The system uses Event Sourcing. Every API sale MUST create a `SALE` event.
```sql
SELECT * FROM events WHERE event_type = 'SALE' ORDER BY timestamp DESC LIMIT 1;
```
- Verify `synced = 0` (it should wait for the next Cloud Sync).
- Verify the `payload` contains the `receiptSignature`.

### 3.2 Check Materialized Views (`txn` & `transaction_items`)
The `EventProcessor` should have "projected" the event into the transaction tables.
```sql
SELECT * FROM txn ORDER BY timestamp DESC LIMIT 1;
SELECT * FROM transaction_items WHERE transactionId = <id>;
```
- Ensure `totalAmount` matches the API request.
- Ensure `type` is `sale`.

---

## 4. Common Failure Modes & Fixes

| Issue | Symptom | Fix |
| :--- | :--- | :--- |
| **IP Mismatch** | `Connection Refused` | Check `lib/server/local_server.dart`. If on Hotspot, the IP might be `192.168.43.1`. |
| **400 Bad Request** | `Item not found` | Verify that the `id` passed in `items[]` exists in the `inventory` table. |
| **Insufficient Stock** | `400 Bad Request` | Update product stock in the Inventory Screen before testing. |
| **Auth Failures** | `500 Internal Error` | Ensure `DeviceService.getDeviceId()` returns a valid string (used as the HMAC key). |

---

## 5. Agent-Specific Debugging Protocol

When an agent is asked "Why isn't the API working?", they should:
1. `grep_search` for `ShopServer.start` to see if it's called in `main.dart` or `BackgroundShopService`.
2. `view_file` on `lib/server/routes/api_router.dart` to verify path regex.
3. `run_command` a small dart script that attempts a `GET` request to `localhost:8080/api/v1/status`.
4. Check `pubspec.yaml` for `shelf` and `shelf_router` versions if there are compilation errors.
