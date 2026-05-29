import 'package:flutter/material.dart';

class NarrativeContentService {
  static const Map<String, Map<String, dynamic>> ecosystemNarrative = {
    'LAN': {
      'title': 'Local WiFi Sync',
      'body': 'This green dot means all your Mbeck devices — your cashier phone, the kitchen tablet, the manager\'s screen — are talking to each other over your shop\'s WiFi.\n\nExample: Your cashier at Till 1 completes a sale. The stock count on the manager\'s device drops immediately — no internet needed. Even if your internet is cut, your team keeps working in sync.',
    },
    'Cloud': {
      'title': 'Cloud Backup',
      'body': 'When this is active, your data is being safely saved to Mbeck\'s secure online servers. Even if your phone is lost, stolen, or falls in water tonight — your sales, customers, and stock records are fully safe.\n\nExample: You check last month\'s performance from home on a Sunday morning, on a completely different device.',
    },
    '+': {
      'title': 'Quick Actions',
      'body': 'The floating action button at the bottom right is your quickest way to record new transactions, no matter what part of the dashboard you are looking at.',
    },
    'Sales': {
      'title': 'New Sale',
      'body': 'Quickly launches the checkout scanner to process general store sales outside of the normal flow.',
    },
    'Income': {
      'title': 'Record Income',
      'body': 'Log external income that isn\'t a direct product sale into your accounting module.',
    },
    'Expenses': {
      'title': 'Record Expenses',
      'body': 'Keep your books perfectly accurate by recording outgoing money like rent, utility bills, or vendor purchases right away.',
    },
    'Mbeck Buyer': {
      'title': 'Mbeck Go — Your Customer App',
      'body': 'Mbeck Go is the app your customers download on their own phones. From it, they can browse your [Shop Appearance], check what is in stock, place orders, message you directly, and even pay — all before walking into your shop.\n\nExample: A customer at home is craving your special fries. She opens Mbeck Go, sees your menu, and sends her order. By the time she arrives, it is ready.',
    },
    'Shop Appearance': {
      'title': 'Your Digital Shopfront',
      'body': 'This is how your business looks to customers browsing Mbeck Go. You set your shop name, cover photo, colors, opening hours, and a welcome note.\n\nExample: A boutique owner sets a pink banner reading "New arrivals every Friday!" — customers in the area see this the moment they open Mbeck Go.',
    },
    'Web Inventory': {
      'title': 'Publishing Your Stock Online',
      'body': 'When switched on, your product list becomes visible to nearby Mbeck Go customers. They can browse what you have and its price before leaving home.\n\nExample: A customer searches "bluetooth speaker" — your shop appears with the exact model, price, and how many are left in stock.',
    },
  };

  // ─── Retail Module Narrative ───
  static const Map<String, Map<String, dynamic>> retailNarrative = {
    'main': {
      'title': 'The Retail Command Center',
      'body': 'Welcome to Mbeck Business. This is your command center. At the top of the screen, you can map your connection status with [LAN], [Cloud], and the future [Mbeck Buyer] app bridge integration.\n\nThe large pulse cards monitor your [Revenue] and [Sold] items.\n\nThe Core Grid grants you swift access to your [Customers], [Accounting] books, and daily [Cash] counts.\n\nFurther down is the Retail Tools section where you manage operations like [Stock], [Restock], and [Returns].\n\nLastly, you can use the bottom right [+] button at any time to swiftly record new [Sales], [Income], or [Expenses].\n\nTap on any highlighted word, or explore different [Use Cases] for examples of how to master this module.',
    },
    'Use Cases': {
      'title': 'Scenarios in Action',
      'body': 'Wondering how to piece this all together? Read about a [Boutique Scenario], a [Wholesale Scenario], or a [Multi-Branch Scenario] to see the system in action.',
    },
    'Boutique Scenario': {
      'title': 'Use Case: Boutique',
      'body': 'A clothing boutique owner taps the [+] button to quickly ring up a "New Sale" using the barcode scanner. At the end of the day, she checks the [Profits] section to see which fast-fashion items yielded the highest margins.',
    },
    'Wholesale Scenario': {
      'title': 'Use Case: Hardware Supply',
      'body': 'A busy hardware supply store uses the [Restock] feature. The application analyzes which items are moving fast and immediately enables the owner to view his [Suppliers] to dispatch a new purchase order before they run completely dry.',
    },
    'Multi-Branch Scenario': {
      'title': 'Use Case: Supermarket',
      'body': 'In a high-traffic supermarket, 3 cashiers ring up multiple walk-in shoppers effortlessly. Using [LAN] sync, the central [Stock] inventory stays perfectly synchronized locally between all 3 registers, while the [Cloud] simultaneously backs everything up for the regional manager viewing it from his tablet at home.',
    },
    'Revenue': {
      'title': 'Revenue Tracking',
      'body': 'The Revenue card sums up every completed sale for today across the retail module. It gives you instant visibility into your gross takings.',
    },
    'Sold': {
      'title': 'Items Sold',
      'body': 'This metric tracks the sheer volume of products moving out of your store today.',
    },
    'Customers': {
      'title': 'Customer Management',
      'body': 'Tap Customers to view your client directory, track debts, and review their purchase history.',
    },
    'Accounting': {
      'title': 'Accounting',
      'body': 'Your ledger. The Accounting screen provides deep financial insights, income statements, and cashflow reports.',
    },
    'Cash': {
      'title': 'Cash Count',
      'body': 'Use the Cash feature at the end of your shift to reconcile physical cash against system sales, ensuring every cent is accounted for.',
    },
    'Stock': {
      'title': 'Stock Management',
      'body': 'Inventory is the lifeblood of retail. Here you can add new items, adjust stock levels, perform audits, and categorize your products.',
    },
    'Restock': {
      'title': 'Restock Analysis',
      'body': 'The Restock tool analyzes sales trends to suggest what items you need to order before they run out.',
    },
    'Profits': {
      'title': 'Profit Margins',
      'body': 'A detailed analysis of your profit margins per item and category, ensuring your pricing strategy remains lucrative.',
    },
    'Returns': {
      'title': 'Returns & Refunds',
      'body': 'Process customer returns quickly, adjust inventory back, and issue refunds directly from here.',
    },
    'Suppliers': {
      'title': 'Suppliers',
      'body': 'Manage the vendors who supply your shop, track purchase orders, and monitor your supplier debts.',
    },
    'Promos': {
      'title': 'Promotions',
      'body': 'Set up discounts, happy hours, or buy-one-get-one offers to boost your sales.',
    },
    'Trust': {
      'title': 'Trust Score',
      'body': 'Your Trust Score grows as you use the app consistently. A higher score unlocks access to working capital [Loans].',
    },
    'Loans': {
      'title': 'Capital Loans',
      'body': 'Based on your Trust Score and sales volume, you can access fast, flexible financing to grow your business.',
    },
  };

