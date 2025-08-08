### # Day 1

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

```
Common crictl Commands
```bash
sudo crictl info
sudo crictl images
sudo crictl ps
sudo crictl pods
sudo crictl stats
#delete all images 
sudo crictl rmi --all
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

#

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

#Verify internet connection 
curl google.com
```

#### 2.3 Configure worker02 and the other nodes as in section 2.2


## 3. Init Control plane (`master01` node)
#### 3.1   A pod cidr must not overlap with a node cidr 
   - node cidr : 10.0.2.0/24
   - pod cidr : 192.168.0.0/16
   - host cidr : 10.3.6.0/22

#### 3.2 init control plane 
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
export KUBECONFIG=/etc/kubernetes/admin.conf && \
sudo chmod -R 755 /etc/kubernetes/admin.conf


```

#### 3.3 Install CNI with Calico

```bash
# Apply the Calico operator manifest
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Apply the Calico custom resources, which define the network configuration
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml

# All pods must be up and running  
watch kubectl get pods -A
```

### 3.4 (Optional) to reset and re-initialize the control plane  
```bash
sudo kubeadm reset 
sudo rm -rf $HOME/.kube
sudo crictl rmi --all
```

## 4. Have the worker nodes join the master node
Once a controlplane is created, worker nodes can join using the output token

```bash
#Use the join command output from sudo kubeadm init (see section 3.2) to add worker nodes (run in worker nodes)
sudo kubeadm join 10.0.2.4:6443 --token 5869hq.4ziibryvbzkfmdnt \
	--discovery-token-ca-cert-hash sha256:6c7fdefe7ada3e9e7357034773a96eed392005cbb1999bb62dc39ef4722da020 

#At the controlplane node 
#Wait until the worker nodes are ready
watch kubectl get nodes
#or 
watch kubectl get pods -A
```

## 5. Install Helm Package Manager
#### 5.1 Open the controlplane terminal and install Helm
```bash
# Get the signed gpg  
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

# Add the Helm to sources.list 
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Update and install Helm
sudo apt-get update && \
sudo apt-get install -y helm
```

#### 5.2 Install Kubernetes Dashboard
```bash
# Add the Kubernetes Dashboard Helm repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

# Install the dashboard into its own namespace
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard 

# Create a ServiceAccount named 'admin-user'
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Grant the ServiceAccount cluster-wide admin privileges
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Generates a token for an admin-user
kubectl -n kubernetes-dashboard create token admin-user

# Bind service port 8443:443 for the address 0.0.0.0 
kubectl -n kubernetes-dashboard port-forward --address 0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443 > /dev/null &

#Open a browser and access the dashboard via
https://10.3.6.90:8443/ 
```

## 6. NGINX Gateway Fabric and Example App Deployment
#### 6.1 Install the NGINX Gateway Fabric
ref: https://docs.nginx.com/nginx-gateway-fabric/install/manifests/
```bash
# 1. Install the Gateway API CRDs (Custom Resource Definitions)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.0.2" | kubectl apply -f -

# 2. Deploy the NGINX Gateway Fabric CRDs
kubectl apply --server-side -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.0.2/deploy/crds.yaml

# 3. Deploy NGINX Gateway Fabric itself
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.0.2/deploy/default/deploy.yaml

# 4. Verify the deployment
watch kubectl get pods -n nginx-gateway

#Use the public IP of the load balancer to access NGINX Gateway Fabric. To get the public IP which is reported in the EXTERNAL-IP column:
kubectl get svc nginx-gateway -n nginx-gateway

kubectl patch svc nginx-gateway \
  -n nginx-gateway \
  --type='merge' \
  -p '{
    "spec": {
      "ports": [
        {
          "name": "http",
          "port": 80,
          "protocol": "TCP",
          "targetPort": 80
        },
        {
          "name": "https",
          "port": 443,
          "protocol": "TCP",
          "targetPort": 443
        }
      ]
    }
  }'
```
```bash
kubectl get svc nginx-gateway -n nginx-gateway -o wide/json/yaml
kubectl describe svc nginx-gateway -n nginx-gateway

```
#### 6.2 Deploy a simple app (cafe)
```bash

# List of geteway class 
kubectl get gatewayclass
kubectl describe gatewayclass

# Clone the NGINX Gateway Fabric repository to get the examples
git clone --branch v2.0.2 https://github.com/nginx/nginx-gateway-fabric.git
cd nginx-gateway-fabric/examples/cafe-example

# Create the Gateway resource (port 80)
kubectl apply -f gateway.yaml

#inspect gateway object
kubectl get pod
kubectl get svc

# Deploy the coffee and tea deployments and services
kubectl apply -f cafe.yaml

# Insepct cafe deployment 
watch kubectl get pods -n default

# Create the HTTPRoute
kubectl apply -f cafe-routes.yaml

# Verify the Gateway and HTTPRoute
kubectl get svc -n default -o wide

kubectl patch svc coffee -n default -p '{"spec": {"externalIPs": ["10.0.2.4","192.168.30.19"]}}'

kubectl get httproute -A
kubectl describe httproute coffee -n default
kubectl get endpoints coffee -n default
kubectl get endpoints coffee -o wide

```

#### 6.3 Reference

```bash
# gatewayClass detail
kubectl get gatewayclass -A
kubectl describe gatewayclass nginx

# geteway detail
kubectl get gateway -A
kubectl describe gateway gateway

# httproutes detail
kubectl get httproutes -A
kubectl describe httproutes

# service detail
kubectl get svc -A
kubectl get svc -n nginx-gateway -o wide
kubectl get svc -n default -o wide
```

# Day 2
# KubeBench 
# Auto Scale
# CI/CD Auto deployment