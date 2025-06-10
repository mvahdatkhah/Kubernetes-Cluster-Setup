#!/bin/bash
# Kubernetes Node Cleanup Script 🧹
# Ensures a clean Kubernetes reset

set -euo pipefail

echo "🚀 Resetting Kubernetes and cleaning up system..."

# Stop Kubernetes services
systemctl stop kubelet containerd

# Perform kubeadm reset
kubeadm reset -f

# Remove Kubernetes-related directories
echo "🗑️ Removing Kubernetes data..."
rm -rf /etc/cni/net.d \
       /var/lib/cni \
       /var/lib/kubelet \
       /etc/kubernetes \
       ~/.kube \
       /var/lib/etcd \
       /etc/containerd \
       /opt/cni/bin

echo "✅ Cleanup complete!"
