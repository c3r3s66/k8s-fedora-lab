---

# 🚀 Automated Kubernetes Lab on Fedora

A completely automated, infrastructure-as-code setup for spinning up a **3-node Kubernetes cluster (v1.30)** on **Fedora Linux** using **Terraform**, **libvirt/cloud-init**, **Ansible**, **containerd**, and **Flannel CNI**.

---

## 🏗 Architecture & Design

| Node Name | Role | OS | Container Runtime | Network CNI |
| --- | --- | --- | --- | --- |
| `k8s-master` | Control Plane | Fedora | containerd (systemd cgroup) | Flannel |
| `k8s-worker-1` | Worker | Fedora | containerd (systemd cgroup) | Flannel |
| `k8s-worker-2` | Worker | Fedora | containerd (systemd cgroup) | Flannel |

### Key Fedora & K8s Fixes Included

* **Containerd Cgroups:** Automates `SystemdCgroup = true` configuration.
* **CNI Symlinking:** Links `/opt/cni/bin` to `/usr/libexec/cni` for Fedora package compatibility.
* **NetworkManager Isolation:** Prevents NetworkManager from managing `cni0`, `flannel.1`, and `veth*` interfaces.
* **Swap & zRAM:** Completely disables host swap and Fedora's default `zRAM` generator.
* **Kube-Proxy Mode:** Configured for `iptables` mode compatibility with Kubernetes v1.30.

---

## 📋 Prerequisites

Before running the project, configure your Fedora host with the HashiCorp repository, virtualization stack, and required automation tools.

### 1. Add HashiCorp DNF Repo & Install Tools

Run the following commands to add the official HashiCorp repository and install Terraform, Ansible, and Libvirt build tools:

```bash
# Add the HashiCorp stable repository configuration
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/Fedora/hashicorp.repo

# Install Terraform, Ansible, and Libvirt development tools
sudo dnf install -y terraform ansible libvirt-devel

```

### 2. Set Up Virtualization Stack

Ensure KVM/QEMU is active and grant your local user user-level hypervisor permissions:

```bash
# Install the core Fedora virtualization package group
sudo dnf groupinstall -y "Virtualization"

# Start and enable the libvirt system virtualization daemon
sudo systemctl enable --now libvirtd

# Add your local user to the libvirt group to run commands without sudo
sudo usermod -aG libvirt $USER

```

> *Note: If you added your user to the `libvirt` group, log out and back in (or run `newgrp libvirt`) for group permissions to take effect.*

---

## 📂 Project Structure

```text
k8s-fedora-lab/
├── cloud_init.cfg     # Cloud-init template for VM initialization
├── main.tf            # Terraform configuration for libvirt VMs
└── ansible/           # Cluster configuration & setup
    ├── ansible.cfg    # Config with host_key_checking = False
    ├── inventory.ini  # Node inventory definitions
    └── playbook.yml   # Main cluster deployment playbook

```

---

## 🚀 Quick Start Guide

### Step 1: Provision Infrastructure (Terraform)

From the project root (`k8s-fedora-lab/`), initialize Terraform and apply `main.tf` to spin up the VMs with cloud-init:

```bash
terraform init
terraform apply -auto-approve

```

---

### Step 2: Deploy Kubernetes Cluster (Ansible)

Change into the `ansible/` directory and execute `playbook.yml`:

```bash
cd ansible/
ansible-playbook -i inventory.ini playbook.yml

```

> **Note:** `ansible.cfg` disables SSH host key checking, so Ansible connects automatically without prompt interruptions.

---

## ✅ Cluster Verification

### 1. Check Node Readiness

SSH into the master node and verify all 3 nodes are in the `Ready` state:

```bash
ssh fedora@192.168.150.10 "kubectl get nodes -o wide"

```

**Expected Output:**

```text
NAME           STATUS   ROLES           AGE   VERSION    INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                          KERNEL-VERSION            CONTAINER-RUNTIME
k8s-master     Ready    control-plane   31m   v1.30.14   192.168.150.10   <none>        Fedora Linux 44 (Cloud Edition)   6.19.10-300.fc44.x86_64   containerd://2.3.3
k8s-worker-1   Ready    <none>          30m   v1.30.14   192.168.150.11   <none>        Fedora Linux 44 (Cloud Edition)   6.19.10-300.fc44.x86_64   containerd://2.3.3
k8s-worker-2   Ready    <none>          27m   v1.30.14   192.168.150.12   <none>        Fedora Linux 44 (Cloud Edition)   6.19.10-300.fc44.x86_64   containerd://2.3.3

```

---

### 2. Verify Pod Health

Check that all control plane and CNI pods are running cleanly across all namespaces:

```bash
ssh fedora@192.168.150.10 "kubectl get pods -A"

```

**Expected Output:**

```text
NAMESPACE      NAME                                 READY   STATUS    RESTARTS   AGE
kube-flannel   kube-flannel-ds-66jdh                1/1     Running   0          27m
kube-flannel   kube-flannel-ds-dt7m9                1/1     Running   0          27m
kube-flannel   kube-flannel-ds-fg2tw                1/1     Running   0          27m
kube-system    coredns-55cb58b774-hdfsp             1/1     Running   0          31m
kube-system    coredns-55cb58b774-jchn6             1/1     Running   0          31m
kube-system    etcd-k8s-master                      1/1     Running   0          31m
kube-system    kube-apiserver-k8s-master            1/1     Running   0          31m
kube-system    kube-controller-manager-k8s-master   1/1     Running   0          31m
kube-system    kube-proxy-2xhgw                     1/1     Running   0          27m
kube-system    kube-proxy-8hz54                     1/1     Running   0          30m
kube-system    kube-proxy-8pnb9                     1/1     Running   0          31m
kube-system    kube-scheduler-k8s-master            1/1     Running   0          31m

```

---

### 3. Test DNS & Connectivity

Run a temporary test pod to ensure internal DNS and pod-to-pod networking are operational:

```bash
ssh fedora@192.168.150.10 "kubectl run nettest --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default"

```

**Expected Output:**

```text
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
pod "nettest" deleted

```

---

## 🧹 Cluster Teardown

To destroy the entire environment and release resources:

```bash
cd ..
terraform destroy -auto-approve

```
