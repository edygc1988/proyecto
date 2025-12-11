# 🚀 Solución Completa de Microservicios con Python, Flask, PostgreSQL, Docker y Kubernetes

Una arquitectura de microservicios lista para producción con dos servicios Flask, PostgreSQL, orquestación Kubernetes completa y pipeline CI/CD automático con GitHub Actions.

## ✨ Características

- ✅ **Dos Microservicios Flask**: CRUD de Items + Consumidor
- ✅ **PostgreSQL**: Base de datos con persistencia
- ✅ **Docker**: Dockerfiles optimizados para cada servicio
- ✅ **Kubernetes**: Configuración completa (namespaces, deployments, services, HPA, network policies)
- ✅ **CI/CD**: Pipeline GitHub Actions automático (build, test, push, deploy)
- ✅ **Seguridad**: Network policies, secrets management, health checks
- ✅ **Escalabilidad**: HorizontalPodAutoscaler, rolling updates, recursos configurados
- ✅ **Monitoreo**: Logging, health checks, smoke tests

## 📊 Arquitectura

```
┌────────────────────────────────────────────────┐
│         Kubernetes Cluster                     │
│  ┌─────────────────────────────────────────┐   │
│  │ Namespace: microservices                │   │
│  │                                         │   │
│  │  ┌──────────────┐    ┌──────────────┐   │   │
│  │  │ Microservice │    │ Microservice │   │   │
│  │  │      1       │<-->│      2       │   │   │
│  │  │   (CRUD)     │    │  (Consumer)  │   │   │
│  │  │   :5000      │    │   :5001      │   │   │
│  │  └──────┬───────┘    └──────────────┘   │   │
│  │         │                               │   │
│  │         └──────────┬                    │   │
│  │                    ↓                    │   │
│  │         ┌──────────────────┐            │   │
│  │         │   PostgreSQL     │            │   │
│  │         │   (Database)     │            │   │
│  │         │     :5432        │            │   │
│  │         └──────────────────┘            │   │
│  └─────────────────────────────────────────┘   │
└────────────────────────────────────────────────┘
              ↓ (GitHub Actions)
    ┌─────────────────────────────────┐
    │   CI/CD Pipeline Automático     │
    │ Build → Test → Push → Deploy    │
    └─────────────────────────────────┘
```

## 🎯 Requerimientos Cumplidos

### Microservicio 1 (CRUD de Items)

- [x] Python + Flask
- [x] Conectado a PostgreSQL
- [x] Tabla `items` con campos: id, name, description
- [x] Endpoints: GET /items, POST /items, GET/PUT/DELETE /items/{id}
- [x] Dockerfile incluido
- [x] requirements.txt incluido

### Microservicio 2 (Consumidor)

- [x] Python + Flask
- [x] Consume endpoints del Microservicio 1
- [x] Endpoints: GET /items, POST /items
- [x] Retry logic con timeout
- [x] Dockerfile incluido
- [x] requirements.txt incluido

### Kubernetes

- [x] Namespace `microservices`
- [x] Deployment + Service para ambos microservicios
- [x] StatefulSet + Service para PostgreSQL
- [x] PersistentVolume y PersistentVolumeClaim
- [x] ConfigMaps y Secrets
- [x] Network Policies
- [x] Health checks (liveness + readiness)
- [x] Horizontal Pod Autoscaler
- [x] Variables de entorno configuradas
- [x] Imágenes como: `your-repo/microservice-1` y `your-repo/microservice-2`

### CI/CD (GitHub Actions)

- [x] Build automático de imágenes Docker
- [x] Tests unitarios
- [x] Push a registro (GitHub Container Registry)
- [x] Aplicación automática de k8s.yaml
- [x] KUBECONFIG desde secretos
- [x] Smoke tests post-deployment
- [x] Notificación de estado

## 📁 Estructura del Proyecto

```
proyecto/
├── microservice-1/                 # Servicio CRUD
│   ├── app.py                     # Aplicación Flask
│   ├── requirements.txt           # Dependencias
│   └── Dockerfile                 # Imagen Docker
├── microservice-2/                 # Servicio Consumidor
│   ├── app.py                     # Aplicación Flask
│   ├── requirements.txt           # Dependencias
│   └── Dockerfile                 # Imagen Docker
├── k8s/
│   └── k8s.yaml                   # Configuración Kubernetes completa
├── .github/workflows/
│   └── deploy.yml                 # Pipeline GitHub Actions
├── docker-compose.yml             # Para desarrollo local
├── microservices.sh               # Script helper (comandos útiles)
├── quick-test.sh                  # Testing rápido
├── README.md                       # Este archivo
├── DEPLOYMENT_GUIDE.md            # Guía detallada de despliegue
└── ARCHITECTURE.md                # Documentación técnica de la arquitectura
```

