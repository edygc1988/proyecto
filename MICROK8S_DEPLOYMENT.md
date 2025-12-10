# Despliegue con MicroK8s

Guía paso a paso para desplegar tu solución de microservicios en **MicroK8s** (Kubernetes ligero).

## 📋 ¿Qué es MicroK8s?

MicroK8s es una distribución ligera de Kubernetes que puedes instalar en:

- macOS (con VM)
- Linux
- Windows (con WSL2)

Perfecto para desarrollo y pruebas antes de producción.

## 🚀 Instalación de MicroK8s

### En macOS

```bash
# Opción 1: Con Homebrew (Recomendado)
brew install microk8s

# Opción 2: Descargar directamente
# https://microk8s.io/docs/getting-started

# Iniciar MicroK8s
microk8s start

# Verificar estado
microk8s status

# Esperar a que esté listo
microk8s status --wait-ready
```

### En Linux (Ubuntu/Debian)

```bash
# Instalar snapd si no lo tienes
sudo apt update
sudo apt install snapd

# Instalar MicroK8s
sudo snap install microk8s --classic

# Dar permisos al usuario
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube

# Reiniciar para aplicar permisos
exit  # Salir y volver a iniciar sesión

# Iniciar
microk8s start

# Verificar
microk8s status --wait-ready
```

### En Windows (WSL2)

```bash
# En WSL2 (Ubuntu)
sudo snap install microk8s --classic

sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube

# En PowerShell como admin (opcional para integración)
wsl -d Ubuntu microk8s status
```

## ⚙️ Configuración de MicroK8s

### Paso 1: Habilitar Add-ons Necesarios

```bash
# Habilitar storage (para PersistentVolumes)
microk8s enable storage

# Habilitar DNS
microk8s enable dns

# Habilitar registry local (para imágenes Docker)
microk8s enable registry

# Habilitar ingress (para acceso HTTP)
microk8s enable ingress

# Opcional: Dashboard de Kubernetes
microk8s enable dashboard

# Ver estado de add-ons
microk8s status
```

### Paso 2: Configurar microk8s kubectl

```bash
# Crear alias para no escribir "microk8s microk8s kubectl" cada vez
alias microk8s kubectl='microk8s microk8s kubectl'

# O agregar a tu ~/.zshrc o ~/.bash_profile
echo "alias microk8s kubectl='microk8s microk8s kubectl'" >> ~/.zshrc
source ~/.zshrc

# Verificar que funciona
microk8s kubectl version

# Ver nodos
microk8s kubectl get nodes

# Ver estado del cluster
microk8s kubectl cluster-info
```

### Paso 3: Configurar Docker (Opcional pero Recomendado)

Si quieres usar Docker en tu máquina local:

```bash
# Ver imagen de Docker de MicroK8s
microk8s ctr images list

# Puedes usar Docker normalmente, MicroK8s verá las imágenes
docker build -t edygc1988/microservice-1:latest ./microservice-1

# O construir directamente en MicroK8s
microk8s ctr image import <(docker save edygc1988/microservice-1:latest)
```

## 🚢 Despliegue en MicroK8s

### Opción 1: Despliegue desde Docker Hub (Recomendado)

Las imágenes ya están en Docker Hub: `edygc1988/microservice-1` y `edygc1988/microservice-2`

```bash
# 1. Verificar conexión
microk8s kubectl cluster-info

# 2. Desplegar todo
microk8s kubectl apply -f k8s/k8s.yaml

# 3. Verificar que se creó
microk8s kubectl get pods -n microservices
microk8s kubectl get svc -n microservices
```

### Opción 2: Despliegue desde Imágenes Locales

Si quieres usar imágenes que construiste localmente:

```bash
# 1. Construir imágenes localmente
docker build -t edygc1988/microservice-1:latest ./microservice-1
docker build -t edygc1988/microservice-2:latest ./microservice-2

# 2. Cargar imágenes en MicroK8s
microk8s ctr image import <(docker save edygc1988/microservice-1:latest)
microk8s ctr image import <(docker save edygc1988/microservice-2:latest)

# 3. Modificar k8s.yaml para usar imagePullPolicy: Never
sed -i 's/imagePullPolicy: Always/imagePullPolicy: Never/g' k8s/k8s.yaml

# 4. Desplegar
microk8s kubectl apply -f k8s/k8s.yaml

# 5. Restaurar k8s.yaml
sed -i 's/imagePullPolicy: Never/imagePullPolicy: Always/g' k8s/k8s.yaml
```

## 🔍 Verificar el Despliegue

