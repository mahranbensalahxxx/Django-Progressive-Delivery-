# 🚀 Progressive Delivery for Django

**Topic 33** — Progressive Delivery using Django, Docker, Kubernetes (Minikube), and Argo Rollouts.

This project demonstrates three progressive delivery strategies:
1. **Canary Deployment** — Gradual traffic shifting with automated health analysis (Student 1)
2. **Blue-Green Deployment** — Zero-downtime traffic switching (Student 2)
3. **Shadow Traffic** — Silent traffic mirroring via NGINX (Student 3)

---

## 📁 Project Structure

```
progressive-delivery-django/
├── django-app/                  # Shared Django codebase (v1 and v2)
│   ├── manage.py
│   ├── progressive_delivery/    # Django project config
│   │   ├── __init__.py
│   │   ├── settings.py
│   │   ├── urls.py
│   │   ├── wsgi.py
│   │   └── asgi.py
│   ├── core/                    # Main application
│   │   ├── __init__.py
│   │   ├── apps.py
│   │   ├── views.py
│   │   ├── urls.py
│   │   └── templates/
│   │       └── home.html
│   ├── requirements.txt
│   └── Dockerfile
├── k8s/                         # Kubernetes manifests
│   ├── namespace.yaml
│   ├── django-service.yaml      # Student 2: Service with blue/green selector
│   ├── blue-deployment.yaml     # Student 2: Blue (v1) Deployment
│   ├── green-deployment.yaml    # Student 2: Green (v2) Deployment
│   ├── rollout-canary.yaml      # Student 1: Argo Rollout (Canary)
│   ├── analysis-template.yaml   # Student 1: Health check analysis
│   ├── nginx-configmap.yaml     # Student 3: NGINX mirror config
│   ├── nginx-deployment.yaml    # Student 3: NGINX proxy deployment
│   └── nginx-service.yaml       # Student 3: NGINX service
├── nginx/                       # NGINX configurations
│   ├── nginx.conf               # For Kubernetes
│   └── nginx-docker.conf        # For Docker Compose (local testing)
├── scripts/                     # Helper scripts
│   ├── deploy-canary.sh         # Student 1: Deploy canary rollout
│   ├── switch-blue-green.sh     # Student 2: Switch blue ↔ green
│   └── run-shadow-test.sh       # Student 3: Test shadow traffic
├── docker-compose.yml           # Local testing without K8s
├── .gitignore
└── README.md
```

---

## 🔧 Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 24+ | Build container images |
| Minikube | 1.32+ | Local Kubernetes cluster |
| kubectl | 1.28+ | Kubernetes CLI |
| Argo Rollouts | latest | Canary deployment controller |
| Git | 2.40+ | Version control |

---

## 🚀 Quick Start (Full Setup)

### 1. Start Minikube

```bash
minikube start --driver=docker
minikube addons enable ingress
```

### 2. Install Argo Rollouts (Student 1)

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### 3. Build Docker Images

```bash
# Build v1 image
docker build -t django-progressive:v1 -f django-app/Dockerfile django-app/

# Edit django-app/core/views.py → Change VERSION = "v1.0" to VERSION = "v2.0"
# Build v2 image
docker build -t django-progressive:v2 -f django-app/Dockerfile django-app/

# Load images into Minikube
minikube image load django-progressive:v1
minikube image load django-progressive:v2
```

### 4. Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml
kubectl config set-context --current --namespace=progressive-django

# Deploy Blue-Green (Student 2)
kubectl apply -f k8s/blue-deployment.yaml
kubectl apply -f k8s/green-deployment.yaml
kubectl apply -f k8s/django-service.yaml

# Deploy NGINX Shadow (Student 3)
kubectl apply -f k8s/nginx-configmap.yaml
kubectl apply -f k8s/nginx-deployment.yaml
kubectl apply -f k8s/nginx-service.yaml

# Deploy Canary (Student 1)
kubectl apply -f k8s/analysis-template.yaml
kubectl apply -f k8s/rollout-canary.yaml
```

### 5. Test

```bash
# Get service URL
minikube service django-service -n progressive-django --url

# Test the endpoint
curl <service-url>
curl <service-url>/healthz
```

---

## 🐦 Student 1: Canary Deployment (Argo Rollouts)

### How It Works
- Uses Argo Rollouts to gradually shift traffic: **20% → 50% → analysis → 100%**
- AnalysisTemplate monitors error rate via Prometheus
- If error rate exceeds 10%, Argo **automatically rolls back**

### Key Commands
```bash
# Deploy canary
bash scripts/deploy-canary.sh

# Trigger canary update to v2
kubectl argo rollouts set image django-rollout django=django-progressive:v2 -n progressive-django

# Watch rollout progress
kubectl argo rollouts get rollout django-rollout -n progressive-django --watch

# Manual promote (if paused)
kubectl argo rollouts promote django-rollout -n progressive-django