  // ─── Customers Core Narrative ───
  static const Map<String, Map<String, dynamic>> customersNarrative = {
    'main': {
      'title': 'Customer & Ledger Directory',
      'body': 'This is your ultimate CRM. Here you can search, track, and manage direct interactions with your clientele.\n\nAt the top, use the horizontal [Ledger Tabs] to see who has [Open Debts], who has overpaid ([Prepaid]), or who has [Pending] payments.\n\nIn the list, you can expand any profile to view their detailed [Financial History].\n\nTap the button at the bottom to register a [New Customer]. When exploring a filter tab like Owing, the button intelligently morphs to allow you to rapidly [Add Entries] instead.',
    },
    'Ledger Tabs': {
      'title': 'Smart Ledger Filters',
      'body': 'The horizontal scrolling bar at the top automatically calculates the number of customers falling under specific financial statuses. Click on any tab to isolate those customers instantly.',
    },
    'Open Debts': {
      'title': 'Owing & Debts',
      'body': 'Customers marked with a red tag are carrying unresolved debts. It calculates precisely how much they owe you across all combined checkout, service, and lodging entries.',
    },
    'Prepaid': {
      'title': 'Prepaid Balances',
      'body': 'Customers marked green have overpaid or put down deposits. They carry a positive ledger balance that can be applied to future transactions.',
    },
    'Pending': {
      'title': 'Pending Transactions',
      'body': 'Transactions that are neither fully cleared nor entirely defaulted. Often used for installment layaways.',
    },
    'Financial History': {
      'title': 'Deep Ledger Tracking',
      'body': 'Expand any customer to see their 3 most recent financial ledger entries. If they have more, you can drill in further to see every single cent they have moved through your business.',
    },
    'New Customer': {
      'title': 'Onboarding Customers',
      'body': 'Clicking the plus button on the "All" tab registers a new client. You can optionally capture their phone number or ID number for verification during high-value credit purchases.',
    },
    'Add Entries': {
      'title': 'Adding Manual Entries',
      'body': 'When you are inside a specific ledger tab (like Owing), the bottom button allows you to instantly select an existing customer and add a new manual ledger entry with a contextual note.',
    },
  };

  // ─── Global App Narratives ───
  static const Map<String, Map<String, dynamic>> historyNarrative = {
    'main': {
      'title': 'Your Full Business History',
      'body': 'Every single thing your shop did — every sale rung up, every appointment completed, every expense recorded — lives here in one place.\n\nThe list is [Grouped by Date] so you can jump to "what happened today" or "what happened last Tuesday."\n\nSwipe right on any entry to [Reprint] the receipt. Swipe left to [Undo/Delete] it (manager or owner only).\n\nUse the filter button at the top right to show only [Specific Types].',
    },
    'Transaction': {
      'title': 'Every Business Event',
      'body': 'Whether a customer paid for a haircut, bought shoes, or checked out of a room — it all lands here.\n\nTap any row to expand it and see the full breakdown: what was bought, who served, and how much was paid.',
    },
    'Groups by Date': {
      'title': 'Organized by Day',
      'body': 'Entries are stacked under clear date headers — TODAY, YESTERDAY, and older dates. Instead of scrolling through hundreds of rows, you jump straight to the right day.',
    },
    'Specific Flows': {
      'title': 'Filter What You See',
      'body': 'Tap the filter icon to show only one type at a time:\n\n• Sales — every customer payment\n• Expenses — money that went out\n• Income — other money received\n\nExample: You want to check what you spent this week. Filter to Expenses and see the full list instantly.',
    },
    'Receipt Action': {
      'title': 'Reprint a Receipt',
      'body': 'Swipe right on any transaction to open the receipt viewer. Share it as a PDF via WhatsApp, print a paper copy, or show it to a customer who lost theirs.',
    },
    'Reversals': {
      'title': 'Undo a Transaction',
      'body': 'Made a mistake? Swipe left on a transaction to delete and reverse it. Any stock that was deducted during that sale is automatically added back to your shelves.\n\nThis is protected — only the Owner or a Manager can approve it, so cashiers cannot quietly erase their own errors.',
    },
  };

  static const Map<String, Map<String, dynamic>> reportsNarrative = {
    'main': {
      'title': 'Your Business Report Card',
      'body': 'This screen shows how your business is actually performing — no spreadsheets needed.\n\nAt the top, [Summary Cards] show your Revenue, Expenses, and Profit at a glance. Tap the tabs below to see [By Time Period], your [Best Sellers], or [Restaurant Stats].\n\nPick any date range using the calendar, and every number recalculates automatically.\n\nUse the button at the bottom right to [Share the Report] with your accountant.',
    },
    'Hero Cards': {
      'title': 'The Big Three Numbers',
      'body': 'Three cards summarize your entire period:\n\n• Revenue — all money that came in\n• Expenses — all money that went out\n• Profit — what actually stayed\n\nExample: Revenue KSh 85,000 / Expenses KSh 42,000 / Profit KSh 43,000.',
    },
    'Time Periods': {
      'title': 'Week, Month, or Year View',
      'body': 'Switch between This Week, This Month, and This Year with a single tap. Each view compares you to the previous period so you can see if you are growing.\n\nExample: "This month is up 15% from last month" — shown as a green arrow.',
    },
    'Item Performance': {
      'title': 'What Is Actually Selling',
      'body': 'Every product and service ranked by how many units moved. The app shows profit per item too — so you know if your bestseller is also your most profitable.\n\nExample: You sell 200 sodas a week (KSh 5 profit each) but only 10 phone cases (KSh 300 each). This tab shows that the phone cases are your real money-makers.',
    },
    'Restaurant Orders': {
      'title': 'Food & Kitchen Stats',
      'body': 'For restaurant owners — see dine-in vs takeaway totals, how many orders are completed vs still pending, and how fast the kitchen is turning orders around.',
    },
    'Custom Date Range': {
      'title': 'Pick Any Date Range',
      'body': 'Tap the calendar icon and choose your start and end date. Every number on screen instantly updates for that period.\n\nExample: You want to see how much you made during Easter weekend. Pick April 18–21 and the full breakdown appears.',
    },
    'Export Data': {
      'title': 'Share as PDF or Spreadsheet',
      'body': 'Tap the share button at the bottom right to send a clean PDF report to your accountant via WhatsApp or email. You can also export as a spreadsheet file for further analysis.',
    },
  };

  // ─── Accounting Core Narrative ───
  static const Map<String, Map<String, dynamic>> accountingNarrative = {
    'main': {
      'title': 'End of Shift Accounting',
      'body': 'This is how you close your shift properly. Mbeck automatically adds up everything sold and subtracts everything spent since your last save — giving you a [Target Total] that your drawer should hold.\n\nYour job is simple: count what is actually in front of you and enter it in the [Payment Inputs] below — cash in hand, Mpesa balance, bank balances.\n\nThe screen shows a [Live Difference] as you type. Green means you are balanced. Red means something is short.\n\nWhen you tap Save, any [Gaps] are recorded for accountability.',
    },
    'Live Variance': {
      'title': 'Are You Balanced?',
      'body': 'The banner at the top updates as you type your physical amounts. Green means your counts match the system. Red means money is unaccounted for.\n\nExample: System expects KSh 42,000. You count KSh 41,200. The banner shows −KSh 800 in red.',
    },
    'Expected Total': {
      'title': 'What the System Expects',
      'body': 'Mbeck silently tracks every sale completed, every expense recorded, and every income logged since the last time you saved accounting. It adds it all up into the number your drawer is supposed to hold.\n\nThis number cannot be changed or faked — it reflects exactly what happened in the system.',
    },
    'Recent Sales': {
      'title': 'Money From Sales',
      'body': 'The total from every completed checkout across your Retail, Restaurant, and Services counters since your last accounting save.',
    },
    'Other Income': {
      'title': 'Extra Money In',
      'body': 'Money that came in but is not linked to a product sale. Examples: a delivery tip, a cash top-up from a partner, advance payment for an event.',
    },
    'Expenses': {
      'title': 'Money That Went Out',
      'body': 'Every expense you recorded (rent, water, wages, gas) reduces the amount your drawer is supposed to hold. The system factors all of these out automatically.',
    },
    'Payment Inputs': {
      'title': 'Count What You Have',
      'body': 'Enter the actual amounts in each payment channel:\n\n• Physical cash in the drawer\n• Mpesa Line 1 — your shop till number\n• Mpesa Line 2 — personal number used for business\n• Bank (Equity, KCB, Co-op)\n\nThe total of all these is compared to the target.',
    },
    'Disparities': {
      'title': 'When the Numbers Don\'t Match',
      'body': 'Any difference between what you counted and what the system expected is logged permanently. This is not deleted or hidden — it becomes part of your business audit trail.\n\nExample: KSh 300 is short every Monday evening — you can look back and spot the pattern.',
    },
    'Accountability Penalties': {
      'title': 'Shortage Penalties',
      'body': 'A large, unexplained shortage (e.g. more than KSh 1,000 missing) lowers your Mbeck Trust Score. A low Trust Score can reduce your access to business [Loans].\n\nSmall differences from rounding are not penalized.',
    },
  };

