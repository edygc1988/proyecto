#!/bin/bash

# Script helper para operaciones comunes en la solución de microservicios
# Uso: ./microservices.sh [comando]

set -e

NAMESPACE="microservices"
MS1_PORT=5000
MS2_PORT=5001
POSTGRES_PORT=5432

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones auxiliares
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

# Comando: status
cmd_status() {
    print_header "Estado de los Servicios"
    
    echo -e "\n${BLUE}Namespaces:${NC}"
    kubectl get namespaces | grep -E "microservices|NAME"
    
    echo -e "\n${BLUE}Pods:${NC}"
    kubectl get pods -n $NAMESPACE 2>/dev/null || echo "Namespace no existe"
    
    echo -e "\n${BLUE}Services:${NC}"
    kubectl get svc -n $NAMESPACE 2>/dev/null || echo "Namespace no existe"
    
    echo -e "\n${BLUE}Deployments:${NC}"
    kubectl get deployments -n $NAMESPACE 2>/dev/null || echo "Namespace no existe"
}

# Comando: deploy
cmd_deploy() {
    print_header "Desplegando servicios en Kubernetes"
    
    # Actualizar referencias de imagen (opcional)
    if [ -z "$1" ]; then
        print_warning "Usando imágenes 'your-repo'. Para usar tu registro, ejecuta:"
        echo "  sed -i 's|your-repo|your-registry|g' k8s/k8s.yaml"
    else
        sed -i "s|your-repo|$1|g" k8s/k8s.yaml
        print_success "Referencias de imagen actualizadas a: $1"
    fi
    
    print_header "Aplicando manifests de Kubernetes"
    kubectl apply -f k8s/k8s.yaml
    
    print_header "Esperando rollout..."
    kubectl rollout status deployment/microservice-1 -n $NAMESPACE --timeout=5m || true
    kubectl rollout status deployment/microservice-2 -n $NAMESPACE --timeout=5m || true
    
    print_success "Despliegue completado"
    cmd_status
}

# Comando: destroy
cmd_destroy() {
    print_header "Eliminando despliegue de Kubernetes"
    
    read -p "¿Estás seguro? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        kubectl delete -f k8s/k8s.yaml || true
        kubectl delete namespace $NAMESPACE || true
        print_success "Recursos eliminados"
    else
        print_warning "Operación cancelada"
    fi
}

# Comando: logs
cmd_logs() {
    local service=$1
    local lines=${2:-50}
    
    if [ -z "$service" ]; then
        print_error "Uso: $0 logs <microservice-1|microservice-2|postgres> [líneas]"
        return 1
    fi
    
    print_header "Logs de $service (últimas $lines líneas)"
    kubectl logs -n $NAMESPACE -l app=$service --tail=$lines -f || \
        kubectl logs -n $NAMESPACE -l app=$service --tail=$lines
}

# Comando: shell
cmd_shell() {
    local pod=$1
    
    if [ -z "$pod" ]; then
        print_error "Uso: $0 shell <pod-name>"
        return 1
    fi
    
    print_header "Abriendo shell en pod: $pod"
    kubectl exec -it -n $NAMESPACE $pod -- /bin/sh
}

# Comando: port-forward
cmd_port_forward() {
    local service=$1
    local local_port=$2
    
    if [ -z "$service" ]; then
        print_header "Port-forward disponibles:"
        echo "  $0 port-forward microservice-1 5000"
        echo "  $0 port-forward microservice-2 5001"
        echo "  $0 port-forward postgres 5432"
        return 0
    fi
    
    local remote_port=$local_port
    if [ "$service" == "microservice-1" ]; then
        remote_port=5000
    elif [ "$service" == "microservice-2" ]; then
        remote_port=5001
    elif [ "$service" == "postgres" ]; then
        remote_port=5432
    fi
    
    print_header "Port-forward $service"
    echo "Disponible en: localhost:$local_port"
    echo "Presiona Ctrl+C para terminar"
    kubectl port-forward -n $NAMESPACE svc/$service $local_port:$remote_port
}

