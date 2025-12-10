# Configuración de Docker Hub en GitHub Actions

## 📋 Pasos para Configurar los Secrets en GitHub

### 1. Crear Access Token en Docker Hub

1. Ve a [Docker Hub](https://hub.docker.com/)
2. Login con tu cuenta (`edygc1988`)
3. Ve a **Account Settings** → **Security**
4. Haz clic en **New Access Token**
5. Dale un nombre descriptivo (ej: "github-actions")
6. Copia el token (solo aparecerá una vez)

### 2. Agregar Secrets en GitHub

1. Ve a tu repositorio en GitHub: https://github.com/edygc1988/proyecto
2. **Settings** → **Secrets and variables** → **Actions**
3. Haz clic en **New repository secret**

**Crear dos secretos:**

#### Secret 1: DOCKER_USERNAME

- **Name**: `DOCKER_USERNAME`
- **Value**: `edygc1988`

#### Secret 2: DOCKER_PASSWORD

- **Name**: `DOCKER_PASSWORD`
- **Value**: (pega el token de Docker Hub que copiaste)

### 3. Verificar que los secretos estén configurados

En GitHub, en **Settings** → **Secrets and variables** → **Actions** deberías ver:

- ✓ DOCKER_USERNAME
- ✓ DOCKER_PASSWORD

## 🚀 Cómo Funciona Ahora

Cuando hagas un `push` a la rama `main`:

1. **Build & Push de Imágenes**:

   ```
   edygc1988/microservice-1:latest  → Docker Hub
   edygc1988/microservice-2:latest  → Docker Hub
   ```

2. **Deploy en Kubernetes**:

   - Las imágenes se descargan desde Docker Hub
   - Se aplica automáticamente el k8s.yaml
   - Los pods se crean con las imágenes

3. **Verificación**:
   - Se ejecutan smoke tests
   - Se muestran logs de los pods

## 📝 Ejemplo de Flujo

```bash
# 1. Haces cambios locales
$ nano microservice-1/app.py

# 2. Haces commit y push
$ git add .
$ git commit -m "Update MS1"
$ git push origin main

# 3. GitHub Actions se activa automáticamente:
#    ✓ Build imagen MS1
#    ✓ Build imagen MS2
#    ✓ Run tests
#    ✓ Push a edygc1988/microservice-1:latest (Docker Hub)
#    ✓ Push a edygc1988/microservice-2:latest (Docker Hub)
#    ✓ Deploy en Kubernetes
#    ✓ Smoke tests
#    ✓ Notificación de resultado
```

## ⚙️ Configuración Actual

### Workflow (deploy.yml)

- **Registry**: Docker Hub (docker.io)
- **Username**: edygc1988
- **Images**:
  - `edygc1988/microservice-1:latest`
  - `edygc1988/microservice-2:latest`

### Kubernetes (k8s.yaml)

- **Image**: `edygc1988/microservice-1:latest`
- **Image**: `edygc1988/microservice-2:latest`
- **imagePullPolicy**: Always (descarga siempre la versión más reciente)

## 🔐 Seguridad

✓ Los secrets están cifrados en GitHub
✓ Solo se usan en el workflow (no se muestran en logs)
✓ El token puede ser revocado en Docker Hub en cualquier momento

## 🧪 Pruebas Locales

Para probar antes de hacer push:

```bash
# Construcción local
docker build -t edygc1988/microservice-1:latest ./microservice-1
docker build -t edygc1988/microservice-2:latest ./microservice-2

# Login en Docker Hub
docker login

# Push manual
docker push edygc1988/microservice-1:latest
docker push edygc1988/microservice-2:latest

# O todo junto
docker-compose build
docker login
docker-compose push
```

## ❌ Troubleshooting

### Error: "unauthorized: authentication required"

- Verificar que DOCKER_PASSWORD está correcto
- El token debe estar activo en Docker Hub

### Error: "repository not found"

- Verificar que el nombre del usuario es correcto: `edygc1988`
- Crear los repositorios públicos en Docker Hub si no existen

### Las imágenes no se actualizan en Kubernetes

```bash
# Forzar descarga de imagen
kubectl set image deployment/microservice-1 \
  microservice-1=edygc1988/microservice-1:latest \
  -n microservices

# O eliminar los pods para que se recreen
kubectl delete pods -l app=microservice-1 -n microservices
```

## 📊 Monitoreo del Pipeline

Para ver el estado del CI/CD:

1. Ve a tu repositorio en GitHub
2. Haz clic en **Actions**
3. Verás los workflows ejecutándose

Haz clic en un workflow para ver detalles de cada job.

## 🎯 Checklist Final

- [ ] Token creado en Docker Hub
- [ ] Secret `DOCKER_USERNAME` configurado en GitHub
- [ ] Secret `DOCKER_PASSWORD` configurado en GitHub
- [ ] k8s.yaml actualizado con imágenes de edygc1988
- [ ] deploy.yml actualizado para usar Docker Hub
- [ ] Hacer un push a main para probar
- [ ] Ver GitHub Actions → Actions para verificar
- [ ] Verificar que las imágenes se subieron a Docker Hub
- [ ] Verificar que el deployment funciona en Kubernetes

---

**¿Todo listo? Haz un push a main y el pipeline se ejecutará automáticamente!**
