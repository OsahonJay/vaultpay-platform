# ADR-001: Network Design

## Status
Accepted

## Date
2026-06-28

## Context
VaultPay Platform handles cardholder data including PANs and authentication values. 
PCI-DSS Requirement 1 mandates network security controls that restrict inbound and outbound traffic to only what is necessary for the cardholder data environment. 
Without network isolation a threat actor can reach payment data directly if worker nodes are on the public internet. 
This network design establishes network segmentation as the foundational control for meeting that requirement.

## Decision:
VaultPay Platform deploys a VPC with public and private subnets across three Availability Zones, with one NAT Gateway per AZ to ensure private subnet outbound connectivity 
survives an AZ failure. Three Availability Zones are used to eliminate single points of failure and meet PCI-DSS availability requirements for cardholder data environments. 
Public subnets expose only load balancers to the internet — EKS worker nodes and all payment processing components run exclusively in private subnets, unreachable from the public internet."


## Alternatives Considered

### Option A: Single public subnet, no private subnets
- Cost: lowest
- Security: Public unauthorized access
- Rejected because: attackers can access worker nodes directly and steal cardholder data

    
### Option B: Private subnets with single NAT Gateway
- Cost: lower than chosen approach
- Security: acceptable network isolation but single NAT Gateway creates an availability single point of failure
- Rejected because: if the single NAT Gateway's AZ goes down, all private subnets lose outbound connectivity

  
### Option C: VPC with PrivateLink only, no NAT Gateway
- Cost: Higher
- Security: Private Communication between AWS services
- Rejected because: PrivateLink only covers AWS services, external dependencies like GitHub and third-party APIs cannot be reached.

## Consequences
### Positive
EKS worker nodes are unreachable from the internet, and an AZ failure doesn't take down the entire platform.

### Negative
3 NAT Gateway cost a lot of money, The platform infrastructure may be expensive for smaller startup to use

## Security Rationale
VPC Flow Logs capture network traffic metadata — which in a fintech environment allows us to detect unusual connection and provides forensic evidence in the event of a breach

## Compliance Relevance
Network segmentation with private subnets directly satisfies PCI-DSS 
Requirement 1.3, which mandates restricting inbound and outbound traffic 
to only that which is necessary for the cardholder data environment.
# test trigger
