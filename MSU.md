### LAB Environments

![Network Diagram](https://github.com/suwatgl/wunca44-kube-lab/blob/main/images/MSUlab.png?raw=true)

## 1. Setting Up a Virtual Machine

#### 1.1 Download and import VirtualBox image(s)

The VirtualBox images include both AMD and ARM architectures
https://drive.google.com/drive/folders/1KarpiITxRwtPABC92949cbotvQP_aQ4y

All virtual machines require at least the following specifications listed in the table.

| Role          | Hostname   | vCPUs | RAM | Disk | IP Address     |
| :------------ | :--------- | :---- | :-- | :--- | :------------- |
| Control Plane | `master01` | 4     | 2GB | 20GB | `10.0.2.4` |
| Worker Node1   | `worker01` | 2     | 2GB | 20GB | `10.0.2.5` |
| Worker Node2   | `worker02` | 2     | 2GB | 20GB | `10.0.2.6` |
| Worker NodeX   | `worker0X` | 2     | 2GB | 20GB | `10.0.2.X` |

#### 1.2 Start the `master01` VM and install common packages.
```bash
# Check VM IP address
ifconfig 

# Check the internet access
curl -v google.com
```
#### 1.3 Access `master01` remotely via SSH. Suppose the IP address of `master01` is `192.168.1.235`. Open a terminal or command prompt and run the following command:

```bash
# Check VM IP address
ssh wunca44@192.168.1.235 
# VM password is wunca44
```

####  1.4 Update and install common packages
```bash
# update & upgrade ubuntu
sudo apt update && sudo apt upgrade -y

# Install common packages for the `master01` node 
sudo apt install -y net-tools network-manager ssh iproute2 iptables inetutils-ping gcc make perl build-essential bzip2 tar apt-transport-https ca-certificates curl gpg git wrk
```

#### 1.5 Disable Swap

```bash
# Ensure that swap is permanently disabled
sudo sed -i '/swap/ s/^/#/' /etc/fstab

#Edit the fstab file — a # must be inserted at the beginning of the /swap.img line to disable swap. Using cat to inspect files.
cat /etc/fstab
```

#### 1.6 Enable Required Kernel Modules 

```bash
sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```
#### 1.7 Install and Configure `containerd`
```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings && \
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the Docker repository to APT sources
echo \
 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
 $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
 sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list and install containerd
sudo apt-get update && \
sudo apt-get install -y containerd.io

# Generate the default containerd configuration file
sudo mkdir -p /etc/containerd && \
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Configure containerd to use systemd for cgroup management, which is recommended for Kubernetes
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable the containerd service
sudo systemctl restart containerd

# Check whether containerd is up and running by inspecting its status
sudo systemctl status containerd
```
#### 1.8 Install Kubernetes Container Runtime Interface (CRI) 

```bash
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.32.0/crictl-v1.32.0-linux-$(dpkg --print-architecture).tar.gz

sudo tar zxvf crictl-v1.32.0-linux-$(dpkg --print-architecture).tar.gz -C /usr/local/bin

rm -f crictl-v1.32.0-linux-$(dpkg --print-architecture).tar.gz

sudo tee /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

sudo systemctl restart containerd && \
sudo systemctl status containerd
```
Common crictl Commands
```bash
sudo crictl info
sudo crictl images
sudo crictl ps
sudo crictl pods
sudo crictl stats
```


#### 1.9 Install `kubeadm`, `kubectl`, and `kubelet`
```bash
# Add the Kubernetes APT repository GPG key
sudo mkdir -p -m 755 /etc/apt/keyrings && \
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the Kubernetes APT repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list and install Kubernetes tools
sudo apt-get update && \
sudo apt-get install -y kubelet kubeadm kubectl

# Hold the packages at their current version to prevent unintended upgrades
sudo apt-mark hold kubelet kubeadm kubectl

# Enable the kubelet service
sudo systemctl enable --now kubelet

sudo init 0
```

#### 1.10 Shutdown the `master01` VM and perform a full clone of the `master01` VM to create `worker01` and `worker02`


## 2. IP configuration for all VM nodes, including master01, worker01, worker02

#### 2.1 Access `master01` via SSH and configure its hostname namd ip address

```bash
# Access to master01
ssh wunca44@<master01_ip>

#inspect network interfaces 
ip addr

#inspect local DNS 
resolvectl status

#inspect gateway 
ip route

#add master01 into hosts file 
echo 10.0.2.4 master01 >> /etc/hosts
#set hostname 
sudo hostnamectl set-hostname master01

#configure ip address
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOF
network:
  ethernets:
    enp0s8: #external interface 
      addresses: [ 10.3.6.90/22 ] #Allocated IP Address
      routes:
        - to: default
          via: 10.3.7.254 #Gateway 
      nameservers:
        search: [local]
        addresses: [192.168.2.4] # DNS 
      dhcp4: false
    enp0s9: #internal interface 
      addresses: [10.0.2.4/24]
      nameservers:
        search: [local]
        addresses: [192.168.2.4] # DNS 
      dhcp4: false
  version: 2
EOF


# Apply network changes
sudo netplan apply

#Add NAT for enp0s8 external interface 
sudo iptables -t nat -A POSTROUTING -o enp0s8 -s 10.0.2.0/24 -j MASQUERADE

```

#### 2.2 Configure `worker01` 
 - hostname namd ip address
```bash
#configure ip address  
sudo ip addr add 10.0.2.5/24 dev enp0s8

#remote jump to worker01 using ssh command 
ssh -J wunca44@<master01> wunca44@<worker01>
#example 
ssh -J wunca44@192.168.1.235 wunca44@10.0.2.5

#set worker hostname 
sudo hostnamectl set-hostname worker01

#configure ip address
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOF
network:
  ethernets:
    enp0s8: #external interface 
      addresses: [ 10.0.2.5/24 ]
      routes:
        - to: default
          via: 10.0.2.4
      nameservers:
        search: [local]
        addresses: [1.1.1.1, 8.8.8.8] # DNS 
      dhcp4: false
  version: 2
EOF

#Apply changes 
sudo netplan apply
```

#### 2.3 Configure worker02 and the other nodes as in section 2.2


## 3. Init Control plane (`master01` node)
   A pod cidr must not overlap with a node cidr 
   - node cidr : 10.0.2.0/24
   - pod cidr : 10.244.0.0/16
   - host cidr : 10.3.6.0/22
```bash
#init controlvplane 
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=10.0.2.4 \
  --control-plane-endpoint=10.0.2.4


#To start using a cluster, you need to run the following as a regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#Alternatively, if you are the root user, you can run:
export KUBECONFIG=/etc/kubernetes/admin.conf

```

### 5.3. Install the Pod Network Add-on (Calico)

A Container Network Interface (CNI) plugin is required for pods to communicate with each other. We will use Calico.

```bash
# Apply the Calico operator manifest
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Apply the Calico custom resources, which define the network configuration
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml

# All pods must be up and running  
watch kubectl get pods -A
```



Once a controlplane is created, worker nodes can join using the output token

```bash

  kubeadm join 10.0.2.4:6443 --token aimdme.4h71q03f6rtpxknp \
	--discovery-token-ca-cert-hash sha256:968145f35645814faa0022cd89dcd56fa8a7bb04b207a27d204bc8aa9313387a \
	--control-plane 

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.2.4:6443 --token aimdme.4h71q03f6rtpxknp \
	--discovery-token-ca-cert-hash sha256:968145f35645814faa0022cd89dcd56fa8a7bb04b207a27d204bc8aa9313387a 

```
