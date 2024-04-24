
# Kubeadm Cluster Setup

## Introduction

This README provides detailed instructions and scripts for setting up a Kubernetes cluster using Kubeadm on Proxmox-managed VMs(in my case). The setup utilizes Ubuntu 22.04 LTS, CRI-O as the container runtime, and Calico for networking(CNI). This guide includes all necessary steps, prerequisites, and troubleshooting tips.

## Prerequisites

- Minimum two Ubuntu nodes (one master and one worker).
- Master node: Minimum 2 vCPU and 2GB RAM.
- Worker node: Minimum 1 vCPU and 2GB RAM.
- IP CIDR range for Proxmox: 192.168.1.0/24.
- Static IPs for master and worker nodes.
- Ensure the pod IP CIDR is set to 192.168.2.0/24(my choice, you can choose any other CIDR that does not overlap with your Node CIDR).

## Kubeadm Port Requirements

Refer to the following table for the required ports:

### Master Node Port Requirements

Ensure the following ports are allowed for the master node (control plane):

| Port     | Protocol | Description                  |
|----------|----------|------------------------------|
| 6443     | TCP      | Kubernetes API server        |
| 2379-2380| TCP      | etcd server client API       |
| 10250    | TCP      | Kubelet API                  |
| 10251    | TCP      | kube-scheduler               |
| 10252    | TCP      | kube-controller-manager      |
| 10255    | TCP      | Read-only Kubelet API (If kubelet is running on master) |

### Worker Node Port Requirements

Ensure the following ports are allowed for the worker nodes:

| Port     | Protocol | Description                  |
|----------|----------|------------------------------|
| 10250    | TCP      | Kubelet API                  |
| 30000-32767 | TCP   | NodePort Services (default range for NodePort services) |

## Step 1: Enable iptables Bridged Traffic

Execute the following commands on all the nodes to enable iptables to see bridged traffic:

```bash
# Load kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
```

## Step 2: Disable Swap

For proper operation of Kubernetes, it's essential to disable swap on all nodes:

```bash
# Disable swap
sudo swapoff -a

# Ensure swap remains off after reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
```

The `fstab` entry will ensure swap remains off on system reboots.

**Note:** From Kubernetes version 1.28, there is beta support for using swap with kubeadm clusters. Please refer to the Kubernetes documentation for more information.

Got it! Here's the README document with the critical note maintained:

---

# Installing CRI-O Runtime on Kubernetes Nodes

**NOTE** This document provides instructions for installing the CRI-O container runtime on Kubernetes nodes. CRI-O is preferred over Docker for Kubernetes certification exams and is a viable runtime choice for Kubernetes clusters.

## Step 3: Install CRI-O Runtime On All The Nodes

Execute the following commands on all the nodes to install required dependencies, the latest version of CRIO, and crictl:

```bash
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update -y
sudo apt-get install -y cri-o

sudo systemctl daemon-reload
sudo systemctl enable crio --now
sudo systemctl start crio.service

# Install crictl (Optional)
VERSION="v1.28.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz
```

**Note:** crictl is a CLI utility to interact with containers created by the container runtime.

Below is the README document with your provided instructions:

---

# Installing Kubeadm, Kubelet & Kubectl on All Nodes

This document provides instructions for installing Kubeadm, Kubelet, and Kubectl on all Kubernetes nodes.

## Step 4: Install Kubeadm & Kubelet & Kubectl on all Nodes

Download the GPG key for the Kubernetes APT repository on all the nodes.