  // ─── Cash Count Core Narrative ───
  static const Map<String, Map<String, dynamic>> cashNarrative = {
    'main': {
      'title': 'Counting Your Cash',
      'body': 'No more mental math or paper tally sheets. This screen does all the counting for you.\n\nTap the [Notes] section to count paper money (KSh 1000s, 500s, 200s, 100s). Tap [Coins] for small change. The total updates live as you add each denomination.\n\nUse [Presets] to fill quickly if you are testing, or just tap the exact quantities you have. When done, hit Submit to send this total directly into your [Accounting] for shift closing.',
    },
    'Notes': {
      'title': 'Paper Money',
      'body': 'Tap + or − to add or remove notes by denomination, or type a large quantity directly.\n\nExample: You have 14 pieces of KSh 1,000 notes. Tap the 1000 row and set it to 14. The total updates instantly.',
    },
    'Coins': {
      'title': 'Coins & Small Change',
      'body': 'Count your coins down to the last shilling. Great for shops dealing in small change like kiosks, buses, or market stalls.',
    },
    'Smart Slider': {
      'title': 'Visual Balance Bar',
      'body': 'The progress bar under each denomination shows what percentage of your total cash it represents.\n\nExample: You have KSh 10,000 total and KSh 5,000 is in 1,000 notes — that bar fills to exactly 50%.',
    },
    'Presets': {
      'title': 'Quick Fill Options',
      'body': 'Tap the preset pills (Small, Medium, Large) to automatically load a sample cash amount. Useful when training a new cashier on how to use the counter.',
    },
    'Accounting Ledger': {
      'title': 'Connected to Accounting',
      'body': 'When you save the cash count, it flows directly into the Accounting screen as your cash balance — ready to be compared against what the system expects. No double entry needed.',
    },
  };

  // ─── Verify Core Narrative ───
  static const Map<String, Map<String, dynamic>> verifyNarrative = {
    'main': {
      'title': 'Checking If a Receipt is Real',
      'body': 'This screen protects you when a customer brings back a receipt demanding a refund or claiming there is a problem with their order.\n\nType in the [Reference Code] from the receipt and the [Amount] they paid. The app will look up that exact sale in your records and confirm if it is genuine.\n\nIf it checks out (green tick), you will see exactly what was purchased and can immediately process a [Return].',
    },
    'Return': {
      'title': 'Safe Returns Only',
      'body': 'Without checking the receipt first, you risk accepting a return for something you never sold. This screen makes sure every return has a real, verified purchase behind it.\n\nExample: A customer claims they bought a KSh 2,500 blender last week. You verify the receipt first — if it\'s genuine, the Return button appears. If not, the screen shows a red warning.',
    },
    'Reference Code': {
      'title': 'The Receipt Number',
      'body': 'This is the short code printed at the bottom of every Mbeck receipt (usually 6 digits). It uniquely identifies when the sale happened.\n\nExample: A receipt from 3:47 PM last Tuesday might show code 094734.',
    },
    'Amount': {
      'title': 'The Total Paid',
      'body': 'Entering the total amount alongside the code helps the app pinpoint the exact transaction instantly, especially when a customer visited multiple times in the same day.',
    },
    'Cryptographic Signature': {
      'title': 'Is It Tampered?',
      'body': 'Every receipt has a hidden security stamp baked in at the time of sale. If anyone tries to alter the receipt — changing the amount or items — this check fails and the screen shows a red warning.\n\nExample: A customer crosses out "KSh 500" and writes "KSh 5,000" on the paper. The stamp check fails immediately, exposing the forgery.',
    },
    'Returns': {
      'title': 'One Tap to Process',
      'body': 'Once the receipt is confirmed as genuine (green tick), tap "Push to Returns" and all the items from that sale are automatically loaded into the Returns screen ready for processing — no retyping needed.',
    },
  };

  // ─── Profits Narrative ───
  static const Map<String, Map<String, dynamic>> profitsNarrative = {
    'main': {
      'title': 'Profits Analysis',
      'body': 'This screen breaks down your true profitability over time.\n\nIt aggregates [Revenue], subtracts [Cost] of goods sold, and automatically factors in any processed [Returns] to calculate your accurate [Net Profit].\n\nUse the Filter Bar at the bottom to adjust the [Time Range] or scan the [Transaction List] below to see exactly which items generated the highest margins.',
    },
    'Revenue': {
      'title': 'Total Revenue',
      'body': 'The raw gross amount of cash flow coming in from complete sales, before any expenses, cost of goods, or taxes are factored in.',
    },
    'Cost': {
      'title': 'Cost of Goods',
      'body': 'A sum of the Original Price you set for your inventory items multiplied by the quantity. This shows how much money is locked in your procured stock.',
    },
    'Net Profit': {
      'title': 'Net Profit Margin',
      'body': 'The actual money the business made. If this is red, you sold items for less than you bought them for. Keep a close eye on the percentage Margin!',
    },
    'Returns': {
      'title': 'Calculated Returns',
      'body': 'This screen smartly queries the retail returns ledger to deduct any refunded quantities and cash from the total revenue, ensuring your numbers aren\'t artificially inflated by items that came back.',
    },
    'Time Range': {
      'title': 'Date Filtering',
      'body': 'Hit the filter icon to select specific dates (like tracking performance during a particular holiday week).',
    },
    'Transaction List': {
      'title': 'Granular Breakdown',
      'body': 'A complete timeline of every item sold across the entire module. Green dots indicate a profitable sale, red dots indicate a loss.',
    },
  };

  // ─── Suppliers Narrative ───
  static const Map<String, Map<String, dynamic>> suppliersNarrative = {
    'main': {
      'title': 'Supplier Management',
      'body': 'Keep your supply chain running smoothly. Here you manage the vendors who stock your business.\n\nThe [Suppliers] tab holds vendor contact details and history.\n\nThe [POs] tab (Purchase Orders) lets you create orders for new stock. Once a delivery arrives, you can simply mark it as [Received] and the system will automatically [Auto-Update Stock] and log the [Expense].',
    },
    'Suppliers': {
      'title': 'Vendor Directory',
      'body': 'Register the companies or individuals supplying your inventory. Keeping clear records enables you to analyze who gives you the best reliability.',
    },
    'POs': {
      'title': 'Purchase Orders',
      'body': 'Creating a PO acts as a digital record of intent to purchase. It tracks the exact items, expected cost, and maps it directly to a known supplier.',
    },
    'Received': {
      'title': 'Receiving Inventory',
      'body': 'Once a truck arrives, simply click "Mark Received". The system closes the PO preventing modifications.',
    },
    'Auto-Update Stock': {
      'title': 'Smart Inventory Growth',
      'body': 'When a PO is received, Mbeck Business instantly reads the quantities inside it and increments your live inventory stock securely without you lifting a finger.',
    },
    'Expense': {
      'title': 'Bridged Expenses',
      'body': 'Receiving a PO immediately generates an immutable Expense entry in your Accounting ledger for the total cost, keeping your financial variance perfectly accurate.',
    },
  };

