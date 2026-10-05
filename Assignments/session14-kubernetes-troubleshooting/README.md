# Session 14 - Kubernetes Troubleshooting & Debugging

## Student Details

- **Name:** Srujan Gowda KS
- **Roll Number:** 24BCS10339
- **Session:** 14 - Kubernetes Pod Diagnostics, Cluster Events & Failure Modes

---

## Introduction

In this session, I practiced foundational and advanced Kubernetes troubleshooting workflows. In production environments, containerized applications face various failure modes such as broken image tags, startup script errors, node resource exhaustion, and service selector mismatches.

Rather than guessing or restarting containers blindly, Kubernetes provides structured diagnostic tools and telemetry:
- **`kubectl get`**: Provides rapid macro-level cluster visibility.
- **`kubectl describe`**: Inspects granular object metadata, conditions, and the control plane **Events** chronological timeline.
- **`kubectl logs`**: Reads `stdout` and `stderr` application streams, including previous crash outputs (`--previous`).
- **`kubectl exec`**: Enables direct internal container validation, network loopback testing, and interactive debugging.

This report documents the hands-on execution, root cause analyses, and solutions across all practical tasks (Tasks 1–9) and the final Mini-Project Troubleshooting Challenge.

---

<br>

# Task 1: Inspecting Cluster State via `kubectl get`

## Objective

Use `kubectl get` as the first line of observation to answer: *"What is currently happening across the cluster?"*

## Manifest (`01-kubectl-get/sample-workload.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: get-demo
  labels:
    app: get-demo
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

## Commands Executed

```bash
cd 01-kubectl-get

# Deploy sample pod
kubectl apply -f sample-workload.yaml

# Check general pod status
kubectl get pods

# Inspect detailed network and node placement
kubectl get pods -o wide

# Check other cluster components
kubectl get nodes
kubectl get services
kubectl get all

# Stream real-time resource state transitions
kubectl get pods -w
```

## Concepts & Key Learnings

- **Column Header Breakdown**:
  - `NAME`: Unique identifier of the resource.
  - `READY (1/1)`: Ready containers vs. total containers in the Pod.
  - `STATUS`: Pod phase (`Running`, `Pending`, `CrashLoopBackOff`, `ErrImagePull`).
  - `RESTARTS`: Restart counter incremented by kubelet upon container termination.
  - `AGE`: Uptime since creation.
- **Extended Node & IP Visibility (`-o wide`)**: Revealed the internal Pod IP (`10.244.0.20`) and host node (`minikube`).
- **Live Stream Tracking (`-w`)**: Continuously monitors state transitions without repeatedly re-running the command.

## Output & Verification

![Task 1 - Apply & Get Pods](Screenshots/01-01-pod-apply-and-get.png)

![Task 1 - Wide Output](Screenshots/01-02-kubectl-get-wide.png)

![Task 1 - Get All Resources](Screenshots/01-03-kubectl-get-all.png)

![Task 1 - Watch Mode](Screenshots/01-04-kubectl-get-watch.png)

---

<br>

# Task 2: Deep-Dive Diagnostics via `kubectl describe`

## Objective

Use `kubectl describe` to answer: *"Why is a resource in its current state?"* by inspecting container states, conditions, and lifecycle events.

## Manifest (`02-kubectl-describe/demo-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: describe-demo
  labels:
    app: describe-demo
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

## Commands Executed

```bash
cd ../02-kubectl-describe

kubectl apply -f demo-pod.yaml
kubectl get pods
kubectl describe pod describe-demo
```

## Concepts & Key Learnings

- **`get` vs `describe`**: `kubectl get` gives a summary table, whereas `kubectl describe` provides complete configuration, controller references, and runtime conditions.
- **Key Sections Analyzed**:
  - **Containers**: Image tag (`nginx:1.27`), container ID, state (`Running`), and readiness status.
  - **Conditions**: `PodScheduled`, `Initialized`, `ContainersReady`, and `Ready` all reported `True`.
  - **Events**: The chronological log at the bottom recorded `Scheduled`, `Pulling`, `Pulled`, `Created`, and `Started`. This is the single most valuable section when debugging non-running pods.

## Output & Verification

![Task 2 - Describe Apply and Get](Screenshots/02-01-describe-apply-and-get.png)

![Task 2 - Describe Pod Details & Events](Screenshots/02-02-describe-pod-details.png)

---

<br>

# Task 3: Application Telemetry & Stream Diagnostics via `kubectl logs`

## Objective

Use `kubectl logs` to answer: *"What is the application reporting from standard output and standard error?"*