## 🚀 Inicio Rápido

### Opción 1: Desarrollo Local con Docker Compose

```bash
# Clonar/navegar al proyecto
cd proyecto

# Iniciar todos los servicios
docker-compose up -d

# Verificar estado
docker-compose ps

# Ejecutar tests
bash quick-test.sh

# Ver logs
docker-compose logs -f microservice-1

# Detener
docker-compose down
```

### Opción 2: Despliegue en Kubernetes

```bash
# Prerequisitos
kubectl cluster-info  # Verificar conexión

# Desplegar
./microservices.sh deploy ghcr.io/tu-usuario

# Verificar
./microservices.sh status

# Ver logs
./microservices.sh logs microservice-1

# Limpiar
./microservices.sh destroy
```

### Opción 3: Despliegue Manual Kubernetes

```bash
# Actualizar referencias de imagen
sed -i 's|your-repo|ghcr.io/tu-usuario|g' k8s/k8s.yaml

# Aplicar configuración
kubectl apply -f k8s/k8s.yaml

# Monitorear despliegue
kubectl rollout status deployment/microservice-1 -n microservices

# Port-forward para testing
kubectl port-forward -n microservices svc/microservice-1 5000:5000

# Test en otra terminal
curl http://localhost:5000/health
```

## 🔌 API Endpoints

### Microservicio 1 (5000)

```bash
# Health check
GET /health

# Listar todos los items
GET /items

# Obtener item específico
GET /items/{id}

# Crear nuevo item
POST /items
Body: {"name":"Item Name","description":"Optional description"}

# Actualizar item
PUT /items/{id}
Body: {"name":"New Name","description":"New description"}

# Eliminar item
DELETE /items/{id}
```

### Microservicio 2 (5001)

```bash
# Health check
GET /health

# Status de servicios
GET /status

# Listar items desde MS1
GET /items

# Obtener item específico desde MS1
GET /items/{id}

# Crear item en MS1
POST /items
Body: {"name":"Item Name","description":"Description"}

# Actualizar item en MS1
PUT /items/{id}

# Eliminar item en MS1
DELETE /items/{id}

# Info de proxy
GET /proxy/info
```

## 🧪 Testing

### Tests rápidos

```bash
bash quick-test.sh
```

### Tests con curl

```bash
# Health check
curl http://localhost:5000/health

# Crear item
curl -X POST http://localhost:5000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Test item"}'

# Listar items
curl http://localhost:5000/items

# Desde MS2 (consumidor)
curl http://localhost:5001/items
```

### Tests en Kubernetes

```bash
./microservices.sh test
```

## 🔧 Configuración

### Variables de Entorno

**Microservicio 1**:

```
FLASK_ENV=production        # development/production
PORT=5000
DB_HOST=postgres            # Hostname de PostgreSQL
DB_PORT=5432
DB_NAME=microservices_db
DB_USER=postgres
DB_PASSWORD=<secret>
```

**Microservicio 2**:

```
FLASK_ENV=production
PORT=5001
MICROSERVICE_1_HOST=microservice-1
MICROSERVICE_1_PORT=5000
MICROSERVICE_1_URL=http://microservice-1:5000
```

**PostgreSQL**:

```
POSTGRES_DB=microservices_db
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<secret>
```

## 🔄 CI/CD Pipeline

El workflow automático se activa en:

- **Push a main**: Build, test, push a registry y deploy
- **Push a develop**: Solo build y test
- **Pull Requests**: Build y test

### Configuración requerida en GitHub

1. **Crear token de acceso personal**:

   - Settings → Developer settings → Personal access tokens
   - Seleccionar scopes: `write:packages`, `read:packages`

2. **Agregar secreto `KUBECONFIG`**:

   ```bash
   # Codificar kubeconfig en base64
   cat ~/.kube/config | base64 | tr -d '\n'
   ```

   - Settings → Secrets and variables → Actions → New repository secret
   - Name: `KUBECONFIG`
   - Value: (pegar base64 codificado)

3. **Actualizar referencias en `.github/workflows/deploy.yml`**:
   ```bash
   sed -i 's|your-repo|tu-usuario|g' .github/workflows/deploy.yml
   ```

## 📚 Documentación Detallada

- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)**: Guía completa de instalación y despliegue
- **[ARCHITECTURE.md](./ARCHITECTURE.md)**: Documentación técnica de la arquitectura

