# Flow Analyzer Skill

## Purpose
Trace and validate subsystem execution flows for use cases.

## Capabilities
- Map actual execution paths through code
- Compare against expected flow diagrams
- Identify deviations and anomalies
- Detect circular dependencies

## Usage
Invoke with: "Analyze the flow for [use case name]"

## Inputs Required
- Use case description
- Expected flow diagram (mermaid or sequence diagram)
- Entry point function/endpoint
- List of subsystems involved

## Outputs Produced
- Flow map artifact (mermaid diagram)
- Deviation report
- Bottleneck analysis
- Recommendations

## Implementation Instructions
1. Start from the entry point (API endpoint, function, etc.)
2. Use code analysis to trace function calls across subsystems
3. Build execution graph
4. Compare with expected flow
5. Generate flow diagram artifact
6. Highlight deviations in red
7. Produce summary report

## Example Prompt
"Analyze the flow for the order placement use case. Entry point is POST /api/orders. Expected flow: CartService → InventoryService → PaymentService → OrderService → NotificationService. Highlight any deviations."