## Manifest (`03-kubectl-logs/pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: logs-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command:
        - sh
        - -c
        - |
          echo "Application started"
          echo "Connecting to database..."
          echo "Database connection successful"
          echo "Application is running"
          while true; do
            echo "Application is healthy"
            sleep 5
          done
```

## Commands Executed

```bash
cd ../03-kubectl-logs

kubectl apply -f pod.yaml
kubectl logs logs-demo
kubectl logs -f logs-demo
kubectl logs logs-demo -c app
```

## Concepts & Key Learnings

- **Container I/O Logging**: Kubernetes standardizes logging by capturing all console writes (`stdout`/`stderr`).
- **Live Stream Tracking (`-f`)**: Follows active logging in real time (e.g. tracking health check loops).
- **Multi-Container Pods (`-c`)**: Isolates logs when a pod contains multiple containers (such as app + sidecar).
- **Post-Mortem Analysis (`--previous`)**: Retrieves logs from previous crashed instances when debugging `CrashLoopBackOff`.

## Output & Verification

![Task 3 - Apply and Get Pod](Screenshots/03-01-logs-apply-and-get.png)

![Task 3 - Application Logs Output](Screenshots/03-02-kubectl-logs-output..png)

![Task 3 - Stream Logs Follow](Screenshots/03-03-kubectl-logs-follow.png)

---

<br>

# Task 4: In-Container Inspection & Verification via `kubectl exec`

## Objective

Directly access running containers using `kubectl exec` to verify files, configurations, and internal network responsiveness.

## Manifest (`04-kubectl-exec/pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exec-demo
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

## Commands Executed

```bash
cd ../04-kubectl-exec

# Apply workload
kubectl apply -f pod.yaml

# Direct non-interactive diagnostic commands
kubectl exec exec-demo -- hostname
kubectl exec exec-demo -- ls //usr/share/nginx/html
kubectl exec exec-demo -- cat //etc/hosts

# Interactive shell debugging
kubectl exec -it exec-demo -- bash

# (Inside container shell)
ls /usr/share/nginx/html
cat /etc/hosts
curl localhost
exit
```

## Concepts & Key Learnings

- **Non-Interactive Execution**: Allows quick checks (e.g., hostname, network hosts) without attaching a full interactive TTY.
- **Git Bash Path Conversion**: On Windows MINGW64, paths like `/usr/...` are auto-converted to host paths; using double slashes (`//usr/...`) or opening an interactive `bash` session bypasses this.
- **Local Application Verification**: Running `curl localhost` directly inside the container proved NGINX was running and listening on port 80 before exposing it to services.

## Output & Verification

![Task 4 - Direct Commands](Screenshots/04-01-exec-direct-commands.png)

![Task 4 - Interactive Shell & Curl](Screenshots/04-02-exec-interactive-curl.png)

---

<br>

# Task 5: Cluster Activity Logging via Kubernetes Events

## Objective

Inspect and filter Kubernetes Events to understand control plane decisions, scheduling steps, and runtime warnings.

## Manifest (`05-events/pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: events-demo
spec:
  containers:
    - name: nginx
      image: nginx:1.27
```

## Commands Executed

```bash
cd ../05-events

kubectl apply -f pod.yaml

# Inspect all events
kubectl get events

# Sort events chronologically
kubectl get events --sort-by=.lastTimestamp

# Inspect events for a specific pod
kubectl describe pod events-demo
```

## Concepts & Key Learnings

- **Event Retention & Ephemerality**: Events are stored in `etcd` and retained for 1 hour by default.
- **Sorting by Timestamp**: `--sort-by=.lastTimestamp` presents events in chronological order, making recent failures stand out immediately.
- **Event Filtering**: In production triage, filtering by `--field-selector type=Warning` eliminates noise and highlights actionable errors.

## Output & Verification

![Task 5 - Get Events](Screenshots/05-01-events-get.png)

![Task 5 - Sort Events by Timestamp](Screenshots/05-02-events-sort-timestamp.png)

![Task 5 - Describe Pod Events](Screenshots/05-03-events-describe-pod.png)

---

<br>

# Task 6: Diagnosing & Resolving `CrashLoopBackOff`

## Objective

Diagnose an application that repeatedly starts, crashes, and triggers Kubernetes back-off restart delays.

### Broken Manifest (`broken-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crash-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo 'Application starting...'; echo 'Something went wrong!'; exit 1"]
```

### Fixed Manifest (`fixed-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crash-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo 'Application starting...'; echo 'Application is healthy'; sleep 3600"]
```

## Commands Executed

```bash
cd ../06-crashloopbackoff

# 1. Deploy broken pod
kubectl apply -f broken-pod.yaml
kubectl get pods

