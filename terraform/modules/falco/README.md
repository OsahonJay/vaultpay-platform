# Falco Runtime Security Module

## What This Does

Installs Falco on the EKS cluster to provide runtime threat detection.
Falco monitors Linux kernel system calls using eBPF and alerts when
containers exhibit suspicious behaviour — shell spawning, sensitive file
reads, or unexpected network connections.

## Payment-Specific Rules

This module includes two custom rules scoped to VaultPay workloads:

**Shell Spawned in Payment Container** — CRITICAL alert if a shell process
appears inside a payment service container. Legitimate application code
never spawns shells. Any match indicates active exploitation.

**Sensitive File Read in Payment Container** — WARNING alert if a payment
container reads `/etc/passwd`, `/etc/shadow`, or `/etc/sudoers`. These
files have no legitimate use in a payment service.

## Node Requirements

Falco requires kernel-level instrumentation via eBPF. This has minimum
node requirements:

- Instance type: `t3.large` or larger (minimum 8GB RAM)
- Kernel version: 5.8+ for `modern_ebpf` driver

**The dev environment uses `t3.medium` (4GB RAM) which is insufficient
for Falco's eBPF buffer allocation.** Falco is architected and ready but
disabled in dev to avoid node resizing costs.

For production deployment, update `node_instance_type` in the EKS module
to `t3.large` before enabling this module.

## Alerts

Alerts route to Slack via Falcosidekick. Configure the webhook URL via
the `slack_webhook_url` variable. Minimum priority for Slack alerts is
`warning` — informational events are logged only.
