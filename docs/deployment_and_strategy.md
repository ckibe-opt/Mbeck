# Mbeck — Deployment, Naming, Icons & Strategy Guide

---

## 1. Supabase SQL Migrations

**No new SQL scripts are required.** Here's why:

| Concern | Status |
|---------|--------|
| Events table (`events`) | Schema-agnostic — stores `event_type TEXT` + `payload JSONB`. New event types (ENTERTAINMENT_ASSET_UPDATE, ENTERTAINMENT_SESSION_START, LODGING_ROOM_UPDATE, etc.) are just text values, no constraint changes needed. |
| Entertainment tables | Already created in `005_entertainment_module.sql` |
| Lodging tables | Already created in `006_lodging_module.sql` |
| `shop_modules` CHECK constraint | Already updated in 006 to allow all 5 modules |
| `transactions` CHECK constraints | Already updated in 006 to allow 'lodging' + 'reservation' |
| `subscription_plans` | Already updated in 006 to include lodging in pro/enterprise |

**One optional improvement** — if you want to add a `source_module` column to the Supabase `events` table for easier cloud-side analytics filtering, you could run:

```sql
-- OPTIONAL: Add source_module index for cloud analytics
ALTER TABLE events ADD COLUMN IF NOT EXISTS source_module TEXT;
CREATE INDEX IF NOT EXISTS idx_events_source_module ON events(shop_id, source_module);

-- Backfill from payload where possible
UPDATE events 
SET source_module = payload->>'source_module'
WHERE source_module IS NULL 
  AND payload->>'source_module' IS NOT NULL;
```

This is purely optional — the system works without it.

---

## 2. App Naming Suggestions

The naming should follow the **[Root Brand] [Role Noun]** pattern (like Uber Driver / Uber Rider).

### Recommended: **Mbeck Business** + **Mbeck Shop**

| App | Name | Rationale |
|-----|------|-----------|
| Seller app | **Mbeck Business** | The owner/staff manages their *business* — retail, restaurant, services, entertainment, lodging. "Business" is module-neutral and professional. |
| Buyer app | **Mbeck Shop** | Customers *shop* — they browse, order, book. Short, clear, action-oriented. |

### Alternative Options

| Pair | Seller | Buyer | Vibe |
|------|--------|-------|------|
| **Option A** | Mbeck Business | Mbeck Shop | Professional / Universal |
| **Option B** | Mbeck Manager | Mbeck Go | Operations / Quick access |
| **Option C** | Mbeck Pro | Mbeck | Power tool / Simple consumer |
| **Option D** | Mbeck Hub | Mbeck Connect | Central ops / Customer link |
| **Option E** | Mbeck Merchant | Mbeck Market | Commerce-focused |

### My Pick: **Option A** — `Mbeck Business` + `Mbeck Shop`

**Why:**
- "Business" covers all 5 modules without bias toward any one
- "Shop" is universally understood in Kenya — people say "niko kwa shop" for any establishment
- Clean, memorable, differentiable at a glance
- Mirrors successful patterns: Square (Square POS / Square Reader), Shopify (Shopify / Shop)

### Package IDs
```
Seller: com.mbeck.business
Buyer:  com.mbeck.shop
```

---

## 3. App Icons

### Design Concept

Both icons share the **Mbeck "M" lettermark** but with distinct color treatment:

| App | Icon Concept | Primary Color | Shape |
|-----|-------------|---------------|-------|
| **Mbeck Business** | Bold "M" with a subtle bar chart rising from the right leg | Deep Green (#1B5E20) → Emerald (#4CAF50) gradient | Rounded square (adaptive icon) |
| **Mbeck Shop** | Bold "M" with a shopping bag silhouette integrated into the letter | Deep Blue (#0D47A1) → Sky Blue (#2196F3) gradient | Rounded square (adaptive icon) |

### Implementation

Add `flutter_launcher_icons` to both apps:

**Seller `pubspec.yaml`:**
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/mbeck_business_icon.png"
  adaptive_icon_background: "#1B5E20"
  adaptive_icon_foreground: "assets/icons/mbeck_business_foreground.png"
  min_sdk_android: 21
```

**Buyer `pubspec.yaml`:**
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.3

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/mbeck_shop_icon.png"
  adaptive_icon_background: "#0D47A1"
  adaptive_icon_foreground: "assets/icons/mbeck_shop_foreground.png"
  min_sdk_android: 21
```

**To generate icons:**
```bash
# In each app directory:
dart run flutter_launcher_icons
```

### What you need to create (in Figma/Canva/AI):
1. **1024x1024 PNG** — full icon with background for iOS
2. **512x512 PNG** — foreground-only (transparent bg) for Android adaptive
3. Export as `mbeck_business_icon.png` / `mbeck_shop_icon.png`
4. Place in `assets/icons/` in each project

---

## 4. Splash / Loading Screen

### Implementation: `flutter_native_splash`

**Seller `pubspec.yaml`:**
```yaml
dev_dependencies:
  flutter_native_splash: ^2.4.4

flutter_native_splash:
  color: "#1B5E20"
  image: "assets/splash/mbeck_business_splash.png"
  android_12:
    color: "#1B5E20"
    icon_background_color: "#1B5E20"
    image: "assets/splash/mbeck_business_splash.png"
```

**Buyer `pubspec.yaml`:**
```yaml
dev_dependencies:
  flutter_native_splash: ^2.4.4

flutter_native_splash:
  color: "#0D47A1"
  image: "assets/splash/mbeck_shop_splash.png"
  android_12:
    color: "#0D47A1"
    icon_background_color: "#0D47A1"
    image: "assets/splash/mbeck_shop_splash.png"
```

**To generate:**
```bash
dart run flutter_native_splash:create
```

### Splash Design Spec

| Element | Mbeck Business | Mbeck Shop |
|---------|---------------|------------|
| Background | Solid deep green #1B5E20 | Solid deep blue #0D47A1 |
| Center logo | White "M" lettermark (200x200) | White "M" lettermark (200x200) |
| Tagline below | "Run your business" (white, 14px) | "Discover & shop local" (white, 14px) |

### What you need to create:
1. **512x512 PNG** — white logo on transparent bg (centered)
2. Place in `assets/splash/` in each project

---

## 5. Google Play Store Deployment Guide

### 5A. Developer Account Setup
- Google Play Developer account: **$25 one-time fee**
- URL: https://play.google.com/console/signup
- Use a business email, not personal

### 5B. Information Required Per App

#### **App 1: Mbeck Business (Seller)**

| Field | Value to Fill |
|-------|---------------|
| **App name** | Mbeck Business |
| **Short description** (80 chars) | All-in-one business manager: POS, orders, bookings, sessions & rooms. |
| **Full description** (4000 chars) | See template below |
| **App category** | Business |
| **App type** | Application |
| **Free or Paid** | Free (with in-app subscription) |
| **Content rating** | Complete the IARC questionnaire — answer No to all (no violence, gambling, etc.) → Rated for Everyone |
| **Target audience** | 18+ (business tool) |
| **Tags** | POS, point of sale, inventory, restaurant, booking, business management |
| **Contact email** | your-support@mbeck.co.ke |
| **Privacy policy URL** | https://mbeck.co.ke/privacy (you must host this) |
| **Default language** | English (United States) |
| **Country availability** | Kenya (start), then expand |

**Full Description Template (Mbeck Business):**
```
Mbeck Business is the all-in-one management app for Kenyan entrepreneurs.

Whether you run a retail shop, restaurant, salon, gaming lounge, or guest house — Mbeck Business gives you the tools to manage everything from one app.

🏪 RETAIL — Full POS, inventory tracking, barcode scanning, supplier management
🍽️ RESTAURANT — Menu management, kitchen order queue, table service, order tracking
💇 SERVICES — Booking calendar, staff scheduling, service catalog, supply deduction
🎮 ENTERTAINMENT — Session timing, asset management, automatic billing
🏨 LODGING — Room management, reservations, check-in/out, guest tracking

KEY FEATURES:
• Works 100% offline — no internet required for daily operations
• LAN sync — multiple devices stay in sync over WiFi
• Cloud backup — never lose your data
• Team management — add staff with role-based permissions
• Reports & analytics — daily, weekly, monthly insights
• M-Pesa integration — accept mobile payments
• Enterprise dashboard — manage multiple branches

Built for Kenyan businesses. Accepts KES. Works without internet.

Start free, upgrade when you grow.
```

#### **App 2: Mbeck Shop (Buyer)**

| Field | Value to Fill |
|-------|---------------|
| **App name** | Mbeck Shop |
| **Short description** (80 chars) | Browse, order & book from local businesses near you — no internet needed. |
| **Full description** (4000 chars) | See template below |
| **App category** | Shopping |
| **App type** | Application |
| **Free or Paid** | Free |
| **Content rating** | Everyone |
| **Target audience** | 13+ |
| **Tags** | local shopping, restaurant order, booking, QR scan, offline shopping |
| **Contact email** | your-support@mbeck.co.ke |
| **Privacy policy URL** | https://mbeck.co.ke/privacy |
| **Default language** | English (United States) |
| **Country availability** | Kenya (start) |

**Full Description Template (Mbeck Shop):**
```
Mbeck Shop connects you to local businesses around you.

Walk into any Mbeck-powered shop, scan the QR code or connect via WiFi, and instantly browse their products, menu, services, and more — no internet needed.

🛒 RETAIL — Browse products, see prices & stock, add to cart
🍽️ RESTAURANT — View the menu, order from your table, ping the waiter
💇 SERVICES — Book appointments, see available times
🎮 ENTERTAINMENT — See available gaming stations, pool tables & more
🏨 LODGING — Browse rooms, check availability, make reservations

WHY MBECK SHOP?
• No internet required — connects directly to the shop's WiFi
• No account needed — just scan and browse
• Real-time updates — see live stock, menu changes, availability
• Fast & lightweight — works on any Android phone
• Privacy first — no tracking, no data sold

Discover what's available at your favorite local spots.
Download Mbeck Shop and start exploring.
```

### 5C. Required Assets Per App

| Asset | Spec |
|-------|------|
| **App icon** | 512x512 PNG, 32-bit, no alpha |
| **Feature graphic** | 1024x500 PNG or JPG |
| **Phone screenshots** | Min 2, max 8. 16:9 or 9:16. Min 320px, max 3840px |
| **7-inch tablet screenshots** | Min 1 (recommended) |
| **10-inch tablet screenshots** | Min 1 (recommended) |

### 5D. Pre-Launch Checklist

- [ ] Privacy policy page hosted at a public URL
- [ ] App icon (512x512) designed and exported
- [ ] Feature graphic (1024x500) designed
- [ ] At least 4 screenshots per app (show key flows)
- [ ] App signed with upload key (not debug)
- [ ] `versionCode` and `versionName` set in `build.gradle`
- [ ] `minSdkVersion` set to 21 (Android 5.0+)
- [ ] ProGuard/R8 enabled for release build
- [ ] Removed all `debugPrint` or wrapped in `kDebugMode`
- [ ] Tested on real device (not just emulator)
- [ ] Data safety form completed in Play Console
- [ ] Content rating questionnaire completed

### 5E. Data Safety Form Answers

| Question | Mbeck Business | Mbeck Shop |
|----------|---------------|------------|
| Does your app collect user data? | Yes | Yes (minimal) |
| Data types collected | Name, email, phone (for account), business data, financial data (transactions) | Device ID only (no account) |
| Is data encrypted in transit? | Yes (HTTPS to Supabase) | Yes (local WiFi + HTTPS) |
| Can users request data deletion? | Yes | N/A (no persistent data) |
| Data shared with third parties? | No (except Supabase for cloud sync) | No |

### 5F. Signing & Release

```bash
# Generate upload key (one time)
keytool -genkey -v -keystore mbeck-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mbeck

# Build release APK
flutter build appbundle --release

# The .aab file will be at:
# build/app/outputs/bundle/release/app-release.aab
```

**IMPORTANT:** Back up `mbeck-upload-key.jks` and its password. If you lose it, you cannot update the app.

---

## 6. YouTube Video Analysis — Dan Martell: "How to Get SO Many Customers with AI it Feels ILLEGAL"

### Video Summary

Dan Martell walks through **5 phases of using AI in sales**:

1. **Prospecting** — Use AI tools (like Manis.AI) to auto-generate lead lists matching your ICP (ideal customer profile). 100% automatable.
2. **Qualifying** — Use AI voice/chat bots (like Your.com) to pre-qualify leads before they book into your calendar. Filter out 95% of unqualified leads.
3. **Presenting** — Feed CRM data + prospect info into ChatGPT to generate personalized proposals. Never just send a proposal — always schedule a call to present it.
4. **Objection Handling** — Upload call transcripts to ChatGPT, get AI-generated talk tracks for common objections. Use AI for roleplay practice.
5. **Closing & Delivery** — Celebrate the purchase, get the customer a quick win, automate onboarding. The human touch matters most here.

**Core principle:** 10-80-10 Rule — 10% ideation (human), 80% execution (AI), 10% integration/QA (human). AI handles the mechanical work; humans provide taste, vision, and care.

### How This Applies to Mbeck

#### Phase 1: Prospecting — Finding Business Owners

| Dan's Advice | Mbeck Application |
|-------------|-------------------|
| Use AI to build ICP-based lead lists | Build a prospect list of Kenyan SMBs: shop owners, restaurant operators, salon owners, gaming lounges, guest houses |
| Find the right person + contact details | Target: business owners on Facebook groups ("Nairobi Entrepreneurs", "Kenyan Restaurant Owners"), WhatsApp business groups, county trade registries |
| Automate research | Use ChatGPT to scrape public business directories (Google Maps, Yellow Pages Kenya) and generate CSV lead lists with name, business type, location, phone |

**Action items:**
- [ ] Create ICP document: "Kenyan SMB owner, 1-5 employees, handles cash + M-Pesa, no current POS system, located in urban/peri-urban area"
- [ ] Use ChatGPT to generate outreach message templates in English + Swahili
- [ ] Build a Google Sheet lead tracker with columns: Business Name, Type (retail/restaurant/services/entertainment/lodging), Location, Phone, Status, Notes
- [ ] Join 10+ Facebook groups for Kenyan entrepreneurs and observe pain points

#### Phase 2: Qualifying — Filtering Real Buyers

| Dan's Advice | Mbeck Application |
|-------------|-------------------|
| Use AI to pre-qualify before meetings | Create a WhatsApp Business auto-reply or chatbot that asks: (1) What type of business? (2) How many staff? (3) Do you currently use any POS/management app? (4) Would you like a free demo? |
| Only spend time on qualified leads | A qualified Mbeck lead: has a physical business, has staff or plans to hire, currently uses paper/manual tracking, has a smartphone |

**Action items:**
- [ ] Set up WhatsApp Business with auto-greeting that qualifies
- [ ] Create a simple Google Form: "Get a free Mbeck demo" with qualifying questions
- [ ] Use ChatGPT to generate a qualification script for phone calls

#### Phase 3: Presenting — Demo Strategy

| Dan's Advice | Mbeck Application |
|-------------|-------------------|
| Personalized proposals using AI | Before each demo, use ChatGPT to generate a personalized pitch based on their business type |
| Describe their pain better than they can | Pain points by module: |

**Pain points to agitate per module:**

| Module | Pain Point | Mbeck Solution |
|--------|-----------|----------------|
| Retail | "You lose track of stock and don't know what sold today" | Real-time inventory, auto stock alerts, daily reports |
| Restaurant | "Orders get lost between the table and kitchen" | Digital order queue, kitchen display, waiter ping |
| Services | "Clients double-book or don't show up" | Booking calendar with conflict detection, reminders |
| Entertainment | "You don't know how long someone's been playing or what to charge" | Auto-timer, calculated billing, session history |
| Lodging | "You track check-ins on paper and forget who's in which room" | Room status board, reservation management, auto billing |

**Action items:**
- [ ] Create a ChatGPT prompt template: "I'm about to demo Mbeck to a [business type] owner in [location]. Their pain is [X]. Generate a 5-minute demo script that starts with their pain, shows the solution, and ends with a clear offer."
- [ ] Record 5 short demo videos (one per module) for WhatsApp/YouTube
- [ ] Create a one-page PDF flyer per module (Swahili + English)

#### Phase 4: Objection Handling — Kenyan Market Specifics

| Common Objection | AI-Generated Response |
|-----------------|----------------------|
| "I don't need an app, my notebook works fine" | "How much time do you spend counting stock at month end? Mbeck does it automatically. And when your employee steals, the notebook won't tell you — Mbeck will." |
| "I can't afford monthly subscriptions" | "Mbeck is free to start. Most shop owners save more from catching stock theft than the subscription costs. And your first 90 days are completely free." |
| "My staff won't know how to use it" | "If they can use WhatsApp, they can use Mbeck. We designed it for phone-first users. And we give you free onboarding." |
| "What if the internet goes down?" | "Mbeck works 100% offline. It syncs over your WiFi — no internet needed for any daily operation." |
| "I already use [competitor]" | "Does it work offline? Does it sync across multiple phones? Can it handle your restaurant AND your shop? Mbeck does all of that in one app." |

**Action items:**
- [ ] Upload 10+ real sales call recordings/notes to ChatGPT
- [ ] Ask it to identify the top 10 objections and generate response scripts
- [ ] Create a "Sales Playbook" document your field agents can reference

#### Phase 5: Closing & Delivery — Onboarding

| Dan's Advice | Mbeck Application |
|-------------|-------------------|
| Celebrate the purchase | Send a personalized WhatsApp message: "Welcome to Mbeck, [Name]! You just upgraded your business." |
| Get them a quick win | Help them add their first 10 products or menu items during onboarding. First sale through the app within 24 hours. |
| Automate onboarding | Create 3 short YouTube tutorial videos: (1) Setting up your shop, (2) Adding your first products/menu, (3) Making your first sale/order |

**Action items:**
- [ ] Create onboarding WhatsApp message template
- [ ] Record 3 onboarding videos (screen recording + voiceover)
- [ ] Build a "First 24 Hours" checklist that auto-appears in the app after setup
- [ ] Set up automated 3-day and 7-day check-in messages

### Growth Strategy Summary

```
Week 1-2: Build prospect list (AI-automated research)
Week 3-4: Qualify + demo 20 businesses (5 per module type)
Week 5-6: Close first 10 paying customers
Week 7-8: Get testimonials + referral program
Month 3:  Field agent model — recruit 3 people to demo Mbeck in their area (commission per conversion)
Month 6:  Target 100 businesses across Nairobi
```

### Key Metrics to Track
- Prospects identified per week
- Demos conducted per week
- Conversion rate (demo → install → paying)
- Module adoption rate (which modules are most popular)
- Revenue per business per month
- Churn rate (who stops using after 30 days and why)

---

*Generated for Mbeck deployment planning. Last updated: 2025.*