```bash
# Ver estado de los pods
microk8s kubectl get pods -n microservices

# Ver servicios
microk8s kubectl get svc -n microservices

# Ver deployments
microk8s kubectl get deployments -n microservices

# Ver eventos (útil para debugging)
microk8s kubectl get events -n microservices --sort-by='.lastTimestamp'

# Ver logs de un servicio
microk8s kubectl logs -n microservices -l app=microservice-1

# Ver recursos utilizados
microk8s kubectl top pods -n microservices
```

## 🔌 Acceder a los Servicios

### Opción 1: Port-Forward (Rápido y Fácil)

```bash
# Terminal 1: Microservicio 1
microk8s kubectl port-forward -n microservices svc/microservice-1 5000:5000

# Terminal 2: Microservicio 2
microk8s kubectl port-forward -n microservices svc/microservice-2 5001:5001

# Terminal 3: PostgreSQL
microk8s kubectl port-forward -n microservices svc/postgres 5432:5432
```

Ahora accede desde tu máquina:

- MS1: `http://localhost:5000`
- MS2: `http://localhost:5001`
- PostgreSQL: `localhost:5432`

### Opción 2: Usando NodePort

Modificar el k8s.yaml para cambiar Service type a NodePort:

```bash
# Editar k8s.yaml
sed -i 's/type: ClusterIP/type: NodePort/g' k8s/k8s.yaml

# Aplicar
microk8s kubectl apply -f k8s/k8s.yaml

# Ver puertos asignados
microk8s kubectl get svc -n microservices

# Obtener IP de MicroK8s
microk8s microk8s kubectl get nodes -o wide

# Acceder
curl http://<MICROK8S_IP>:<NODE_PORT>/health
```

### Opción 3: Usando Ingress

```bash
# Verificar que ingress está habilitado
microk8s status | grep ingress

# Crear un Ingress resource (opcional)
# Ver INGRESS.yaml en este repositorio
microk8s kubectl apply -f ingress.yaml

# Acceder
curl http://localhost/health
```

## 🧪 Pruebas Rápidas

```bash
# Health check MS1
curl http://localhost:5000/health

# Health check MS2
curl http://localhost:5001/health

# Crear un item
curl -X POST http://localhost:5000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","description":"Test Item"}'

# Listar items
curl http://localhost:5000/items

# Desde MS2 (consumidor)
curl http://localhost:5001/items
```

## 📊 Monitoreo

### Dashboard de Kubernetes

```bash
# Acceso al dashboard de MicroK8s
microk8s dashboard-proxy

# O manualmente
microk8s kubectl proxy --port=8001

# Acceder a: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

### Ver logs en tiempo real

```bash
# Todos los pods del namespace
microk8s kubectl logs -f -n microservices --all-containers=true

# Pod específico
microk8s kubectl logs -f -n microservices POD_NAME

# Todos con label específico
microk8s kubectl logs -f -n microservices -l app=microservice-1 --tail=50
```

### Monitoreo de recursos

```bash
# Ver uso de CPU y memoria
microk8s kubectl top pods -n microservices

# Ver uso de nodos
microk8s kubectl top nodes

# En tiempo real (con watch)
watch microk8s kubectl top pods -n microservices
```

## 🔄 Actualizar Despliegue

### Si cambias el código

```bash
# 1. Construir nueva imagen
docker build -t edygc1988/microservice-1:latest ./microservice-1

# 2. Push a Docker Hub (si quieres usar desde internet)
docker login
docker push edygc1988/microservice-1:latest

# 3. Actualizar en Kubernetes
microk8s kubectl set image deployment/microservice-1 \
  microservice-1=edygc1988/microservice-1:latest \
  -n microservices

# 4. Ver rollout
microk8s kubectl rollout status deployment/microservice-1 -n microservices

# 5. Si algo va mal, revertir
microk8s kubectl rollout undo deployment/microservice-1 -n microservices
```

## 🐛 Troubleshooting

### "Pod en CrashLoopBackOff"

```bash
# Ver logs detallados
microk8s kubectl logs -n microservices POD_NAME --previous

# Ver descripción del pod
microk8s kubectl describe pod POD_NAME -n microservices

# Ver eventos
microk8s kubectl get events -n microservices --sort-by='.lastTimestamp'
```

### "Connection refused"

```bash
# Verificar que los servicios están corriendo
microk8s kubectl get pods -n microservices

# Verificar que el servicio existe
microk8s kubectl get svc -n microservices

# Verificar conectividad entre pods
microk8s kubectl exec -it POD_MS2 -n microservices -- ping microservice-1

