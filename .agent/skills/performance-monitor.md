# Performance Monitor Skill

## Purpose
Monitor and analyze performance of subsystem flows.

## Capabilities
- End-to-end latency measurement
- Bottleneck identification
- Resource utilization tracking
- Load testing

## Usage
Invoke with: "Monitor performance for [use case]"

## Inputs Required
- Use case scenario
- Performance SLAs
- Load parameters (requests/sec)
- Duration

## Outputs Produced
- Performance dashboard artifact
- Bottleneck analysis
- Resource usage graphs
- SLA compliance report

## Implementation Instructions
1. Instrument code with timing probes or use APM tools
2. Execute use case under various loads
3. Collect metrics (latency, throughput, CPU, memory)
4. Identify slowest subsystems
5. Analyze percentiles (p50, p95, p99)
6. Compare against SLAs
7. Generate performance artifact with charts

## Example Prompt
"Monitor performance for order placement under 100 requests/second load. SLA requires p95 latency < 500ms. Identify which subsystem is the bottleneck."