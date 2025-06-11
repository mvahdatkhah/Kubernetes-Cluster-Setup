#!/bin/bash
# ☸️ Kubernetes Master Node Setup 🚀
# Compatible with Ubuntu-based systems 🐧

set -euo pipefail

# 🎯 Configuration Variables
KUBEADM_VERSION=$(kubeadm version -o short)
K8S_VERSION="1.33"
CALICO_VERSION="v3.26.4"
CONTAINERD_VERSION="2.0.0"
RUNC_VERSION="1.3.0"
CNI_VERSION="1.6.0"
POD_CIDR="10.10.0.0/16"
NERDCTL_VERSION="2.1.2"
APISERVER_ADVERTISE_ADDRESS="192.168.56.109"  # ⛳ Replace with actual IP

# 🔧 System Preparation
echo "🧹 Disabling swap..."
swapoff -a
sed -i.bak '/ swap / s/^/#/' /etc/fstab

echo "🌍 Setting timezone to Asia/Tehran..."
timedatectl set-timezone Asia/Tehran

echo "🔐 Configuring kernel modules..."
tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "🛡️ Configuring sysctl parameters..."
tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

echo "📡 Applying sysctl params..."
sysctl --system
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# 📦 Installing Dependencies
echo "📦 Installing required system packages..."
apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https bash-completion

# 🐳 Install Containerd
echo "🐳 Installing containerd..."
wget -qO /tmp/containerd.tar.gz "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
tar -C /usr/local -xzf /tmp/containerd.tar.gz
rm /tmp/containerd.tar.gz

echo "🔧 Setting up containerd systemd service..."
wget -qO /usr/lib/systemd/system/containerd.service "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# 🛠️ Install Runc
echo "🔧 Installing runc..."
wget -qO /usr/local/sbin/runc "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
ls -l /usr/local/sbin/
rm -rf runc.amd64

# 🛠️ Configure Containerd
echo "📝 Configuring containerd..."
mkdir -p /etc/containerd/
containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# 🌐 Install CNI Plugins
echo "🌐 Installing CNI plugins..."
mkdir -p /opt/cni/bin
wget -qO /tmp/cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz"
tar -C /opt/cni/bin -xzf /tmp/cni-plugins.tgz
rm /tmp/cni-plugins.tgz

# 🐳 Install Nerdctl
echo "🐳 Installing nerdctl..."
wget -qO /tmp/nerdctl.tar.gz "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz"
tar -C /usr/local -xzf /tmp/nerdctl.tar.gz
rm /tmp/nerdctl.tar.gz

# ☸️ Install Kubernetes Components
echo "☸️ Installing Kubernetes tools..."
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 🧠 Initialize Kubernetes Master
echo "🧠 Initializing Kubernetes master node..."
kubeadm init \
    --control-plane-endpoint="${APISERVER_ADVERTISE_ADDRESS}:6443" \
    --pod-network-cidr="${POD_CIDR}" \
    --apiserver-advertise-address="${APISERVER_ADVERTISE_ADDRESS}" \
    --kubernetes-version="${KUBEADM_VERSION}" \
    --upload-certs

# 🔐 Configure Kubectl
echo "🔐 Setting up kubectl access..."
mkdir -p "$HOME/.kube"
cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
chown "$(id -u):$(id -g)" "$HOME/.kube/config"

# 🚀 Install Calico CNI
echo "🚀 Deploying Calico CNI (Version: ${CALICO_VERSION})..."
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

echo "🔎 Checking Calico installation..."
kubectl get ns
kubectl get pods -n tigera-operator

echo "📥 Downloading custom Calico resources..."
wget -qO custom-resources.yaml "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

echo "🔧 Editing Calico configuration..."
cat <<EOF > custom-resources.yaml
# This section includes base Calico installation configuration.
# For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  # Configures Calico networking.
  calicoNetwork:
    # Note: The ipPools section cannot be modified post-install.
    ipPools:
    - blockSize: 26
      cidr: 10.10.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()

---

# This section configures the Calico API server.
# For more information, see: https://projectcalico.docs.tigera.io/master/reference/installation/api#operator.tigera.io/v1.APIServer
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
EOF

echo "🔧 Applying Calico configuration..."
kubectl create -f custom-resources.yaml

# ⚡ Enable kubectl Autocomplete
echo "⚡ Setting up kubectl autocomplete..."
exec bash
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
source ~/.bashrc

# ✅ Verify Kubernetes & Calico Deployment
echo "📡 Checking available namespaces..."
kubectl get ns

echo "📡 Checking Tigera Operator pods..."
kubectl get pods -n tigera-operator -o wide

echo "📡 Watching Calico pods as they initialize..."
watch kubectl get pod -n calico-system

echo "📡 Checking kube-system namespace pods..."
kubectl get po -n kube-system -o wide

echo "📡 Displaying detailed pod information from kube-system..."
kubectl get pod -n kube-system -o wide

echo "📡 Checking Kubernetes cluster nodes..."
kubectl get nodes

echo "📡 Listing all pods across namespaces..."
kubectl get pod -o wide

echo "📡 Displaying detailed pod information from kube-system..."
kubectl get pod -n kube-system -o wide

echo "✅ Kubernetes Master Node setup completed successfully! 🎉"
