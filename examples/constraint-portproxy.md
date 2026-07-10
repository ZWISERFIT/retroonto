---
id: C-PORTPROXY-CLEANUP
name: portproxy-cleanup
description: "Any portproxy operation must include cleanup logic"
source: ERR-INFRA-001
type: executable
severity: 🔴
---

# Constraint: Portproxy Zombie Rule Prevention

**Source Error:** ERR-INFRA-001 — Port forwarding rule caused proxy loop

## Check

```
Check for stale netsh interface portproxy rules.
On Windows: netsh interface portproxy show all
If rules exist and no matching process: flag as zombie
On Linux/Mac: check iptables REDIRECT/TPROXY rules
```

## Precondition

Any operation that creates a network forwarding rule.

## Enforcement

1. Before creating a portproxy rule: log the rule for later cleanup
2. After troubleshooting: verify rule was removed
3. Automated guard: scheduled task scans every 5 minutes for zombie rules
4. If zombie detected: auto-remove + alert

## Severity

🔴 — Zombie portproxy rules cause silent network failures that are extremely hard to diagnose.
