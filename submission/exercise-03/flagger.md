# Flagger Traffic Shifting and Criteria

## How Flagger Shifts Traffic

Flagger implements progressive traffic shifting for canary deployments through the following process:

### Initialization Phase
When a new deployment is detected (e.g., image updated from v6.5.3 to v6.5.4):
1. Flagger creates a `podinfo-canary` deployment with the new version
2. Creates separate `podinfo-primary` and `podinfo-canary` services
3. Executes the **pre-rollout acceptance test** webhook to validate the canary is responding correctly

### Progressive Traffic Shift
If the acceptance test passes, Flagger begins incrementally shifting traffic:

| Time | Primary | Canary | Action |
|------|---------|--------|--------|
| T+0s | 100% | 0% | Initial stable state |
| T+30s | 90% | 10% | First traffic shift |
| T+60s | 80% | 20% | Metrics validated, increase canary |
| T+90s | 70% | 30% | Metrics validated, increase canary |
| T+120s | 60% | 40% | Metrics validated, increase canary |
| T+150s | 50% | 50% | Reached maxWeight, final validation |
| T+180s | 0% | 100% | All checks passed, promote canary |

At each 30-second interval, Flagger validates metrics before proceeding to the next step.

### Promotion or Rollback
- **Success**: If all metrics pass for 5 consecutive checks, the canary spec is copied to the primary deployment, and the canary is scaled down
- **Failure**: If success rate drops below 99% OR latency exceeds 500ms, traffic is immediately routed back to primary (rollback in <30 seconds)

## Configured Criteria

### Traffic Management
- **interval**: 30s - How often metrics are checked
- **threshold**: 5 - Maximum consecutive failures before rollback
- **maxWeight**: 50% - Maximum traffic to canary
- **stepWeight**: 10% - Traffic increment per successful check

### Metrics Monitored

1. **request-success-rate**
   - Minimum threshold: 99%
   - Measurement: Percentage of non-5xx responses
   - Check interval: 1 minute
   - Source: NGINX Ingress metrics

2. **request-duration**
   - Maximum threshold: 500ms (P99 latency)
   - Measurement: 99th percentile response time
   - Check interval: 30 seconds
   - Source: NGINX Ingress metrics

### Webhooks Configured

1. **acceptance-test** (pre-rollout)
   - Type: Pre-rollout validation
   - Timeout: 30 seconds
   - Purpose: Validates canary endpoint responds correctly before any traffic is shifted

2. **load-test** (during rollout)
   - Type: Rollout traffic generation
   - Purpose: Generates consistent traffic during rollout to ensure meaningful metrics collection