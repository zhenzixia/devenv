#!/bin/bash

set -e

echo "=== Kubernetes 1.33.4 Environment Setup Script ==="
echo "This script will set up your VM for Kubernetes 1.33.4 with kubeadm"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_VERSION="1.33.4"
GO_VERSION="1.22.5"

check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root"
        echo "Run as a regular user with sudo privileges"
        exit 1
    fi
}

check_system() {
    echo "🔍 Checking system requirements..."
    
    # Check OS
    if ! command -v lsb_release &> /dev/null; then
        echo "❌ This script requires Ubuntu/Debian. Please install lsb-release package."
        exit 1
    fi
    
    DISTRIB=$(lsb_release -si)
    if [[ "$DISTRIB" != "Ubuntu" && "$DISTRIB" != "Debian" ]]; then
        echo "❌ This script is designed for Ubuntu/Debian systems"
        exit 1
    fi
    
    # Check memory
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    
    if [[ $MEMORY_GB -lt 2 ]]; then
        echo "❌ Insufficient memory. Required: 2GB, Available: ${MEMORY_GB}GB"
        exit 1
    fi
    
    # Check CPU
    CPU_COUNT=$(nproc)
    if [[ $CPU_COUNT -lt 2 ]]; then
        echo "⚠️  Warning: Less than 2 CPUs detected. Control plane requires at least 2 CPUs."
    fi
    
    echo "✅ System requirements check passed"
    echo "   - OS: $DISTRIB"
    echo "   - Memory: ${MEMORY_GB}GB"
    echo "   - CPUs: ${CPU_COUNT}"
}

update_system() {
    echo "🔄 Updating system packages..."
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        gnupg2 \
        lsb-release \
        wget \
        git \
        build-essential
}

disable_swap() {
    echo "🚫 Disabling swap..."
    sudo swapoff -a
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    echo "✅ Swap disabled"
}

configure_networking() {
    echo "🌐 Configuring networking..."
    
    # Load required kernel modules
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
    
    sudo modprobe overlay
    sudo modprobe br_netfilter
    
    # Set sysctl params required by setup
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
    
    sudo sysctl --system
    echo "✅ Network configuration completed"
}

install_go() {
    echo "🐹 Installing Go ${GO_VERSION}..."
    
    if command -v go &> /dev/null; then
        CURRENT_GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
        echo "Current Go version: $CURRENT_GO_VERSION"
        if [[ "$CURRENT_GO_VERSION" == "$GO_VERSION" ]]; then
            echo "✅ Go ${GO_VERSION} is already installed"
            return
        fi
    fi
    
    cd /tmp
    wget -q "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    
    if [[ -d /usr/local/go ]]; then
        sudo rm -rf /usr/local/go
    fi
    
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # Add Go to PATH
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    fi
    
    export PATH=$PATH:/usr/local/go/bin
    
    echo "✅ Go ${GO_VERSION} installed successfully"
    go version
}

install_containerd() {
    echo "📦 Installing containerd..."
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y containerd.io
    
    # Configure containerd
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    
    # Enable SystemdCgroup
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    
    # Start and enable containerd
    sudo systemctl restart containerd
    sudo systemctl enable containerd
    
    echo "✅ containerd installed and configured"
}

install_kubernetes() {
    echo "☸️  Installing Kubernetes components (version ${K8S_VERSION})..."
    
    # Add Kubernetes GPG key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add Kubernetes repository
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    sudo apt-get update
    
    # Install specific version of kubeadm, kubelet, and kubectl
    sudo apt-get install -y kubelet=${K8S_VERSION}-1.1 kubeadm=${K8S_VERSION}-1.1 kubectl=${K8S_VERSION}-1.1
    
    # Hold packages to prevent automatic updates
    sudo apt-mark hold kubelet kubeadm kubectl
    
    # Configure kubelet to use systemd cgroup driver
    echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd"' | sudo tee /etc/default/kubelet
    
    sudo systemctl enable kubelet
    
    echo "✅ Kubernetes components installed"
    kubeadm version
    kubelet --version
    kubectl version --client
}

main() {
    echo "Starting Kubernetes 1.33.4 environment setup..."
    
    check_root
    check_system
    update_system
    disable_swap
    configure_networking
    install_go
    install_containerd
    install_kubernetes
    
    echo
    echo "🎉 Kubernetes 1.33.4 environment setup completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Run 'source ~/.bashrc' to reload your shell environment"
    echo "2. Run './init-k8s-cluster.sh' to initialize the Kubernetes cluster"
    echo "3. For worker nodes, use the join command provided after cluster init"
    echo
    echo "Installed versions:"
    /usr/local/go/bin/go version
    kubeadm version --output=short
    echo
}

main "$@"