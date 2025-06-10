#!/bin/bash
# setup_k8s_worker_containerd_stable.sh 🚀🐧
# For Ubuntu-based systems 🐧

set -euo pipefail

# --- Configuration 🛠️ ---
echo "🔧 Setting version variables..."
K8S_VERSION="1.33.1"
CONTAINERD_VERSION="2.0.0"
RUNC_VERSION="1.3.0"
CNI_VERSION="1.6.0"
POD_CIDR="10.10.0.0/16"
APISERVER_ADVERTISE_ADDRESS="192.168.56.109"  # ⛳ Replace with actual IP

# --- Provide your kubeadm join command below! ⬇️⬇️⬇️
KUBEADM_JOIN_COMMAND="<PASTE_YOUR_FULL_KUBEADM_JOIN_COMMAND_HERE>"

echo "🕒 Setting timezone to Asia/Tehran 🌍"
timedatectl set-timezone Asia/Tehran

echo "❌ Disabling swap to satisfy Kubernetes requirements 💾"
swapoff -a
sed -i.bak '/ swap / s/^/#/' /etc/fstab

echo "🧬 Loading kernel modules and setting sysctl parameters..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

echo "📦 Installing dependencies..."
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

echo "📥 Downloading and installing containerd v${CONTAINERD_VERSION}..."
cd /tmp
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
sudo tar Czxvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

echo "🧩 Setting up containerd systemd service..."
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mv containerd.service /usr/lib/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl enable --now containerd

echo "🛠 Installing runc v${RUNC_VERSION}..."
wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

echo "🌐 Installing CNI plugins v${CNI_VERSION}..."
sudo mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v${CNI_VERSION}.tgz

echo "🧾 Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# ** Install nerdctl **
# https://github.com/containerd/nerdctl
# https://github.com/containerd/nerdctl/blob/main/docs/command-reference.md
echo "🐳 Installing nerdctl (containerd CLI) ..."
NERDCTL_VERSION="1.5.0"  # adjust if needed
wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz -O /tmp/nerdctl.tar.gz
sudo tar -C /usr/local/bin -xzf /tmp/nerdctl.tar.gz nerdctl
rm /tmp/nerdctl.tar.gz

echo "📥 Installing Kubernetes tools kubelet, kubeadm, kubectl v${K8S_VERSION}..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "📥 Installing kubelet, kubeadm, kubectl..."
apt-get update
apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}
apt-mark hold kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}

echo "🔑 Joining the Kubernetes cluster..."
sudo $KUBEADM_JOIN_COMMAND

echo "🎉 Worker node successfully joined the Kubernetes cluster!"