# Ver DNS desde dentro del pod
microk8s kubectl exec -it POD_MS2 -n microservices -- nslookup microservice-1
```

### "ImagePullBackOff"

```bash
# Opción 1: Verificar que la imagen existe en Docker Hub
docker pull edygc1988/microservice-1:latest

# Opción 2: Si usas imagen local, cambiar imagePullPolicy
microk8s kubectl patch deployment microservice-1 \
  -n microservices \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value":"Never"}]'

# Opción 3: Cargar imagen en MicroK8s
docker save edygc1988/microservice-1:latest | microk8s ctr image import -
```

### PostgreSQL no inicia

```bash
# Ver logs
microk8s kubectl logs -n microservices postgres-0

# Verificar PVC
microk8s kubectl get pvc -n microservices

# Si el volumen está corrupto
microk8s kubectl delete pvc postgres-pvc -n microservices

# Los datos se perderán pero se recreará la PVC
```

## 🔐 Acceso a PostgreSQL

### Con microk8s kubectl

```bash
# Conectar directamente
microk8s kubectl exec -it -n microservices postgres-0 -- psql -U postgres -d microservices_db

# Dentro de psql:
\dt              # Ver tablas
SELECT * FROM items;  # Ver items
\q              # Salir
```

### Con port-forward

```bash
# Terminal 1
microk8s kubectl port-forward -n microservices svc/postgres 5432:5432

# Terminal 2
psql -h localhost -U postgres -d microservices_db
# Password: postgres
```

## 🛑 Detener y Eliminar

```bash
# Eliminar todo el namespace (borra todos los datos)
microk8s kubectl delete namespace microservices

# O solo detener los pods
microk8s kubectl delete -f k8s/k8s.yaml

# Detener MicroK8s
microk8s stop

# Reiniciar MicroK8s
microk8s start
```

## 📝 Script Automatizado (Bonus)

Crear archivo `deploy-microk8s.sh`:

```bash
#!/bin/bash

set -e

echo "=== Despliegue en MicroK8s ==="

# Verificar MicroK8s
echo "Verificando MicroK8s..."
microk8s status --wait-ready

# Crear alias
alias microk8s kubectl='microk8s microk8s kubectl'

# Aplicar configuración
echo "Desplegando..."
microk8s kubectl apply -f k8s/k8s.yaml

# Esperar a que esté listo
echo "Esperando a que los pods estén listos..."
microk8s kubectl wait --for=condition=ready pod -l app=microservice-1 -n microservices --timeout=5m || true

# Ver estado
echo ""
echo "=== Estado del Despliegue ==="
microk8s kubectl get pods -n microservices
microk8s kubectl get svc -n microservices

# Port-forward en background
echo ""
echo "Iniciando port-forward..."
microk8s kubectl port-forward -n microservices svc/microservice-1 5000:5000 &
microk8s kubectl port-forward -n microservices svc/microservice-2 5001:5001 &

echo ""
echo "✓ Despliegue completado"
echo ""
echo "Servicios disponibles:"
echo "  - MS1: http://localhost:5000/health"
echo "  - MS2: http://localhost:5001/health"
echo ""
echo "Ver logs: microk8s kubectl logs -f -n microservices -l app=microservice-1"
echo "Ver pods: microk8s kubectl get pods -n microservices"
```

Ejecutar:

```bash
chmod +x deploy-microk8s.sh
./deploy-microk8s.sh
```

## 🎯 Flujo Completo

1. **Instalar MicroK8s**

   ```bash
   brew install microk8s
   microk8s start
   microk8s status --wait-ready
   ```

2. **Habilitar Add-ons**

   ```bash
   microk8s enable storage dns registry
   ```

3. **Crear Alias**

   ```bash
   alias microk8s kubectl='microk8s microk8s kubectl'
   ```

4. **Desplegar**

   ```bash
   microk8s kubectl apply -f k8s/k8s.yaml
   ```

5. **Verificar**

   ```bash
   microk8s kubectl get pods -n microservices
   ```

6. **Port-Forward**

   ```bash
   microk8s kubectl port-forward -n microservices svc/microservice-1 5000:5000
   ```

7. **Probar**
   ```bash
   curl http://localhost:5000/health
   ```

## 🔗 Útiles

- **Documentación MicroK8s**: https://microk8s.io/
- **Troubleshooting**: https://microk8s.io/docs/troubleshooting
- **Add-ons disponibles**: `microk8s enable --help`

## 💡 Tips

- MicroK8s usa ~1-2GB de RAM y 2-4GB de disco
- Perfecto para laptops y desarrollo
- Puedes exportar kubeconfig para usar con otros clientes
- Usa `microk8s reset` si algo se rompe (reset completo)

---

**¡Listo para desplegar con MicroK8s!**
