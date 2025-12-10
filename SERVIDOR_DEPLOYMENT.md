# Guía de Despliegue Directo en Servidor

Esta guía te ayudará a desplegar la solución de microservicios directamente en tu servidor con Kubernetes.

## 📋 Requisitos Previos

- **Kubernetes** instalado y configurado en tu servidor
- **kubectl** accesible desde línea de comandos
- **Docker Hub** con las imágenes ya construidas y publicadas:
  - `edygc1988/microservice-1:latest`
  - `edygc1988/microservice-2:latest`

## 🚀 Despliegue Rápido (5 minutos)

### Opción 1: Despliegue Automático (Recomendado)

```bash
# 1. Clonar o descargar el proyecto
cd /ruta/al/proyecto

# 2. Verificar conexión a Kubernetes
kubectl cluster-info

# 3. Desplegar todo de una vez
kubectl apply -f k8s/k8s.yaml

# 4. Verificar que se creó todo
kubectl get pods -n microservices
kubectl get svc -n microservices

# 5. Ver logs para verificar que está corriendo
kubectl logs -n microservices -l app=microservice-1 -f
```

### Opción 2: Despliegue Paso a Paso

```bash
# 1. Crear namespace
kubectl create namespace microservices

# 2. Crear secrets
kubectl create secret generic microservices-secrets \
  -n microservices \
  --from-literal=DB_PASSWORD=postgres

# 3. Crear configmap
kubectl create configmap microservices-config \
  -n microservices \
  --from-literal=FLASK_ENV=production \
  --from-literal=DB_HOST=postgres \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=microservices_db \
  --from-literal=DB_USER=postgres

# 4. Aplicar todas las configuraciones
kubectl apply -f k8s/k8s.yaml
```

## 🔍 Verificación Post-Despliegue

```bash
# Ver estado de todos los componentes
./microservices.sh status

# Ver logs de Microservicio 1
kubectl logs -n microservices -l app=microservice-1 --tail=50

# Ver logs de Microservicio 2
kubectl logs -n microservices -l app=microservice-2 --tail=50

# Ver logs de PostgreSQL
kubectl logs -n microservices -l app=postgres --tail=50

# Ver eventos (útil para debugging)
kubectl get events -n microservices --sort-by='.lastTimestamp'

# Ver recursos utilizados
kubectl top pods -n microservices
```

## 🔌 Acceder a los Servicios

### Port-Forward Local

```bash
# Para Microservicio 1
kubectl port-forward -n microservices svc/microservice-1 5000:5000

# En otra terminal, para Microservicio 2
kubectl port-forward -n microservices svc/microservice-2 5001:5001

# En otra terminal, para PostgreSQL
kubectl port-forward -n microservices svc/postgres 5432:5432
```

Ahora puedes acceder:

- Microservicio 1: `http://localhost:5000`
- Microservicio 2: `http://localhost:5001`
- PostgreSQL: `localhost:5432`

### Pruebas Quick

```bash
# Health check MS1
curl http://localhost:5000/health

# Health check MS2
curl http://localhost:5001/health

# Listar items (debería estar vacío)
curl http://localhost:5000/items

# Crear un item
curl -X POST http://localhost:5000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item","description":"Test Description"}'

# Listar nuevamente
curl http://localhost:5000/items
```

## 🐳 Si Necesitas Reconstruir Imágenes Localmente

Si quieres hacer cambios y reconstruir:

```bash
# 1. Hacer cambios en el código
nano microservice-1/app.py

# 2. Reconstruir imagen localmente
docker build -t edygc1988/microservice-1:latest ./microservice-1

# 3. Hacer push a Docker Hub
docker login
docker push edygc1988/microservice-1:latest

# 4. Actualizar en Kubernetes
kubectl set image deployment/microservice-1 \
  microservice-1=edygc1988/microservice-1:latest \
  -n microservices

# 5. Verificar rollout
kubectl rollout status deployment/microservice-1 -n microservices
```

## 🔄 Actualizar Despliegue

### Actualizar a nueva versión

```bash
# Actualizar la imagen
kubectl set image deployment/microservice-1 \
  microservice-1=edygc1988/microservice-1:v2.0 \
  -n microservices

# Monitorear el rollout
kubectl rollout status deployment/microservice-1 -n microservices

# Ver historial de rollouts
kubectl rollout history deployment/microservice-1 -n microservices

# Si necesitas revertir a versión anterior
kubectl rollout undo deployment/microservice-1 -n microservices
```

## 📊 Monitoreo Continuo

### Dashboard en tiempo real

```bash
# Ver pods en tiempo real
watch kubectl get pods -n microservices

# Ver todos los recursos
watch kubectl get all -n microservices

# Ver uso de recursos
watch kubectl top pods -n microservices
```

### Logs en streaming

