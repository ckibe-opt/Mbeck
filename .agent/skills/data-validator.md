# Data Validator Skill

## Purpose
Validate data integrity across subsystem boundaries.

## Capabilities
- Schema validation at interfaces
- Data transformation verification
- Detect data corruption or loss
- Business rule compliance checking

## Usage
Invoke with: "Validate data flow for [subsystem interaction]"

## Inputs Required
- Source subsystem
- Target subsystem
- Data schema/contract
- Sample test data
- Business rules

## Outputs Produced
- Validation report artifact
- Schema mismatch errors
- Data corruption incidents
- Compliance violations

## Implementation Instructions
1. Identify all data exchange points between subsystems
2. Extract input/output schemas from code or OpenAPI specs
3. Run test data through the flow
4. Capture data at each boundary
5. Validate against schemas
6. Check transformations
7. Verify business rules
8. Generate validation report

## Example Prompt
"Validate data flow from CartService to PaymentService. Check that order total is correctly calculated, tax is applied, and payment payload matches the expected schema."