# ADR-003: Kyverno Admission Control for Kubernetes Policy Enforcement

## Status
Accepted

## Context

VaultPay uses Checkov to identify Infrastructure-as-Code misconfigurations during the CI/CD pipeline, Trivy to scan container images for vulnerabilities before deployment, and IRSA to enforce least-privilege access to AWS resources at runtime. While these controls reduce the likelihood of deploying insecure infrastructure, they do not prevent Kubernetes resources that bypass the CI/CD pipeline from being deployed directly to the cluster.

As a PCI-DSS payment platform, VaultPay requires consistent enforcement of security controls regardless of how workloads are deployed. Without admission control, developers or administrators with cluster access could apply manifests that violate security requirements, such as running privileged containers, using the default ServiceAccount, or deploying workloads without required runtime security settings. Without Kubernetes NetworkPolicies, pod-to-pod communication is unrestricted by default, allowing a compromised workload to reach other services and increasing the risk of lateral movement.

A Kubernetes-native policy engine is therefore required to enforce security policies at admission time.

## Decision

Kyverno was selected as the Kubernetes-native policy engine to enforce security policies at admission time using Enforce mode, as the new EKS cluster contained no existing workloads and the risk of blocking legitimate deployments was minimal. Kyverno integrates directly with the Kubernetes admission controller and allows policies to be defined as Kubernetes resources without requiring additional tooling or knowledge of a separate policy language. The implemented policies enforce secure pod runtime settings (allowPrivilegeEscalation: false, runAsNonRoot: true, and readOnlyRootFilesystem: true), restrict container images to VaultPay's approved ECR registry, and prevent pods from using the default ServiceAccount.

## Alternatives Considered

### OPA/Gatekeeper
**Rejected.** OPA/Gatekeeper provides admission control using the Open Policy Agent and Rego policy language. It was not selected because Kyverno allows policies to be written as native Kubernetes resources using YAML, making them easier to develop, review, and maintain within VaultPay's existing Kubernetes workflows without requiring knowledge of Rego.

### Pod Security Admission
**Rejected.** Pod Security Admission is built into Kubernetes and enforces predefined pod security standards. It was rejected because it focuses only on pod security settings and cannot enforce the broader set of policies required by VaultPay, such as validating approved ServiceAccounts, restricting container image sources, or applying other custom admission controls needed for a PCI-DSS environment.

### Kyverno Audit Mode
**Rejected.** Audit mode reports policy violations without blocking deployments. It was not selected because the EKS cluster was newly provisioned with no existing workloads, making the operational risk of Enforce mode low. Enforcing policies from the outset ensures that non-compliant workloads cannot enter the payment environment.

## Consequences

### Positive
- Security policies are enforced at admission time regardless of how workloads are deployed.
- Non-compliant workloads are blocked before they can run in the payment environment.
- Runtime security settings are applied consistently across all payment workloads.
- Container images are restricted to VaultPay's approved ECR registry, reducing supply chain risk.
- Policies are defined as Kubernetes resources, making them version-controlled and auditable.

### Negative
- Kyverno policies must be maintained as application and platform requirements evolve.
- Enforce mode means misconfigured policies can block legitimate workloads until corrected.
- Developers must understand policy requirements before deploying workloads to the cluster.
- Adding new services requires reviewing existing policies to ensure compatibility.

## Residual Risk

Kyverno validates Kubernetes resource configuration at admission time but does not monitor application behaviour after a workload is admitted. It does not detect application vulnerabilities, protect against runtime exploits within an already compliant workload, or prevent misuse of legitimate application functionality.

These risks are mitigated through complementary controls including Trivy image scanning, IRSA least-privilege access, and secure application development practices. Runtime threat detection using a tool such as Falco is identified as a future improvement to provide visibility into workload behaviour after admission.
