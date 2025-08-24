# Development Environment Setup Utilities

This repository provides scripts to set up a development VM with various tools and environments.

## Kubernetes 1.33.4 Setup

Scripts to install and configure Kubernetes 1.33.4 using kubeadm with all required dependencies.

### Quick Start

1. **Set up the environment** (install all dependencies):
   ```bash
   ./setup-k8s-env.sh
   ```

2. **Initialize the cluster**:
   ```bash
   ./init-k8s-cluster.sh
   ```

3. **Reset cluster** (if needed):
   ```bash
   ./reset-k8s-cluster.sh
   ```

### What Gets Installed

The `setup-k8s-env.sh` script installs:

- **Go 1.22.5** - Compatible Go version for Kubernetes development
- **containerd** - Container runtime with proper systemd cgroup configuration
- **kubeadm, kubelet, kubectl** - Kubernetes 1.33.4 components
- **System prerequisites** - Required packages and kernel modules
- **Network configuration** - Proper networking setup for Kubernetes

### System Requirements

- **OS**: Ubuntu/Debian Linux
- **Memory**: Minimum 2GB RAM
- **CPU**: 2+ CPUs (recommended for control plane)
- **Network**: Full connectivity between nodes
- **Swap**: Will be automatically disabled

### Cluster Features

- **Kubernetes Version**: 1.33.4
- **Container Runtime**: containerd
- **CNI Plugin**: Flannel
- **Pod Network**: 10.244.0.0/16
- **Service Network**: 10.96.0.0/12
- **Single-node option**: Available during initialization

### Usage Examples

After cluster initialization:

```bash
# Check cluster status
kubectl get nodes

# View all pods
kubectl get pods --all-namespaces

# Create a test deployment
kubectl create deployment nginx --image=nginx

# Expose the deployment
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Adding Worker Nodes

After running `init-k8s-cluster.sh`, use the generated `join-worker-node.sh` command on worker nodes:

```bash
# On worker node (after running setup-k8s-env.sh)
sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash <hash>
```

### Troubleshooting

- **Check containerd**: `sudo systemctl status containerd`
- **Check kubelet**: `sudo systemctl status kubelet`
- **View logs**: `sudo journalctl -xeu kubelet`
- **Reset and retry**: `./reset-k8s-cluster.sh` then `./init-k8s-cluster.sh`





