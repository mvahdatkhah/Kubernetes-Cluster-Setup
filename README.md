# Kubernetes Cluster Setup 🚀

This repository contains Bash scripts to deploy a Kubernetes cluster with **3 master nodes** and **3 worker nodes**, using **containerd** as the container runtime.

## 📂 Project Overview

| Script | Description |
|--------|------------|
| `refresh_node.sh` | Resets a node and cleans up Kubernetes data. |
| `setup_k8s_master_containerd_stable.sh` | Configures a master node with Kubernetes and containerd. |
| `setup_k8s_worker_containerd_stable.sh` | Sets up a worker node and joins it to the cluster. |
| `join_k8s_master_node.sh` | Adds a new master node to the Kubernetes cluster. |

## 🛠️ Prerequisites

- **Ubuntu-based system** (recommended)
- Root or sudo access
- Firewall and networking properly configured

## ⚡ Setup Instructions

### 1️⃣ Reset a Node (Optional)
If needed, reset an existing Kubernetes node:

```sh
bash refresh_node.sh
```

## 2️⃣ Set Up Kubernetes Master
Run the following command on the first master node:


```sh
bash setup_k8s_master_containerd_stable.sh
```
Once initialized, copy the kubeadm join command, token, discovery hash, and certificate key.

## 3️⃣ Add More Master Nodes
On additional master nodes, update the TOKEN, DISCOVERY_HASH, and CERT_KEY in join_k8s_master_node.sh with values from the first master setup, then run:

```sh
bash join_k8s_master_node.sh
```

## 4️⃣ Set Up Kubernetes Workers
On each worker node, update the KUBEADM_JOIN_COMMAND in setup_k8s_worker_containerd_stable.sh with the output from the master setup, then run:

```sh
bash setup_k8s_worker_containerd_stable.sh
```

## 🎯 Verify Cluster
After setting up all nodes, check the cluster:

```sh
kubectl get nodes
```

## 📜 Notes

- The first master node is initialized with kubeadm init.
- Additional master nodes join using kubeadm join --control-plane.
- Worker nodes join using kubeadm join.
- Containerd is used as the container runtime.
- **Swap** is disabled as required by Kubernetes.
- System dependencies (CNI plugins, runc, nerdctl) are installed.

