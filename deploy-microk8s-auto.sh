#!/bin/bash

# Script de despliegue automático para MicroK8s
# Uso: ./deploy-microk8s.sh

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

# Verificar si MicroK8s está instalado
if ! command -v microk8s &> /dev/null; then
    print_error "MicroK8s no está instalado"
    echo "Instala con: brew install microk8s (macOS) o snap install microk8s --classic (Linux)"
    exit 1
fi

print_header "Despliegue en MicroK8s"

# Iniciar MicroK8s si no está corriendo
print_header "Verificando MicroK8s"
if ! microk8s status 2>/dev/null | grep -q "is running"; then
    print_warning "MicroK8s no está corriendo, iniciando..."
    microk8s start
    sleep 5
fi

# Esperar a que esté listo
print_warning "Esperando a que MicroK8s esté listo..."
microk8s status --wait-ready
print_success "MicroK8s está listo"

# Habilitar add-ons necesarios
print_header "Habilitando add-ons"
echo "Habilitando storage..."
microk8s enable storage > /dev/null 2>&1 || print_warning "Storage ya estaba habilitado"

echo "Habilitando dns..."
microk8s enable dns > /dev/null 2>&1 || print_warning "DNS ya estaba habilitado"

echo "Habilitando registry..."
microk8s enable registry > /dev/null 2>&1 || print_warning "Registry ya estaba habilitado"

print_success "Add-ons habilitados"

# Crear alias para kubectl
alias kubectl='microk8s kubectl'

print_header "Desplegando aplicación"

# Limpiar despliegue anterior (opcional)
# microk8s kubectl delete -f k8s/k8s.yaml 2>/dev/null || true

# Aplicar configuración Kubernetes
print_warning "Aplicando manifests..."
microk8s kubectl apply -f k8s/k8s.yaml

print_success "Manifests aplicados"

# Esperar a que el namespace se cree
print_warning "Esperando a que se cree el namespace..."
sleep 2

# Esperar a que los pods estén listos
print_header "Esperando que los pods estén listos"
print_warning "Esto puede tomar 1-2 minutos..."

# PostgreSQL
echo -n "PostgreSQL: "
microk8s kubectl wait --for=condition=ready pod -l app=postgres -n microservices --timeout=300s 2>/dev/null && print_success "Listo" || print_warning "Timeout"

# Microservicio 1
echo -n "Microservicio 1: "
microk8s kubectl wait --for=condition=ready pod -l app=microservice-1 -n microservices --timeout=300s 2>/dev/null && print_success "Listo" || print_warning "Timeout"

# Microservicio 2
echo -n "Microservicio 2: "
microk8s kubectl wait --for=condition=ready pod -l app=microservice-2 -n microservices --timeout=300s 2>/dev/null && print_success "Listo" || print_warning "Timeout"

print_header "Estado del Despliegue"

echo ""
echo "Namespace:"
microk8s kubectl get namespace microservices

echo ""
echo "Pods:"
microk8s kubectl get pods -n microservices

echo ""
echo "Servicios:"
microk8s kubectl get svc -n microservices

echo ""
echo "Deployments:"
microk8s kubectl get deployments -n microservices

# Información de acceso
print_header "Acceso a los Servicios"

echo ""
echo "Para acceder a los servicios, usa port-forward en otra terminal:"
echo ""
echo "  Microservicio 1:"
echo "  $ microk8s kubectl port-forward -n microservices svc/microservice-1 5000:5000"
echo ""
echo "  Microservicio 2:"
echo "  $ microk8s kubectl port-forward -n microservices svc/microservice-2 5001:5001"
echo ""
echo "  PostgreSQL:"
echo "  $ microk8s kubectl port-forward -n microservices svc/postgres 5432:5432"
echo ""

# Pruebas rápidas
print_header "Pruebas Rápidas"

echo ""
echo "En otra terminal, ejecuta:"
echo "  curl http://localhost:5000/health"
echo "  curl http://localhost:5001/health"
echo ""

# Ofrecer iniciar port-forward en background
read -p "¿Deseas iniciar port-forward automáticamente? (s/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_header "Iniciando port-forward"
    
    nohup microk8s kubectl port-forward -n microservices svc/microservice-1 5000:5000 > /tmp/ms1-pf.log 2>&1 &
    MS1_PID=$!
    echo "MS1 PID: $MS1_PID"
    
    nohup microk8s kubectl port-forward -n microservices svc/microservice-2 5001:5001 > /tmp/ms2-pf.log 2>&1 &
    MS2_PID=$!
    echo "MS2 PID: $MS2_PID"
    
    nohup microk8s kubectl port-forward -n microservices svc/postgres 5432:5432 > /tmp/pg-pf.log 2>&1 &
    PG_PID=$!
    echo "PostgreSQL PID: $PG_PID"
    
    sleep 2
    
    print_success "Port-forward iniciado"
    
    # Guardar PIDs para poder detenerlos después
    echo "$MS1_PID $MS2_PID $PG_PID" > /tmp/microk8s-pf-pids.txt
    
    echo ""
    echo "Para detener port-forward, ejecuta:"
    echo "  kill $(cat /tmp/microk8s-pf-pids.txt)"
    echo ""
fi

print_header "Comandos Útiles"

echo ""
echo "Ver logs:"
echo "  microk8s kubectl logs -f -n microservices -l app=microservice-1"
echo "  microk8s kubectl logs -f -n microservices -l app=microservice-2"
echo ""
echo "Ver estado en tiempo real:"
echo "  watch microk8s kubectl get pods -n microservices"
echo ""
echo "Conectar a PostgreSQL:"
echo "  microk8s kubectl exec -it postgres-0 -n microservices -- psql -U postgres -d microservices_db"
echo ""
echo "Detener MicroK8s:"
echo "  microk8s stop"
echo ""
echo "Limpiar todo:"
echo "  microk8s kubectl delete -f k8s/k8s.yaml"
echo "  microk8s kubectl delete namespace microservices"
echo ""

print_success "¡Despliegue completado!"
echo ""
echo "Servicios disponibles:"
echo "  - MS1: http://localhost:5000/health"
echo "  - MS2: http://localhost:5001/health"
echo ""
