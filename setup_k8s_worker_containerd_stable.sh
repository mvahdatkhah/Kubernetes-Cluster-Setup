#!/bin/bash
# Kubernetes Worker Node Setup 🚀🐧
# Compatible with Ubuntu-based systems 🐧

set -euo pipefail

# --- Configuration Variables 🛠️ ---
K8S_VERSION="1.33"
CONTAINERD_VERSION="2.0.0"
RUNC_VERSION="1.3.0"
CNI_VERSION="1.6.0"
POD_CIDR="10.10.0.0/16"
NERDCTL_VERSION="2.1.2"
APISERVER_ADVERTISE_ADDRESS="192.168.56.109"  # Replace with actual IP

# --- Worker Node Join Parameters (Replace These) ---
MASTER_API_SERVER="${APISERVER_ADVERTISE_ADDRESS}:6443"
TOKEN="<YOUR_KUBEADM_TOKEN>"
DISCOVERY_HASH="<YOUR_DISCOVERY_HASH>"

# --- System Preparation ---
echo "🧹 Disabling swap..."
swapoff -a
sed -i.bak '/ swap / s/^/#/' /etc/fstab

echo "🌐 Setting timezone to Asia/Tehran..."
timedatectl set-timezone Asia/Tehran

echo "🔐 Configuring kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "🛡️ Configuring sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

# --- Apply sysctl params without reboot ---
echo "🛡️ Apply sysctl params..."
sysctl --system

echo "🛡️ Verify that the net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables, and net.ipv4.ip_forward system..."
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward


# --- Install Dependencies ---
echo "📦 Installing dependencies..."
apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

# --- Install Containerd ---
echo "🐳 Installing containerd..."
wget -qO /tmp/containerd.tar.gz "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
tar -C /usr/local -xzf /tmp/containerd.tar.gz
rm /tmp/containerd.tar.gz

echo "🔧 Setting up containerd systemd service..."
wget -qO /usr/lib/systemd/system/containerd.service "https://raw.githubusercontent.com/containerd/containerd/main/containerd.service"
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# --- Install Runc ---
echo "🔧 Installing runc..."
wget -qO /usr/local/sbin/runc "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
ls -l /usr/local/sbin/
rm -rf runc.amd64

# --- Install Containerd ---
echo "🔧 Installing Containerd..."
sudo mkdir -p /etc/containerd/
containerd config default | sudo tee /etc/containerd/config.toml
ls -l /etc/containerd/
sudo systemctl restart containerd

# --- Install CNI Plugins ---
echo "🌐 Installing CNI plugins..."
mkdir -p /opt/cni/bin
wget -qO /tmp/cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz"
tar -C /opt/cni/bin -xzf /tmp/cni-plugins.tgz
rm /tmp/cni-plugins.tgz

# --- Configure Containerd ---
echo "📝 Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# --- Install Nerdctl ---
echo "🐳 Installing nerdctl..."
wget -qO /tmp/nerdctl.tar.gz "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz"
tar -C /usr/local -xzf /tmp/nerdctl.tar.gz
rm /tmp/nerdctl.tar.gz

# --- Install Kubernetes Components ---
echo "☸️ Installing Kubernetes components..."
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# --- Join Worker Node to the Cluster ---
echo "🔑 Joining the Kubernetes cluster..."
kubeadm join "${MASTER_API_SERVER}" \
    --token "${TOKEN}" \
    --discovery-token-ca-cert-hash "${DISCOVERY_HASH}"

echo "🎉 Worker node successfully joined the Kubernetes cluster!"