  // ─── Returns Narrative ───
  static const Map<String, Map<String, dynamic>> returnsNarrative = {
    'main': {
      'title': 'Processing a Return',
      'body': 'When a customer brings something back, this screen guides you through safely handling it.\n\nSearch for the [Original Sale] using the customer name or receipt number. Once found, the exact items they bought are loaded automatically.\n\nUse the [Item Counter] to say how many units are coming back. Tap Process and the app calculates the [Refund Amount], adds the items back to your stock, and records everything.',
    },
    'Original Transaction': {
      'title': 'Preventing Fake Returns',
      'body': 'You cannot process a return without linking it to a real sale. This prevents cashiers from inventing returns to pocket money.\n\nExample: A customer claims they bought a blender. The app looks it up — if there is no matching sale, the return is blocked.',
    },
    'Incrementer': {
      'title': 'Partial Returns',
      'body': 'If a customer bought 10 plates but only 2 were broken, you return exactly 2. The other 8 remain sold.\n\nExample: Customer bought a 6-pack of juice. 2 cans were damaged. You set the counter to 2 and only those 2 are refunded.',
    },
    'Refund Amount': {
      'title': 'Exact Payout',
      'body': 'The app works out the correct refund based on what they actually paid per unit — including any discounts that applied at the time of the original sale.',
    },
    'Inventory Re-stock': {
      'title': 'Back on the Shelf',
      'body': 'The returned quantity is automatically added back to your live stock count. You do not need to manually update inventory.',
    },
    'Audit Log': {
      'title': 'Recorded for Accuracy',
      'body': 'Every return is logged permanently and shows up as a deduction in your Profits screen — so your profit numbers are always honest and not inflated by items that came back.',
    },
  };

  // ─── Promotions Narrative ───
  static const Map<String, Map<String, dynamic>> promosNarrative = {
    'main': {
      'title': 'Promotions Engine',
      'body': 'Accelerate your sales by running targeted offers.\n\nYou can create standard [Percentage Discounts], heavy [Fixed Amount] deductions, or enticing [BOGO] (Buy-One-Get-One) deals.\n\nPromos can be flipped on and off instantly with the [Toggle Switch], and you can target them to affect the entire store or just a specific [Product Category].\n\nThe checkout scanner is completely [Promo-Aware] and will apply them automatically!',
    },
    'Percentage Discounts': {
      'title': 'Scalable Offers',
      'body': 'Takes a percentage off the cart. Excellent for holiday weekends or clearing out old stock (e.g. 15% OFF).',
    },
    'Fixed Amount': {
      'title': 'Absolute Deductions',
      'body': 'Deducts a hard KSh amount from the subtotal. Great for high-value items or loyalty rewards (e.g. KSh 500 OFF).',
    },
    'BOGO': {
      'title': 'Buy One, Get One',
      'body': 'Encourages volume buying. If they buy 1, they get the 2nd one completely free. A massive driver of foot-traffic.',
    },
    'Toggle Switch': {
      'title': 'Instant Activation',
      'body': 'No need to delete older promos. Just flip the switch to deactivate them when the campaign ends, and flip them back on next year!',
    },
    'Product Category': {
      'title': 'Targeting Deals',
      'body': 'You don\'t have to discount your entire store. You can create a 20% OFF promo that exclusively triggers when scanning items in the "Electronics" category.',
    },
    'Promo-Aware': {
      'title': 'Automated Checkout',
      'body': 'The moment a cashier scans items, the engine silently calculates the strongest active promo and deducts the price automatically, printing the savings directly onto the receipt.',
    },
  };

  // ─── Stock Audit Narrative ───
  static const Map<String, Map<String, dynamic>> auditNarrative = {
    'main': {
      'title': 'Physical Stock Audit',
      'body': 'Over time, your computer\'s expected stock diverges from physical reality due to theft, damage, or undocumented sales.\n\nThe Stock Audit tools brings you back to reality. It lists your entire inventory alongside its [Expected Count].\n\nWalk through your aisles and use the stepper to input the true [Physical Count]. The system instantly highlights any [Discrepancies], allowing you to pinpoint shrinkage accurately.',
    },
    'Expected Count': {
      'title': 'System Reality',
      'body': 'This is what the database calculates you SHOULD have, based purely on your last stock entries minus the sales processed through the POS checkout.',
    },
    'Physical Count': {
      'title': 'Ground Truth',
      'body': 'The reality check. If the shelf has 4 cans but the system expects 12, someone has either stolen them, broken them without reporting, or checked out the wrong item.',
    },
    'Discrepancies': {
      'title': 'Shrinkage Highlights',
      'body': 'Any row where the Physical Count mismatches the Expected Count lights up in red with a badge indicating exactly how many units are vanishing into thin air.',
    },
  };

  // ─── Restock Analysis Narrative ───
  static const Map<String, Map<String, dynamic>> restockNarrative = {
    'main': {
      'title': 'Predictive Restocking',
      'body': 'Never run out of your best sellers again.\n\nThis intelligent module queries your transaction history to build a [Sales Velocity] profile for every item. It compares this against your [Current Stock].\n\nIf your stock drops too low relative to how fast it is selling (less than 20%), the system raises a [Critical Warning].\n\nYou can adjust the analysis window using the [Time Filter] at the top.',
    },
    'Sales Velocity': {
      'title': 'Movement Metrics',
      'body': 'By looking at exactly how many units moved over the past 7 or 30 days, the app knows exactly what items are the true heartbeat of your business.',
    },
    'Current Stock': {
      'title': 'Inventory Check',
      'body': 'Comparing the velocity against what is physically left on the shelf.',
    },
    'Critical Warning': {
      'title': 'Looming Shortages',
      'body': 'If an item is selling fast (High Velocity) but your stock is dropping dangerously low, the indicator flashes Orange or Red. This is your cue to open the Suppliers tab immediately.',
    },
    'Time Filter': {
      'title': 'Dynamic Horizons',
      'body': 'Change the filter to "Last 7 Days" to see extreme short-term trends (like a new viral product), or "All Time" to find your consistent, long-term anchor products.',
    },
  };