# 2. Investigate failure
kubectl describe pod crash-demo
kubectl logs crash-demo
kubectl logs crash-demo --previous

# 3. Fix pod
kubectl delete pod crash-demo
kubectl apply -f fixed-pod.yaml
kubectl get pods
kubectl logs crash-demo
```

## Concepts & Root Cause Analysis

- **Understanding `CrashLoopBackOff`**: It is a status symptom indicating that a container exited with a non-zero code repeatedly. Kubernetes applies an exponential back-off delay (10s, 20s, 40s... up to 5m) before restarting.
- **Root Cause**: The startup script executed `exit 1`, causing immediate container death.
- **Resolution**: Replaced `exit 1` with a persistent long-running process (`sleep 3600`), stabilizing the pod in `1/1 Running`.

## Output & Verification

![Task 6 - CrashLoop Error Status](Screenshots/06-01-crashloop-error-status.png)

![Task 6 - Logs Investigation](Screenshots/06-02-crashloop-logs-investigate.png)

![Task 6 - Fixed Pod Running](Screenshots/06-03-crashloop-fixed-running.png)

---

<br>

# Task 7: Diagnosing & Resolving `ImagePullBackOff`

## Objective

Identify and fix image pull failures caused by invalid container tags or nonexistent registry artifacts.

### Broken Manifest (`broken-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: image-demo
spec:
  containers:
    - name: app
      image: nginx:this-image-does-not-exist
```

### Fixed Manifest (`fixed-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: image-demo
spec:
  containers:
    - name: app
      image: nginx:1.27
```

## Commands Executed

```bash
cd ../07-imagepullbackoff

# 1. Deploy broken workload
kubectl apply -f broken-pod.yaml
kubectl get pods

# 2. Inspect failure events
kubectl describe pod image-demo

# 3. Apply fix
kubectl delete pod image-demo
kubectl apply -f fixed-pod.yaml
kubectl get pods
```

## Concepts & Root Cause Analysis

- **`ErrImagePull` vs `ImagePullBackOff`**: `ErrImagePull` is the initial pull failure attempt. If retries fail repeatedly, Kubernetes enters `ImagePullBackOff` to prevent overloading the registry with continuous requests.
- **Root Cause**: The image tag `nginx:this-image-does-not-exist` does not exist on Docker Hub (`manifest unknown`).
- **Resolution**: Corrected the image tag to `nginx:1.27`, allowing the image to pull and start immediately.

## Output & Verification

![Task 7 - ImagePull Error Status](Screenshots/07-01-imagepull-error-status.png)

![Task 7 - Describe Events Root Cause](Screenshots/07-02-imagepull-describe-events.png)

![Task 7 - Fixed Image Running](Screenshots/07-03-imagepull-fixed-running.png)

---

<br>

# Task 8: Diagnosing & Resolving `Pending` Pods

## Objective

Identify why a Pod remains unscheduled in `Pending` state and resolve node scheduling constraints.

### Broken Manifest (`broken-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pending-demo
spec:
  nodeSelector:
    kubernetes.io/hostname: node-that-does-not-exist
  containers:
    - name: nginx
      image: nginx:1.27
```

### Fixed Manifest (`fixed-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pending-demo
spec:
  containers:
    - name: nginx
      image: nginx:1.27
```

## Commands Executed

```bash
cd ../08-pending-pods

# 1. Deploy broken workload
kubectl apply -f broken-pod.yaml
kubectl get pods

# 2. Inspect scheduler rejection
kubectl describe pod pending-demo
kubectl get nodes

# 3. Fix pod
kubectl delete pod pending-demo
kubectl apply -f fixed-pod.yaml
kubectl get pods
```

## Concepts & Root Cause Analysis

- **Scheduler Lifecycle**: When a pod is submitted to `etcd`, `kube-scheduler` filters all available nodes. If zero nodes satisfy requirements (nodeSelector, resource limits, taints), the pod stays in `Pending` with `Node: <none>` and `PodScheduled: False`.
- **Root Cause**: The `nodeSelector` requested `node-that-does-not-exist`, but the cluster only contains `minikube`.
- **Resolution**: Removed the invalid selector in `fixed-pod.yaml`, allowing `kube-scheduler` to bind the pod to `minikube`.

## Output & Verification

![Task 8 - Pending Status](Screenshots/08-01-pending-error-status.png)

![Task 8 - Describe FailedScheduling](Screenshots/08-02-pending-describe-events.png)

![Task 8 - Fixed Pod Running](Screenshots/08-03-pending-fixed-running.png)

---

<br>

# Task 9: Service Routing, Selector Mismatch & DNS Troubleshooting

## Objective

Verify Service endpoint routing, test in-cluster DNS resolution via CoreDNS, and troubleshoot broken services caused by label selector mismatches.

## Manifests

- **Deployment (`deployment.yaml`)**: Runs 2 replicas of NGINX labeled `app: web`.
- **Valid Service (`service.yaml`)**: Exposes port 80 with selector `app: web`.
- **Broken Service (`broken-service.yaml`)**: Selector set to `app: does-not-exist`.

## Commands Executed

```bash
cd ../09-service-dns-troubleshooting