## 🛠️ Scripts Helper

```bash
# Ver estado
./microservices.sh status

# Desplegar
./microservices.sh deploy [registry]

# Ver logs
./microservices.sh logs microservice-1 [líneas]

# Port-forward
./microservices.sh port-forward microservice-1 5000

# Tests
./microservices.sh test

# Shell en pod
./microservices.sh shell <pod-name>

# Base de datos
./microservices.sh db-shell
./microservices.sh db-backup

# Eliminar despliegue
./microservices.sh destroy

# Ayuda
./microservices.sh help
```

## 🐛 Troubleshooting

### Pod en CrashLoopBackOff

```bash
kubectl logs -n microservices POD_NAME --previous
```

### Microservicio 2 no puede conectar a MS1

```bash
kubectl exec -it -n microservices POD_MS2 -- nslookup microservice-1
```

### PostgreSQL no inicia

```bash
kubectl logs -n microservices -l app=postgres
kubectl describe pvc postgres-pvc -n microservices
```

### Error de imágenes

```bash
# Crear secret para autenticación
kubectl create secret docker-registry regcred \
  --docker-server=ghcr.io \
  --docker-username=USERNAME \
  --docker-password=TOKEN \
  -n microservices
```

Ver [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#troubleshooting) para más soluciones.

## 📊 Monitoreo

```bash
# Ver recursos en tiempo real
kubectl top pods -n microservices

# Ver eventos
kubectl get events -n microservices --sort-by='.lastTimestamp'

# Ver logs con streaming
kubectl logs -f -n microservices -l app=microservice-1

# Acceder a PostgreSQL
kubectl exec -it -n microservices postgres-0 -- psql -U postgres -d microservices_db
```

## 🔐 Seguridad

- ✅ Network Policies para restringir tráfico entre pods
- ✅ Secrets para credenciales sensibles
- ✅ ConfigMaps para datos públicos
- ✅ RBAC (recomendado para producción)
- ✅ Health checks para detectar pods fallidos
- ✅ Resource limits para evitar consumo excesivo

## 📈 Escalabilidad

El cluster incluye:

- **HPA (Horizontal Pod Autoscaler)**: Escala 2-5 réplicas basado en CPU/Memory
- **Rolling Updates**: Zero-downtime deployments
- **Resource Limits**: Aseguran que los pods no consuman recursos excesivos

## 🌍 Despliegue en la Nube

### AWS EKS

```bash
aws eks create-cluster --name microservices --version 1.27
aws eks update-kubeconfig --region us-east-1 --name microservices
```

### Google Kubernetes Engine (GKE)

```bash
gcloud container clusters create microservices --zone us-central1-a
```

### Azure Kubernetes Service (AKS)

```bash
az aks create --resource-group myRG --name microservices
az aks get-credentials --resource-group myRG --name microservices
```

Luego aplicar:

```bash
./microservices.sh deploy
```

## 📋 Checklist de Despliegue

- [ ] Clonar/descargar el proyecto
- [ ] Tener Docker y kubectl instalados
- [ ] Configurar kubeconfig del cluster
- [ ] (GitHub Actions) Crear token y secreto KUBECONFIG
- [ ] (GitHub Actions) Actualizar referencias de imagen
- [ ] (Local) Ejecutar `docker-compose up -d`
- [ ] (Local) Ejecutar `bash quick-test.sh`
- [ ] (K8s) Ejecutar `./microservices.sh deploy`
- [ ] (K8s) Ejecutar `./microservices.sh test`
- [ ] Hacer push a main para activar CI/CD

## 📞 Soporte

Para problemas:

1. Revisar [DEPLOYMENT_GUIDE.md - Troubleshooting](./DEPLOYMENT_GUIDE.md#troubleshooting)
2. Verificar logs: `kubectl logs -n microservices`
3. Verificar eventos: `kubectl get events -n microservices`
4. Revisar documentación oficial de Kubernetes

## 📄 Licencia

MIT License - Libre para usar y modificar

## 🎉 ¡Listo para usar!

Esta solución incluye todo lo necesario para un entorno de producción:

- ✅ Código Flask completo
- ✅ Dockerfiles optimizados
- ✅ Configuración Kubernetes completa
- ✅ Pipeline CI/CD automático
- ✅ Scripts de testing y debugging
- ✅ Documentación exhaustiva

**Próximos pasos**: Revisa [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) para instrucciones detalladas de despliegue.

---

**Última actualización**: Diciembre 2025
**Estado**: ✅ Listo para producción
# proyecto
