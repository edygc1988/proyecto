# Arquitectura de Microservicios - Solución Completa

## 🏗️ Descripción de la Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                     KUBERNETES CLUSTER                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         NAMESPACE: microservices                      │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │      Service Mesh & Load Balancing             │  │  │
│  │  │  (Ingress/Service Discovery)                   │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  │           ↓                        ↓                   │  │
│  │  ┌──────────────────┐   ┌──────────────────┐         │  │
│  │  │ Microservice 1   │   │ Microservice 2   │         │  │
│  │  │ (CRUD Items)     │   │ (Consumer)       │         │  │
│  │  │ :5000            │   │ :5001            │         │  │
│  │  │ - Deployment (2) │   │ - Deployment (2) │         │  │
│  │  │ - Service        │   │ - Service        │         │  │
│  │  │ - ConfigMap      │   │ - ConfigMap      │         │  │
│  │  │ - HPA            │   │ - HPA            │         │  │
│  │  └────────┬─────────┘   └─────────┬────────┘         │  │
│  │           │                        │                   │  │
│  │           │ DB Connection          │ HTTP Calls       │  │
│  │           ↓                        ↓                   │  │
│  │  ┌──────────────────────────────────────────────┐    │  │
│  │  │          PostgreSQL Database                 │    │  │
│  │  │          StatefulSet (1 replica)             │    │  │
│  │  │          Service + PVC + PV                  │    │  │
│  │  │          Port: 5432                          │    │  │
│  │  └──────────────────────────────────────────────┘    │  │
│  │                                                       │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │       Network Policies (Security)              │  │  │
│  │  │  - Pod-to-Pod communication                   │  │  │
│  │  │  - Egress rules                               │  │  │
│  │  └────────────────────────────────────────────────┘  │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         ↓ (Push de imágenes + Deploy)
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Actions CI/CD                      │
├─────────────────────────────────────────────────────────────┤
│  1. Build Docker Images                                     │
│  2. Run Tests                                               │
│  3. Push to Registry (ghcr.io)                             │
│  4. Apply K8s Manifests                                     │
│  5. Smoke Tests                                             │
│  6. Notification                                            │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Flujo de Comunicación

### Entre Microservicios

```
Cliente HTTP
    ↓
Microservice-2 (5001)
    ↓
[Retry Logic con Timeout]
    ↓
Microservice-1 (5000)  [vía DNS: microservice-1:5000]
    ↓
PostgreSQL (5432)
    ↓
Respuesta JSON
```

### Despliegue CI/CD

```
Push a main
    ↓
GitHub Actions Triggered
    ↓
├─ Build MS1 Docker Image
├─ Build MS2 Docker Image
├─ Run Tests
├─ Push a Registry
    ├─ ghcr.io/user/microservice-1:latest
    ├─ ghcr.io/user/microservice-2:latest
├─ Update k8s.yaml con nuevas refs
├─ Apply Kubernetes Manifests
├─ Wait for Rollout
├─ Run Smoke Tests
└─ Notify Status
```

## 🔐 Componentes de Seguridad

### Network Policies

- **Microservice-1**: Acepta tráfico de MS2 y namespace
- **Microservice-2**: Solo egress a MS1 y DNS
- **PostgreSQL**: Solo ingress desde MS1 y MS2

### Secretos

- ConfigMaps para datos públicos (hosts, ports)
- Secrets para credenciales sensibles (DB_PASSWORD)
- imagePullSecrets para registros privados

### RBAC (Recomendado)

```yaml
# Crear usuarios con permisos limitados
serviceAccountName: microservices
```

## 📊 Escalabilidad

### Horizontal Pod Autoscaler (HPA)

```yaml
Triggers: CPU > 70% OR Memory > 80%
Min Replicas: 2
Max Replicas: 5
Scale Down: -1 pod each 5 minutes
Scale Up: +1 pod each 1 minute
```

### Límites de Recursos