# Comando: test
cmd_test() {
    print_header "Ejecutando pruebas"
    
    # Health checks
    echo -e "\n${BLUE}Health Checks:${NC}"
    
    # Port-forward en background
    kubectl port-forward -n $NAMESPACE svc/microservice-1 5000:5000 &
    PF_PID=$!
    sleep 2
    
    echo "Microservice-1: $(curl -s http://localhost:5000/health | jq -r '.status' 2>/dev/null || echo 'FAILED')"
    
    kill $PF_PID 2>/dev/null || true
    
    kubectl port-forward -n $NAMESPACE svc/microservice-2 5001:5001 &
    PF_PID=$!
    sleep 2
    
    echo "Microservice-2: $(curl -s http://localhost:5001/health | jq -r '.status' 2>/dev/null || echo 'FAILED')"
    
    kill $PF_PID 2>/dev/null || true
    
    print_success "Tests completados"
}

# Comando: db-shell
cmd_db_shell() {
    print_header "Conectando a PostgreSQL"
    
    local pod=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$pod" ]; then
        print_error "Pod de PostgreSQL no encontrado"
        return 1
    fi
    
    kubectl exec -it -n $NAMESPACE $pod -- \
        psql -U postgres -d microservices_db
}

# Comando: db-backup
cmd_db_backup() {
    print_header "Creando backup de PostgreSQL"
    
    local pod=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}')
    local backup_file="backup-$(date +%Y%m%d-%H%M%S).sql"
    
    if [ -z "$pod" ]; then
        print_error "Pod de PostgreSQL no encontrado"
        return 1
    fi
    
    kubectl exec -n $NAMESPACE $pod -- \
        pg_dump -U postgres microservices_db > "$backup_file"
    
    print_success "Backup creado: $backup_file"
}

# Comando: help
cmd_help() {
    cat << EOF
${BLUE}Microservices Helper Script${NC}

Uso: $0 [comando] [opciones]

Comandos disponibles:

  ${YELLOW}Información y Estado:${NC}
    status                    - Mostrar estado de todos los servicios
    help                      - Mostrar esta ayuda

  ${YELLOW}Despliegue:${NC}
    deploy [registry]         - Desplegar en Kubernetes
    destroy                   - Eliminar despliegue
    
  ${YELLOW}Monitoreo:${NC}
    logs <servicio> [líneas]  - Ver logs de un servicio
                                Servicios: microservice-1, microservice-2, postgres
    test                      - Ejecutar smoke tests
    
  ${YELLOW}Acceso a Pods:${NC}
    shell <pod-name>          - Abrir shell en un pod
    port-forward <svc> <port> - Hacer port-forward a un servicio
    
  ${YELLOW}Base de Datos:${NC}
    db-shell                  - Conectar a PostgreSQL
    db-backup                 - Crear backup de base de datos

Ejemplos:

  # Ver estado general
  $0 status
  
  # Desplegar con tu registro
  $0 deploy ghcr.io/tu-usuario
  
  # Ver logs de MS1
  $0 logs microservice-1 100
  
  # Port-forward a MS1
  $0 port-forward microservice-1 5000
  
  # Hacer backup
  $0 db-backup

EOF
}

# Main
case "${1:-help}" in
    status)
        cmd_status
        ;;
    deploy)
        cmd_deploy "$2"
        ;;
    destroy)
        cmd_destroy
        ;;
    logs)
        cmd_logs "$2" "$3"
        ;;
    shell)
        cmd_shell "$2"
        ;;
    port-forward)
        cmd_port_forward "$2" "$3"
        ;;
    test)
        cmd_test
        ;;
    db-shell)
        cmd_db_shell
        ;;
    db-backup)
        cmd_db_backup
        ;;
    help)
        cmd_help
        ;;
    *)
        print_error "Comando desconocido: $1"
        cmd_help
        exit 1
        ;;
esac
