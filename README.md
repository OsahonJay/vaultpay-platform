# VaultPay Platform

## What This Is
Fintech teams deploying payment services risk exposing hardcoded credentials and vulnerable dependencies to production.
A threat actor can find exposed AWS credentials in a public repo within minutes and compromise payment data. 
VaultPay Platform eliminates this by enforcing automated security gates like Trivy, Semgrep, Checkov, and OWASP scans 
that fail the build before anything unsafe reaches the cluster, while developers provision new microservices with secrets 
stored automatically in AWS Secrets Manager, never in code. The result is an engineering team that ships faster because security 
is automated, and a compliance team that can trace every PCI-DSS control to evidence without chasing engineers.

## What This Is Not
VaultPay Platform is the infrastructure and delivery platform. It is not a payment application and contains no payment processing logic.

## Architecture Overview
## Architecture Overview

Payment services run in private subnets so that even if an attacker gains 
a foothold elsewhere in the environment, they cannot directly reach EKS worker 
nodes handling cardholder data. All inbound traffic passes through the load 
balancer — a single controlled entry point.

\```mermaid
graph TB
    subgraph Internet
        User[Developer / CI Pipeline]
    end

    subgraph AWS eu-west-2
        subgraph VPC 10.0.0.0/16
            subgraph Public Subnets
                IGW[Internet Gateway]
                NAT1[NAT GW AZ-a]
                NAT2[NAT GW AZ-b]
                NAT3[NAT GW AZ-c]
                ALB[Load Balancer]
            end

            subgraph Private Subnets
                EKS[EKS Control Plane]
                NODE1[Worker Node AZ-a]
                NODE2[Worker Node AZ-b]
                NODE3[Worker Node AZ-c]
            end
        end

        subgraph Security and Secrets
            KMS[KMS Keys]
            SM[Secrets Manager]
            CW[CloudWatch Logs]
        end

        subgraph State Management
            S3[Terraform State S3]
            DDB[DynamoDB Lock Table]
        end
    end

    User -->|HTTPS| ALB
    ALB --> NODE1
    ALB --> NODE2
    ALB --> NODE3
    NODE1 & NODE2 & NODE3 --> EKS
    NODE1 -->|NAT| NAT1
    NODE2 -->|NAT| NAT2
    NODE3 -->|NAT| NAT3
    NAT1 & NAT2 & NAT3 --> IGW
    EKS --> KMS
    NODE1 & NODE2 & NODE3 --> SM
    EKS --> CW
\```

## Security Posture
VaultPay Platform is built to meet PCI-DSS compliance requirements. 
Our default security assumption is that the environment is already breached and every control is designed around that posture.

## Platform Capabilities
*Updated per build phase.*

## Getting Started
*Prerequisites and setup instructions added once foundation is complete.*
