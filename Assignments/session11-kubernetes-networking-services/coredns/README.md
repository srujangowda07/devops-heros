# CoreDNS Architecture, Service Discovery & Troubleshooting

## 1. What is CoreDNS?

**CoreDNS** is a fast, flexible, and extensible DNS server written in Go. In Kubernetes, CoreDNS is deployed as a standard `Deployment` (typically running 2 replica pods) in the `kube-system` namespace, exposed through a `ClusterIP` Service named `kube-dns` (port 53 UDP/TCP).

CoreDNS serves as the authoritative central directory service for all Kubernetes workloads, answering queries for internal services, pods, and forwarding external requests to upstream DNS resolvers.

---

## 2. Why Kubernetes Uses CoreDNS

Historically, Kubernetes utilized **Kube-DNS** (composed of `kube-dns`, `dnsmasq-nanny`, and `sidecar`). Starting in Kubernetes version 1.13, **CoreDNS became the default DNS server** for the following architectural reasons:

1. **Single Binary & Low Resource Footprint:** Unlike Kube-DNS which ran 3 containers per pod, CoreDNS runs as a single, lightweight Go process, drastically reducing memory usage and CPU overhead.
2. **Modular Plugin Architecture:** Every DNS feature in CoreDNS is an independent plugin (e.g., `kubernetes`, `forward`, `cache`, `errors`, `reload`). Plugins can be enabled or disabled without recompilation.
3. **High Performance & Concurrency:** Written in Go with non-blocking I/O, CoreDNS handles high request volumes and concurrent client connections with minimal latency.
4. **Cloud Native Computing Foundation (CNCF) Graduated Project:** CoreDNS is a mature, production-proven top-level project within the cloud-native ecosystem.

---

## 3. How Kubernetes Service Discovery Works

Service discovery in Kubernetes coordinates three core components:

```
[ Developer / CI/CD ]
         │
         │ 1. kubectl apply -f service.yaml
         ▼
[ kube-apiserver ] <═══════════════════════════════════════════════╗
         │                                                         ║
         │ Watches & Discovers Services / Endpoints                ║
         ▼                                                         ║
[ CoreDNS Controller (plugin/kubernetes) ]                        ║
         │                                                         ║
         │ 2. Dynamically updates in-memory DNS table (no restart) ║
         ▼                                                         ║
[ Authoritative Cluster DNS Table ]                                ║
         │                                                         ║
         │ 3. Resolves queries from client pods                    ║
         ▼                                                         ║
[ Client Application Pods ] ───────────────────────────────────────╝
```

1. **Declaration:** A developer defines a Service with a selector matching backend Pods.
2. **Endpoint Management:** The Kubernetes `EndpointSlice` controller monitors healthy Pods matching the selector and records their real IPs.
3. **DNS Registration:** The CoreDNS `kubernetes` plugin watches the API server. When a Service or EndpointSlice is created or updated, CoreDNS registers the record in its in-memory database in real time.
4. **Zero Downtime Resolution:** Pods querying the Service name receive the immutable virtual `ClusterIP` or the live pod IPs (for Headless Services) without CoreDNS requiring a reload or restart.

---

## 4. How DNS Queries Are Resolved (Step-by-Step)

```text
[ Client Pod ] ─── 1. curl http://api.github.com ───► [ Container DNS Resolver ]
                                                              │
                                                              │ 2. Reads /etc/resolv.conf
                                                              ▼
                                                    [ Query sent to 10.96.0.10:53 ]
                                                              │
                                                              ▼
                                                     [ CoreDNS Plugin Chain ]
                                                              │
                     ┌────────────────────────────────────────┴────────────────────────────────────────┐
                     │                                                                                 │
                     ▼                                                                                 ▼
     [ Matches cluster.local? ]                                                        [ External Public Domain? ]
                     │                                                                                 │
                     ├─ Yes: Resolves via `kubernetes` plugin                                          └─ Yes: Evaluates `forward . /etc/resolv.conf`
                     │       Returns ClusterIP (e.g. 10.108.106.193)                                           Queries upstream node DNS (8.8.8.8)
                     │                                                                                 │
                     ▼                                                                                 ▼
             [ Client connects to VIP ]                                                        [ Public IP returned ]
```

