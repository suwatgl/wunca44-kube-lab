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


```bash
trivy image ubuntu --scanners vuln
```

wunca44@master1:~$ trivy image ubuntu --scanners vuln
2025-01-24T04:35:03Z	INFO	[vuln] Vulnerability scanning is enabled
2025-01-24T04:35:09Z	INFO	Detected OS	family="ubuntu" version="24.04"
2025-01-24T04:35:09Z	INFO	[ubuntu] Detecting vulnerabilities...	os_version="24.04" pkg_num=91
2025-01-24T04:35:09Z	INFO	Number of language-specific files	num=0

ubuntu (ubuntu 24.04)

Total: 16 (UNKNOWN: 0, LOW: 6, MEDIUM: 10, HIGH: 0, CRITICAL: 0)

┌────────────────────┬────────────────┬──────────┬──────────┬─────────────────────────┬───────────────┬──────────────────────────────────────────────────────────────┐
│      Library       │ Vulnerability  │ Severity │  Status  │    Installed Version    │ Fixed Version │                            Title                             │
├────────────────────┼────────────────┼──────────┼──────────┼─────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ coreutils          │ CVE-2016-2781  │ LOW      │ affected │ 9.4-3ubuntu6            │               │ coreutils: Non-privileged session can escape to the parent   │
│                    │                │          │          │                         │               │ session in chroot                                            │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2016-2781                    │
├────────────────────┼────────────────┤          │          ├─────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ gpgv               │ CVE-2022-3219  │          │          │ 2.4.4-2ubuntu17         │               │ gnupg: denial of service issue (resource consumption) using  │
│                    │                │          │          │                         │               │ compressed packets                                           │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2022-3219                    │
├────────────────────┼────────────────┤          │          ├─────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ libc-bin           │ CVE-2016-20013 │          │          │ 2.39-0ubuntu8.3         │               │ sha256crypt and sha512crypt through 0.6 allow attackers to   │
│                    │                │          │          │                         │               │ cause a denial of...                                         │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2016-20013                   │
├────────────────────┤                │          │          │                         ├───────────────┤                                                              │
│ libc6              │                │          │          │                         │               │                                                              │
│                    │                │          │          │                         │               │                                                              │
│                    │                │          │          │                         │               │                                                              │
├────────────────────┼────────────────┤          │          ├─────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ libgcrypt20        │ CVE-2024-2236  │          │          │ 1.10.3-2build1          │               │ libgcrypt: vulnerable to Marvin Attack                       │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-2236                    │
├────────────────────┼────────────────┼──────────┤          ├─────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ libpam-modules     │ CVE-2024-10041 │ MEDIUM   │          │ 1.5.3-5ubuntu5.1        │               │ pam: libpam: Libpam vulnerable to read hashed password       │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10041                   │
│                    ├────────────────┤          │          │                         ├───────────────┼──────────────────────────────────────────────────────────────┤
│                    │ CVE-2024-10963 │          │          │                         │               │ pam: Improper Hostname Interpretation in pam_access Leads to │
│                    │                │          │          │                         │               │ Access Control Bypass                                        │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10963                   │
├────────────────────┼────────────────┤          │          │                         ├───────────────┼──────────────────────────────────────────────────────────────┤
│ libpam-modules-bin │ CVE-2024-10041 │          │          │                         │               │ pam: libpam: Libpam vulnerable to read hashed password       │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10041                   │
│                    ├────────────────┤          │          │                         ├───────────────┼──────────────────────────────────────────────────────────────┤
│                    │ CVE-2024-10963 │          │          │                         │               │ pam: Improper Hostname Interpretation in pam_access Leads to │
│                    │                │          │          │                         │               │ Access Control Bypass                                        │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10963                   │
├────────────────────┼────────────────┤          │          │                         ├───────────────┼──────────────────────────────────────────────────────────────┤
│ libpam-runtime     │ CVE-2024-10041 │          │          │                         │               │ pam: libpam: Libpam vulnerable to read hashed password       │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10041                   │
│                    ├────────────────┤          │          │                         ├───────────────┼──────────────────────────────────────────────────────────────┤
│                    │ CVE-2024-10963 │          │          │                         │               │ pam: Improper Hostname Interpretation in pam_access Leads to │
│                    │                │          │          │                         │               │ Access Control Bypass                                        │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10963                   │
├────────────────────┼────────────────┤          │          │                         ├───────────────┼──────────────────────────────────────────────────────────────┤
│ libpam0g           │ CVE-2024-10041 │          │          │                         │               │ pam: libpam: Libpam vulnerable to read hashed password       │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10041                   │
│                    ├────────────────┤          │          │                         ├───────────────┼──────────────────────────────────────────────────────────────┤
│                    │ CVE-2024-10963 │          │          │                         │               │ pam: Improper Hostname Interpretation in pam_access Leads to │
│                    │                │          │          │                         │               │ Access Control Bypass                                        │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-10963                   │
├────────────────────┼────────────────┼──────────┤          ├─────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ libssl3t64         │ CVE-2024-41996 │ LOW      │          │ 3.0.13-0ubuntu3.4       │               │ openssl: remote attackers (from the client side) to trigger  │
│                    │                │          │          │                         │               │ unnecessarily expensive server-side...                       │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-41996                   │
├────────────────────┼────────────────┼──────────┤          ├─────────────────────────┼───────────────┼──────────────────────────────────────────────────────────────┤
│ login              │ CVE-2024-56433 │ MEDIUM   │          │ 1:4.13+dfsg1-4ubuntu3.2 │               │ shadow-utils: Default subordinate ID configuration in        │
│                    │                │          │          │                         │               │ /etc/login.defs could lead to compromise                     │
│                    │                │          │          │                         │               │ https://avd.aquasec.com/nvd/cve-2024-56433                   │
├────────────────────┤                │          │          │                         ├───────────────┤                                                              │
│ passwd             │                │          │          │                         │               │                                                              │
│                    │                │          │          │                         │               │                                                              │
│                    │                │          │          │                         │               │                                                              │
└────────────────────┴────────────────┴──────────┴──────────┴─────────────────────────┴───────────────┴──────────────────────────────────────────────────────────────┘