```bash
KUBERNETES_VERSION=1.28

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Update apt repo.

```bash
sudo apt-get update -y
```

**Note:**
 If you are preparing for Kubernetes certification, install the specific version of Kubernetes. For example, the current Kubernetes version for CKA, CKAD, and CKS exams is Kubernetes version 1.29. You can use the following commands to find the latest versions. Install the first version in 1.29 so that you can practice cluster upgrade tasks depending on when you are using this repo. i will try to keep this repo up to date.

```bash
apt-cache madison kubeadm | tac
```

Specify the version as shown below. Here I am using 1.30

```bash
sudo apt-get install -y kubelet=1.30 kubectl=1.30 kubeadm=1.30
```

Or, to install the latest version from the repo use the following command without specifying any version.

```bash
sudo apt-get install -y kubelet kubeadm kubectl
```

Add hold to the packages to prevent upgrades.

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

Now we have all the required utilities and tools for configuring Kubernetes components using kubeadm.

Add the node IP to KUBELET_EXTRA_ARGS.

```bash
sudo apt-get install -y jq
local_ip="$(ip --json addr show eth0 | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')"
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF
```
Got it! Let's update the README with the correct IP address:

---

## Step 5: Initialize Kubeadm On Master Node To Setup Control Plane

Execute the commands in this section only on the master node.

### If you are using a Private IP for the master Node:

Set the following environment variables. Replace `192.168.1.77` with the IP of your master node.

```bash
IPADDR="192.168.1.77"
NODENAME=$(hostname -s)
POD_CIDR="192.168.2.0/24"
```

### If you want to use the Public IP of the master node:

Set the following environment variables. The `IPADDR` variable will be automatically set to the server’s public IP using `ifconfig.me` curl call. You can also replace it with a public IP address.

```bash
IPADDR=$(curl ifconfig.me && echo "")
NODENAME=$(hostname -s)
POD_CIDR="192.168.2.0/24"
```

Now, initialize the master node control plane configurations using the `kubeadm` command.

For a Private IP address-based setup use the following init command:

```bash
sudo kubeadm init --apiserver-advertise-address=$IPADDR  --apiserver-cert-extra-sans=$IPADDR  --pod-network-cidr=$POD_CIDR 
```

> **Note:** `--ignore-preflight-errors Swap` is actually not required as we disabled the swap initially.

For Public IP address-based setup use the following init command:

Here instead of `--apiserver-advertise-address` we use `--control-plane-endpoint` parameter for the API server endpoint.

```bash
sudo kubeadm init --control-plane-endpoint=$IPADDR  --apiserver-cert-extra-sans=$IPADDR  --pod-network-cidr=$POD_CIDR 
```

All the other steps are the same as configuring the master node with a private IP.

On a successful kubeadm initialization, you should get an output with kubeconfig file location and the join command with the token. Copy that and save it to the file. We will need it for joining the worker node to the master.

[init] Using Kubernetes version: vX.Y.Z
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
...
[certs] Using certificateDir folder "/etc/kubernetes/pki"
...
[kubeconfig] Writing "admin.conf" kubeconfig file
...
[addons] Applied essential addon: CoreDNS
...
[addons] Applied essential addon: kube-proxy
...
Your Kubernetes control-plane has initialized successfully!

To start using your cluster(interact with API-Sever), you need to run the following as a **regular user:**

  ```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

OR

Alternatively, if you are the **root user**, you can run:

```bash
  export KUBECONFIG=/etc/kubernetes/admin.conf
```

Then you can join any number of worker nodes by running the following on each as root:

**NOTE**
 it's crucial to highlight that the values provided in the `kubeadm join` command, such as the token and the discovery token CA cert hash, will vary based on each user's unique configuration. Let's add a note to emphasize this:

```bash
# The following command is an example of how to join worker nodes to the Kubernetes cluster.
# Note: The values provided (token, discovery token CA cert hash) are unique to your cluster and will differ from the example.
# Make sure to replace them with the actual values obtained during the initialization of your Kubernetes cluster.

kubeadm join 192.168.1.77:6443 --token abcdef.1234567890abcdef \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
```

This note will remind users that they need to replace these values with their own specific values obtained during their Kubernetes cluster setup.

After initializing the Kubernetes control plane and configuring `kubectl`, you can verify the setup by executing the following command:

```bash
kubectl get po -n kube-system
```

The output you expect to see after running this command is:

```
NAME                                READY   STATUS    RESTARTS   AGE
coredns-xxxxxxxxxx-xxxxx            0/1     Pending   0          xxm
coredns-xxxxxxxxxx-xxxxx            0/1     Pending   0          xxm
```

This output indicates that the two CoreDNS pods are in a pending state. This is expected behavior before installing the network plugin. Once you install the network plugin, these pods should transition to a running state.

To verify the health statuses of all cluster components and get cluster information, use the following commands:

```bash
# Verify all cluster component health statuses
kubectl get --raw='/readyz?verbose'

# Get cluster information
kubectl cluster-info
```

