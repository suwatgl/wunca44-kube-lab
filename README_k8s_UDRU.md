# Kubernetes Lab Setup on Ubuntu 24.04 (ARM64) with VirtualBox

This guide provides step-by-step instructions for setting up a Kubernetes cluster on your local machine using Oracle VirtualBox. The cluster will consist of one control-plane node and three worker nodes, running on Ubuntu 24.04 LTS for the ARM64 architecture.

## Table of Contents

- [1. Architecture Overview](#part1)
- [2. Prerequisites](#part2)
- [3. Phase 1: Creating a Base VM Template](#part3)
- [4. Phase 2: Cloning and Configuring Cluster Nodes](#part4)
- [5. Phase 3: Initializing the Kubernetes Cluster](#part5)
- [6. Phase 4: Installing Essential Add-ons](#part6)
- [7. Phase 5: Deploying an Application with NGINX Gateway Fabric](#part7)
- [8. Phase 6: Configuring Horizontal Pod Autoscaling (HPA)](#part8)

---

<a id="part1"></a>

## 1. Architecture Overview

### 1.1. Network Diagram

![Network Diagram](https://github.com/suwatgl/wunca44-kube-lab/blob/main/images/NetworkDiagramUDRU.png?raw=true)

### 1.2. Virtual Machines

The lab consists of four virtual machines with the following specifications:

| Role          | Hostname   | vCPUs | RAM | Disk | IP Address     |
| :------------ | :--------- | :---- | :-- | :--- | :------------- |
| Control Plane | `master01` | 4     | 4GB | 20GB | `192.168.1.51` |
| Worker Node   | `worker01` | 2     | 2GB | 20GB | `192.168.1.56` |
| Worker Node   | `worker02` | 2     | 2GB | 20GB | `192.168.1.57` |
| Worker Node   | `worker03` | 2     | 2GB | 20GB | `192.168.1.58` |

---

<a id="part2"></a>

## 2. Prerequisites

### 2.1. Required Software

Ensure you have the following software installed on your host machine. This guide uses the versions listed below, which have been verified to work together.

| Software Name         | Version | Reference                                                                                                       |
| :-------------------- | :------ | :-------------------------------------------------------------------------------------------------------------- |
| Virtualbox            | 7.1.12  | [https://download.virtualbox.org](https://download.virtualbox.org/virtualbox/7.1.12/)                           |
| Ubuntu Server (ARM64) | 24.04   | [https://ubuntu.com/download/server](https://ubuntu.com/download/server)                                        |
| containerd            | 2.1.3   | [https://github.com/containerd](https://github.com/containerd/containerd/releases)                              |
| crictl                | 1.33.0  | [https://github.com/kubernetes-sigs/cri-tools](https://github.com/kubernetes-sigs/cri-tools/releases)           |
| kubernetes            | 1.33.2  | [https://github.com/kubernetes](https://github.com/kubernetes/kubernetes/releases)                              |
| calico                | 3.30.2  | [https://github.com/projectcalico](https://github.com/projectcalico/calico/releases)                            |
| helm                  | 3.18.4  | [https://github.com/helm](https://github.com/helm/helm/releases)                                                |
| Nginx Gateway Fabric  | 2.0.2   | [https://github.com/nginx](https://github.com/nginx/nginx-gateway-fabric/releases)                              |
| MetalLB               | 0.15.2  | [https://github.com/metallb](https://github.com/metallb/metallb/releases)                                       |
| Metrics Server        | 0.8.0   | [https://github.com/kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server/releases) |
| kustomize             | v5.7.0  | [https://github.com/kubernetes-sigs/kustomize](https://github.com/kubernetes-sigs/kustomize/releases)           |
| wrk                   | 4.2.0   | [https://github.com/wg/wrk](https://github.com/wg/wrk)                                                          |

### 2.2. Initial VirtualBox Setup

1. **Install VirtualBox Extension Pack**: Download and install `Oracle_VirtualBox_Extension_Pack-7.1.12.vbox-extpack`.
2. **Prepare Ubuntu ISO**: Download the **ARM64** version of Ubuntu Server: `ubuntu-24.04.1-live-server-arm64.iso`.

---

<a id="part3"></a>

## 3. Phase 1: Creating a Base VM Template

To streamline the setup, we will first create a single "base" virtual machine with all the common software installed. We will then clone this template to create our master and worker nodes.

### 3.1. Create and Install the Base VM

1. Create a new VM in VirtualBox named `ubuntu-template`.
2. Configure it with **4GB RAM, 2 vCPUs, and a 20GB disk**.
3. Mount the `ubuntu-24.04.1-live-server-arm64.iso`
4. Configure Network Adapter
   - In the VM's Settings -> Network section.
   - Set **Adapter 1** to be a `Bridged Adapter`.
   - Select the network interface on your host machine that is connected to the internet (e.g., `en0: Wi-Fi`).
5. Start the VM and install Ubuntu Server. During installation, ensure you select "Install OpenSSH server".

### 3.2. Install Common Packages and Tools

Start the `ubuntu-template` VM and run the following commands to install all necessary software.

```bash
# Update package lists and upgrade existing packages
sudo apt update && sudo apt upgrade -y

# Install essential networking tools, build tools, and other utilities
sudo apt install -y net-tools network-manager ssh iproute2 iptables inetutils-ping \
                    gcc make perl build-essential bzip2 tar apt-transport-https ca-certificates curl gpg git wrk

# Set the correct hostname
sudo hostnamectl set-hostname master01

# Configure the static IP address
# Note: Verify your interface name with `ip addr` (e.g., enp0s3, enp0s8)
sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOF
network:
  ethernets:
    enp0s8:
      addresses: [192.168.1.51/24]
      routes:
        - to: default
          via: 192.168.1.254 # Replace with your gateway
      nameservers:
        addresses: [192.168.1.2, 192.168.1.3] # Replace with your DNS
      dhcp4: false
  version: 2
EOF

# Apply network changes and reboot
sudo netplan apply
```

### 3.3. Disable Swap

Kubernetes requires swap to be disabled to function correctly.

```bash
# Turn off swap immediately
sudo swapoff -a

# Disable swap permanently by commenting it out in the fstab file
sudo sed -i '/swap/ s/^/#/' /etc/fstab
```

### 3.4. Configure Kernel Modules and System Settings

These settings are required for the container runtime and Kubernetes networking.

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

### 3.5. Install and Configure `containerd`

We will use `containerd` as our container runtime.

```bash
# Add Docker's official GPG key to ensure package authenticity
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
```

### 3.6. Install Kubernetes Components (`kubeadm`, `kubectl`, `kubelet`)

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
```

### 3.7. Finalize the Template

The base template is now ready. Shut it down to prepare for cloning.

```bash
# Shut down the VM
sudo shutdown now
```

---

<a id="part4"></a>

## 4. Phase 2: Cloning and Configuring Cluster Nodes

We will now create our four cluster nodes by cloning the `ubuntu-template` VM.

### 4.1. Clone the VMs

In VirtualBox, perform a "Full Clone" of the `ubuntu-template` VM four times, naming them:

- `master01`
- `worker01`
- `worker02`
- `worker03`

### 4.2. Configure Network and Host-specific Settings

For **each** VM, you must perform the following steps. **Start one VM at a time to avoid IP conflicts.**

1. **Change VM Hardware:** Adjust the CPU and RAM for each node according to the [Architecture](#part1) table.
2. **Configure Network Adapter:**
   - In the VM's Settings -> Network section.
   - Set **Adapter 1** to be a `Bridged Adapter`.
   - Select the network interface on your host machine that is connected to the internet (e.g., `en0: Wi-Fi`).
3. **Start the VM and Configure OS:**

   #### For `worker03`

   ```bash
   # Set the correct hostname
   sudo hostnamectl set-hostname worker03

   # Configure the static IP address
   sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOF
   network:
     ethernets:
       enp0s8:
         addresses: [192.168.1.58/24]
         routes:
           - to: default
             via: 192.168.1.254 # Replace with your gateway
         nameservers:
           addresses: [192.168.1.2, 192.168.1.3] # Replace with your DNS
         dhcp4: false
     version: 2
   EOF

   # Apply network changes and reboot
   sudo netplan apply
   sudo reboot
   ```

   #### For `worker02`

   ```bash
   # Set the correct hostname
   sudo hostnamectl set-hostname worker02

   # Configure the static IP address
   sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOF
   network:
     ethernets:
       enp0s8:
         addresses: [192.168.1.57/24]
         routes:
           - to: default
             via: 192.168.1.254 # Replace with your gateway
         nameservers:
           addresses: [192.168.1.2, 192.168.1.3] # Replace with your DNS
         dhcp4: false
     version: 2
   EOF

   # Apply network changes and reboot
   sudo netplan apply
   sudo reboot
   ```

   #### For `worker01`

   ```bash
   # Set the correct hostname
   sudo hostnamectl set-hostname worker01

   # Configure the static IP address
   sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOF
   network:
     ethernets:
       enp0s8:
         addresses: [192.168.1.56/24]
         routes:
           - to: default
             via: 192.168.1.254 # Replace with your gateway
         nameservers:
           addresses: [192.168.1.2, 192.168.1.3] # Replace with your DNS
         dhcp4: false
     version: 2
   EOF

   # Apply network changes and reboot
   sudo netplan apply
   sudo reboot
   ```

   #### For `master01`

   ```bash
   # Set the correct hostname
   sudo hostnamectl set-hostname master01

   # Configure the static IP address
   # Note: Verify your interface name with `ip addr` (e.g., enp0s3, enp0s8)
   sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null <<EOF
   network:
     ethernets:
       enp0s8:
         addresses: [192.168.1.51/24]
         routes:
           - to: default
             via: 192.168.1.254 # Replace with your gateway
         nameservers:
           addresses: [192.168.1.2, 192.168.1.3] # Replace with your DNS
         dhcp4: false
     version: 2
   EOF

   # Apply network changes and reboot
   sudo netplan apply
   sudo reboot
   ```

---

<a id="part5"></a>

## 5. Phase 3: Initializing the Kubernetes Cluster

### 5.1. Initialize the Control-Plane Node

On the `master01` node, run the following command to initialize the cluster.

```bash
# This command bootstraps the Kubernetes control plane.
# --pod-network-cidr: Specifies the IP address range for the pod network. This is required for the Calico CNI.
# --apiserver-advertise-address: The IP address the API Server will advertise on. This should be the master node's IP.
# --control-plane-endpoint: A stable endpoint for the control plane.
sudo kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=192.168.1.51 \
  --control-plane-endpoint=192.168.1.51
```

After the command completes, it will output a `kubeadm join` command. **Copy this command now**, as you will need it to join the worker nodes to the cluster.

### 5.2. Configure `kubectl` for Your User

To use `kubectl` as a regular user, run these commands on `master01`.

```bash
# Create a .kube directory in your home directory
mkdir -p $HOME/.kube

# Copy the administrator's kubeconfig file to your user's .kube directory
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Change the ownership of the file to your user
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 5.3. Install the Pod Network Add-on (Calico)

A Container Network Interface (CNI) plugin is required for pods to communicate with each other. We will use Calico.

```bash
# Apply the Calico operator manifest
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Apply the Calico custom resources, which define the network configuration
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml

# Monitor the Calico pods until they are all running
watch kubectl get pods -n calico-system
```

### 5.4. Join Worker Nodes to the Cluster

On each worker node (`worker01`, `worker02`, `worker03`), run the `kubeadm join` command that you copied from the `kubeadm init` output. It will look something like this:

```bash
# This command must be run as root on each worker node
sudo kubeadm join 192.168.1.51:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### 5.5. Verify the Cluster

Back on `master01`, verify that all nodes have joined the cluster successfully.

```bash
# Check the status of all nodes. They should all show 'Ready'.
watch kubectl get nodes -o wide
```

---

<a id="part6"></a>

## 6. Phase 4: Installing Essential Add-ons

### 6.1. Install Helm

Helm is the package manager for Kubernetes. Run this on `master01`.

```bash
# Add the Helm repository GPG key
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

# Add the Helm repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

# Update package list and install Helm
sudo apt-get update && \
sudo apt-get install -y helm
```

### 6.2. Install Kubernetes Dashboard

The dashboard provides a web-based UI for managing your cluster.

```bash
# Add the Kubernetes Dashboard Helm repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

# Install the dashboard into its own namespace
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
```

#### Create an Admin User for the Dashboard

For security, we'll create a dedicated ServiceAccount to access the dashboard.

```bash
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
```

#### Access the Dashboard

1. **Get the login token:**

   ```bash
   # This command generates a long-lived token for the admin-user
   kubectl -n kubernetes-dashboard create token admin-user
   ```

   **Copy the output token. You will use it to log in.**

2. **Access the dashboard via port-forwarding:**

   ```bash
   # This command forwards a local port to the dashboard service in the cluster.
   # WARNING: --address 0.0.0.0 makes the dashboard accessible from any IP on your network.
   # This is convenient for a lab but is a security risk in untrusted networks.
   # For higher security, omit '--address 0.0.0.0' and access it via https://localhost:8443.
   kubectl -n kubernetes-dashboard port-forward --address 0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443 > /dev/null &
   ```

3. Open a browser and navigate to `https://<master01-ip>:8443` (e.g., `https://192.168.1.51:8443`). Select "Token" and paste the token you copied.

---

<a id="part7"></a>

## 7. Phase 5: Deploying an Application with NGINX Gateway Fabric

We will deploy a sample application and expose it to the outside world using the modern Gateway API, implemented by NGINX Gateway Fabric.

### 7.1. Install MetalLB

In a bare-metal environment like this, MetalLB is needed to provide LoadBalancer services, which assign external IP addresses to our gateway.

```bash
# Install MetalLB from its manifest
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# Wait for MetalLB pods to be ready
watch kubectl get pods -n metallb-system
```

#### Configure MetalLB's IP Address Pool

Tell MetalLB which IP addresses it is allowed to use. These should be unused IPs on your local network.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.60-192.168.1.69
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
EOF
```

### 7.2. Install NGINX Gateway Fabric

This will install the Gateway API CRDs and the NGINX Gateway Fabric controller.

```bash
# 1. Install the Gateway API CRDs (Custom Resource Definitions)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.0.2" | kubectl apply -f -

# 2. Deploy the NGINX Gateway Fabric CRDs
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.0.2/deploy/crds.yaml

# 3. Deploy NGINX Gateway Fabric itself
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.0.2/deploy/default/deploy.yaml

# 4. Verify the deployment
watch kubectl get pods -n nginx-gateway
```

### 7.3. Deploy the "Cafe" Example Application

We'll deploy a simple application with two services: `coffee` and `tea`.

```bash
# Clone the NGINX Gateway Fabric repository to get the examples
git clone --branch v2.0.2 https://github.com/nginx/nginx-gateway-fabric.git
cd nginx-gateway-fabric/examples/https-termination

# Deploy the coffee and tea deployments and services
kubectl apply -f cafe.yaml
```

### 7.4. Configure Routing with Gateway API

Now, we'll create Gateway API resources to expose the application.

```bash
# Create a secret containing a TLS certificate for cafe.example.com
kubectl apply -f certificate-ns-and-cafe-secret.yaml

# Create a ReferenceGrant to allow the Gateway to access the secret from another namespace
kubectl apply -f reference-grant.yaml

# Create the Gateway resource, which requests a listener on port 443 (HTTPS)
kubectl apply -f gateway.yaml

# Create the HTTPRoute, which defines the routing rules (e.g., /coffee -> coffee-svc)
kubectl apply -f cafe-routes.yaml

# Verify the Gateway and HTTPRoute
kubectl get svc -n default -o wide
```

### 7.5. Test the Application

The NGINX Gateway service will get an external IP from MetalLB (e.g., `192.168.1.60`). Find it with `kubectl get svc -n nginx-gateway`.

```bash
# Replace <EXTERNAL-IP> with the IP of the gateway-nginx service
export GW_IP=$(kubectl get svc -n default gateway-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Gateway IP: $GW_IP"

# Test the /coffee endpoint
curl --resolve cafe.example.com:443:$GW_IP https://cafe.example.com/coffee --insecure

# Test the /tea endpoint
curl --resolve cafe.example.com:443:$GW_IP https://cafe.example.com/tea --insecure
```

You should see responses from the `coffee` and `tea` pods respectively.

---

<a id="part8"></a>

## 8. Phase 6: Configuring Horizontal Pod Autoscaling (HPA)

Finally, we'll set up HPA to automatically scale our application based on CPU usage.

### 8.1. Install the Metrics Server

The HPA controller needs a source for resource metrics, which is provided by the Metrics Server.

```bash
# Install the Metrics Server components
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.0/components.yaml

# Patch the deployment to work with the kubelet's self-signed certificates in our lab environment.
# WARNING: This disables TLS verification and is not recommended for production environments.
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# Verify that the metrics server is running and collecting metrics
# It may take a few minutes for metrics to become available.
watch kubectl top nodes
```

---

### Patch cafe example

```bash
cd ~
mkdir namespaces
cd namespaces && \
mkdir hpa && \
cd hpa

# ------------------------------------
tee cafe.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coffee
spec:
  replicas: 1
  selector:
    matchLabels:
      app: coffee
  template:
    metadata:
      labels:
        app: coffee
    spec:
      containers:
      - name: coffee
        image: nginxdemos/nginx-hello:plain-text
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "200Mi"
            cpu: "200m"
          requests:
            memory: "100Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: coffee
spec:
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: coffee
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tea
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tea
  template:
    metadata:
      labels:
        app: tea
    spec:
      containers:
      - name: tea
        image: nginxdemos/nginx-hello:plain-text
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "200Mi"
            cpu: "200m"
          requests:
            memory: "100Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: tea
spec:
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: tea
EOF

# ----------------------------------

# Deploy the application and its service
kubectl apply -f cafe.yaml

# Create the HPA
kubectl autoscale deployment coffee --cpu-percent=50 --min=1 --max=10

# Watch the HPA status
kubectl get hpa coffee --watch

# Load test HPA
wrk -t10 -c100 -d30s https://cafe.example.com/coffee

# Load test none HPA
wrk -t10 -c100 -d30s https://cafe.example.com/tea

# Watch the HPA status
kubectl get deploy coffee -w

kubectl delete hpa coffee
```

#### Create hpa.yaml

```bash
tee hpa.yaml <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: coffee
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: coffee
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 20
EOF

kubectl apply -f hpa.yaml
```

---

### 8.2. Deploy an Application for HPA Testing

We'll use a simple PHP-Apache application that can generate CPU load.

```bash
# Deploy the application and its service
kubectl apply -f https://k8s.io/examples/application/php-apache.yaml
```

### 8.3. Create the HorizontalPodAutoscaler

This HPA resource will monitor the `php-apache` deployment and scale it up when the average CPU utilization exceeds 50%.

```bash
# Create the HPA
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

# Watch the HPA status
kubectl get hpa -w
```

### 8.4. Generate Load and Observe Autoscaling

1. **Start a load generator pod:**

   ```bash
   # Run a temporary pod to send a continuous loop of queries to the application
   kubectl run -it --rm load-generator --image=busybox /bin/sh

   # Inside the load-generator pod's shell, run this command:
   # while true; do wget -q -O- http://php-apache; done
   ```

2. **Observe the scaling:**

   - In another terminal on `master01`, watch the HPA and the deployment:
     ```bash
     kubectl get hpa -w
     kubectl get deployment php-apache -w
     ```
   - You will see the `TARGETS` CPU percentage increase, and the number of `REPLICAS` will automatically go up to handle the load.

3. **Stop the load:**
   - Go back to the load-generator pod's terminal and press `Ctrl+C` to stop the loop, then type `exit`.
   - Observe the HPA again. After a few minutes, the number of replicas will scale back down to 1.

Congratulations! You have successfully set up a Kubernetes cluster and tested key features like Gateway API and HPA.
