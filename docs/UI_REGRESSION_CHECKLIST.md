UI REGRESSION CHECKLIST — MUST PASS ALL
🔴 HARD FAIL CONDITIONS

If ANY item below fails → DO NOT COMMIT.

1. POS FLOW INTEGRITY

 Can complete a sale without network

 Can complete a sale without scanner

 Can sell multiple items in one transaction

 Checkout button is always reachable

 No modal blocks core POS actions

 No animation delays payment confirmation

2. SPEED & PERFORMANCE

 No new taps added to core flows

 Lists >20 items have reduced animation

 No blur or shader effects

 Animations ≤300ms

 Skeleton loaders used instead of spinners

3. USER CONTROL & RECOVERY

 Undo exists for destructive actions

 Quantity edits are reversible

 Wrong item selection is fixable in ≤2 taps

 No forced AI usage

 Manual paths remain visible

4. OFFLINE BEHAVIOR

 All screens load offline

 Offline state is informational only

 No red error states for offline

 No network dependency for UI rendering

5. DESIGN SYSTEM COMPLIANCE

 Only approved colors used

 Only approved typography used

 Only spacing constants used

 No magic numbers

 One primary CTA per screen

6. VISUAL HIERARCHY

Each screen clearly shows:

 Primary task

 Current state

 Next action

7. LOCAL CONTEXT VALIDATION (KENYA)

 Currency formatted as KSH

 M-Pesa treated as primary payment

 Language is simple and non-technical

 Dates formatted DD MMM YYYY

8. TECHNICAL HYGIENE

 No UI logic in services

 No business logic in widgets

 Widget files < ~300 LOC

 Animations isolated to components

 Code is readable without comments

FINAL COMMIT GATE

Before committing, the agent MUST state:

“I have verified that all items in UI_REGRESSION_CHECKLIST.md pass.
No POS capability was removed or degraded.”

If this statement cannot be made truthfully → DO NOT COMMIT