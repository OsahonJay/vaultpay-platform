# ADR-002: IAM Roles for Service Accounts (IRSA) over Node-Level IAM

## Status
Accepted

## Context

The payment platform runs multiple microservices on Amazon EKS. These services interact with AWS resources including Secrets Manager, Amazon S3, CloudWatch, and DynamoDB. Not every service requires access to every AWS resource, and services handling sensitive payment data have different privilege requirements.

A node-level IAM model assigns a single IAM role to each EC2 worker node. Every pod scheduled on that node can potentially inherit the node's AWS permissions through the EC2 Instance Metadata Service (IMDS). This creates an unnecessary expansion of the trust boundary and makes it difficult to enforce least-privilege access.

For a payment platform, this presents several risks:

- A compromised application can obtain AWS credentials intended for unrelated workloads running on the same node.
- Services receive permissions they do not require, increasing the potential impact of exploitation.
- Auditing becomes more difficult because AWS API calls are attributed to the node role rather than the individual application.
- Meeting compliance requirements for access segregation and least privilege becomes harder.
- Rotating or changing permissions affects every workload on the node rather than a single application.

These issues conflict with the platform's security objectives and PCI DSS principles of least privilege and separation of duties.

## Status
Accepted

## Context

The payment platform runs multiple microservices on Amazon EKS. These services interact with AWS resources including Secrets Manager, Amazon S3, CloudWatch, and DynamoDB. Not every service requires access to every AWS resource, and services handling sensitive payment data have different privilege requirements.

A node-level IAM model assigns a single IAM role to each EC2 worker node. Every pod scheduled on that node can potentially inherit the node's AWS permissions through the EC2 Instance Metadata Service (IMDS). This creates an unnecessary expansion of the trust boundary and makes it difficult to enforce least-privilege access.

For a payment platform, this presents several risks:

- A compromised application can obtain AWS credentials intended for unrelated workloads running on the same node.
- Services receive permissions they do not require, increasing the potential impact of exploitation.
- Auditing becomes more difficult because AWS API calls are attributed to the node role rather than the individual application.
- Meeting compliance requirements for access segregation and least privilege becomes harder.
- Rotating or changing permissions affects every workload on the node rather than a single application.

These issues conflict with the platform's security objectives and PCI DSS principles of least privilege and separation of duties.

## Decision

The platform uses AWS IAM Roles for Service Accounts (IRSA) for all workloads requiring access to AWS services. Each Kubernetes Service Account is mapped to a dedicated IAM role through the EKS cluster's OpenID Connect (OIDC) provider, allowing pods to obtain short-lived AWS credentials from AWS Security Token Service (STS). This provides workload-level identity, enforces least-privilege IAM policies for each microservice, improves CloudTrail auditability, and removes the need to store long-lived AWS credentials inside Kubernetes.

## Alternatives Considered

### Node-Level IAM Roles
**Rejected.** Although simple to configure, node-level IAM grants the same AWS permissions to every pod on a worker node. Any compromised workload could access AWS resources intended for unrelated services. The approach prevents effective workload isolation and makes least-privilege access difficult to enforce.

### Amazon EKS Pod Identity
**Rejected.** EKS Pod Identity provides workload-specific credentials without requiring an OIDC provider but requires the EKS Pod Identity Agent addon, introducing an additional cluster dependency. IRSA had broader community adoption and more established tooling at the time of this decision.

### HashiCorp Vault with Vault Agent Sidecar Injector
**Rejected.** Vault is a strong option for multi-cloud or centralised secrets management but introduces an additional critical service requiring deployment, high availability, backup, and maintenance. IRSA provides the same workload-specific, short-lived credentials through native AWS federation without the operational overhead.

## Consequences

### Positive
- AWS permissions are assigned to individual workloads instead of worker nodes.
- Compromising one pod does not automatically expose permissions belonging to other services.
- Each microservice operates with its own least-privilege IAM policy.
- CloudTrail records are associated with workload-specific IAM roles, improving auditability.
- Long-lived AWS access keys are not stored inside containers or Kubernetes Secrets.

### Negative
- More IAM roles and policies must be managed as the platform grows.
- Additional configuration is required for Kubernetes Service Accounts, IAM roles, and OIDC federation.
- Misconfigured IAM trust policies, particularly incorrect StringEquals conditions on the service account subject, can silently prevent a workload from assuming its role or allow another workload to assume it unintentionally.
- Troubleshooting authentication failures requires knowledge of IAM policies, OIDC federation, Kubernetes Service Accounts, and AWS STS.

## Residual Risk

IRSA significantly reduces privilege escalation compared with node-level IAM but does not eliminate all risk. A compromised pod can still use the temporary credentials associated with its IAM role until they expire. The impact depends on how narrowly the IAM policy is scoped.

Within this project, risks are mitigated by assigning least-privilege IAM policies to each workload, defining explicit trust policy conditions for individual Service Accounts, managing IAM resources through infrastructure as code, and monitoring AWS API activity with CloudTrail.

Automated IAM policy validation and periodic access reviews are identified as future improvements rather than implemented capabilities.
