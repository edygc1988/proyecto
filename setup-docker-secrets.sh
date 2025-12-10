#!/bin/bash

# Script para configurar los secrets de Docker Hub en GitHub
# Este script usa la CLI de GitHub (gh) para automatizar la configuración

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_header "Configuración de Docker Hub Secrets en GitHub"

# Verificar si gh CLI está instalado
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI no está instalado"
    echo "Instala con: brew install gh (macOS) o según tu SO"
    exit 1
fi

# Verificar si estamos en un repositorio Git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "No estás en un repositorio Git"
    exit 1
fi

# Obtener el repositorio actual
REPO=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')

echo ""
print_header "Repositorio detectado: $REPO"

# Verificar autenticación con GitHub
echo ""
print_header "Verificando autenticación con GitHub"

if gh auth status > /dev/null 2>&1; then
    print_success "Autenticado en GitHub"
else
    print_warning "No estás autenticado en GitHub"
    echo "Ejecuta: gh auth login"
    exit 1
fi

# Pedir datos de Docker Hub
echo ""
print_header "Datos de Docker Hub"

read -p "Usuario de Docker Hub [edygc1988]: " DOCKER_USER
DOCKER_USER=${DOCKER_USER:-edygc1988}

read -sp "Token/Contraseña de Docker Hub: " DOCKER_TOKEN
echo ""

# Validaciones
if [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_TOKEN" ]; then
    print_error "Usuario o token vacío"
    exit 1
fi

# Confirmar datos
echo ""
echo "Vas a crear los siguientes secrets en $REPO:"
echo "  - DOCKER_USERNAME = $DOCKER_USER"
echo "  - DOCKER_PASSWORD = ******* (oculto por seguridad)"

read -p "¿Continuar? (s/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    print_warning "Operación cancelada"
    exit 0
fi

# Crear secrets
echo ""
print_header "Creando secrets..."

gh secret set DOCKER_USERNAME --body "$DOCKER_USER" --repo "$REPO" && \
    print_success "Secret DOCKER_USERNAME creado" || \
    print_error "Error creando DOCKER_USERNAME"

gh secret set DOCKER_PASSWORD --body "$DOCKER_TOKEN" --repo "$REPO" && \
    print_success "Secret DOCKER_PASSWORD creado" || \
    print_error "Error creando DOCKER_PASSWORD"

# Verificar que se crearon
echo ""
print_header "Verificando secrets..."

SECRETS=$(gh secret list --repo "$REPO" 2>/dev/null | grep -E "DOCKER_USERNAME|DOCKER_PASSWORD" || true)

if echo "$SECRETS" | grep -q "DOCKER_USERNAME"; then
    print_success "DOCKER_USERNAME está configurado"
else
    print_error "DOCKER_USERNAME NO está configurado"
fi

if echo "$SECRETS" | grep -q "DOCKER_PASSWORD"; then
    print_success "DOCKER_PASSWORD está configurado"
else
    print_error "DOCKER_PASSWORD NO está configurado"
fi

echo ""
print_header "Resumen"
echo "✓ Secrets configurados en GitHub"
echo "✓ Listos para usar en GitHub Actions"
echo ""
echo "Próximos pasos:"
echo "1. Haz un cambio en el código"
echo "2. Commit y push: git push origin main"
echo "3. Ve a GitHub → Actions para ver el workflow ejecutándose"
echo "4. Las imágenes se subirán a Docker Hub como:"
echo "   - $DOCKER_USER/microservice-1:latest"
echo "   - $DOCKER_USER/microservice-2:latest"
echo ""
print_success "¡Configuración completada!"
