# 04. AWS VPC — Virtual Private Cloud (Networking)

## 1. What is VPC?
**Amazon Virtual Private Cloud (Amazon VPC)** is a logically isolated virtual network dedicated to your AWS account. It gives you complete control over your virtual networking environment, including selection of your own IP address range, creation of subnets, and configuration of route tables and network gateways.

VPC closely resembles a traditional on-premises data center network, but with the scalability and elasticity of AWS infrastructure.

---

## 2. Core VPC Networking Components

### 2.1 CIDR (Classless Inter-Domain Routing)
- When creating a VPC, you assign an IPv4 CIDR block (e.g., `10.0.0.0/16`).
- **CIDR Block Size**: Between `/16` (65,536 IP addresses) and `/28` (16 IP addresses).
- AWS recommends using private IPv4 ranges defined by RFC 1918:
  - `10.0.0.0` - `10.255.255.255` (`10.0.0.0/8`)
  - `172.16.0.0` - `172.31.255.255` (`172.16.0.0/12`)
  - `192.168.0.0` - `192.168.255.255` (`192.168.0.0/16`)

### 2.2 Subnets
- A **Subnet** is a segment of a VPC's IP address range allocated to a specific **Availability Zone (AZ)**.
- Each subnet must reside entirely within one Availability Zone and cannot span multiple AZs.
- **Reserved IP Addresses**: AWS reserves **5 IP addresses** in every subnet:
  - `.0`: Network address.
  - `.1`: Reserved by AWS for VPC router.
  - `.2`: Reserved by AWS for DNS mapping (AmazonProvidedDNS).
  - `.3`: Reserved by AWS for future use.
  - `.255`: Network broadcast address (AWS does not support broadcast, but address is reserved).
- *Example:* In a `/24` subnet (256 addresses total), **251 IP addresses** are usable.

### 2.3 Route Tables
- A **Route Table** contains a set of rules (called routes) that determine where network traffic from your subnet or gateway is directed.
- Every VPC has a **Main Route Table** by default.
- Custom route tables can be associated explicitly with specific subnets.
- Each route has a:
  - **Destination**: The CIDR block where traffic is destined (e.g., `0.0.0.0/0` for the Internet).
  - **Target**: The gateway, network interface, or connection through which to send traffic (e.g., `igw-xxxxxx` or `nat-xxxxxx`).

### 2.4 Internet Gateway (IGW)
- An **Internet Gateway** is a horizontally scaled, redundant, highly available VPC component that allows communication between instances in your VPC and the internet.
- **Roles**:
  - Provides a target in your VPC route tables for internet-routable traffic (`0.0.0.0/0 -> igw-id`).
  - Performs Network Address Translation (1:1 NAT) for instances with public IPv4 addresses.
- Exactly one Internet Gateway can be attached per VPC.

### 2.5 NAT Gateway (Network Address Translation)
- A **NAT Gateway** enables instances in a **private subnet** to connect to the internet or other AWS services (e.g., downloading OS patches, installing npm packages), but **prevents the internet from initiating inbound connections** with those private instances.
- **Characteristics**:
  - Must be created inside a **public subnet**.
  - Requires an allocated **Elastic IP (EIP)** address.
  - Managed by AWS (scales up to 45 Gbps automatically with built-in high availability per AZ).

---

## 3. Public Subnet vs. Private Subnet

```text
                  Internet (0.0.0.0/0)
                           │
                           ▼
                  Internet Gateway (IGW)
                           │
       ┌───────────────────┴───────────────────┐
       │                                       │
       ▼                                       ▼
┌───────────────────────────────┐     ┌───────────────────────────────┐
│         Public Subnet         │     │        Private Subnet         │
│  (Route: 0.0.0.0/0 -> IGW)    │     │  (Route: 0.0.0.0/0 -> NAT-GW) │
│                               │     │                               │
│  - Web Servers / Reverse Proxy│     │  - Backend App Servers        │
│  - Application Load Balancers │     │  - Databases (RDS, Aurora)    │
│  - NAT Gateway (with EIP)     │     │  - Internal Microservices     │
└───────────────┬───────────────┘     └───────────────────────────────┘
                │                                     ▲
                └──────── Outbound NAT Traffic ───────┘
```

| Criteria | Public Subnet | Private Subnet |
|---|---|---|
| **Direct Internet Access** | Yes (both Inbound & Outbound) | Outbound only (via NAT Gateway), NO direct inbound |
| **Route to Internet** | Route table points `0.0.0.0/0` to **IGW** | Route table points `0.0.0.0/0` to **NAT Gateway** |
| **Public IP on Instances** | Yes (Auto-assign public IP enabled) | No (Instances only have private IPs) |
| **Typical Resources** | Bastion hosts, ALBs, NAT Gateways | Application servers, Database instances, Caches |

---

## 4. Security Groups vs. Network ACLs (NACLs)

AWS implements a **defense-in-depth** strategy with two layers of firewalls:

| Feature | Security Group (SG) | Network ACL (NACL) |
|---|---|---|
| **Level** | **Instance / ENI Level** | **Subnet Level** |
| **State** | **Stateful**: Return traffic is automatically allowed | **Stateless**: Inbound and outbound must be explicitly allowed |
| **Rules** | Supports **Allow** rules only | Supports both **Allow** and **Deny** rules |
| **Evaluation** | Evaluates **all rules** before deciding to allow | Evaluates rules in numbered order (**lowest number first**) |
| **Default** | Default SG allows all outbound, blocks all inbound | Default NACL allows all inbound and outbound traffic |

---

## 5. Summary Architecture Best Practice
A production VPC follows the standard multi-tier design:
1. Two or more Availability Zones for high availability.
2. Public Subnets across AZs hosting Application Load Balancers and NAT Gateways.
3. Private Application Subnets hosting backend containers/EC2 instances.
4. Private Isolated Database Subnets hosting RDS instances with no direct internet route.