# 1. Deploy app and valid service
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl get pods -l app=web
kubectl get endpoints web-service
kubectl describe service web-service

# 2. Launch DNS testing pod
kubectl run dns-test --image=busybox:1.36 -- sleep 3600

# 3. Test DNS & HTTP
kubectl exec dns-test -- nslookup web-service
kubectl exec dns-test -- nslookup web-service.default.svc.cluster.local
kubectl exec dns-test -- wget -qO- http://web-service
kubectl exec dns-test -- cat //etc/resolv.conf
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 4. Simulate selector mismatch
kubectl apply -f broken-service.yaml
kubectl get endpoints broken-service
```

## Concepts & Key Learnings

- **Service Selector to Endpoint Mapping**: A Service does not route to Pods directly; it dynamically builds an `Endpoints` list from Pods matching its `spec.selector`.
- **The Selector Mismatch Gotcha**: If a Service selector has a typo (`app: does-not-exist`), the Service and Pods can both be healthy, but `ENDPOINTS` will be `<none>`, causing all traffic to drop.
- **In-Cluster DNS Structure**: DNS queries resolve using the format `<service-name>.<namespace>.svc.cluster.local`, managed by CoreDNS (`10.96.0.10`).

## Output & Verification

![Task 9 - Service Deploy & Endpoints](Screenshots/09-01-service-deploy-endpoints.png)

![Task 9 - DNS Lookup & HTTP Wget](Screenshots/09-02-dns-nslookup-wget.png)

![Task 9 - Broken Service Endpoints None](Screenshots/09-03-service-broken-endpoints-none.png)

---

<br>

# Mini-Project: Kubernetes Troubleshooting Challenge

## 1. Challenge Overview & Architecture

The Session 14 Mini-Project tests real-world incident response skills by deploying a multi-tier workload, introducing live failure modes, diagnosing them using Kubernetes primitives, and applying surgical fixes:

```text
[ Deployment: troubleshooting-app (2 replicas) ] ──► [ Pods: app=troubleshooting-app ]
                        │                                          ▲
                        ▼                                          │
        [ Service: troubleshooting-service ] ──────────────────────┘
                  (Selector: app=troubleshooting-app)
                                   +
        [ Isolated Broken Pod: project-broken-pod ]
```

---

## 2. Challenge Part 1: Diagnosing & Fixing `project-broken-pod`

### Manifest (`mini-project/broken-pod.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: project-broken-pod
spec:
  containers:
    - name: app
      image: nginx:this-tag-does-not-exist
```

### Investigation Commands Executed
```bash
cd mini-project

# 1. Deploy broken workload
kubectl apply -f broken-pod.yaml

# 2. Observe status failure
kubectl get pod project-broken-pod

# 3. Inspect Events to isolate failure mode
kubectl describe pod project-broken-pod
```

### Diagnostic Findings (Q&A Analysis)
- **Question 1: What is the Pod status?**  
  `ImagePullBackOff` (alternating with `ErrImagePull`).
- **Question 2: What is the actual error?**  
  `Failed to pull image "nginx:this-tag-does-not-exist": rpc error: code = NotFound desc = failed to pull and unpack image ... manifest unknown`.
- **Question 3: Which command helped you find the reason?**  
  `kubectl describe pod project-broken-pod` (under the **Events** timeline at the bottom).
- **Question 4: What is wrong with the image?**  
  The image tag `this-tag-does-not-exist` does not exist on Docker Hub registry.
- **Question 5: How would you fix it?**  
  Update the container image to an authoritative, existing tag such as `nginx:1.27`.

### Resolution & Verification
```bash
# Apply fix by updating image tag to nginx:1.27
sed -i 's/nginx:this-tag-does-not-exist/nginx:1.27/' broken-pod.yaml
kubectl replace --force -f broken-pod.yaml

