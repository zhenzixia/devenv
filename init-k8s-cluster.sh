#!/bin/bash

set -e

echo "=== Kubernetes 1.33.4 Cluster Initialization Script ==="
echo "This script will initialize a Kubernetes cluster using kubeadm"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_VERSION="1.33.4"
POD_CIDR="10.244.0.0/16"
SERVICE_CIDR="10.96.0.0/12"

check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root"
        echo "Run as a regular user with sudo privileges"
        exit 1
    fi
    
    # Check if kubeadm is installed
    if ! command -v kubeadm &> /dev/null; then
        echo "❌ kubeadm not found. Please run setup-k8s-env.sh first"
        exit 1
    fi
    
    # Check if kubelet is running
    if ! systemctl is-active --quiet kubelet; then
        echo "🔄 Starting kubelet service..."
        sudo systemctl start kubelet
    fi
    
    # Check if containerd is running
    if ! systemctl is-active --quiet containerd; then
        echo "❌ containerd is not running. Please check containerd installation"
        exit 1
    fi
    
    echo "✅ Prerequisites check passed"
}

pull_images() {
    echo "📥 Pre-pulling Kubernetes images..."
    sudo kubeadm config images pull --kubernetes-version=${K8S_VERSION}
    echo "✅ Images pulled successfully"
}

init_cluster() {
    echo "🚀 Initializing Kubernetes cluster..."
    
    # Get the IP address of the primary network interface
    LOCAL_IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    echo "Using IP address: $LOCAL_IP"
    
    # Initialize the cluster
    sudo kubeadm init \
        --kubernetes-version=${K8S_VERSION} \
        --pod-network-cidr=${POD_CIDR} \
        --service-cidr=${SERVICE_CIDR} \
        --apiserver-advertise-address=${LOCAL_IP} \
        --v=5
    
    echo "✅ Cluster initialized successfully"
}

setup_kubeconfig() {
    echo "⚙️  Setting up kubeconfig..."
    
    mkdir -p $HOME/.kube
    sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    
    echo "✅ kubeconfig setup completed"
}

install_cni() {
    echo "🌐 Installing CNI plugin (Flannel)..."
    
    # Install Flannel CNI
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    
    echo "✅ CNI plugin installed"
}

setup_single_node() {
    echo "🔧 Setting up single-node cluster (removing taints)..."
    
    # Remove taints from control-plane node to allow scheduling pods
    kubectl taint nodes --all node-role.kubernetes.io/control-plane-
    
    echo "✅ Single-node setup completed"
}

verify_cluster() {
    echo "🔍 Verifying cluster status..."
    
    echo "Waiting for nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    echo "Cluster nodes:"
    kubectl get nodes -o wide
    
    echo "Cluster pods:"
    kubectl get pods --all-namespaces
    
    echo "✅ Cluster verification completed"
}

generate_join_command() {
    echo "📝 Generating worker node join command..."
    
    JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)
    
    echo "Worker nodes can join this cluster using the following command:"
    echo "---"
    echo "sudo $JOIN_COMMAND"
    echo "---"
    
    # Save join command to file
    echo "sudo $JOIN_COMMAND" > join-worker-node.sh
    chmod +x join-worker-node.sh
    
    echo "✅ Join command saved to 'join-worker-node.sh'"
}

display_summary() {
    echo
    echo "🎉 Kubernetes cluster initialization completed!"
    echo
    echo "Cluster Information:"
    echo "- Kubernetes Version: ${K8S_VERSION}"
    echo "- Pod Network CIDR: ${POD_CIDR}"
    echo "- Service Network CIDR: ${SERVICE_CIDR}"
    echo "- CNI Plugin: Flannel"
    echo
    echo "Useful Commands:"
    echo "- Check cluster status: kubectl get nodes"
    echo "- View all pods: kubectl get pods --all-namespaces"
    echo "- Create a test deployment: kubectl create deployment nginx --image=nginx"
    echo "- Access cluster: export KUBECONFIG=$HOME/.kube/config"
    echo
    echo "Configuration files:"
    echo "- kubeconfig: $HOME/.kube/config"
    echo "- Join command: join-worker-node.sh"
    echo
}

main() {
    echo "Starting Kubernetes cluster initialization..."
    
    check_prerequisites
    pull_images
    init_cluster
    setup_kubeconfig
    install_cni
    
    # Ask if this should be a single-node cluster
    read -p "Setup as single-node cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        setup_single_node
    fi
    
    verify_cluster
    generate_join_command
    display_summary
}

main "$@"