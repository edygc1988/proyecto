# Guía Completa de Despliegue - Solución Microservicios

## 📋 Tabla de Contenidos

1. [Descripción General](#descripción-general)
2. [Estructura del Proyecto](#estructura-del-proyecto)
3. [Prerequisitos](#prerequisitos)
4. [Instalación Local](#instalación-local)
5. [Configuración Docker](#configuración-docker)
6. [Despliegue en Kubernetes](#despliegue-en-kubernetes)
7. [Configuración CI/CD](#configuración-cicd)
8. [Testing y Verificación](#testing-y-verificación)
9. [Troubleshooting](#troubleshooting)
10. [Monitoreo](#monitoreo)

---

## 📌 Descripción General

Esta solución implementa una arquitectura de microservicios con dos servicios Python/Flask:

### Microservicio 1 - CRUD de Items

- **Puerto**: 5000
- **Base de datos**: PostgreSQL
- **Endpoints**: GET/POST /items, GET/PUT/DELETE /items/{id}
- **Responsabilidad**: Gestionar items en base de datos

### Microservicio 2 - Consumidor

- **Puerto**: 5001
- **Dependencia**: Microservicio 1
- **Endpoints**: GET/POST /items (proxy hacia MS1)
- **Responsabilidad**: Consumir y exponer datos de MS1

### PostgreSQL

- **Puerto**: 5432
- **Volumen**: PersistentVolume para datos
- **Usuario**: postgres (configurable)

---

## 📁 Estructura del Proyecto

```
proyecto/
├── microservice-1/
│   ├── app.py                 # Aplicación Flask CRUD
│   ├── requirements.txt       # Dependencias Python
│   └── Dockerfile            # Imagen Docker
├── microservice-2/
│   ├── app.py                 # Aplicación Flask consumidora
│   ├── requirements.txt       # Dependencias Python
│   └── Dockerfile            # Imagen Docker
├── k8s/
│   └── k8s.yaml              # Configuración Kubernetes completa
├── .github/workflows/
│   └── deploy.yml            # Pipeline GitHub Actions
└── README.md                 # Este archivo
```

---

## 🔧 Prerequisitos

### Para desarrollo local:

- Python 3.11+
- PostgreSQL 15+
- pip

### Para Docker:

- Docker Desktop 4.0+
- Docker Compose (opcional)

### Para Kubernetes:

- kubectl 1.24+
- Acceso a cluster Kubernetes (local o nube)
- kubeconfig configurado

### Para CI/CD:

- Repositorio GitHub
- Registro Docker (GitHub Container Registry, Docker Hub, etc.)

---

## 🚀 Instalación Local

### 1. Clonar el repositorio

```bash
cd ~/ruta/al/proyecto
```

### 2. Configurar Microservicio 1

```bash
cd microservice-1

# Crear entorno virtual
python3 -m venv venv
source venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt

# Configurar variables de entorno
cat > .env << EOF
FLASK_ENV=development
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=microservices_db
DB_USER=postgres
DB_PASSWORD=postgres
EOF

# Ejecutar aplicación
python app.py
```

### 3. Configurar Microservicio 2

```bash
cd ../microservice-2

# Crear entorno virtual
python3 -m venv venv
source venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt

# Configurar variables de entorno
cat > .env << EOF
FLASK_ENV=development
PORT=5001
MICROSERVICE_1_URL=http://localhost:5000
EOF

# Ejecutar aplicación
python app.py
```

### 4. Configurar PostgreSQL localmente

```bash
# Crear base de datos
createdb -U postgres microservices_db

# O usando Docker:
docker run --name postgres-local \
  -e POSTGRES_DB=microservices_db \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -d postgres:15-alpine
```

### 5. Pruebas locales

```bash
# Health check MS1
curl http://localhost:5000/health

# Health check MS2
curl http://localhost:5001/health

# Crear item en MS1
curl -X POST http://localhost:5000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Test Description"}'

# Obtener items desde MS2 (que consume MS1)
curl http://localhost:5001/items
```

---

## 🐳 Configuración Docker

### 1. Construir imágenes localmente

```bash
# Microservicio 1
docker build -t microservice-1:latest ./microservice-1

# Microservicio 2
docker build -t microservice-2:latest ./microservice-2
```

### 2. Ejecutar con Docker Compose

Crear archivo `docker-compose.yml`:

```yaml
version: "3.8"

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: microservices_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  microservice-1:
    build: ./microservice-1
    ports:
      - "5000:5000"
    environment:
      FLASK_ENV: development
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: microservices_db
      DB_USER: postgres
      DB_PASSWORD: postgres
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  microservice-2:
    build: ./microservice-2
    ports:
      - "5001:5001"
    environment:
      FLASK_ENV: development
      MICROSERVICE_1_URL: http://microservice-1:5000
    depends_on:
      - microservice-1
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres-data:
```

Ejecutar:

```bash
docker-compose up -d
docker-compose logs -f
```

### 3. Publicar imágenes en registro

```bash
# Hacer login en tu registro (GitHub Container Registry en este ejemplo)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Etiquetar y publicar MS1
docker tag microservice-1:latest ghcr.io/your-username/microservice-1:latest
docker push ghcr.io/your-username/microservice-1:latest

# Etiquetar y publicar MS2
docker tag microservice-2:latest ghcr.io/your-username/microservice-2:latest
docker push ghcr.io/your-username/microservice-2:latest
```

---

## ☸️ Despliegue en Kubernetes

### Opción 1: Cluster local (Docker Desktop)

```bash
# Habilitar Kubernetes en Docker Desktop
# Settings → Kubernetes → Enable Kubernetes

# Verificar conexión
kubectl cluster-info
kubectl get nodes
```

### Opción 2: Minikube

```bash
# Instalar Minikube
brew install minikube

# Iniciar cluster
minikube start --cpus=4 --memory=8192

# Configurar Docker para usar Minikube
eval $(minikube docker-env)
```

### Opción 3: Cluster en la nube (AWS EKS, GKE, AKS)

```bash
# Para AWS EKS
aws eks create-cluster --name my-cluster --version 1.27 ...
aws eks update-kubeconfig --region us-east-1 --name my-cluster

# Para GKE
gcloud container clusters create my-cluster --zone us-central1-a

# Para AKS
az aks create --resource-group myResourceGroup --name myCluster
az aks get-credentials --resource-group myResourceGroup --name myCluster
```

### Desplegar en el cluster

```bash
# 1. Actualizar referencias de imagen en k8s.yaml
sed -i 's|your-repo/microservice-1|ghcr.io/your-username/microservice-1|g' k8s/k8s.yaml
sed -i 's|your-repo/microservice-2|ghcr.io/your-username/microservice-2|g' k8s/k8s.yaml

# 2. Aplicar configuración
kubectl apply -f k8s/k8s.yaml

# 3. Verificar despliegue
kubectl get pods -n microservices
kubectl get svc -n microservices
kubectl get pvc -n microservices

# 4. Ver logs
kubectl logs -n microservices -l app=microservice-1
kubectl logs -n microservices -l app=microservice-2
kubectl logs -n microservices -l app=postgres

# 5. Port-forward para testing
kubectl port-forward -n microservices svc/microservice-1 5000:5000
kubectl port-forward -n microservices svc/microservice-2 5001:5001

# En otra terminal:
curl http://localhost:5000/health
curl http://localhost:5001/health
```

### Actualizar despliegue

```bash
# Actualizar imagen
kubectl set image deployment/microservice-1 \
  microservice-1=ghcr.io/your-username/microservice-1:new-tag \
  -n microservices

# Monitorear rollout
kubectl rollout status deployment/microservice-1 -n microservices

# Revertir si hay problemas
kubectl rollout undo deployment/microservice-1 -n microservices
```

### Eliminar despliegue

```bash
kubectl delete -f k8s/k8s.yaml
kubectl delete namespace microservices
```

---

## 🔄 Configuración CI/CD

### Prerequisitos en GitHub

1. **Crear un token de acceso**:

   - GitHub → Settings → Developer settings → Personal access tokens
   - Crear token con permisos `write:packages, read:packages`

2. **Configurar secretos en el repositorio**:

   - GitHub → Repository Settings → Secrets and variables → Actions
   - Crear secreto: `KUBECONFIG`
     ```bash
     # Codificar kubeconfig
     cat ~/.kube/config | base64 | pbcopy  # macOS
     cat ~/.kube/config | base64 -w 0      # Linux
     ```
   - Pegar el valor en el secreto

3. **Actualizar referencias en GitHub Actions**:
   - Reemplazar `your-repo` por tu usuario/organización

### Workflow automático

Cuando hagas push a la rama `main`:

1. ✅ Se construyen las imágenes Docker
2. ✅ Se ejecutan tests (si existen)
3. ✅ Se publican las imágenes en el registro
4. ✅ Se aplica la configuración Kubernetes
5. ✅ Se ejecutan smoke tests
6. ✅ Se notifica el resultado

### Ejecutar manualmente

```bash
# En GitHub UI:
# Actions → CI/CD Pipeline → Run workflow

# O vía CLI:
gh workflow run deploy.yml --ref main
```

### Logs del workflow

```bash
# Ver último workflow
gh run list --workflow=deploy.yml --limit 5

# Ver detalles de un run
gh run view RUN_ID --log
```

---

## 🧪 Testing y Verificación

### Tests unitarios

Crear `microservice-1/tests/test_app.py`:

```python
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'

def test_get_items_empty(client):
    response = client.get('/items')
    assert response.status_code == 200
    assert response.json['count'] == 0
```

Ejecutar:

```bash
cd microservice-1
pip install pytest
pytest tests/ -v
```

### Tests de integración

```bash
# Verificar conectividad entre servicios
curl -X POST http://localhost:5001/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Integration Test","description":"Testing MS1-MS2"}'

# Verificar que MS2 puede leer de MS1
curl http://localhost:5001/items

# Verificar conectividad a base de datos
kubectl exec -it -n microservices postgres-0 -- \
  psql -U postgres -d microservices_db -c "SELECT COUNT(*) FROM items;"
```

### Tests de carga

```bash
# Instalar Apache Bench
brew install ab  # macOS

# Test de carga en MS1
ab -n 1000 -c 10 http://localhost:5000/items

# Test de carga en MS2
ab -n 1000 -c 10 http://localhost:5001/items
```

---

## ❌ Troubleshooting

### Problemas comunes y soluciones

#### 1. Error de conexión a PostgreSQL

**Síntoma**: `psycopg2.OperationalError: could not connect to server`

**Solución**:

```bash
# Verificar que PostgreSQL está corriendo
docker ps | grep postgres

# Verificar credenciales
export PGPASSWORD=postgres
psql -h localhost -U postgres -d microservices_db -c "SELECT 1"

# Resetear volumen de datos (cuidado, borra datos)
kubectl delete pvc postgres-pvc -n microservices
```

#### 2. Microservicio 2 no puede conectar a MS1

**Síntoma**: `ConnectionError: No such host is known`

**Solución**:

```bash
# Verificar DNS dentro del pod
kubectl exec -it -n microservices deployment/microservice-2 -- nslookup microservice-1

# Verificar network policies
kubectl get networkpolicies -n microservices

# Verificar logs del pod
kubectl logs -n microservices -l app=microservice-2 --tail=50
```

#### 3. Pods en estado CrashLoopBackOff

**Síntoma**: `CrashLoopBackOff` en `kubectl get pods`

**Solución**:

```bash
# Ver logs detallados
kubectl logs -n microservices -l app=microservice-1 --previous

# Verificar eventos
kubectl describe pod POD_NAME -n microservices

# Verificar recursos disponibles
kubectl top nodes
kubectl describe nodes
```

#### 4. Imágenes Docker no se encuentran

**Síntoma**: `ImagePullBackOff`

**Solución**:

```bash
# Crear secret para autenticación
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=USERNAME \
  --docker-password=TOKEN \
  -n microservices

# Actualizar k8s.yaml para usar el secret:
# En los specs de pod, añadir:
# imagePullSecrets:
# - name: regcred

kubectl apply -f k8s/k8s.yaml
```

#### 5. Volumen de PostgreSQL no se monta

**Síntoma**: `Error mounting volume`

**Solución**:

```bash
# Verificar disponibilidad de PersistentVolume
kubectl get pv

# Crear manualmente si es necesario
mkdir -p /mnt/data/postgres
sudo chown 999:999 /mnt/data/postgres  # Usuario de PostgreSQL en Docker

# Verificar PVC
kubectl describe pvc postgres-pvc -n microservices
```

---

## 📊 Monitoreo

### Monitoreo básico con kubectl

```bash
# Dashboard de recursos
kubectl top nodes
kubectl top pods -n microservices

# Monitoreo en tiempo real
watch kubectl get pods -n microservices

# Logs en stream
kubectl logs -n microservices -l app=microservice-1 -f

# Eventos del cluster
kubectl get events -n microservices --sort-by='.lastTimestamp'
```

### Instalar Prometheus (opcional)

```bash
# Añadir helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Instalar Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### Instalar ELK Stack (opcional)

```bash
# Para logs centralizados
helm repo add elastic https://Helm.elastic.co
helm install elasticsearch elastic/elasticsearch -n logging --create-namespace
helm install kibana elastic/kibana -n logging
helm install filebeat elastic/filebeat -n logging
```

### Métricas custom

Los Dockerfiles incluyen health checks que puedes monitorear:

```bash
# Ver status de health checks
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/microservices/pods
```

---

## 📝 Notas importantes

### Seguridad

- ⚠️ **Cambiar contraseña de PostgreSQL en producción**

  ```bash
  kubectl set env statefulset/postgres DB_PASSWORD="new-secure-password" -n microservices
  ```

- ⚠️ **Configurar RBAC apropiadamente**

  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: microservice-role
    namespace: microservices
  rules:
    - apiGroups: [""]
      resources: ["configmaps", "secrets"]
      verbs: ["get", "list", "watch"]
  ```

- ⚠️ **Usar imagePullSecrets para registros privados**

### Performance

- Los HPA están configurados para escalar entre 2-5 réplicas
- Ajustar `minReplicas`, `maxReplicas` y thresholds según carga
- Considerar usar `PodDisruptionBudget` para alta disponibilidad

### Backups

```bash
# Backup de base de datos
kubectl exec -n microservices postgres-0 -- \
  pg_dump -U postgres microservices_db > backup.sql

# Restore
kubectl cp backup.sql microservices/postgres-0:/tmp/
kubectl exec -n microservices postgres-0 -- \
  psql -U postgres microservices_db < /tmp/backup.sql
```

---

## 📞 Soporte

Para problemas adicionales:

- Revisar logs: `kubectl logs -n microservices`
- Verificar eventos: `kubectl describe`
- Consultar documentación oficial de Kubernetes
- Revisar GitHub Issues del repositorio

---

**Última actualización**: Diciembre 2025
