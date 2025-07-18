# Kubernetes Setup on Oracle Virtualbox v7.1.12

## Content

- [Step 1. Setup Virtualbox ENV](#step1)
- [Step 2. Create Master01 VM and Install Ubuntu 24.04 LTS](#step2)
  - 2.1 Update Upgrade package and clone master1 to worker1
  - 2.2 Config Network Adapter master1 (Master1 Only)
  - 2.3 Config Network Adapter worker1 (Worker1 Only)
  - 2.4 Install programs (master1 and worker1)
- [Step 3. Clone Master01 to Worker node 01 - 03](#step3)
- [Step 4. Initialize control-plane node](#step4)
- [Step 5. Join with kubernetes cluster](#step5)
- [Step 6. Install helm](#step6)
- [Step 7. Install Kubernetes Dashboard](#step7)
- [Step 8. Install NGINX Gateway Fabric](#step8)
- [Step 9. Deploy example site](#step9)
  - 9.1 cafe-example (http)
  - 9.2 https-termination (https)
- [Step 10. Horizontal Pod Autoscaler](#step10)

## Network diagram

![Network Diagram](https://github.com/suwatgl/wunca44-kube-lab/blob/main/images/NetworkDiagramUDRU.png?raw=true)

## Virtual Machines (1 Master, 3 Workers)

| Server Role | Host Name | Configuration         | Network Adapter  | IP Address   |
| ----------- | --------- | --------------------- | ---------------- | ------------ |
| Master Node | Master01  | 4GB Ram, 4vcpus, 20GB | Bridged Adapter  | 192.168.1.yy |
|             |           |                       | Internal Newtork | 10.0.2.4     |
| Worker Node | Worker01  | 2GB Ram, 2vcpus, 20GB | Internal Newtork | 10.0.2.5     |
| Worker Node | Worker02  | 2GB Ram, 2vcpus, 20GB | Internal Newtork | 10.0.2.6     |
| Worker Node | Worker03  | 2GB Ram, 2vcpus, 20GB | Internal Newtork | 10.0.2.7     |

## Software

| Software Name             | Version   | Reference                                         |
| ------------------------- | --------- | ------------------------------------------------- |
| Virtualbox                | 7.1.12    | [https://virtualbox.org](https://download.virtualbox.org/virtualbox/7.1.12/) |
| Ubuntu Server             | 24.04     | [https://ubuntu.com](https://ubuntu.com/download/server)                |
| containerd                | 2.1.3     | [https://github.com/containerd/containerd](https://github.com/containerd/containerd/releases)          |
| crictl                    | 1.33.0    | [https://github.com/kubernetes-sigs/cri-tools](https://github.com/kubernetes-sigs/cri-tools/releases)      |
| kubernetes                | 1.33.2    | [https://github.com/kubernetes/kubernetes](https://github.com/kubernetes/kubernetes/releases)          |
| calico                    | 3.30.2    | [https://github.com/projectcalico/calico](https://github.com/projectcalico/calico/releases)           |
| helm                      | 3.18.4    | [https://github.com/helm/helm](https://github.com/helm/helm/releases)               |
| Nginx Gateway Fabric      | 2.0.2     | [https://github.com/nginx/nginx-gateway-fabric](https://github.com/nginx/nginx-gateway-fabric/releases)     |
| Metrics Server            | 0.7.1     | [https://github.com/kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server/releases)   |

<a id="step1"></a>

## Step 1. Setup Virtualbox ENV

- Install Oracle VirtualBox Extension Pack
  - Oracle_VirtualBox_Extension_Pack-7.1.12.vbox-extpack
- Add optical disk
  - ubuntu-24.04.1-live-server-arm64.iso

<a id="step2"></a>

## Step 2. Create VM master1 and Install Ubuntu 24.04 LTS Server

### 2.1 Update Upgrade package and clone master1 to worker1

```bash
sudo apt update && \
sudo apt upgrade -y && \
sudo apt install net-tools network-manager ssh iproute2 iptables inetutils-ping -y && \
sudo systemctl enable ssh

sudo init 0
```

#### Install Virtualbox Guest Additions (Optional)

```bash
sudo apt install -y build-essential dkms linux-headers-$(uname -r)

# Insert VBoxGuestAdditions.iso CD file into Linux guest's CD-ROM drive and mount it.
sudo mount /dev/cdrom /media
cd /media
sudo ./VBoxLinuxAdditions.run

sudo reboot

lsmod | grep vboxguest
```

- Clone master1 to worker1
- Start master1 and worker1

---

### 2.2 Config Network Adapter master1 (Master1 Only)

- Go to VM Settings
- Select Network menu
  - Adapter 1
    - Attached to: `Bridged Network`
    - Name: `en0: WiFi` (Interface ที่เชื่อมต่อกับ Internet)
  - Adapter 2
    - Enabel Network Adapter
    - Attached to: `Internal Network`
    - Name: `WUNCANet` (ตั้งชื่อ Internal Network ใหม่เพื่อใช้สื่อสารใน Cluster)
- Click `OK` button
- Start VM

### config network ip address for master1

```bash
# ตรวจสอบ Interface ที่มีอยู่ใน MV
ip addr
ifconfig

# ทำการ Up Interface ที่ยังไม่เห็นจากคำสั่ง ifconfig
sudo ifconfig enp0s9 up

# แก้ไขค่าของ Network Interfaces ทั้ง 2 
sudo vi /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  ethernets:
    enp0s8:  # Interface ที่เป็น Bridged Adapter
      addresses: [192.168.x.yy/24] # Ip ที่อยู่ใน Network เดียวกันกับเครื่อง Host
      routes:
        - to: default
          via: 192.168.x.254
      nameservers:
        search: [local]
        addresses: [192.168.2.153] # Ip ของ DNS Server
      dhcp4: false
    enp0s9:  # Interface ที่เป็น Internal Network
      addresses: [10.0.2.4/24]
      nameservers:
        search: [local]
        addresses: [8.8.8.8, 8.8.8.4]
      dhcp4: false
  version: 2
```

```bash
sudo netplan apply
ifconfig enp0s8
```

### เพิ่ม Routing table `ในเครื่อง Host` ให้สามารถติดต่อกับ VM ที่อยู่ใน Internal Network ได้

```bash
# สำหรับ MacOS ==================
netstat -rn -f inet
sudo route delete 10.0.2.0/24  # ถ้ามีอยู่แล้ว ให้ลบทิ้งก่อน
sudo route add -net 10.0.2.0/24 192.168.x.yy  # Ip ของ Bridged Adapter
netstat -rn -f inet

# สำหรับ Windows =================
route print
route delete 10.0.2.0  # ถ้ามีอยู่แล้ว ให้ลบทิ้งก่อน
route add 10.0.2.0 MASK 255.255.255.0 192.168.x.yy # Ip ของ Bridged Adapter
route print
```

### Enable IP Forwarding and s-nat

```bash
# ให้ VM master1 สามารถทำ ip forward ได้
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward && \
sudo sh -c "echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf" && \
sudo sysctl -p

# สำหรับทุก package ที่มาจาก network 10.0.2.0/24 ให้ทำการ Masquerade หลังออกไป (ที่ Interface Internal Network ของ VM master1)
sudo iptables -t nat -L -nv
sudo iptables -t nat -A POSTROUTING -o enp0s8 -s 10.0.2.0/24 -j MASQUERADE
```

---

### 2.3 Config Network Adapter worker1 (Worker1 Only)

- Go to VM Settings
- Select Network menu
  - Adapter 1
    - Attached to: `Internal Network`
    - Name: `WUNCANet` (ใช้ชื่อเดียวกันกับ Internal Network ของ VM master1)
- Click `OK` button
- Start VM

### config network ip address for worker1

```bash
# เปลี่ยนชื่อ ของ VM ให้เป็น worker1
sudo hostnamectl set-hostname worker1

# แก้ไขไฟล์ hostname ให้เป็น worker1
sudo vi /etc/hostname
```

```bash
worker1
```

```bash
# แก้ไขค่าของ Network Interface ของ VM worker1
sudo vi /etc/netplan/50-cloud-init.yaml
```

```yaml
network:
  ethernets:
    enp0s8:  # Interface ที่เป็น Internal Network
      addresses: [10.0.2.5/24]
      routes:
        - to: default
          via: 10.0.2.4
          metric: 100
      nameservers:
        search: [local]
        addresses: [8.8.8.8, 8.8.8.4]
      dhcp4: false
  version: 2
```

```bash
sudo netplan apply
ifconfig enp0s8
```

### 2.4 Install programs (master1 and worker1)

```bash
# ติดตั้ง Programs ที่จำเป็นต้องใช้ใน VM master1 และ work1
sudo apt update && \
sudo apt upgrade -y && \
sudo apt install gcc make perl build-essential bzip2 tar apt-transport-https ca-certificates curl gpg git -y
```

### Disable Swap

```bash
sudo swapoff -a && \
sudo sed -i '/swap/ s/^/#/' /etc/fstab && \
sudo rm -f /swap.img && \
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
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

```bash
sudo systemctl restart containerd && \
sudo systemctl enable containerd && \
systemctl status containerd
```

### Install crictl

```bash
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.33.0/crictl-v1.33.0-linux-$(dpkg --print-architecture).tar.gz

sudo tar zxvf crictl-v1.33.0-linux-$(dpkg --print-architecture).tar.gz -C /usr/local/bin

rm -f crictl-v1.33.0-linux-$(dpkg --print-architecture).tar.gz

sudo tee /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

sudo systemctl restart containerd && \
sudo systemctl status containerd
```

### Validate Containerd and IP Forwarding

```bash
sudo crictl info
sudo crictl images
sudo crictl ps
sudo crictl pods
sudo crictl stats
```

### Install Kubeadm, Kubectl and Kubelet

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update && \
sudo apt-get install kubelet kubeadm kubectl -y && \
sudo apt-mark hold kubelet kubeadm kubectl && \
sudo systemctl enable --now kubelet
```

### Turn off เฉพาะ VM worker1 เพื่อทำการ Clone ไปเป็น worker2 และ worker3

```bash
sudo init 0
```

<a id="step3"></a>

## Step 3. Clone worker1 to worker2 and worker3

### Clone VM worker1 to worker2

#### With VM worker2 change hostname `worker1` to `worker2`

```bash
sudo hostnamectl set-hostname worker2
sudo vi /etc/hostname
```

```bash
worker2
```

#### With VM worker2 change IP Address `10.0.2.5` to `10.0.2.6`

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo init 0
```

### Clone VM worker1 to worker3

#### With VM worker3 change hostname `worker1` to `worker3`

```bash
sudo hostnamectl set-hostname worker3
sudo vi /etc/hostname
```

```bash
worker3
```

#### With VM worker3 change IP Address `10.0.2.5` to `10.0.2.7`

```bash
sudo vi /etc/netplan/50-cloud-init.yaml
sudo netplan apply
sudo init 0
```

<a id="step4"></a>

## Step 4. Initialize control-plane node (Master Node only)

### Initialize control-plane node

```bash
sudo kubeadm init \
  --apiserver-advertise-address=10.0.2.4 \
  --apiserver-bind-port=6443 \
  --control-plane-endpoint=10.0.2.4:6443 \
  --pod-network-cidr=192.168.0.0/16 \
  --cri-socket=/var/run/containerd/containerd.sock \
  --v=5

mkdir -p $HOME/.kube && \
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && \
sudo chown $(id -u):$(id -g) $HOME/.kube/config && \
export KUBECONFIG=/etc/kubernetes/admin.conf && \
sudo chmod -R 755 /etc/kubernetes/admin.conf
```

#### Install Pod network add-on (calico)

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml

# Verify the plugin works.
kubectl calico -h

watch kubectl get pods -n calico-system
nc 127.0.0.1 6443 -v
```

<a id="step5"></a>

## Step 5. Join with kubernetes cluster (All Worker Nodes)

```bash
sudo kubeadm join 10.0.2.4:6443 --token xxxxx.yyyyyyyyyyyyyyyy \
 --discovery-token-ca-cert-hash sha256:xyxyxyxyxyxyxyxyxyxyxyxyxyxyxyxyxyxyxyxyxyx
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

sudo apt-get update && \
sudo apt-get install helm
```

<a id="step7"></a>

## Step 7. Install Kubernetes Dashboard (Master Node only)

```bash
mkdir namespaces && \
cd namespaces && \
mkdir kubernetes-dashboard && \
cd kubernetes-dashboard

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

kubectl -n kubernetes-dashboard get svc -o wide
```

### Creating sample user

```bash
tee dashboard-adminuser.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF

kubectl apply -f dashboard-adminuser.yaml
```

#### Creating a ClusterRoleBinding

```bash
tee cluster-role.yaml <<EOF
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

kubectl apply -f cluster-role.yaml
```

#### Getting a Bearer Token for ServiceAccount

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

#### Port forwarding for kubernetes-dashboard

```bash
kubectl -n kubernetes-dashboard port-forward --address 0.0.0.0 svc/kubernetes-dashboard-kong-proxy 8443:443 > /dev/null &
```

#### Access dashboard

```html
https://10.0.2.4:8443
```

<a id="step8"></a>

## Step 8. Install NGINX Gateway Frabic Controller

### Install NGINX Gateway fabric

#### 1. Install the Gateway API resources

```bash
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.0.2" | kubectl apply -f -
```

#### 2. Deploy the NGINX Gateway Fabric CRDs

```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.0.2/deploy/crds.yaml
```

#### 3. Deploy NGINX Gateway Fabric

```bash
kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v2.0.2/deploy/default/deploy.yaml
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
kubectl patch svc nginx-gateway -n nginx-gateway -p '{"spec": {"externalIPs": ["10.0.2.4"], "externalTrafficPolicy": "Cluster"}}'

kubectl get svc nginx-gateway -n nginx-gateway -o json
kubectl describe svc nginx-gateway -n nginx-gateway
```

#### 6. Reference

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

<a id="step9"></a>

## Step 9. Deploy example site

### 9.1 Clone Nginx Gateway Fabric from github

```bash
cd namespace
git clone --branch v2.0.2 https://github.com/nginx/nginx-gateway-fabric.git
cd nginx-gateway-fabric
```

---

### 9.2 cafe-example

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

---

### 9.3 https-termination

```bash
cd examples/https-termination
```

#### Create the coffee and the tea Deployments and Services

```bash
kubectl apply -f cafe.yaml
```

#### Create the Namespace certificate and a Secret with a TLS certificate and key

```bash
kubectl apply -f certificate-ns-and-cafe-secret.yaml && \
kubectl apply -f reference-grant.yaml && \
kubectl apply -f gateway.yaml && \
kubectl apply -f cafe-routes.yaml
```

#### Test HTTPS Redirect

```bash
curl --resolve cafe.example.com:80:10.0.2.4 http://cafe.example.com:80/coffee --include

curl --resolve cafe.example.com:80:10.0.2.4 http://cafe.example.com:80/tea --include
```

#### Access Coffee and Tea

```bash
curl --resolve cafe.example.com:443:10.0.2.4 https://cafe.example.com:443/coffee --insecure

curl --resolve cafe.example.com:443:10.0.2.4 https://cafe.example.com:443/tea --insecure
```

#### Remove the ReferenceGrant

```bash
kubectl delete -f reference-grant.yaml

curl --resolve cafe.example.com:443:10.0.2.4 https://cafe.example.com:443/coffee --insecure -vvv

 kubectl describe gateway gateway
```

<a id="step10"></a>

## Step 10. Horizontal Pod Autoscaler

### Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.1/components.yaml

kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# kubectl patch deployment metrics-server -n kube-system \
#   --type='json' \
#   -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args/-", "value": "--metric-resolution=90s"}]'

kubectl get apiservices
kubectl top nodes
kubectl top pods
kubectl top pod my-nginx
```

### Patch cafe example

```bash
cd namespaces
mkdir hpa
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

kubectl apply -f cafe.yaml

kubectl autoscale deployment coffee --cpu-percent=20 --min=1 --max=5

kubectl get hpa coffee --watch

# Load test HPA
wrk -t10 -c100 -d30s https://cafe.example.com/coffee

# Load test none HPA
wrk -t10 -c100 -d30s https://cafe.example.com/tea

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

## References

### [Kubernetes Cluster Setup on Ubuntu 24.04 LTS Server](https://medium.com/@rabbi.cse.sust.bd/kubernetes-cluster-setup-on-ubuntu-24-04-lts-server-c17be85e49d1)

- Md. Mehedi Hasan
- May 26, 2024

---

### [Gateway API คือขั้นกว่าของการทำ Ingress บน Kubernetes](https://dev.to/terngr/gateway-api-khuuekhankwaakhngkaartham-ingress-bn-kubernetes-10nl)

- terngr
- Jul 8, 2023

---

### [Kubernetes Best Practices ที่ทุกคนควรรู้ EP.1](https://developers.ascendcorp.com/kubernetes-best-practices-%E0%B8%97%E0%B8%B5%E0%B9%88%E0%B8%97%E0%B8%B8%E0%B8%81%E0%B8%84%E0%B8%99%E0%B8%84%E0%B8%A7%E0%B8%A3%E0%B8%A3%E0%B8%B9%E0%B9%89-ep-1-29767c8a18f0)

- Mongkol Thongkraikaew
- Jan 22, 2023

---

### [Kubernetes Best Practices ที่ทุกคนควรรู้ EP.2](https://developers.ascendcorp.com/kubernetes-best-practices-%E0%B8%97%E0%B8%B5%E0%B9%88%E0%B8%97%E0%B8%B8%E0%B8%81%E0%B8%84%E0%B8%99%E0%B8%84%E0%B8%A7%E0%B8%A3%E0%B8%A3%E0%B8%B9%E0%B9%89-ep-2-c2e0d3fa78a1)

- Mongkol Thongkraikaew
- Jan 30, 2023

---

### [Kubernetes Best Practices ที่ทุกคนควรรู้ EP.3 (End)](https://developers.ascendcorp.com/kubernetes-best-practices-%E0%B8%97%E0%B8%B5%E0%B9%88%E0%B8%97%E0%B8%B8%E0%B8%81%E0%B8%84%E0%B8%99%E0%B8%84%E0%B8%A7%E0%B8%A3%E0%B8%A3%E0%B8%B9%E0%B9%89-ep-3-end-ebdaef4d82b4)

- Mongkol Thongkraikaew
- Feb 22, 2023

---

### [Kubernetes คือ อะไร ? หนทางสู่การทำระบบให้แกร่งกว่าที่เคย !](https://blog.openlandscape.cloud/what-is-kubernetes)

- openlandscape.cloud
- Nov 2, 2022

---

### [Kubernetes Gateway API คืออะไร? ถึงเวลาใช้แทน Ingress แล้ว](https://nopnithi.com/posts/what-is-kubernetes-gateway-api-time-to-replace-ingress/#concept-%E0%B8%82%E0%B8%AD%E0%B8%87-kubernetes-gateway-api)

- Nopnithi Khaokaew
- Apr 1, 2024

---

### [What is Gateway API in Kubernetes and How does it differ from Ingress API?](https://medium.com/@kedarnath93/what-is-gateway-api-in-kubernetes-and-how-does-it-differ-from-ingress-api-aa0404d7fc09)

- Kedarnath Grandhe
- Jul 10, 2024

---
