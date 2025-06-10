#!/bin/bash
set -e

echo "🧹 Resetting Kubernetes and cleaning up..."

sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo systemctl stop containerd

sudo rm -rf /etc/cni/net.d \
  /var/lib/cni \
  /var/lib/kubelet \
  /etc/kubernetes \
  ~/.kube \
  /var/lib/etcd \
  /etc/containerd \
  /opt/cni/bin

echo "✅ Cleanup done."
