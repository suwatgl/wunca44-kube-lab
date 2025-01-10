# Kubernetes Setup on Oracle Virtualbox v7.1.4

## Content

- [Step 1. Setup Virtualbox ENV](#step1)
- [Step 2. Create Master01 VM and Install Ubuntu 24.04 LTS](#step2)
- [Step 3. Clone Master01 to Worker node 01 - 03](#step3)
- [Step 4. Initialize control-plane node](#step4)
- [Step 5. Join with kubernetes cluster](#step5)
- [Step 6. Install helm](#step6)
- [Step 7. Install Kubernetes Dashboard](#step7)
- [Step 8. Install NGINX Gateway Fabric](#step8)
- [Step 9. Deploy example site](#step9)
-

## Network diagram

```text
                    10.0.2.5
                  +----+
                  | W1 |
                  +----+
                   /
         10.0.2.4 /           10.0.2.6
               +----+       +----+
   ----------- | M1 | ----- | W2 |
               +----+       +----+
                  \
                   \ 10.0.2.7
                  +----+
                  | W3 |
                  +----+
```

## Virtual Machines (1 Master, 3 Workers)

| Server Role | Host Name | Configuration         | IP Address | Network Adapter |
| ----------- | --------- | --------------------- | ---------- | --------------- |
| Master Node | Master01  | 4GB Ram, 4vcpus, 20GB | 10.0.2.4   | NAT Network     |
| Worker Node | Worker01  | 2GB Ram, 2vcpus, 20GB | 10.0.2.5   | NAT Network     |
| Worker Node | Worker02  | 2GB Ram, 2vcpus, 20GB | 10.0.2.6   | NAT Network     |
| Worker Node | Worker03  | 2GB Ram, 2vcpus, 20GB | 10.0.2.7   | NAT Network     |

## Software

| Software Name             | Version   | Reference                                         |
| ------------------------- | --------- | ------------------------------------------------- |
| Virtualbox                | 7.1.4     | [https://virtualbox.org](https://download.virtualbox.org/virtualbox/7.1.4/) |
| VirtualBox Extension Pack | 7.1.4     | [https://virtualbox.org](https://download.virtualbox.org/virtualbox/7.1.4/) |
| VboxGuestAdditions        | 7.1.4     | [https://virtualbox.org](https://download.virtualbox.org/virtualbox/7.1.4/) |
| Ubuntu Server             | 24.04 LTS | [https://ubuntu.com](https://ubuntu.com/download/server)                |
| containerd.io             | 1.7.24    | [https://github.com/containerd/containerd](https://github.com/containerd/containerd)          |
| crictl                    | 1.32.0    | [https://github.com/kubernetes-sigs/cri-tools](https://github.com/kubernetes-sigs/cri-tools)      |
| kubernetes                | 1.32.0    | [https://kubernetes.io/releases/download/](https://kubernetes.io/releases/download/)          |
| calico                    | 3.29.1    | [https://github.com/projectcalico/calico](https://github.com/projectcalico/calico)           |
| helm                      | 3.16.3    | [https://helm.sh/docs/intro/install/](https://helm.sh/docs/intro/install/)               |
| Nginx Gateway Fabric      | 1.5.1     | [https://github.com/nginx/nginx-gateway-fabric](https://github.com/nginx/nginx-gateway-fabric)     |

<a id="step1"></a>

## Step 1. Setup Virtualbox ENV

- Install Oracle VirtualBox Extension Pack
  - Oracle_VirtualBox_Extension_Pack-7.1.4-165100.vbox-extpack
- Add optical disk
  - ubuntu-24.04.1-live-server-arm64.iso
  - VboxGuestAdditions_7.1.4.iso
- Create NAT Networks

  - Name: `NatNetwork`
  - IPv4 Prefix: `10.0.2.0/24`
  - Enable DHCP: `true`
  - Add port forwarding

    | Name      | Protocal | Host IP | Host Port | Guest IP | Guest Port |
    | --------- | -------- | ------- | --------- | -------- | ---------- |
    | HTTP      | TCP      |         | 80        | 10.0.2.4 | 80         |
    | HTTPS     | TCP      |         | 443       | 10.0.2.4 | 443        |
    | Dashboard | TCP      |         | 8443      | 10.0.2.4 | 8443       |
    | SSH4      | TCP      |         | 2224      | 10.0.2.4 | 22         |
    | SSH5      | TCP      |         | 2225      | 10.0.2.5 | 22         |
    | SSH6      | TCP      |         | 2226      | 10.0.2.6 | 22         |
    | SSH7      | TCP      |         | 2227      | 10.0.2.7 | 22         |

<a id="step2"></a>

## Step 2. Create Master01 VM and Install Ubuntu 24.04 LTS Server

### Update and Upgrade package

```bash
sudo apt update && \
sudo apt upgrade -y && \
sudo apt install net-tools network-managerm ssh -y && \
sudo systemctl enable ssh
```

### config network ip address

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  ethernets:
    enp0s8:
      addresses: [10.0.2.4/24]
      routes:
        - to: default
          via: 10.0.2.1
          metric: 100
      nameservers:
        search: [local]
        addresses: [10.0.2.1, 8.8.8.8, 8.8.8.4]
  dhcp4: false
version: 2
```

### apply network config and turn off VM

```bash
sudo netplan apply
sudo init 0
```

### Change VM Network Adapter from `NAT` to `NAT Network`

- Go to VM Settings
- Select Network menu
- Change Attached to: `NAT Network`
- Change Name: `NatNetwork`
- Click `OK` button
- Start VM

### Install programs

```bash
sudo apt update && \
sudo apt upgrade -y && \
sudo apt install gcc make perl build-essential bzip2 tar apt-transport-https ca-certificates curl gpg -y
```

### Disable Swap

```bash
sudo swapoff -a && \
sudo sed -i '/ swap / s/^\(.\*\)$/#\1/g' /etc/fstab
sudo sed -i '/swap/ s/^/#/' /etc/fstab
sudo rm -f /swap.img
systemctl disable swap.target
```

### Configure Ubuntu 24.04 enable kernel modules

```bash
sudo modprobe overlay && \
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

### Add Docker's official GPG key

```bash
sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc
```

### Add the repository to Apt sources

```bash
echo \
 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
 $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
 sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

### Install containerd

```bash
sudo apt-get install containerd.io -y && \
sudo mkdir -p /etc/containerd && \
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

### Edit containerd configuration

```bash
sudo vi /etc/containerd/config.toml
```

```yaml
[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

```bash
sudo systemctl restart containerd && \
sudo systemctl enable containerd && \
systemctl status containerd
```

### Enable IP Forwarding

```bash
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward && \
sudo sh -c "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf" && \
sudo sysctl -p
```

### Install crictl

```bash
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.32.0/crictl-v1.32.0-linux-arm64.tar.gz

sudo tar zxvf crictl-v1.32.0-linux-arm64.tar.gz -C /usr/local/bin

rm -f crictl-v1.32.0-linux-arm64.tar.gz

crictl commands:
  crictl info
  crictl images
  crictl ps
  crictl pods
  crictl stats

```

### Validate Containerd and IP Forwarding

```bash
sudo crictl info
cat /proc/sys/net/ipv4/ip_forward
```

### Install Kubeadm, Kubectl and Kubelet

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update && \
sudo apt-get install kubelet kubeadm kubectl -y && \
sudo apt-mark hold kubelet kubeadm kubectl && \
sudo systemctl enable --now kubelet
```

### install VBox Guest Additions (Optional)

```bash
sudo mount /dev/cdrom /media
sudo /media/VBoxLinuxAdditions-arm64.run
```

### Turn off VM

```bash
sudo init 0
```

<a id="step3"></a>

## Step 3. Clone Master01 to Worker nodes 01 - 03

### Clone Master01 to Worker01

#### Change VM Worker01 hostname to `Worker01`

```bash
sudo vi /etc/hostname
```

#### Change VM Worker01 IP Address to `10.0.2.5` and turn off MV

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo init 0
```

### Clone Master01 to Worker02

#### Change VM Worker02 hostname to `Worker02`

```bash
sudo vi /etc/hostname
```

#### Change VM Worker02 IP Address to `10.0.2.6` and turn off MV

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo init 0
```

### Clone Master01 to Worker03

#### Change VM Worker03 hostname to `Worker03`

```bash
sudo vi /etc/hostname
```

#### Change VM Worker03 IP Address to `10.0.2.7` and turn off MV

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo init 0
```

### Snapshot All VM after config and install programs

<a id="step4"></a>

## Step 4. Initialize control-plane node (Master Node only)

### Initialize control-plane node

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --cri-socket=/var/run/containerd/containerd.sock --v=5

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf
sudo chmod -R 755 /etc/kubernetes/admin.conf
```

#### Install Pod network add-on (calico)

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml

watch kubectl get pods -n calico-system
nc 127.0.0.1 6443 -v
```

<a id="step5"></a>

## Step 5. Join with kubernetes cluster (All Worker Nodes)

```bash
kubeadm join 10.0.2.4:6443 --token tr5tga.1zh2ggq5hjmrbw20 \
 --discovery-token-ca-cert-hash sha256:474f33595720b9327d581dbbfa728024802ea4cb7cbe144218b7c326075548aa
```

### Check nodes and pods on Master node

```bash
kubectl get nodes -o wide
kubectl get pods -o wide --all-namespaces
```

<a id="step6"></a>

## Step 6. Install helm (Master Node only)

```bash
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null

sudo apt-get install apt-transport-https --yes

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install helm
```

<a id="step7"></a>

## Step 7. Install Kubernetes Dashboard (Master Node only)

```bash
mkdir namespaces
cd namespaces
mkdir kubernetes-dashboard
cd kubernetes-dashboard

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

kubectl -n kubernetes-dashboard port-forward --address 0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443

kubectl -n kubernetes-dashboard get svc -o wide
```

### Install screen

```bash
sudo apt-get install screen
screen -S kubernetes-dashboard
# Ctrl+A and Ctrl+D for Exit screen
screen -dr kubernetes-dashboard
```

#### Port forwarding for kubernetes-dashboard

```bash
kubectl -n kubernetes-dashboard port-forward --address 0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443
```

#### Creating sample user

```bash
vi dashboard-adminuser.yaml
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
```

```bash
kubectl apply -f dashboard-adminuser.yaml
```

#### Creating a ClusterRoleBinding

```bash
vi cluster-role.yaml
```

```yaml
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
```

```bash
kubectl apply -f cluster-role.yaml
```

#### Getting a Bearer Token for ServiceAccount

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

#### Access dashboard

```html
https://localhost:8443
```

<a id="step8"></a>

## Step 8. Install NGINX Gateway Frabic Controller

### Install NGINX Gateway fabric

#### 1. Install the Gateway API resources

```bash
kubectl kustomize "https://github.com/nginxinc/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.5.1" | kubectl apply -f -
```

#### 2. Deploy the NGINX Gateway Fabric CRDs

```bash
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
```

#### 3. Deploy NGINX Gateway Fabric

```bash
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/default/deploy.yaml
```

#### 4. Verify the Deployment

```bash
kubectl get pods -n nginx-gateway -o wide
```

#### 5. Access NGINX Gateway Fabric

##### Retrieve the External IP and Port

```bash
kubectl get svc nginx-gateway -n nginx-gateway
```

##### Patch nginx-gateway service for assign external ip

```bash
kubectl patch svc nginx-gateway -n nginx-gateway -p '{"spec": {"externalIPs": ["10.0.2.4"]}}'

kubectl get svc nginx-gateway -n nginx-gateway -o wide
```

```bash
git clone -b release-1.5 https://github.com/nginxinc/nginx-gateway-fabric.git

kubectl apply -f https://github.com/nginxinc/nginx-kubernetes-gateway/releases/latest/download/deploy.yaml

kubectl get pods -n nginx-gateway
kubectl get crds | grep gateway
kubectl get gateway,httproute
```

### Upgrade Gateway API resources

```bash
kubectl kustomize "https://github.com/nginxinc/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.5.1" | kubectl apply -f -
```

### Upgrade NGINX Gateway Fabric CRDs

```bash
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v1.5.1/deploy/crds.yaml
```

<a id="step9"></a>

## Step 9. Deploy example site

### Clone Nginx Gateway Fabric from github

```bash
cd namespace
git clone -b release-1.5 https://github.com/nginxinc/nginx-gateway-fabric.git
cd nginx-gateway-fabric
```

### Go to cafe-example

```bash
cd examples/cafe-example
```

#### Deploy the Cafe Application

```bash
kubectl apply -f cafe.yaml
kubectl -n default get pods -o wide
```

#### Configure Routing

```bash
kubectl apply -f gateway.yaml
kubectl apply -f cafe-routes.yaml

kubectl describe gateway gateway
```

#### Test the Application

```bash
curl --resolve cafe.example.com:80:10.0.2.4 http://cafe.example.com/coffee -v
```

```bash
Server address: 10.12.0.18:80
Server name: coffee-7586895968-r26zn
```

```bash
curl --resolve cafe.example.com:80:10.0.2.4 http://cafe.example.com/tea -v
```

```bash
Server address: 10.12.0.19:80
Server name: tea-7cd44fcb4d-xfw2x
```

#### Check the generated nginx config

```bash
kubectl get pods -n nginx-gateway
kubectl exec -it -n nginx-gateway nginx-gateway-964449b44-c45f4 -c nginx -- nginx -T
```
