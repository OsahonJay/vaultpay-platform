How I Built a Production-Grade DevSecOps Platform for Fintech on AWS EKS
The Problem
Deploying a payment service on Kubernetes is relatively straightforward. Deploying one securely is not.
A typical fintech service needs access to secrets, must authenticate to AWS without long-lived credentials, enforce least-privilege permissions, prevent insecure workloads from reaching production, and provide evidence that these controls are working. In many teams, these responsibilities are handled through a combination of manual configuration, deployment guides, and code reviews. The result is inconsistent implementations, configuration drift, and security controls that are difficult to verify.
The goal was to embed these requirements directly into the platform rather than relying on every application team to implement them independently.
The result was VaultPay, a reusable DevSecOps platform built on Amazon EKS. Instead of treating security as a deployment checklist, the platform enforces identity, admission policies, private networking, and automated security validation by default. Developers deploy services through Terraform, while the platform consistently applies the security controls required for a PCI DSS-aligned payment environment.

Architecture Overview
VaultPay applies security at three distinct stages of the software delivery lifecycle. Each layer addresses a different class of risk, providing defence in depth rather than relying on a single control.
Pipeline Security
Security begins before infrastructure or application code reaches Kubernetes. Every pull request passes through automated validation using GitHub Actions. The pipeline executes Terraform validation, Checkov, Gitleaks, Semgrep, and Trivy to identify:

Terraform misconfigurations
Exposed secrets
Vulnerable container images
Common application security flaws
Infrastructure policy violations

This prevents known issues from progressing further into the deployment pipeline.
Admission Control
Passing CI does not guarantee that workloads are deployed securely. Kubernetes manifests can still be modified after scanning or applied manually.
Kyverno addresses this by validating workloads at admission time. Policies require every workload to use a dedicated ServiceAccount, run as a non-root user, disable privilege escalation, use a read-only root filesystem, and pull images only from trusted Amazon ECR repositories. Any workload that violates these requirements is rejected before it reaches the cluster.
Runtime Identity
Once a workload is running, VaultPay uses IAM Roles for Service Accounts (IRSA) to provide temporary AWS credentials without storing secrets inside Kubernetes. Each service receives only the permissions required for its function. Identity is enforced through IAM trust policies and validated using runtime verification rather than configuration alone.
Section 3 covers how this was verified end-to-end, including proof that unauthorised access was explicitly denied.

IRSA Deep Dive
IRSA was the most interesting component of the project because it solved one of Kubernetes' biggest security challenges: giving workloads access to AWS services without exposing long-lived credentials.
Traditionally, Kubernetes applications inherit the IAM permissions attached to the worker node. Every pod on that node effectively shares the same AWS identity, making least privilege difficult to achieve. If one pod is compromised, the attacker inherits the permissions of the entire node through the EC2 Instance Metadata Service (IMDS).
IRSA changes this model by assigning an IAM role directly to a Kubernetes ServiceAccount. When a pod starts, Kubernetes issues an OIDC token representing that ServiceAccount. AWS Security Token Service validates the token against the cluster's OIDC provider. If the IAM trust policy permits the ServiceAccount to assume the role, temporary credentials are issued automatically. The application never stores AWS access keys.
The trust policy used in VaultPay restricts role assumption to a single ServiceAccount within a specific namespace. The condition uses StringEquals on oidc.eks.eu-west-2.amazonaws.com/id/{cluster-id}:sub set to system:serviceaccount:default:vaultpay-app-sa, ensuring no other pod in the cluster can assume this role.
Configuring IRSA is only part of the solution. The more important question is whether it actually works as intended.
Rather than assuming the configuration was correct, I verified it through a four-checkpoint validation:

The pod successfully authenticated using its ServiceAccount — AWS_ROLE_ARN and AWS_WEB_IDENTITY_TOKEN_FILE were injected by the EKS Pod Identity Webhook.
AWS STS returned the expected IAM role: arn:aws:sts::875522883478:assumed-role/dev-vaultpay-workload-role
The application successfully retrieved its authorised secret from AWS Secrets Manager: {"api_key":"vaultpay-demo-key-dev","db_host":"db.vaultpay.internal"}
An attempt to list all secrets failed with AccessDeniedException: User is not authorized to perform: secretsmanager:ListSecrets because no identity-based policy allows the secretsmanager:ListSecrets action

The final checkpoint was particularly important. Successful authentication proves that IRSA is configured correctly. Failed unauthorised access proves that least privilege is actually being enforced.
Many demonstrations stop after showing a successful AssumeRoleWithWebIdentity call. I wanted to demonstrate both the positive and negative paths to provide evidence that the security boundary behaved exactly as designed.

Kyverno Policies
Pipeline scanning answers the question: "Is this code safe to deploy?"
Admission control answers a different question: "Should this workload be allowed into the cluster at all?"
These controls complement each other rather than replacing one another. A workload might pass every CI security scan but still request privileged execution or reference an image hosted outside the organisation's trusted registry. Kyverno evaluates these conditions when Kubernetes receives the deployment request.
One example from VaultPay requires workloads to use a non-default ServiceAccount:
yamlapiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-default-serviceaccount
spec:
  validationFailureAction: Enforce
  rules:
  - name: check-serviceaccount
    match:
      any:
      - resources:
          kinds: [Pod]
          namespaces: [default]
    validate:
      message: "Pods must use a named ServiceAccount."
      pattern:
        spec:
          serviceAccountName: "?*"
          =(serviceAccountName): "!default"
If any policy fails, Kubernetes rejects the deployment before the pod is created. This shifts security enforcement from documentation and code review into the platform itself.

What I'd Do Differently
Although the platform achieved its original objectives, several improvements would strengthen it further.
The first would be fully integrating Falco for runtime threat detection. The Falco module and custom payment-specific rules are implemented, but the dev environment uses t3.medium nodes which lack sufficient memory for eBPF buffer allocation. Production deployment requires t3.large or larger nodes. The module is ready — it's a node sizing decision, not a configuration gap.
The egress NetworkPolicy currently permits HTTPS traffic to the VPC CIDR to support the Secrets Manager VPC endpoint. A more complete implementation would restrict egress to specific endpoint IP ranges rather than the entire VPC CIDR, reducing the lateral movement surface further.
The Terraform workflow was split into two sequential stages — AWS infrastructure and Kubernetes resources — to resolve a provider dependency that prevented planning when the cluster was destroyed. This pattern should be extended to staging and production environments with appropriate approval gates between stages.

Conclusion
Building VaultPay reinforced an important lesson: security controls have more value when they are embedded into the platform than when they depend on developers remembering to configure them correctly.
Pipeline scanning, admission control, and runtime identity each solve different problems, but together they create a platform where secure deployment becomes the default rather than an optional extra.
The most valuable outcome wasn't deploying a payment service to Amazon EKS. It was producing evidence that the platform's security controls behaved exactly as intended, from workload identity to least-privilege enforcement.
The complete implementation — including Terraform modules, GitHub Actions workflows, Kyverno policies, IRSA configuration, and verification outputs — is available here:
Repository: https://github.com/OsahonJay/vaultpay-platform
