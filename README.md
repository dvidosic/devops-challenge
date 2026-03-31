# DevOps Internship Challenge

## What I Built

A containerized nginx web server built with Docker, pushed to Docker Hub, deployed on an Azure VM, and then taken to Kubernetes (AKS) with Traefik as the ingress controller.

> README based on notes written during implementation. Full unedited notes available in the [Wiki](https://github.com/dvidosic/devops-challenge/wiki).

**Part 1 — Live at:** [http://20.203.245.187](http://20.203.245.187)

<img width="1914" height="1032" alt="Screenshot_8" src="https://github.com/user-attachments/assets/90f93396-e484-4785-9fc8-a0328c9255c1" />

---


**Part 2 — Live at:** [http://20.250.80.162](http://20.250.80.162)

<img width="1919" height="1040" alt="Screenshot_9" src="https://github.com/user-attachments/assets/53fcc73d-17d1-42de-8106-d9af1a74002d" />


---

## Architecture

### Part 1 — VM & Docker

```
Browser
  |
  | HTTP request port 80
  v
Azure NSG (firewall — port 80 open)
  |
  v
Azure VM (Ubuntu 24.04 — devops-vm)
  |
  | port binding -p 80:80
  v
Docker container (nginx-app)
  |
  v
nginx → serves index.html (name is displayed)
```

### Part 2 — Kubernetes (AKS)

```
Browser
  |
  | HTTP request http://20.250.80.162
  v
Azure Load Balancer (provisioned automatically by Traefik)
  |
  v
Traefik Pod (Ingress Controller — reads ingress.yaml rules)
  |
  v
nginx-service (ClusterIP — internal load balancing)
  |           |
  v           v
nginx Pod 1  nginx Pod 2
  |
  v
index.html → name displayed
```

---

## Repository Structure

```
devops-challenge/
├── Dockerfile              # Custom nginx image definition
├── index.html              # HTML page served by nginx (my name)
├── deployment.yaml         # Kubernetes Deployment — 2 nginx replicas
├── service.yaml            # Kubernetes Service — ClusterIP internal endpoint
├── ingress.yaml            # Kubernetes Ingress — Traefik routing rules
├── README.md
└── terraform/
    ├── vm/
    │   ├── main.tf         # VM, VNet, NSG, disk, NIC, public IP
    │   ├── variables.tf    # Configurable values
    │   └── outputs.tf      # Public IP, SSH command
    └── aks/
        ├── main.tf         # AKS cluster, identity, network profile
        ├── variables.tf    # Configurable values
        └── outputs.tf      # Cluster name, API endpoint, kubeconfig
```

---

## Part 1 — VM & Docker

### Infrastructure

- **Cloud:** Microsoft Azure (Azure for Students — Region: Switzerland North)
- **VM:** Ubuntu 24.04 LTS, Standard_B2ls_v2 (2 vCPU, 4GB RAM)
- **User:** `devops` (SSH key-based auth only, password login disabled)
- **Data disk:** 32GB Standard LRS — mounted at `/mnt/docker-data`, configured as Docker data root

### SSH Hardening

After VM creation, SSH was hardened in `/etc/ssh/sshd_config`:

```
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
```

Verified with:

```bash
sudo sshd -T | grep -E "passwordauthentication|permitrootlogin|pubkeyauthentication"
```

### Docker Data Disk

Docker was configured to store all data on a separate 32GB disk instead of the OS disk.

```bash
# Format and mount the disk
sudo mkfs.ext4 /dev/sdb
sudo mkdir -p /mnt/docker-data
sudo mount /dev/sdb /mnt/docker-data

# Persist mount across reboots
echo 'UUID=a987be8c-9b53-435f-a9eb-061b7b605a3d /mnt/docker-data ext4 defaults 0 2' | sudo tee -a /etc/fstab

# Configure Docker to use the new disk
sudo nano /etc/docker/daemon.json
# { "data-root": "/mnt/docker-data" }
```

### Docker Image

Built a custom nginx image based on `nginx:1.25-alpine`

```dockerfile
FROM nginx:1.25-alpine
LABEL maintainer="david.vidosic16@gmail.com"
RUN rm -rf /usr/share/nginx/html/*
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```bash
# Build
docker build -t dvidosic/nginx-devops:1.0 .

# Push to Docker Hub
docker push dvidosic/nginx-devops:1.0

# Run on VM
docker run -d --name nginx-app --restart unless-stopped -p 80:80 dvidosic/nginx-devops:1.0
```

Docker Hub: [hub.docker.com/r/dvidosic/nginx-devops](https://hub.docker.com/r/dvidosic/nginx-devops)

---

## Part 2 — Kubernetes (AKS)

### Cluster

- **Type:** Azure Kubernetes Service (AKS) — managed Kubernetes
- **Node:** 1 × Standard_B2ls_v2 (2 vCPU, 4GB RAM)
- **Kubernetes version:** 1.33.7

```bash
az aks create --resource-group devops-rg --name devops-aks --node-count 1 --node-vm-size Standard_B2ls_v2 --generate-ssh-keys --enable-managed-identity
```

```bash
# Connect kubectl to cluster
az aks get-credentials --resource-group devops-rg --name devops-aks
```

### Deployment

2 nginx replicas running in the `nginx-app` namespace with resource limits set.

- **Service type:** ClusterIP — internal only, not reachable from internet directly
- **Replicas:** 2 — if one pod crashes, the other continues serving traffic

### Traefik Ingress Controller

Traefik was installed via Helm as the ingress controller.

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
kubectl create namespace traefik
helm install traefik traefik/traefik --namespace traefik
```

After installation Traefik received external IP `20.250.80.162` from Azure.

<img width="622" height="46" alt="Screenshot_11" src="https://github.com/user-attachments/assets/7bb7e9f6-3db6-4935-b9a2-c9fa42f8c635" />


### How Traffic Flows

1. Browser sends HTTP GET to `http://20.250.80.162`
2. Azure Load Balancer routes the connection to the AKS node
3. Traefik pod receives the request and reads routing rules from `ingress.yaml`
4. Traefik forwards to `nginx-service` (ClusterIP) on port 80
5. Kubernetes Service selects one of 2 healthy nginx pods
6. nginx pod returns `index.html`
7. Browser displays the page

### Service Types Used

| Type         | Used for        | Reason                                            |
| ------------ | --------------- | ------------------------------------------------- |
| ClusterIP    | nginx-service   | Internal only — Traefik handles external access   |
| LoadBalancer | Traefik service | Single public IP entry point for all HTTP traffic |

---

## Problems & Solutions

### 1. VM size Standard_B2s not available in Switzerland North

**Problem:** Running `az aks create` with `--node-vm-size Standard_B2s` returned an error — this size is not allowed in Switzerland North for AKS.  
**Solution:** Switched to `Standard_B2ls_v2` which is available in the region and has the same 2 vCPU / 4GB RAM spec.

### 2. Basic load balancer SKU not allowed

**Problem:** Using `--load-balancer-sku basic` in `az aks create` returned an error — Azure now requires Standard SKU for AKS load balancers.  
**Solution:** Removed the `--load-balancer-sku` flag entirely and let Azure use the Standard SKU by default.

### 3. Microsoft.ContainerService provider not registered

**Problem:** Running `az aks create` failed with `MissingSubscriptionRegistration` — the Azure subscription was not registered for the Kubernetes service.  
**Solution:** Manually registered the provider and waited for it to complete:

```bash
az provider register --namespace Microsoft.ContainerService
az provider show --namespace Microsoft.ContainerService --query registrationState
```

---

## Technologies Used

| Technology       | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| Microsoft Azure  | Cloud provider (VM, AKS, disks, networking)          |
| Ubuntu 24.04 LTS | Linux OS on the VM                                   |
| Docker           | Containerization — build and run nginx image         |
| nginx (alpine)   | Web server — serves HTML page                        |
| Docker Hub       | Container registry — stores the image                |
| Kubernetes (AKS) | Container orchestration                              |
| Traefik          | Ingress controller — HTTP traffic routing            |
| Helm             | Kubernetes package manager — used to install Traefik |
| Azure CLI        | Infrastructure provisioning from command line        |
| kubectl          | Kubernetes cluster management                        |

## Bonus — Infrastructure as Code (Terraform)

Terraform code is provided in the `terraform/` directory to provision the same
infrastructure declaratively instead of manually via Azure CLI.

> Terraform code was written with AI assistance (Claude) and reviewed afterwards
> for this project's specific Azure configuration and region constraints.

### Structure

```
terraform/
├── vm/
│   ├── main.tf        # VM, VNet, NSG, disk, NIC, public IP
│   ├── variables.tf   # Configurable values (region, VM size, etc.)
│   └── outputs.tf     # Public IP, SSH command
└── aks/
    ├── main.tf        # AKS cluster, identity, network profile
    ├── variables.tf   # Configurable values (node count, VM size, etc.)
    └── outputs.tf     # Cluster name, API endpoint, kubeconfig
```

### What It Provisions

**VM project** — 10 resources:

- Resource Group
- Virtual Network + Subnet
- Public IP (static)
- Network Security Group (ports 22 and 80 open)
- Network Interface + NSG association
- 32GB Managed Disk (Docker data)
- Linux Virtual Machine (Ubuntu 22.04, Standard_B2ls_v2)
- Data disk attachment

**AKS project** — 2 resources:

- Resource Group
- AKS cluster (1 node, Standard_B2ls_v2, Kubernetes 1.33)

### Limitation Encountered

During `terraform apply` for the VM project, the Public IP resource failed with:

```
Error: PublicIPCountLimitReached: Cannot create more than 3 public IP addresses
for this subscription in this region.
```

Azure for Students subscriptions are limited to **3 public IP addresses per region**.
At the time of running Terraform, all 3 were already in use.

`terraform plan` completed successfully and confirmed all 10 resources were
correctly defined — the failure was a subscription limitation, not a
code issue. The remaining 5 resources that were created before the error were
cleaned up with `terraform destroy`.

<img width="932" height="158" alt="Screenshot_14" src="https://github.com/user-attachments/assets/ffe31c5b-cd32-47c5-bde5-b0c9e5a8286c" />