1. **Inside the Client Pod:** The process checks `/etc/resolv.conf`. The nameserver is set to `10.96.0.10` (the `kube-dns` service IP).
2. **Search Domain Suffixing:** Because `options ndots:5` is default, queries with fewer than 5 dots have the search domains (`<namespace>.svc.cluster.local`, `svc.cluster.local`, `cluster.local`) appended in sequence.
3. **CoreDNS Chain of Plugins:**
   - **Internal Domains (`*.cluster.local`):** Intercepted by the `kubernetes` plugin and resolved against cluster Services/Endpoints.
   - **External Domains (e.g., `api.github.com`):** Forwarded via the `forward` plugin to the node's upstream host nameservers.
4. **Caching Layer:** The `cache` plugin caches query responses for 30 seconds to minimize load on upstream servers and the API server.

---

## 5. CoreDNS Configuration (`Corefile` Breakdown)

CoreDNS configuration is managed declaratively via a Kubernetes ConfigMap in `kube-system`:

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

### Typical `Corefile`:
```text
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    k8s_external example.com
    prometheus :9153
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

### Plugin Descriptions:
* **`errors`:** Logs errors to standard output for debugging.
* **`health`:** Exposes a health check endpoint at `http://localhost:8080/health`.
* **`ready`:** Exposes an HTTP endpoint on port 8181 for readiness probes.
* **`kubernetes cluster.local`:** The core plugin that resolves all queries within the `.cluster.local` zone against the Kubernetes API.
* **`forward . /etc/resolv.conf`:** Forwards queries not matching the cluster zone to the upstream DNS nameservers defined in the node's `/etc/resolv.conf`.
* **`cache 30`:** Implements an internal TTL cache for 30 seconds to reduce query latency.
* **`loop`:** Detects and terminates accidental forwarding loops.
* **`reload`:** Allows automatic reloading of the configuration when the ConfigMap changes without pod restarts.
* **`loadbalance`:** Acts as a round-robin DNS load balancer that randomizes the order of `A` and `AAAA` records in responses.

---

## 6. How to Troubleshoot DNS Issues in Kubernetes

When DNS resolution fails in a cluster, follow this systematic 5-step troubleshooting checklist:

### Step 1: Check CoreDNS Pod Status
Verify that CoreDNS pods are scheduled and healthy:
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```
*Expected: 2/2 pods in `Running` state.*

---

### Step 2: Inspect CoreDNS Logs
Check for lookup errors, crash loops, or forwarding timeouts:
```bash
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

---

### Step 3: Verify the `kube-dns` Service and ClusterIP
Verify that the `kube-dns` service exists and has valid endpoints:
```bash
kubectl get svc kube-dns -n kube-system
kubectl get endpoints kube-dns -n kube-system
```
*If `ENDPOINTS` is `<none>`, CoreDNS pods are unhealthy or selector labels do not match.*

---

### Step 4: Run an Interactive DNS Debug Client
Deploy an ephemeral debugging container with `nslookup` and `dig`:
```bash
kubectl run dns-test-client --image=infoblox/dnstools --rm -it -- restart=Never -- sh

# Inside the debug pod:
# 1. Test cluster-internal lookup
nslookup kubernetes.default

# 2. Test specific service FQDN
nslookup web-service-clusterip.default.svc.cluster.local

# 3. Test external resolution
nslookup google.com

# 4. Check resolver configuration
cat /etc/resolv.conf
```

---

### Step 5: Check `ndots:5` Latency Impact
If external DNS queries are slow, check the dot count. An external address like `api.github.com` has 2 dots (less than 5), causing the resolver to make 3 failing cluster searches before trying public DNS.
* **Remedy:** In production manifests, add a trailing period (e.g. `api.github.com.`) to force an immediate public FQDN query.