Additionally, if you want to allow apps to be scheduled on the master node, you can remove the taint on the master node using:

```bash
# Allow apps to be scheduled on the master node
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

These commands provide essential insights into the health of your Kubernetes cluster and its components and allow you to manage node taints as needed.

## Custom Deployment Script
Below is a custom deployment script for deploying a sample Nginx application with a customized webpage for Buamtech Consulting:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Buamtech Consulting</title>
    <style>
        body {
            background-color: #f4f4f4;
            font-family: Arial, sans-serif;
            margin: 40px;
            color: #333;
        }
        .container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #0056b3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Buamtech Consulting!</h1>
        <p>We are dedicated to providing top-notch consulting services.</p>
    </div>
</body>
</html>
```

## Configuring kubectl on Your Workstation
To configure kubectl on your local workstation:
```bash
# On your local workstation:
mkdir -p $HOME/.kube
scp user@master_ip:/etc/kubernetes/admin.conf $HOME/.kube/config
```

## Troubleshooting
- **Pod Resource Constraints:** Ensure nodes meet minimum resource requirements.
- **Networking Issues:** Check firewall settings and network connectivity between nodes.
- **Calico Pod Restarts:** Avoid overlapping IP ranges for node and pod networks.

## Generating Kubeadm Join Command
To generate the join command:
```bash
# On the master node:
kubeadm token create --print-join-command
```

## Further Resources
- [Official Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes CRI-O Integration Guide](https://cri-o.io/documentation/kubelet/)
- [Calico Documentation](https://docs.projectcalico.org/)

---

This README provides a comprehensive guide for setting up a Kubernetes cluster using Kubeadm on Proxmox-managed VMs. If you have any questions or need further assistance, please feel free to ask!







Sure, here's the revised section with the port requirements presented in a tabular format:

---

# Kubernetes Cluster Setup Using Kubeadm

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
    - [Master Node Port Requirements](#master-node-port-requirements)
    - [Worker Node Port Requirements](#worker-node-port-requirements)
3. [Installation Steps](#installation-steps)
    - [Setting Up the Master Node](#setting-up-the-master-node)
    - [Setting Up Worker Nodes](#setting-up-worker-nodes)
4. [Configuring kubectl on Your Workstation](#configuring-kubectl-on-your-workstation)
5. [Deploying a Sample Application](#deploying-a-sample-application)
6. [Troubleshooting Common Issues](#troubleshooting-common-issues)
7. [Generating the Kubeadm Join Command](#generating-the-kubeadm-join-command)
8. [Upgrading Your Cluster](#upgrading-your-cluster)
9. [Backup and Recovery](#backup-and-recovery)
10. [Monitoring with Prometheus](#monitoring-with-prometheus)

## Introduction
This guide provides step-by-step instructions for setting up a Kubernetes cluster using Kubeadm. It covers all the necessary components and configurations to deploy a fully functional Kubernetes cluster.

## Prerequisites



Certainly! Here's the adjusted README document with step 4 included as part of step 3:

---

# Installing CRI-O Runtime on Kubernetes Nodes

This document provides instructions for installing the CRI-O container runtime on Kubernetes nodes. CRI-O is preferred over Docker for Kubernetes certification exams and is a viable runtime choice for Kubernetes clusters.

## Step 3: Install CRI-O Runtime On All The Nodes

Execute the following commands on all the nodes to install required dependencies, the latest version of CRIO, and crictl:

```bash
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates

curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/prerelease:/main/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

sudo apt-get update -y
sudo apt-get install -y cri-o

sudo systemctl daemon-reload
sudo systemctl enable crio --now
sudo systemctl start crio.service

# Install crictl
VERSION="v1.28.0"
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
sudo tar zxvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz
```

**Note:** We are using CRI-O instead of containerd or Docker for this setup. In Kubernetes certification exams, CRI-O is used as the container runtime in the exam clusters. It's essential to follow this choice as Kubernetes has deprecated the Docker engine. crictl is a CLI utility to interact with containers created by the container runtime.

---

This README provides clear instructions for installing CRI-O runtime on Kubernetes nodes. Follow these steps carefully to ensure proper configuration and compatibility with Kubernetes clusters.