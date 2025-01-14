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