# Abort/rollback
kubectl argo rollouts abort django-rollout -n progressive-django
```

### Files
- `k8s/rollout-canary.yaml` — Argo Rollout definition
- `k8s/analysis-template.yaml` — Prometheus error rate check
- `scripts/deploy-canary.sh` — Deployment script

---

## 🔵🟢 Student 2: Blue-Green Deployment

### How It Works
- Two identical Deployments run simultaneously (Blue = v1, Green = v2)
- Service selector points to one version at a time
- **Zero-downtime** switch by patching the Service selector

### Key Commands
```bash
# Switch traffic (blue ↔ green)
bash scripts/switch-blue-green.sh

# Or manually:
kubectl patch service django-service -n progressive-django \
  -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback:
kubectl patch service django-service -n progressive-django \
  -p '{"spec":{"selector":{"version":"blue"}}}'

# Verify current active version
kubectl get service django-service -n progressive-django -o jsonpath='{.spec.selector.version}'
```

### Files
- `k8s/blue-deployment.yaml` — Blue (v1) Deployment
- `k8s/green-deployment.yaml` — Green (v2) Deployment
- `k8s/django-service.yaml` — Service with version selector
- `scripts/switch-blue-green.sh` — Switch script

---

## 👻 Student 3: Shadow Traffic (NGINX Mirror)

### How It Works
- NGINX reverse proxy sits in front of Blue (v1)
- All incoming requests are **mirrored** to Green (v2) silently
- User only sees Blue response; Green processes the request for testing
- Allows testing v2 with real production traffic **without user impact**

### Key Commands
```bash
# Deploy and test shadow traffic
bash scripts/run-shadow-test.sh

# Check Green pod logs for mirrored requests
kubectl logs -l version=green -n progressive-django --tail=20

# Port-forward to test manually
kubectl port-forward service/nginx-shadow-service 8080:80 -n progressive-django
curl http://localhost:8080/
```

### Files
- `nginx/nginx.conf` — NGINX mirror configuration
- `k8s/nginx-configmap.yaml` — ConfigMap for NGINX config
- `k8s/nginx-deployment.yaml` — NGINX proxy Deployment
- `k8s/nginx-service.yaml` — NGINX proxy Service
- `scripts/run-shadow-test.sh` — Shadow test script

---

## 🧪 Local Testing (Docker Compose)

Test without Kubernetes using Docker Compose:

```bash
# Start all services
docker-compose up --build

# Blue (v1): http://localhost:8001
# Green (v2): http://localhost:8002
# Shadow Proxy: http://localhost:8080 (mirrors to Green)

# Test
curl http://localhost:8001/      # Direct Blue
curl http://localhost:8002/      # Direct Green
curl http://localhost:8080/      # Through shadow proxy

# Stop
docker-compose down
```

---

## 🌿 Git Branch Strategy

| Branch | Owner | Contents |
|--------|-------|----------|
| `main` | All | Final integrated system |
| `student1-canary` | Student 1 | Canary + Argo Rollouts files |
| `student2-bluegreen` | Student 2 | Blue-Green deployment files |
| `student3-shadow` | Student 3 | Shadow + NGINX files |

### Merge Instructions
1. Each student pushes their branch with their responsible files + shared base
2. Use `git merge` or Pull Requests with conflict resolution
3. Final integration on `main` combines all strategies
4. Resolve conflicts in `k8s/` by including all resources (they coexist)

---

## 📊 Health Metric Simulation

- **v1** (`VERSION = "v1.0"`): Always returns 200 OK
- **v2** (`VERSION = "v2.0"`): Returns 500 error ~15% of the time (simulated)
- This error rate triggers Argo Rollout's automatic rollback when it exceeds the 10% threshold

---

## 📚 References

- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Martin Fowler — Canary Release](https://martinfowler.com/bliki/CanaryRelease.html)
- [Google SRE Workbook](https://sre.google/workbook/table-of-contents/)
- [NGINX Mirror Module](https://nginx.org/en/docs/http/ngx_http_mirror_module.html)
- [Kubernetes Blue-Green Deployments](https://kubernetes.io/blog/2018/04/30/zero-downtime-deployment-kubernetes-jenkins/)

---

## 👥 Contributors

| Student | Responsibility | Files |
|---------|---------------|-------|
| Student 1 | Canary + Argo Rollouts | `rollout-canary.yaml`, `analysis-template.yaml`, `deploy-canary.sh` |
| Student 2 | Blue-Green Deployment | `blue-deployment.yaml`, `green-deployment.yaml`, `django-service.yaml`, `switch-blue-green.sh` |
| Student 3 | Shadow Traffic (NGINX) | `nginx.conf`, `nginx-configmap.yaml`, `nginx-deployment.yaml`, `run-shadow-test.sh` |
#   D j a n g o - P r o g r e s s i v e - D e l i v e r y -  
 