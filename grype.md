sudo curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin


kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort | uniq

single image 
grype "<image name>"


all images 

vi grypescan.sh 

#!/bin/bash

for image in $(kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort | uniq); do
        echo scanning $image
        #grype "$image"
        echo completed 
done
