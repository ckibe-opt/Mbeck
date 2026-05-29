---
description: Subsystem Testing Workflow
---

## Workflow Steps

### 1. Use Case Ingestion
**Task**: Parse use case specification
**Agent**: Orchestrator
**Output**: Test plan with subsystems, scenarios, and success criteria

### 2. Parallel Agent Dispatch
**Task**: Spawn specialized testing agents
**Agents**: 
- Flow Analyzer (analyze execution flow)
- Data Validator (validate data integrity)
- Integration Tester (test API contracts)
- Performance Monitor (measure performance)
**Execution**: Parallel

### 3. Result Collection
**Task**: Gather artifacts from all agents
**Agent**: Orchestrator
**Inputs**: Flow diagrams, validation reports, test results, performance metrics

### 4. Report Generation
**Task**: Create consolidated test report
**Agent**: Orchestrator
**Output**: Comprehensive HTML/PDF report with all findings

### 5. Issue Prioritization
**Task**: Classify and prioritize issues
**Agent**: Orchestrator
**Output**: Prioritized issue list with severity and recommendations

## Example Usage
In Agent Manager, create new task:
"Execute subsystem testing workflow for the user registration use case"

