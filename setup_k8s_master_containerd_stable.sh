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
➜  reset_k8s_master cat setup_k8s_master_containerd_stable.sh 
#!/bin/bash
# setup_k8s_master_containerd_stable.sh 🚀🎯
# For Ubuntu-based systems 🐧🧊

set -euo pipefail

# --- Configuration 🛠️ ---
echo "🔧 Setting version variables..."
K8S_VERSION="1.33.1"
CONTAINERD_VERSION="2.0.0"
RUNC_VERSION="1.3.0"
CNI_VERSION="1.6.0"
POD_CIDR="10.10.0.0/16"
NERDCTL_VERSION="v2.1.2"
APISERVER_ADVERTISE_ADDRESS="192.168.56.109"

# --- Disable swap ❌💾 ---
echo "🧹 Disabling swap..."
swapoff -a
sed -i.bak '/ swap / s/^/#/' /etc/fstab

# --- Timezone 🌍🕒 ---
echo "🌐 Setting timezone to Asia/Tehran..."
timedatectl set-timezone Asia/Tehran

# --- Kernel Modules and Sysctl 🧬🛡️ ---
echo "🔐 Configuring kernel modules and sysctl..."
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

# --- Install dependencies 📦🔐 ---
echo "📦 Installing dependencies..."
apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https

# --- Install containerd 🐳 ---
echo "📥 Downloading and installing containerd..."
cd /tmp
wget https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
mkdir -p /usr/local/lib/systemd/system

# Extract containerd 📂
echo "📂 Extracting containerd archive..."
sudo tar Czxvf /usr/local containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Set up systemd service 🧩
echo "🧩 Setting up containerd systemd service..."
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mv containerd.service /usr/lib/systemd/system/
systemctl daemon-reexec
systemctl enable --now containerd

# Install nerdctll
echo "🐳 Installing nerdctl (containerd CLI) ..."
wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-amd64.tar.gz -O /tmp/nerdctl.tar.gz
tar -C /usr/local -xzf /tmp/nerdctl.tar.gz
rm /tmp/nerdctl.tar.gz

# Install runc 🛠️
echo "🔧 Installing runc..."
wget https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

# Install CNI plugins 🔌🌐
echo "🌐 Installing CNI plugins..."
mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v${CNI_VERSION}.tgz

# Containerd config 🧾🔧
echo "📝 Configuring containerd to use SystemdCgroup..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd

# --- Kubernetes install ☸️🚀 ---
echo "☸️ Installing Kubernetes components..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

echo "📥 Installing kubelet, kubeadm, kubectl..."
apt-get update
apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}
apt-mark hold kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}

# --- Init Kubernetes master 🧠👑 ---
echo "🧠 Initializing Kubernetes master node..."
kubeadm init --control-plane-endpoint=${APISERVER_ADVERTISE_ADDRESS}:6443 --pod-network-cidr=${POD_CIDR} --apiserver-advertise-address=${APISERVER_ADVERTISE_ADDRESS}  --kubernetes-version=${K8S_VERSION}  --upload-certs

echo "🔐 Setting up kubeconfig for kubectl access..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo "🔎 Checking cluster nodes..."
kubectl get nodes 🌟
