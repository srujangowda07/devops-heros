# Kubernetes FQDN (Fully Qualified Domain Name) Architecture

## 1. What is an FQDN?

A **Fully Qualified Domain Name (FQDN)** is the complete, unambiguous domain name that specifies an exact location of a host or service within the Domain Name System (DNS) hierarchy. It leaves no room for ambiguity anywhere within the network.

### The Real-World Analogy
* **Short Name:** If you are at home with your family, you can say *"Hey Alex, pass the salt"*. Everyone in the room knows exactly who Alex is.
* **FQDN:** If you send a postal letter across the world, writing just *"Alex"* on the envelope will result in a delivery failure. You must specify the complete hierarchical address:
  `Alex Smith, Apartment 4B, 120 Main Street, New York, NY 10001, USA`.

In Kubernetes:
* **Inside the same namespace:** Pods can communicate using short service names (e.g., `http://backend:8080`).
* **Across different namespaces or clusters:** Pods must use the fully qualified domain name (e.g., `http://backend.production.svc.cluster.local:8080`).

---

## 2. Kubernetes Service DNS Architecture

Kubernetes deploys an internal DNS service (defaulting to **CoreDNS**) in the `kube-system` namespace. CoreDNS continuously watches the Kubernetes API server for the creation, update, and deletion of Services and Pods.

When a Service is created, CoreDNS automatically generates an authoritative DNS record mapping the service name to its static virtual IP (`ClusterIP`). When backend pods change, restart, or scale, the `ClusterIP` remains static, preventing broken connections.

```
+-------------------------------------------------------------------------------+
|                             Kubernetes Cluster                                |
|                                                                               |
|   +-----------------------+              +--------------------------------+   |
|   |   Client Pod (curl)   |              |         CoreDNS Server         |   |
|   |  (/etc/resolv.conf)   |              |       (10.96.0.10:53)          |   |
|   +-----------+-----------+              +---------------+----------------+   |
|               |                                          ^                    |
|               | 1. DNS Query: "web-service"              |                    |
|               +------------------------------------------+                    |
|               |                                                               |
|               | 2. DNS Answer: ClusterIP (10.108.106.193)                     |
|               |<-----------------------------------------+                    |
|               v                                                               |
|   +-----------+-----------------------------------------------------------+   |
|   | HTTP Request to 10.108.106.193:8080                                   |   |
|   | (Intercepted by kube-proxy iptables/IPVS to healthy backend pod)       |   |
|   +-----------------------------------------------------------------------+   |
+-------------------------------------------------------------------------------+
```

---

## 3. Kubernetes DNS Naming Convention

Every standard Kubernetes Service receives an official FQDN formatted strictly according to RFC 1123:

$$\underbrace{\mathbf{service\text{-}name}}_{\text{Service Name}} \;\mathbf{.}\; \underbrace{\mathbf{namespace}}_{\text{Namespace}} \;\mathbf{.}\; \underbrace{\mathbf{svc}}_{\text{Resource Type}} \;\mathbf{.}\; \underbrace{\mathbf{cluster.local}}_{\text{Cluster Domain}}$$

### Segment Breakdown:

| Segment | Meaning | Example | Purpose |
| :--- | :--- | :--- | :--- |
| **`service-name`** | The name defined in `metadata.name` | `web-service-clusterip` | Identifies the specific Service resource. |
| **`namespace`** | The namespace where the Service is deployed | `default` / `production` | Provides logical boundary and multi-tenancy. |
| **`svc`** | The Kubernetes resource type | `svc` | Distinguishes Services from Pods (`pod`). |
| **`cluster.local`** | The cluster root domain | `cluster.local` | The top-level cluster domain configured during cluster initialization. |

---

## 4. Namespace-Based DNS Resolution

When resolving service names, CoreDNS leverages the `/etc/resolv.conf` configuration injected into every Pod container.

### The Search List Autocomplete
Inside every container, Kubernetes configures `/etc/resolv.conf` as:
```text
nameserver 10.96.0.10
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

When an application queries `http://web-service:8080`, the Linux DNS resolver appends the `search` domains in order until a match is found:
1. `web-service` + `.default.svc.cluster.local` $\rightarrow$ **MATCH FOUND (Resolved immediately!)**
2. `web-service` + `.svc.cluster.local`
3. `web-service` + `.cluster.local`

### Cross-Namespace Communication
* **Same Namespace (`default` to `default`):**
  ```bash
  curl http://web-service:8080
  ```
* **Different Namespace (`dev` calling `production`):**
  ```bash
  # Short form (Service + Namespace)
  curl http://web-service.production:8080

  # Full FQDN form (Unambiguous & recommended in configs)
  curl http://web-service.production.svc.cluster.local:8080
  ```

---

## 5. Pod-to-Service Communication Flow

1. **Client Execution:** Pod application initiates an outbound TCP/HTTP request to `http://web-service:8080`.
2. **Resolver Inspection:** The container resolver reads `/etc/resolv.conf` and forwards UDP port 53 query to the CoreDNS IP (`10.96.0.10`).
3. **CoreDNS Lookup:** CoreDNS inspects its in-memory Kubernetes service registry and returns the virtual ClusterIP (e.g. `10.108.106.193`).
4. **Packet Dispatch:** The client pod constructs an IP packet with destination `10.108.106.193:8080`.
5. **Kernel Interception:** The packet traverses the node's network stack where `kube-proxy` rules (`iptables` or `IPVS`) perform Destination NAT (DNAT).
6. **Backend Delivery:** The virtual ClusterIP is rewritten to the real IP of an active, healthy Pod endpoint (e.g. `10.244.0.4:80`), delivering the request to the container.

---

## 6. Examples of Kubernetes FQDNs

### 1. Standard ClusterIP Service
* **Service:** `auth-api` in namespace `security`
* **FQDN:** `auth-api.security.svc.cluster.local`
* **Resolution:** Resolves to a single virtual `ClusterIP`.

### 2. Headless Service (`clusterIP: None`)
* **Service:** `database-headless` in namespace `db`
* **FQDN:** `database-headless.db.svc.cluster.local`
* **Resolution:** Resolves to multiple `A` records containing the direct IP addresses of all backing pods.

### 3. StatefulSet Individual Pod FQDN
* **Pod Ordinal:** Pod 0 in StatefulSet `mysql` backed by headless service `mysql-svc` in namespace `prod`
* **FQDN:** `mysql-0.mysql-svc.prod.svc.cluster.local`
* **Resolution:** Resolves directly and deterministically to `mysql-0`'s unique pod IP.

### 4. Direct Pod IP DNS Record
* **Pod IP:** `10.244.1.25` in namespace `default`
* **FQDN:** `10-244-1-25.default.pod.cluster.local`
* **Resolution:** Resolves to `10.244.1.25` (dashed IP format).
