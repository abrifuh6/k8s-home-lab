#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Step 1: Enable iptables Bridged Traffic
echo "Enabling iptables bridged traffic..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Step 2: Disable Swap
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Step 3: Install CRI-O Runtime
echo "Installing CRI-O Runtime..."
sudo apt-get update -y
sudo apt-get install -y software-properties-common curl
sudo modprobe overlay
sudo modprobe br_netfilter

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y cri-o cri-o-runc

# Step 4: Install Kubeadm, Kubelet, & Kubectl
echo "Installing Kubeadm, Kubelet, and Kubectl..."
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
