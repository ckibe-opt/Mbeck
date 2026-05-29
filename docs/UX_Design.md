UI / UX EXECUTION SPEC

Project: myShop POS
Version: 2.0.0
Audience: Cursor Auto Agent (Autonomous Coding Mode)
Authority Level: HARD CONSTRAINTS
Failure Mode: If uncertain → STOP and ask for clarification

0. EXECUTION MODE

You are operating as an autonomous implementation agent, not a designer.

You MUST:

Convert specifications into Flutter code

Favor deterministic rules over interpretation

Avoid stylistic creativity outside what is defined here

Preserve POS reliability above all else

If a decision is not explicitly allowed here → do not invent it

1. NON-NEGOTIABLE SYSTEM CONSTRAINTS
1.1 POS Priority Rule

POS flows (selling, payment, stock updates) MUST:

Never block

Never wait on animations

Never depend on network state

UI polish must NEVER degrade transaction speed

If UI change increases tap count or latency → reject it

1.2 Offline-First UX Rule

All screens must function fully offline

Offline state must:

Be informational only

Never appear as an error

Never interrupt workflows

Forbidden

Modal dialogs for offline state

Red error colors for offline mode

1.3 Device Performance Rule

Target device: Low-end Android (e.g. TECNO KL4)

Maintain 60 FPS during transactions

Disable heavy animations for lists > 20 items

No blur effects

No shader masks in scrollable views

2. UX GUARDRAILS (HARD RULES)
2.1 Fast Path vs Guided Path

Every transactional screen MUST support both.

Fast Path

Minimal copy

Defaults pre-selected

No confirmations unless irreversible

Guided Path

Empty states with instruction

Optional helper text

No forced tutorials

The system MUST NOT force one path.

2.2 Human Error Tolerance

Assume:

Mis-taps

Wrong quantities

Wrong item selection

Mandatory UX

Undo for destructive actions

Edit instead of delete when possible

≤ 2 taps to recover from common mistakes

2.3 Removal Protection Rule

The agent MUST NOT remove any existing user capability unless ALL are true:

It is unused

It has a superior replacement

It is not a fallback path

Explicitly Protected Capabilities

Manual item entry (no scan)

Multi-item transactions

Non-AI workflows

AI is assistive, not authoritative.

3. NEW TRANSACTION SCREEN — STRICT SPEC
3.1 Required Capabilities (DO NOT REMOVE)

Add multiple items per transaction

Add items without scanning

Edit quantities inline

Cancel or undo item addition

3.2 Scanner Role

Scanner is OPTIONAL

Scanner accelerates, never replaces manual entry

If scan fails → manual path must be immediately visible

3.3 Cart Behavior

Real-time totals

Animated number updates (≤300ms)

No blocking loaders

Checkout button:

Always visible

Disabled only if transaction invalid

Immediate visual confirmation on success

4. VISUAL HIERARCHY RULE

Each screen MUST clearly answer, in order:

Primary task

Current state

Next action

Constraints

One primary CTA per screen

One secondary CTA max

Tertiary actions hidden (bottom sheet, long-press)

5. DESIGN SYSTEM — IMPLEMENTATION RULES
5.1 Colors

Use defined palette only

Semantic colors must map to meaning

No arbitrary hex values

5.2 Typography

Use provided scale only

No ad-hoc font sizes

No text smaller than 12sp

5.3 Spacing

Use spacing constants only

No magic numbers

Padding must be consistent across screens

5.4 Components

Screens assemble components

Components contain animations

Components contain NO business logic

Max ~300 lines of UI code per screen.

6. ANIMATION RULES (STRICT)
Type	Rule
Duration	≤ 300ms
Curve	easeOutCubic
Blocking	Forbidden
Lists	Stagger ≤ 40ms
Loading	Skeletons only

Forbidden

Infinite animations

Spinner-only loading

Animation during payment confirmation

7. LOCAL CONTEXT RULES (KENYA)

Currency: KSH

Payments: M-Pesa primary, cash secondary

Language: Simple, non-technical

Dates: DD MMM YYYY

Avoid fintech jargon.

8. SCREEN-LEVEL ACCEPTANCE CHECKLIST

Before completing any screen, verify:

 Works fully offline

 Transaction completes in <30s

 No blocked UI

 Recovery path exists

 Manual alternatives preserved

 Animation budget respected

If any check fails → screen is incomplete.

9. IMPLEMENTATION ORDER (MANDATORY)

Design system file

Reusable components

Dashboard

New Transaction screen

Inventory

Accounting

Customers

Trust Score

Do not skip steps.

10. FAILURE MODE

If the agent encounters:

Ambiguous UX decision

Conflict between polish and speed

Risk of removing user control

It MUST:

Stop

Explain the conflict

Request clarification

Silent assumptions are forbidden.

11. SUCCESS CRITERIA

The implementation is considered correct if:

POS flows feel instant

UI communicates trust

AI features never block workflows

Manual paths always exist

System works offline without friction

END OF EXECUTION SPEC