  // ─── Restaurant Module Narratives ───
  static const Map<String, Map<String, dynamic>> restaurantNarrative = {
    'main': {
      'title': 'Restaurant Command Center',
      'body': 'Welcome to the Restaurant Module. Your operations revolve around speed and synchronization. At the top of the screen, you can map your connection status with [LAN], [Cloud], and the future [Mbeck Buyer] app bridge integration.\n\nThe [POS] lets you place orders quickly, while the [KDS] (Order Queue) organizes prep for your kitchen staff. Your waitstaff use [Waiter Rings] to place items directly from the floor, and the [Live Table Map] shows you exactly who is seated and for how long.\n\nEverything ties back to your dynamic [Menu] and [Kitchen Stock], governed by exact [BOM Recipes].\n\nLastly, you can use the bottom right [+] button at any time to swiftly record new [Sales], [Income], or [Expenses].\n\nTap on any highlighted word, or explore different [Use Cases] to see how these features act together.',
    },
    'Use Cases': {
      'title': 'Scenarios in Action',
      'body': 'Wondering how to piece this all together? Read about a [Food Truck Scenario], a [Fine Dining Scenario], or a [Bar Scenario] to see the system in action.',
    },
    'Food Truck Scenario': {
      'title': 'Use Case: Food Truck',
      'body': 'A busy food truck operator uses just the [POS] and the [KDS]. As she taps orders into the POS, they instantly pop up on the KDS tablet for her cook in the back to prepare.',
    },
    'Fine Dining Scenario': {
      'title': 'Use Case: Fine Dining',
      'body': 'In a large restaurant, 5 waiters carry phones running the Mbeck app. They tap orders into [Waiter Rings], which instantly fires the "Starters" course to the [KDS]. The host uses the [Live Table Map] to seat new guests and track who has been waiting for their mains too long.',
    },
    'Bar Scenario': {
      'title': 'Use Case: Busy Bar',
      'body': 'A bartender uses the [POS] to quickly add drinks to open tabs. Meanwhile, the system uses [BOM Recipes] to automatically deduct 40ml of vodka from the [Kitchen Stock] for every Martini rung up, preventing shrinkage.',
    },
    'POS': {
      'title': 'Restaurant POS',
      'body': 'A split-screen Point of Sale designed specifically for speed. Supports quick courses (Starters, Mains, Desserts) out of the box and seamlessly opens floor-plan tables on demand.',
    },
    'KDS': {
      'title': 'Kitchen Queue',
      'body': 'Your digital Kitchen Display System. Replaces paper tickets with a synchronized Kanban board so your chefs can "Fire" orders and mark them Ready for Waiters.',
    },
    'Waiter Rings': {
      'title': 'Customer Pings',
      'body': 'Customers using the Mbeck Buyer (Mbeck Go) app can connect to your local broadcast. They can browse your menu on their own devices or on provided table/counter phones, select what they want, and send a digital ping to your staff with their items and table seat.',
    },
    'Live Table Map': {
      'title': 'Interactive Floor Plan',
      'body': 'A real-time overview of your entire restaurant. Tables pulse when food is ready to be served, and turn red when customers have been waiting too long.',
    },
    'Menu': {
      'title': 'Menu Management',
      'body': 'Create elegant digital menus categorized by course. Automatically synchronizes over LAN to all Waiter and Kitchen tablets instantly.',
    },
    'Kitchen Stock': {
      'title': 'Raw Ingredients',
      'body': 'The raw backbone of your operations. Instead of tracking finished items, you track raw inputs like "Tomato Paste" or "Flour".',
    },
    'BOM Recipes': {
      'title': 'Recipe Configurator',
      'body': 'Link your Menu items to Raw Kitchen Stock. When 1 Pizza is sold, the system automatically deducts 200g of Flour and 50g of Cheese.',
    },
  };

  static const Map<String, Map<String, dynamic>> posNarrative = {
    'main': {
      'title': 'Point of Sale',
      'body': 'Designed for high-volume environments, this POS uses a fluid category-switching tab. Tap items to add them to the tray.\n\nFor complex dine-in orders, long-press to separate items into [Courses] for the kitchen.',
    },
    'Courses': {
      'title': 'Kitchen Courses',
      'body': 'By defining Starters vs Mains, the Kitchen (KDS) knows exactly when to fire the food to prevent hot meals from sitting cold on the pass while guests eat their salads.',
    },
  };

  static const Map<String, Map<String, dynamic>> kdsNarrative = {
    'main': {
      'title': 'Kitchen Display System',
      'body': 'The screen your kitchen team watches instead of paper tickets.\n\nEvery order placed on the POS or by a waiter appears here instantly. Move tickets from [Pending] to [Cooking], then to [Ready to Serve] as the food is prepared.\n\nAll devices in the restaurant stay in sync automatically over your WiFi — no internet required.',
    },
    'Pending': {
      'title': 'Waiting to Be Started',
      'body': 'These orders have been placed but the kitchen has not started cooking yet. Your chef picks from here when they are free.',
    },
    'Cooking': {
      'title': 'In the Kitchen Now',
      'body': 'A chef has started this order. Moving it here tells the front-of-house that this ticket is being worked on.',
    },
    'Ready to Serve': {
      'title': 'Food is on the Pass!',
      'body': 'The food is ready and waiting for a waiter to pick it up. The Live Table Map will pulse for that table and the Waiter screen will glow until someone collects it.',
    },
    'Event Subscriptions': {
      'title': 'Works Without Internet',
      'body': 'The POS and Kitchen screens talk to each other directly over your shop\'s WiFi. Orders appear in the kitchen within seconds of being placed — even if your internet is completely off.\n\nExample: Your internet goes down on a busy Friday night. Orders still flow from the POS to the kitchen tablet without interruption.',
    },
  };

  static const Map<String, Map<String, dynamic>> menuNarrative = {
    'main': {
      'title': 'Menu Builder',
      'body': 'Use the [+] button to add new dishes.\n\nYou can instantly toggle [Availability] on or off if a dish runs out; every tablet in the restaurant gets the update within 100 milliseconds.',
    },
    'Availability': {
      'title': 'Instant 86',
      'body': '"86ing" an item means marking it out of stock. A single tap here physically prevents waiters from selling dishes the kitchen cannot make.',
    },
  };

  static const Map<String, Map<String, dynamic>> recipeNarrative = {
    'main': {
      'title': 'BOM Recipes',
      'body': 'One of the most powerful features to prevent theft.\n\nYou construct a [BOM] for every finished dish. The system does the rest to preserve margins.',
    },
    'BOM': {
      'title': 'Bill of Materials',
      'body': 'A literal recipe book. When a "Burger" is sold, the BOM instructs the database to automatically deplete 1 Bun, 200g of Beef, and 1 Slice of Cheese from the Raw Kitchen Stock.',
    },
  };

  static const Map<String, Map<String, dynamic>> waiterNarrative = {
    'main': {
      'title': 'Waiter Terminal',
      'body': 'Every digital ping from your customers ends up here.\n\nWhen customers use Mbeck Buyer to send a ping with their selected items and table number, waiters receive the notifications, can [Confirm] the order directly, or go to the table first. Waiters can also use [Quick Actions] to ring up a new order entirely.',
    },
    'Confirm': {
      'title': 'Order Confirmation',
      'body': 'A waiter can confirm the digital ping right from the counter and send it straight to the kitchen as Fired Tickets, bypassing the POS.',
    },
    'Quick Actions': {
      'title': 'Direct Waiter Ordering',
      'body': 'Waiters don\'t have to rely on customer pings; they can approach a table, take the order, and use the quick actions menu to directly fire those items off to the kitchen devices over the network.',
    },
  };

  static const Map<String, Map<String, dynamic>> tablesNarrative = {
    'main': {
      'title': 'Live Floor Map',
      'body': 'You gain a bird\'s eye view of your entire operation.\n\nVisual cues denote [Table Statuses]. Tap on any table to [Clear] it, [Split Bills] down to the decimal, or [Transfer] customers moving to the bar.',
    },
    'Table Statuses': {
      'title': 'Color-Coded Status',
      'body': 'Green = Free\nYellow = Seated\nRed = Waiting for >15 minutes\nOrange Pulse = Food is ready on the pass\nGray = Paid, needs cleaning.',
    },
    'Clear': {
      'title': 'Bussing',
      'body': 'Marks a paid table as "Cleaned" and resets its presence to Available on the Floor Plan.',
    },
    'Split Bills': {
      'title': 'Advanced Payments',
      'body': 'Split by items, split by percentage, or split by specific cash amounts. Great for large parties paying separately.',
    },
    'Transfer': {
      'title': 'Migrate Tables',
      'body': 'If Table 4 moves to Table 12, click Transfer. The Kitchen and Waiters instantly see the update on their tablets.',
    },
  };

  static const Map<String, Map<String, dynamic>> restInventoryNarrative = {
    'main': {
      'title': 'Kitchen Stock',
      'body': 'Track raw materials in any measurement (Litres, Kilos, Units).\n\nSet [Minimum Alerts] to never run out. The system connects these raw inputs to your finished menu via [Recipes].',
    },
    'Minimum Alerts': {
      'title': 'Critical Stock',
      'body': 'If your flour dips below 5 Kilos, the stock card turns bright red and alerts you well in advance.',
    },
    'Recipes': {
      'title': 'Connecting the Dots',
      'body': 'Inventory here isn\'t sold directly; it gets used as ingredients inside Menu Management via the Recipe Configurator.',
    },
  };

