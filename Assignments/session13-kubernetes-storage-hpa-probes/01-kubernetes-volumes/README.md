# Task 1: Kubernetes Storage Architecture & Volume Primitives

## 1. Introduction: Why Do Kubernetes Containers Need Volumes?

By default, container filesystems are **ephemeral**. When a container crashes, is killed, or is rescheduled:
1. All files written inside the container layers are destroyed.
2. The `kubelet` restarts the container from the base image in a clean, blank state.
3. Multiple containers running inside the same Pod cannot share files directly without a shared volume.

A **Kubernetes Volume** solves this by providing persistent or shared directory abstractions that exist across container restarts.

```text
Ephemeral Container FS (Dies on container restart)
                      VS
Kubernetes Volume (Preserved across container restarts, mounted into Pod paths)
```

---

## 2. Ephemeral Storage Primitives

### A. `emptyDir`

#### Concept & Lifecycle
* An `emptyDir` volume is created as an empty directory when a Pod is assigned to a node.
* It lives as long as the Pod runs on that node.
* If a container inside the Pod crashes, the data in `emptyDir` is **safe and preserved**.
* However, if the **Pod is deleted, evicted, or rescheduled**, the `emptyDir` is permanently erased.

#### Primary Use Cases
* Scratch space (e.g., temporary disk-based merge sorts, cache directories).
* Checkpointing long computation.
* Sharing files between a primary container and a sidecar container (e.g., a log-collector sidecar reading logs produced by the web server).

#### Practical Manifest Example (`emptydir-pod.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo-pod
spec:
  containers:
    - name: writer
      image: alpine:latest
      command: ["sh", "-c", "echo 'Hello from Container A' > /cache/data.txt; sleep 3600"]
      volumeMounts:
        - name: shared-cache
          mountPath: /cache
    - name: reader
      image: alpine:latest
      command: ["sh", "-c", "sleep 2; cat /cache/data.txt; sleep 3600"]
      volumeMounts:
        - name: shared-cache
          mountPath: /cache
  volumes:
    - name: shared-cache
      emptyDir: {}
```

---

### B. `hostPath`

#### Concept & Lifecycle
* A `hostPath` volume mounts a specific file or directory from the host worker node's physical filesystem directly into the Pod container.
* Data persists on the physical node even after the Pod is deleted.
* **Limitation & Hazard:** If the Pod is rescheduled onto a different worker node, the new node will not have the previous node's files.

#### Primary Use Cases
* System-level DaemonSets (e.g., Fluentd / Promtail reading node host logs from `/var/log`).
* Node metrics exporters inspecting `/sys` or `/proc`.
* Accessing host Docker / Containerd sockets (`/var/run/containerd.sock`).

#### Practical Manifest Example (`hostpath-pod.yaml`)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-demo-pod
spec:
  containers:
    - name: log-reader
      image: alpine:latest
      command: ["sh", "-c", "ls -l /host-logs; sleep 3600"]
      volumeMounts:
        - name: host-log-volume
          mountPath: /host-logs
          readOnly: true
  volumes:
    - name: host-log-volume
      hostPath:
        path: /var/log
        type: Directory
```

---

## 3. Persistent Storage Primitives (Decoupled Storage)

In enterprise production, developers should not need to know physical storage IPs or cloud disk IDs. Kubernetes decouples storage into two administrative layers:

$$\underbrace{\mathbf{PersistentVolume}\;\text{(Admin)}}_{\text{The Physical Storage Infrastructure}} \;\xleftrightarrow{\text{Bound}}\; \underbrace{\mathbf{PersistentVolumeClaim}\;\text{(Developer)}}_{\text{The Request for Storage}}$$

---

### C. PersistentVolume (PV)

#### Concept
A **PersistentVolume (PV)** is a cluster-wide storage resource provisioned by a cluster administrator or dynamically created by a StorageClass. It represents real physical storage (AWS EBS, GCP Persistent Disk, Azure Managed Disk, NFS, or local SAN).
* It has an independent lifecycle completely separate from any Pod that consumes it.
* It specifies capacity (e.g., `5Gi`), access modes (`ReadWriteOnce`, `ReadOnlyMany`, `ReadWriteMany`), and a reclaim policy (`Retain`, `Delete`).

#### Practical Manifest Example (`pv-static.yaml`)
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: manual-pv-5gi
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
```

---

### D. PersistentVolumeClaim (PVC)

#### Concept
A **PersistentVolumeClaim (PVC)** is a developer's request for storage. Just as a Pod requests specific CPU and Memory, a PVC requests a specific storage size and access mode.
* The Kubernetes control plane matches the PVC to a suitable PV and binds them permanently in a 1-to-1 relationship.
* When a Pod mounts the PVC, Kubernetes attaches the bound PV to the Pod.

#### Practical Manifest Example (`pvc.yaml`)
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: standard
```

#### Mounting PVC inside a Deployment / Pod:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-db-pod
spec:
  containers:
    - name: mysql
      image: mysql:8.0
      volumeMounts:
        - name: db-data
          mountPath: /var/lib/mysql
  volumes:
    - name: db-data
      persistentVolumeClaim:
        claimName: app-storage-pvc
```

---

## 4. StorageClass & Dynamic Provisioning

### E. StorageClass (SC)

#### The Problem with Static Provisioning
Without a StorageClass, a cluster administrator must manually pre-create hundreds of individual PersistentVolumes in advance. If a developer submits a PVC for 3Gi, but only 10Gi PVs exist, storage is either wasted or the claim remains indefinitely pending.

#### The Solution: StorageClass
A **StorageClass** defines a "storage profile" and designates a dynamic volume plugin (provisioner). It tells Kubernetes:
> *"When a developer creates a PVC requesting this StorageClass, call the cloud storage API (e.g. AWS EBS, GCP PD, or Minikube Hostpath) and automatically create the exact volume on-the-fly!"*

#### Practical Manifest Example (`storageclass.yaml`)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

---

### F. Dynamic Provisioning Flow

```
1. Developer applies PVC (requests 5Gi with StorageClass: fast-storage)
                          │
                          ▼
2. Control Plane sees PVC with no matching PV
                          │
                          ▼
3. StorageClass Provisioner invokes Cloud / Driver API
                          │
                          ▼
4. Physical disk created in cloud & PersistentVolume object registered
                          │
                          ▼
5. Kubernetes binds PV <---> PVC automatically (Status: Bound)
                          │
                          ▼
6. Pod mounts PVC and begins read/write operations seamlessly!
```

* **`volumeBindingMode: WaitForFirstConsumer`:** Delays PV creation and binding until the Pod using the claim is scheduled onto a node. This prevents the volume from being bound in an availability zone different from where the Pod gets scheduled!

---

## 5. Storage Primitives Master Comparison Matrix

| Primitive | Scope | Lifecycle | Data Persistence | Primary Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **`emptyDir`** | Pod-level | Pod lifetime only | ❌ Erased when Pod is deleted | In-memory cache, multi-container shared scratch space |
| **`hostPath`** | Node-level | Bound to specific host | ⚠️ Persists on node, but lost if rescheduled to another node | DaemonSet log collectors, Docker socket access |
| **`PersistentVolume` (PV)** | Cluster-wide | Independent of Pods | ✅ Completely persistent across Pod and Node lifecycle | Real physical disk representation managed by admins |
| **`PersistentVolumeClaim` (PVC)** | Namespace | Bound to one PV | ✅ Persists via bound PV | Developer abstraction to consume storage |
| **`StorageClass` (SC)** | Cluster-wide | Configuration template | ✅ Drives automated volume lifecycle | Automated, on-demand dynamic disk creation |