```bash
# Todos los logs del namespace
kubectl logs -f -n microservices --all-containers=true

# Logs de un pod específico
kubectl logs -f POD_NAME -n microservices

# Logs de todos los pods con un label
kubectl logs -f -n microservices -l app=microservice-1 --all-containers=true
```

## 🔐 Gestión de Secrets

### Ver secrets configurados

```bash
kubectl get secrets -n microservices

# Ver contenido de un secret (base64)
kubectl get secret microservices-secrets -n microservices -o yaml
```

### Actualizar secretos

```bash
# Cambiar contraseña de PostgreSQL
kubectl set env statefulset/postgres \
  DB_PASSWORD=nueva-contraseña \
  -n microservices
```

## 💾 Backup y Restore de Base de Datos

### Hacer backup

```bash
# Conectar a PostgreSQL
kubectl exec -it -n microservices postgres-0 -- psql -U postgres -d microservices_db

# Dentro del pod
\dt  # Ver tablas
SELECT * FROM items;  # Ver items
\q   # Salir

# O hacer dump SQL
kubectl exec -n microservices postgres-0 -- \
  pg_dump -U postgres microservices_db > backup.sql
```

### Restaurar desde backup

```bash
# Copiar archivo al pod
kubectl cp backup.sql microservices/postgres-0:/tmp/backup.sql

# Restaurar
kubectl exec -n microservices postgres-0 -- \
  psql -U postgres microservices_db < /tmp/backup.sql
```

## ❌ Troubleshooting

### Pod en CrashLoopBackOff

```bash
# Ver logs detallados
kubectl logs -n microservices POD_NAME --previous

# Describir pod para ver errores
kubectl describe pod POD_NAME -n microservices

# Verificar eventos
kubectl get events -n microservices --sort-by='.lastTimestamp'
```

### Imagen no se encuentra

```bash
# Verificar que existe en Docker Hub
docker pull edygc1988/microservice-1:latest

# Si no existe, construir y subir
docker build -t edygc1988/microservice-1:latest ./microservice-1
docker login
docker push edygc1988/microservice-1:latest

# Forzar descarga en Kubernetes
kubectl set image deployment/microservice-1 \
  microservice-1=edygc1988/microservice-1:latest \
  -n microservices

# O eliminar pods para que se recreen
kubectl delete pods -l app=microservice-1 -n microservices
```

### No se pueden conectar entre servicios

```bash
# Verificar DNS desde dentro del pod
kubectl exec -it -n microservices microservice-2-xxxxx -- nslookup microservice-1

# Ver network policies
kubectl get networkpolicies -n microservices

# Verificar logs de conectividad
kubectl logs -n microservices -l app=microservice-2 | grep -i "connection\|error"
```

### PostgreSQL no inicia

```bash
# Ver logs
kubectl logs -n microservices -l app=postgres

# Verificar PVC
kubectl get pvc -n microservices

# Describir PVC
kubectl describe pvc postgres-pvc -n microservices

# Si el volumen está corrupto, limpiar
kubectl delete pvc postgres-pvc -n microservices
# Los datos se perderán, pero se recreará la PVC
```

## 🛑 Limpiar Todo

### Eliminar despliegue completo

```bash
# Eliminar todas las configuraciones
kubectl delete -f k8s/k8s.yaml

# O eliminar namespace (elimina todo dentro)
kubectl delete namespace microservices

# Verificar que se eliminó
kubectl get namespaces | grep microservices
```

## 📝 Configuración Personalizada

### Cambiar número de réplicas

```bash
# Escalar manualmente
kubectl scale deployment/microservice-1 --replicas=3 -n microservices

# O editar el deployment
kubectl edit deployment/microservice-1 -n microservices
# Cambiar replicas: 3 y guardar
```

### Cambiar variables de entorno

```bash
# Editar configmap
kubectl edit configmap microservices-config -n microservices

# Luego hacer rollout restart para aplicar cambios
kubectl rollout restart deployment/microservice-1 -n microservices
```

## 🎯 Checklist de Despliegue

- [ ] Kubernetes configurado y accesible
- [ ] Imágenes publicadas en Docker Hub
- [ ] Archivo k8s/k8s.yaml con referencias correctas
- [ ] Ejecutar: `kubectl apply -f k8s/k8s.yaml`
- [ ] Verificar: `kubectl get pods -n microservices`
- [ ] Hacer port-forward: `kubectl port-forward svc/microservice-1 5000:5000`
- [ ] Probar health check: `curl http://localhost:5000/health`
- [ ] Crear un item de prueba
- [ ] Verificar que MS2 puede consumir desde MS1
- [ ] Revisar logs: `kubectl logs -f -l app=microservice-1`

---

**¡Tu aplicación está desplegada y corriendo en Kubernetes!**

Para más información, revisar [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
