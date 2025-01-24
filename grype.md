#Grype 

```bash
sudo curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
```


```bash
kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort | uniq
grype "registry.k8s.io/kube-apiserver:v1.32.0"
```


vi grypescan.sh 

```bash
#!/bin/bash

for image in $(kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort | uniq); do
        echo scanning $image
        #grype "$image"
        echo completed 
done

```

#Trivy

```bash
sudo apt install wget gnupg
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt install trivy
```


```bash
kubectl get pods -A -o=jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort | uniq

trivy image nginxdemos/nginx-hello:plain-text --scanners vuln
```


