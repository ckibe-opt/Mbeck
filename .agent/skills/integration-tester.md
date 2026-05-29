# Integration Tester Skill

## Purpose
Test communication and integration between subsystems.

## Capabilities
- API contract testing
- Message format validation
- Authentication/authorization testing
- Error handling verification

## Usage
Invoke with: "Test integration between [subsystem A] and [subsystem B]"

## Inputs Required
- Subsystem endpoints/interfaces
- API contracts (OpenAPI, gRPC proto, etc.)
- Authentication credentials
- Test scenarios

## Outputs Produced
- Integration test report
- API contract violations
- Communication failures
- Performance metrics

## Implementation Instructions
1. Load API contracts for both subsystems
2. Generate test cases from contracts
3. Execute API calls using terminal/browser
4. Validate responses
5. Test error scenarios (timeouts, 4xx, 5xx)
6. Measure latency
7. Check retry/circuit breaker logic
8. Generate test report artifact

## Example Prompt
"Test the integration between OrderService and NotificationService. Verify that order confirmation triggers email notification, SMS notification, and push notification within 5 seconds."