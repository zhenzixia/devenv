#!/bin/bash

set -e

echo "=== Kubernetes Cluster Reset Script ==="
echo "This script will reset the Kubernetes cluster"
echo

check_confirmation() {
    echo "⚠️  WARNING: This will completely reset your Kubernetes cluster!"
    echo "All pods, services, and cluster data will be lost."
    echo
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
}

reset_cluster() {
    echo "🔄 Resetting Kubernetes cluster..."
    
    # Drain the node
    if command -v kubectl &> /dev/null && kubectl get nodes &> /dev/null; then
        NODE_NAME=$(kubectl get nodes -o name | head -1 | cut -d/ -f2)
        kubectl drain $NODE_NAME --delete-emptydir-data --force --ignore-daemonsets || true
    fi
    
    # Reset kubeadm
    sudo kubeadm reset --force
    
    # Clean up files
    sudo rm -rf /etc/kubernetes/
    sudo rm -rf ~/.kube/
    sudo rm -rf /var/lib/etcd/
    rm -f join-worker-node.sh
    
    # Reset iptables
    sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
    
    # Restart services
    sudo systemctl restart kubelet
    sudo systemctl restart containerd
    
    echo "✅ Cluster reset completed"
    echo
    echo "To reinitialize the cluster, run: ./init-k8s-cluster.sh"
}

main() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root"
        exit 1
    fi
    
    check_confirmation
    reset_cluster
}

main "$@"