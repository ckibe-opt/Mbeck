# Orchestrator Skill

## Purpose
Coordinate multiple testing agents for comprehensive use case testing.

## Capabilities
- Decompose use cases into test scenarios
- Assign tasks to specialized agents
- Consolidate results
- Generate comprehensive reports

## Usage
Invoke with: "Test use case: [description]"

## Inputs Required
- Use case description
- Subsystems involved
- Expected flow
- Success criteria

## Outputs Produced
- Test execution plan
- Consolidated test report
- Issue summary
- Recommendations

## Implementation Instructions
1. Parse use case description
2. Identify subsystems and interactions
3. Create test plan with scenarios
4. Spawn parallel agent tasks:
   - Flow Analyzer for flow tracing
   - Data Validator for data checks
   - Integration Tester for API testing
   - Performance Monitor for performance
5. Wait for all agents to complete
6. Consolidate results into unified report
7. Prioritize issues by severity
8. Generate executive summary

## Example Prompt
"Test the complete order placement use case end-to-end. Verify flow, data integrity, integration points, and performance. Expected flow: User adds items → checkout → payment → order confirmation → email sent."