```
MS1: 128Mi RAM / 100m CPU (requests)
     256Mi RAM / 500m CPU (limits)
MS2: Mismo que MS1
PG: 256Mi RAM / 250m CPU
```

## 🗄️ Persistencia

### PostgreSQL Storage

- **Type**: PersistentVolume (hostPath para desarrollo)
- **Capacity**: 10Gi
- **Access Mode**: ReadWriteOnce
- **Storage Class**: standard

Para producción, considerar:

- AWS EBS, GCP Persistent Disks, Azure Disks
- StatefulSet para datos stateful
- Backups automáticos

## 🔄 Health Checks

### Liveness Probe

- Endpoint: `/health`
- Interval: 10s
- Timeout: 5s
- Failure Threshold: 3 (reinicia pod)

### Readiness Probe

- Endpoint: `/health`
- Interval: 5s
- Timeout: 3s
- Failure Threshold: 2 (marca como not ready)

## 📈 Monitoreo y Logging

### Logs por Componente

```
Pod logs: kubectl logs POD_NAME -n microservices
Stream: kubectl logs -f -l app=microservice-1
Previous crashes: kubectl logs --previous POD_NAME
```

### Métricas

```
CPU/Memory: kubectl top pods -n microservices
Pod events: kubectl describe pod POD_NAME
Node usage: kubectl top nodes
```

## 🔄 Variables de Entorno

### Microservice-1

```
FLASK_ENV=production
PORT=5000
DB_HOST=postgres              # Service DNS name
DB_PORT=5432
DB_NAME=microservices_db
DB_USER=postgres
DB_PASSWORD=<from secret>
```

### Microservice-2

```
FLASK_ENV=production
PORT=5001
MICROSERVICE_1_HOST=microservice-1
MICROSERVICE_1_PORT=5000
MICROSERVICE_1_URL=http://microservice-1:5000
```

### PostgreSQL

```
POSTGRES_DB=microservices_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<from secret>
PGDATA=/var/lib/postgresql/data/pgdata
```

## 🚀 Ciclo de Vida de Despliegue

### 1. Rolling Update

```
Existing Pod v1
├─ New Pod v2 starts
├─ New Pod becomes Ready
├─ Old Pod gracefully terminates (preStop: sleep 15s)
└─ Repeat hasta maxUnavailable=0 (zero downtime)
```

### 2. Rollback

```
kubectl rollout undo deployment/microservice-1 -n microservices
```

### 3. Pausa/Resume

```
kubectl rollout pause deployment/microservice-1 -n microservices
kubectl rollout resume deployment/microservice-1 -n microservices
```

## 💾 Base de Datos

### Schema

```sql
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Conexión desde Pods

```
Host: postgres (Kubernetes DNS)
Port: 5432
Database: microservices_db
User: postgres
Password: (from k8s Secret)
```

## 🔗 Networking

### Service Discovery

```
Microservice-1 es accesible como:
- microservice-1           (dentro del namespace)
- microservice-1.microservices     (FQDN)
- microservice-1.microservices.svc.cluster.local
```

### DNS

```
Pod → DNS query → kube-dns (10.x.x.x:53)
     → Service → Endpoints
     → Load Balance a Pods
```

## 📋 Checklist de Despliegue

- [ ] Cambiar `your-repo` en k8s.yaml por tu registro
- [ ] Crear KUBECONFIG secret en GitHub
- [ ] Verificar acceso al cluster: `kubectl cluster-info`
- [ ] Crear namespace: `kubectl create namespace microservices`
- [ ] Aplicar manifests: `kubectl apply -f k8s/k8s.yaml`
- [ ] Verificar pods: `kubectl get pods -n microservices`
- [ ] Verificar services: `kubectl get svc -n microservices`
- [ ] Port-forward para testing
- [ ] Ejecutar tests: curl http://localhost:5000/health
- [ ] Verificar logs: `kubectl logs -n microservices -f -l app=microservice-1`
- [ ] Verificar DB: `kubectl exec -it postgres-0 -n microservices -- psql -U postgres`

---

**Documentación técnica de la arquitectura**