# Verify pod reaches 1/1 Running state
kubectl get pod project-broken-pod
```

![Mini-Project Broken Pod Describe Events](Screenshots/10-01-miniproject-broken-describe.png)

![Mini-Project Fixed Pod Running](Screenshots/10-02-miniproject-pod-fixed.png)

---

## 3. Challenge Part 2: Service Selector Mismatch Outage

### Incident Simulation & Symptoms
In production, a common outage occurs when a Service selector is changed or typoed, leaving existing pods running but severing all inbound network traffic.

### Commands Executed
```bash
# 1. Deploy baseline deployment and service
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl get svc,endpoints troubleshooting-service

# 2. Simulate selector outage by patching with an incorrect label
kubectl patch svc troubleshooting-service -p '{"spec":{"selector":{"app":"wrong-label"}}}'

# 3. Observe the critical symptom: Endpoints drops to <none>!
kubectl get svc,endpoints troubleshooting-service

# 4. Apply fix: Restore selector to match Pod labels (app: troubleshooting-app)
kubectl patch svc troubleshooting-service -p '{"spec":{"selector":{"app":"troubleshooting-app"}}}'

# 5. Verify endpoints restoration
kubectl get endpoints troubleshooting-service
```

### Root Cause Analysis & Resolution
- **Root Cause:** A Service routes traffic exclusively through the dynamically maintained `Endpoints` object. When `spec.selector` (`app: wrong-label`) failed to match the pod labels (`app: troubleshooting-app`), the endpoint controller removed all backend IPs.
- **Resolution:** Re-aligned the selector to `app: troubleshooting-app`. The controller immediately detected the active pods and repopulated endpoints (`10.244.0.36:80, 10.244.0.37:80`).

![Mini-Project Service Endpoints Outage and Restoration](Screenshots/10-03-miniproject-service-fixed.png)

---

## 4. Troubleshooting Master Reference Matrix

| Failure Mode | Primary Symptom | Diagnostic Tool | Underlying Root Cause | Permanent Resolution |
| :--- | :--- | :--- | :--- | :--- |
| **`CrashLoopBackOff`** | Container starts, terminates with non-zero exit, restart counter increments | `kubectl logs <pod> --previous` & `kubectl describe pod` | Application startup script syntax error, uncaught runtime exception, missing DB dependency | Fix application code, wrap transient scripts in long-running processes (`sleep 3600`) |
| **`ImagePullBackOff`** | Status toggles between `ErrImagePull` and `ImagePullBackOff` | `kubectl describe pod` (Events section) | Typo in image name/tag, private registry authentication missing (`imagePullSecrets`) | Correct image tag to valid repository version, configure Docker registry credentials |
| **`Pending` Pod** | Status stuck in `Pending`, `Node: <none>` | `kubectl describe pod` (`FailedScheduling` events) | Unmatched `nodeSelector`/affinity, node taint without toleration, insufficient CPU/memory | Remove erroneous nodeSelectors, adjust resource requests, add worker nodes |
| **Silent Service Outage** | Service IP reachable but requests drop/timeout | `kubectl get endpoints <svc>` & `kubectl describe svc` | Typo in Service `spec.selector` mismatching Pod `metadata.labels` | Align Service `spec.selector` labels with Pod template labels |
| **DNS Resolution Failure** | In-cluster lookup fails with `NXDOMAIN` | `kubectl exec <pod> -- nslookup <svc>` | Misconfigured search domains, querying incorrect namespace, or CoreDNS pod down | Query complete FQDN `<svc>.<ns>.svc.cluster.local`, verify CoreDNS in `kube-system` |

---

## 5. Conclusion & DevOps Engineering Takeaways

Mastering Kubernetes troubleshooting requires a disciplined, methodical approach rather than trial-and-error:

1. **Follow the Diagnostic Escalation Ladder:**
   $$\mathbf{kubectl\;get} \;\longrightarrow\; \mathbf{kubectl\;describe} \;\longrightarrow\; \mathbf{kubectl\;logs} \;\longrightarrow\; \mathbf{kubectl\;exec}$$
   - Start with macro state visibility (`get`), inspect control plane events and conditions (`describe`), analyze application stdout/stderr (`logs`), and validate internal network state directly from within the container (`exec`).

2. **Understand the Separation of Control Plane and Workload Layers:**
   - A pod failure is often not a bug in the application, but a failure in scheduling (`Pending`), image transport (`ImagePullBackOff`), or storage provisioning (`PersistentVolumeClaim`).
   - Similarly, a networking outage frequently occurs at the routing abstraction layer (`Endpoints: <none>`) rather than inside the web container itself.

3. **Treat Events as the First Source of Truth:**
   - The `Events` timeline in `kubectl describe` records exact error messages from `kube-scheduler`, `kubelet`, and CNI/CSI plugins, instantly pinpointing root causes without guesswork.