  // ─── Entertainment Module Narratives ───
  static const Map<String, Map<String, dynamic>> entertainmentNarrative = {
    'main': {
      'title': 'Entertainment Command Center',
      'body': 'Welcome to the Entertainment Module. At the top of the screen, you can map your connection status with [LAN], [Cloud], and the future [Mbeck Buyer] app bridge integration.\n\nThe Entertainment Module is built for tracking time-based and flat-rate operational assets.\n\nFrom the [Sessions Dashboard], you handle active players and usage. You define what those assets are within [Asset Management], and how much they cost dynamically using [Dynamic Pricing].\n\nIf you want to place hard caps on playtime, use [Pre-paid Limits]. For customers taking a break without losing their spot, deploy [Session Pausing]. Ensure cross-departmental billing works smoothly via [Cross-Module Tabs].',
    },
    'Sessions Dashboard': {
      'title': 'Live Monitoring',
      'body': 'The bustling center of the entertainment module. Assets marked as FREE are ready to be used; IN USE assets accrue billable running costs by the millimeter.',
    },
    'Asset Management': {
      'title': 'Configuration',
      'body': 'Configure whether you charge KSh 500 flat for swimming, or KSh 200 per hour for a PlayStation console.',
    },
    'Dynamic Pricing': {
      'title': 'Time-Based Surges',
      'body': 'Automatically increase rates on Friday nights, or establish \'Happy Hour\' discounts for off-peak periods.',
    },
    'Pre-paid Limits': {
      'title': 'Time Caps',
      'body': 'Set an automatic lockout timer for customers who only paid for exactly 2 hours of gameplay.',
    },
    'Session Pausing': {
      'title': 'Idle States',
      'body': 'Temporarily halt the ticking bill if a customer steps out to answer a call or take a break.',
    },
    'Cross-Module Tabs': {
      'title': 'Unified Billing',
      'body': 'Link a restaurant food order directly onto a live entertainment session tab so the customer pays for everything at once.',
    },
  };

  static const Map<String, Map<String, dynamic>> entSessionsNarrative = {
    'main': {
      'title': 'Sessions Dashboard',
      'body': 'Your real-time view of all entertainment assets. At the top of the screen, you can map your connection status with [LAN], [Cloud], and the future [Mbeck Buyer] app bridge integration.\n\nTap on any [FREE] asset to [Start Session] for a customer. If an asset is already [IN USE], you can tap it to manage, end, or bill the current players.',
    },
    'FREE': {
      'title': 'Available Assets',
      'body': 'Assets glowing green are idle and generating zero revenue. Your goal is to get these occupied.',
    },
    'Start Session': {
      'title': 'Initiating Timers',
      'body': 'You can track who the customer is and add custom notes before officially starting their billing timer.',
    },
    'IN USE': {
      'title': 'Occupied Assets',
      'body': 'Assets glowing orange display exactly how many active sessions are registered, along with the running duration and current bill amount.',
    },
  };

  static const Map<String, Map<String, dynamic>> entAssetMgmtNarrative = {
    'main': {
      'title': 'Asset Management',
      'body': 'Control your physical inventory.\n\nFirst, define your [Asset Types] (e.g. "PS5 Station" or "Pool Table"). Then, deploy the actual [Assets] using the powerful [Batch Add] feature.',
    },
    'Asset Types': {
      'title': 'The Blueprints',
      'body': 'Define the categorical settings, flat or hourly billing models, and upload display photos that will be inherited by every physical asset you deploy of this type.',
    },
    'Assets': {
      'title': 'Physical Deployments',
      'body': 'These are the distinct physical stations. PS5 Station 1 is a separate asset from PS5 Station 2, allowing independent billing timers.',
    },
    'Batch Add': {
      'title': 'Mass Creation',
      'body': 'Quickly spin up 10 brand new PS5 stations at once without manually typing them out one by one.',
    },
  };

  static const Map<String, Map<String, dynamic>> entTabsNarrative = {
    'main': {
      'title': 'Cross-Module Tabs',
      'body': 'Consolidate separate purchases onto a single master bill.\n\nIf a customer is playing Pool, and orders a burger from the Restaurant Module, use this screen to [Link Tab]. When they finally leave, you collect payment for both the Pool time and the food simultaneously.',
    },
    'Link Tab': {
      'title': 'Digital Stapling',
      'body': 'Grab an external Order ID (like a POS receipt) and securely append it to the live Entertainment Session to ensure the customer is charged.',
    },
  };

  static const Map<String, Map<String, dynamic>> entPricingNarrative = {
    'main': {
      'title': 'Dynamic Pricing Rules',
      'body': 'Maximize your yield based on demand.\n\nEstablish [Automated Scheduling] to charge premium rates during peak hours, or discount rates during slow mornings. The timers intelligently factor in when these rules activate, ensuring [Automated Billing].',
    },
    'Automated Scheduling': {
      'title': 'Set & Forget',
      'body': 'Map a rule to trigger every Friday between 18:00 and 23:59 exclusively for your Karaoke rooms.',
    },
    'Automated Billing': {
      'title': 'Clock Perfect',
      'body': 'Your staff never has to manually remember when Happy Hour starts or ends. The underlying billing engine applies rules accurately.',
    },
  };

  static const Map<String, Map<String, dynamic>> entPrepaidNarrative = {
    'main': {
      'title': 'Pre-paid Session Limits',
      'body': 'Perfect for environments where customers pay upfront for a fixed block of time (e.g. Cybercafes, VR arcades).\n\nAssign a [Time Boundary] to any active session. Once the limit is breached, the Session is flagged as [TIME UP], demanding staff attention.',
    },
    'Time Boundary': {
      'title': 'Hard Caps',
      'body': 'Input exact Hours and Minutes representing how much time the customer has purchased.',
    },
    'TIME UP': {
      'title': 'Visual Lockout',
      'body': 'When the countdown hits zero, the session box pulses red across the dashboard, warning staff to confront the patron for an extension or stop play immediately.',
    },
  };

  static const Map<String, Map<String, dynamic>> entPauseNarrative = {
    'main': {
      'title': 'Session Pausing',
      'body': 'Fairness embedded directly into the tracker.\n\nIf a customer needs a break, or hardware fails temporarily, you can immediately hit [Pause]. The screen records exactly how much [Paused Time] accrues. When resumed, the running bill ignores entirely the idle gap!',
    },
    'Pause': {
      'title': 'Freezing Time',
      'body': 'A halted session changes color to orange, indicating the customer is still "checked in" but is no longer being charged for that slice of runtime.',
    },
    'Paused Time': {
      'title': 'Metric Subtraction',
      'body': 'The system meticulously calculates the raw time difference between the initial Pause and the eventual Resume, deducting it cleanly from the final duration invoice.',
    },
  };

