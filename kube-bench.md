
1. yaml
   
cd namespaces

git clone https://github.com/aquasecurity/kube-bench.git

cd kube-bench

kubectl apply -f job.yaml
kubectl apply -f job-master.yaml

kubectl delete -f job-master.yaml
kubectl apply -f job-master.yaml

kubectl get pods

kubectl logs kube-bench > kube-bench-master.log
kubectl logs kube-bench-master-mmfvh > kube-bench-master.log


2. full report  

cd 

curl -L https://github.com/aquasecurity/kube-bench/releases/download/v0.6.2/kube-bench_0.6.2_linux_amd64.tar.gz -o kube-bench_0.6.2_linux_amd64.tar.gz

tar -xvf kube-bench_0.6.2_linux_amd64.tar.gz

sudo mv kube-bench /usr/local/bin/

cd namespaces/kube-bench

kube-bench --config-dir cfg --config cfg/config.yaml --benchmark cis-1.9