  // ─── Services Module Narratives ───
  static const Map<String, Map<String, dynamic>> srvDashboardNarrative = {
    'main': {
      'title': 'Services Dashboard',
      'body': 'Welcome to the Services Hub.\n\nFrom here you control your facility\'s offerings and the technicians who perform them. Tap any of the primary tools to dive into specialized workflows for [Appointments], [Shift Configuration], or managing [Addons].',
    },
    'Appointments': {
      'title': 'Booking Command Control',
      'body': 'Open the Calendar to view reservations, check-in customers, and seamlessly bridge them over to the POS for billing.',
    },
    'Shift Configuration': {
      'title': 'Timeline Security',
      'body': 'Using Staff and Schedule controls helps the system automatically lock out overlapping appointments or book people on their days off.',
    },
    'Addons': {
      'title': 'Upsell Engine',
      'body': 'You can configure dynamic modifiers (like a 15-minute deep conditioning treatment) that optionally bolt onto root services.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvBookingsNarrative = {

    'main': {
      'title': 'Bookings Calendar',
      'body': 'Manage incoming appointments and scheduling. At the top of the screen, you can map your connection status with [LAN], [Cloud], and the future [Mbeck Buyer] app bridge integration.\n\nThe calendar provides visual [Day Views] to track your daily agenda. The system enforces [Conflict Resolution] so you never double-book a staff member, taking their specific shift schedule into account. As appointments progress, you can move them through custom [Status Pipelines].',
    },
    'Day Views': {
      'title': 'Calendar Granularity',
      'body': 'Tap across the timeline to view commitments by the hour, ensuring steady pacing throughout your operational day.',
    },
    'Conflict Resolution': {
      'title': 'Intelligent Blocking',
      'body': 'When attempting to schedule a booking, Mbeck Business queries the assigned staff member\'s exact Shift Schedule, checking for overlaps with existing jobs to mathematically prevent double-booking.',
    },
    'Status Pipelines': {
      'title': 'Workflow States',
      'body': 'Track a customer from "Checked In" to "In Progress" to "Completed", giving receptionists crystal clear visibility over the waiting room.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvCatalogNarrative = {
    'main': {
      'title': 'Service Catalog',
      'body': 'Define what your business actually does.\n\nYou can organize your offerings into [Categories], defining strict [Duration Times] and establishing base [Pricing]. A powerful backend feature allows you to setup [Linked Supply Deductions] to tie service offerings back into Retail Inventory.',
    },
    'Categories': {
      'title': 'Service Grouping',
      'body': 'Keep long lists manageable by defining parent groups (e.g. "Haircuts", "Coloring", "Nail Treatments").',
    },
    'Duration Times': {
      'title': 'Appointment Lengths',
      'body': 'Setting accurate durations ensures the Bookings Calendar reserves the proper amount of timeline space automatically when customers book this service.',
    },
    'Pricing': {
      'title': 'Base Costs',
      'body': 'Dictate standard price models, which can later be augmented by Addons or Dynamic Pricing rules.',
    },
    'Linked Supply Deductions': {
      'title': 'Bridging to Retail',
      'body': 'You can link a "Hair Wash" service to deduct exactly 50ml of Shampoo from your Retail Stock every time a booking is completed, managing dual-module inventory perfectly.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvStaffNarrative = {
    'main': {
      'title': 'Staff Management',
      'body': 'Control your workforce seamlessly.\n\nYou can issue [Team Invites], letting staff log into their own restricted app views. You can define specific [Roles] and configure their standard [Work Days] to prevent them from being booked on their days off.',
    },
    'Team Invites': {
      'title': 'Delegated Login',
      'body': 'Onboard employees securely. They receive their own credentials, meaning every action they take on the POS is tracked directly to them.',
    },
    'Roles': {
      'title': 'Permissions & Services',
      'body': 'Not every staff member can perform every service. Roles allow you to dictate exactly what services a specific employee is qualified to perform.',
    },
    'Work Days': {
      'title': 'Standard Hours',
      'body': 'Set the default availability block for an employee (e.g., 9 AM to 5 PM, Mon-Fri), laying the foundation for the Bookings system.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvShiftsNarrative = {
    'main': {
      'title': 'Shift Scheduling',
      'body': 'A granular timeline of when people are actually on the floor.\n\nShift Scheduling overrides default Staff Management hours via powerful [Timeline Management] controls. You can set up rapid [Recurring Blocks] for standard employees or handle erratic part-time rosters.',
    },
    'Timeline Management': {
      'title': 'Day-By-Day Control',
      'body': 'Adjust an employee\'s shift for a specific Tuesday, allowing you to accommodate sick days or overtime without breaking their permanent profile.',
    },
    'Recurring Blocks': {
      'title': 'Automated Rotations',
      'body': 'Once you build a perfect weekly shift pattern, you can flag it as Recurring to automatically populate the calendar indefinitely.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvAddonsNarrative = {
    'main': {
      'title': 'Service Addons',
      'body': 'Boost your average ticket size.\n\nAddons allow you to configure optional [Upsells] and [Modifications] that receptionists can tack onto a base service during booking, dynamically recalculating the time and cost.',
    },
    'Upsells': {
      'title': 'Revenue Generators',
      'body': 'Add a "Deep Conditioning Treatment" addon to a standard "Haircut" service to cleanly boost the final invoice.',
    },
    'Modifications': {
      'title': 'Time Adjustments',
      'body': 'Addons don\'t just affect price—you can configure an addon to add an extra 15 minutes to the scheduled Booking, ensuring the timeline doesn\'t overlap subsequent clients.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvBuffersNarrative = {
    'main': {
      'title': 'Service Buffers',
      'body': 'Protect your staff from burning out.\n\nBuffers automatically enforce padded [Turnaround Times] between intense appointments, giving professionals breathing room and [Clean Up Time].',
    },
    'Turnaround Times': {
      'title': 'Mandatory Padding',
      'body': 'If a 60-minute massage service has a 15-minute buffer, the Bookings calendar will physically block out 75 minutes of the employee\'s timeline, prohibiting back-to-back crunches.',
    },
    'Clean Up Time': {
      'title': 'Sanitation Cycles',
      'body': 'Crucial for medical, spa, or clinical services requiring room turnover protocols before the next client can enter.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvRecurringNarrative = {
    'main': {
      'title': 'Recurring Subscriptions',
      'body': 'Lock in consistent revenue with loyal clients.\n\nEstablish automated [Repeat Bookings] for customers who want the exact same slot every week/month, deploying aggressive [Automation] to handle your calendar.',
    },
    'Repeat Bookings': {
      'title': 'Guaranteed Slots',
      'body': 'Set a rule once, and Mbeck Business will perpetually reserve that Tuesday 10 AM slot for Mrs. Johnson\'s weekly appointment.',
    },
    'Automation': {
      'title': 'Set and Forget',
      'body': 'Free your receptionist from manual data entry. The system parses the calendar infinitely forward, respecting staff days off, and flagging any future holiday collisions.',
    },
  };

  static const Map<String, Map<String, dynamic>> srvRoomsNarrative = {
    'main': {
      'title': 'Room Facilities',
      'body': 'Set up physical [Service Rooms] that your staff need to perform tasks. When a room gets attached to a booking, the system guarantees no overlapping reservations can double-book this space.',
    },
    'Service Rooms': {
      'title': 'Spatial Management',
      'body': 'If a spa service or VIP haircut mandates a specific private room, adding rooms here ensures the calendar considers physical space as well as staff time.',
    },
  };

  // ─── Lodging Module Narratives ───
  static const Map<String, Map<String, dynamic>> lodgingReservationsNarrative = {
    'main': {
      'title': 'Lodging Front Desk',
      'body': 'Welcome to the Lodging module. The top banner displays your active [LAN], [Cloud], and upcoming [Mbeck Buyer] sync connections.\n\nHere you can execute rapid [Check Ins] into available rooms, view the timeline for [Groups], and handle [Check Outs].\n\nThe system intelligently protects you from assigning guests to a room under [Cleaning Status], and will immediately flag unpaid checkout tabs to the central [Customer Ledger].',
    },
    'Check Ins': {
      'title': 'Intelligent Check-In',
      'body': 'Starting a timeline drops the guest into the billing folio. The room instantly locks from the availability pool to prevent double-booking.',
    },
    'Groups': {
      'title': 'Corporate Master Folios',
      'body': 'Use the Groups tab to map multiple parallel reservations (like a wedding party) under a unified billing ledger, allowing one entity to pay the master invoice.',
    },
    'Check Outs': {
      'title': 'Deficit Ledgers',
      'body': 'If a guest ends their stay without settling the final amount, their deficit is quietly separated from your cash drawer and sent to their CRM file as an owing balance.',
    },
    'Cleaning Status': {
      'title': 'Housekeeping Enforcement',
      'body': 'Rooms transition into a cleaning state after a checkout. Standard reservations are blocked until staff manually mark the room as ready.',
    },
    'Customer Ledger': {
      'title': 'Automated Debt Tracing',
      'body': 'Unpaid tabs are routed to the central Retail/Customers tab. You can collect your debts at any time later without destroying your daily accounting cash pool.',
    },
  };

  static const Map<String, Map<String, dynamic>> lodgingRoomsNarrative = {
    'main': {
      'title': 'Your Room Directory',
      'body': 'This is where you register every room in your property. Assign a [Room Number or Name], set which [Floor or Wing] it is on, how many guests it fits ([Max Guests]), and what [Rate Category] applies to it.\n\nOnce a room is in here, it becomes bookable from the front desk.',
    },
    'Yield Layout': {
      'title': 'Your Property Map',
      'body': 'The full list of all your rooms. If you put a room into maintenance, it disappears from the booking calendar automatically until you mark it available again.',
    },
    'Floor Zones': {
      'title': 'Floors and Wings',
      'body': 'Group rooms by which floor or section of the building they are in. This makes it easy for housekeeping to clean by area rather than jumping all over the building.',
    },
    'Capacity Limits': {
      'title': 'Maximum Guests',
      'body': 'Set the maximum number of guests allowed in the room. The front desk cannot check in more people than this limit allows.',
    },
    'Yield Rates': {
      'title': 'Room Pricing Tiers',
      'body': 'Assign each room a pricing category: Standard, Deluxe, or Suite. The rate for each tier is set in the Rates section and automatically applied when booking.\n\nExample: Standard rooms at KSh 2,500/night. Suite at KSh 7,000/night.',
    },
  };

  static const Map<String, Map<String, dynamic>> lodgingFoliosNarrative = {
    'main': {
      'title': 'Billing Folios',
      'body': 'Every active room carries an attached [Resident Tab] that tracks their accumulated overnight fees and allows [Split Adjustments] if needed.',
    },
    'Resident Tab': {
      'title': 'Live Invoicing',
      'body': 'As nights pass or extras drop into the account, total amounts scale automatically in real time.',
    },
    'Split Adjustments': {
      'title': 'Dynamic Billing',
      'body': 'The cashier can override or deduct partial payments throughout a stay without waiting for the final checkout sequence.',
    },
  };

  static const Map<String, Map<String, dynamic>> lodgingGroupsNarrative = {
    'main': {
      'title': 'Master Groups',
      'body': 'Combine multiple independent reservations under one localized [Corporate Flag] to process a single unified check.',
    },
    'Corporate Flag': {
      'title': 'Unified Ledgers',
      'body': 'Used when a company pays for 5 rooms. The individual residents can check out freely, but the final bill funnels up to this overarching ledger.',
    },
  };

  static const Map<String, Map<String, dynamic>> lodgingRatesNarrative = {
    'main': {
      'title': 'Room Rate Settings',
      'body': 'Set how much you charge per night, and create special discounts for guests who stay longer.\n\nYou can set a [Weekly Rate] for guests who book 7+ nights, and a [Monthly Rate] for long-term residents. The app switches to the right rate automatically based on how long they are staying.',
    },
    'Duration Hooks': {
      'title': 'Longer Stay Discounts',
      'body': 'If a guest books for 7 days or more, the app automatically switches from the nightly rate to your weekly rate — giving them the discount without you doing anything manually.\n\nExample: Nightly rate is KSh 2,500. Weekly rate is KSh 14,000 (saving the guest KSh 3,500).',
    },
    'Monthly Yield': {
      'title': 'Monthly Residents',
      'body': 'When a guest\'s stay crosses 30 days, the system switches into monthly billing automatically.\n\nExample: A corporate visitor staying 45 days gets billed at KSh 45,000/month instead of KSh 2,500 × 45 = KSh 112,500.',
    },
  };

  static const Map<String, Map<String, dynamic>> lodgingChannelLogsNarrative = {
    'main': {
      'title': 'Room Activity Log',
      'body': 'A complete history of everything that happened to your rooms. Every check-in, checkout, cleaning, rate change, and maintenance record is stored here permanently.\n\nUse this when you need to investigate something that happened days or weeks ago.',
    },
    'Event Auditor': {
      'title': 'Who Did What',
      'body': 'If a room rate was changed or a reservation was deleted, this log shows you exactly who approved it and when.\n\nExample: Your rate dropped from KSh 2,500 to KSh 1,200 on a Saturday. Check here to find out which staff member made that change.',
    },
    'Immutable Chain': {
      'title': 'Cannot Be Erased',
      'body': 'Entries in this log cannot be deleted or altered after the fact. This protects you from staff trying to hide mistakes or cover up unauthorized changes.',
    },
  };

  static Map<String, Map<String, dynamic>> getNarrative(String contextKey) {
    switch (contextKey) {
      case 'retail':
        return {...retailNarrative, ...ecosystemNarrative};
      case 'customers':
        return customersNarrative;
      case 'accounting':
        return accountingNarrative;
      case 'cash':
        return cashNarrative;
      case 'verify':
        return verifyNarrative;
      case 'profits':
        return profitsNarrative;
      case 'suppliers':
        return suppliersNarrative;
      case 'returns':
        return returnsNarrative;
      case 'promos':
        return promosNarrative;
      case 'audit':
        return auditNarrative;
      case 'restock':
        return restockNarrative;

      // Restaurant Maps
      case 'restaurant': return {...restaurantNarrative, ...ecosystemNarrative};
      case 'pos': return posNarrative;
      case 'kds': return kdsNarrative;
      case 'menu': return menuNarrative;
      case 'recipe': return recipeNarrative;
      case 'waiter': return waiterNarrative;
      case 'tables': return tablesNarrative;
      case 'rest_inventory': return restInventoryNarrative;

      // Entertainment Maps
      case 'entertainment': return {...entertainmentNarrative, ...ecosystemNarrative};
      case 'entertainment_sessions': return {...entSessionsNarrative, ...ecosystemNarrative};
      case 'asset_management': return entAssetMgmtNarrative;
      case 'entertainment_tabs': return entTabsNarrative;
      case 'entertainment_pricing': return entPricingNarrative;
      case 'entertainment_prepaid': return entPrepaidNarrative;
      case 'entertainment_pause': return entPauseNarrative;

      // Services Maps
      case 'services': return {...srvDashboardNarrative, ...ecosystemNarrative};
      case 'services_bookings': return {...srvBookingsNarrative, ...ecosystemNarrative};
      case 'services_catalog': return srvCatalogNarrative;
      case 'services_staff': return srvStaffNarrative;
      case 'services_shifts': return srvShiftsNarrative;
      case 'services_addons': return srvAddonsNarrative;
      case 'services_buffers': return srvBuffersNarrative;
      case 'services_recurring': return srvRecurringNarrative;
      case 'services_rooms': return srvRoomsNarrative;
      
      // Lodging Maps
      case 'lodging': return {...lodgingReservationsNarrative, ...ecosystemNarrative};
      case 'lodging_reservations': return {...lodgingReservationsNarrative, ...ecosystemNarrative};
      case 'lodging_rooms': return lodgingRoomsNarrative;
      case 'lodging_folios': return lodgingFoliosNarrative;
      case 'lodging_groups': return lodgingGroupsNarrative;
      case 'lodging_rates': return lodgingRatesNarrative;
      case 'lodging_channel_logs': return lodgingChannelLogsNarrative;

      // Global Maps
      case 'history': return historyNarrative;
      case 'reports': return reportsNarrative;

      default:
        // fallback to retail if it matches a module, otherwise generic empty
        return {
          'main': {
            'title': 'Feature Guide',
            'body': 'Explore the features of this screen by clicking around.',
          }
        };
    }
  }
}
