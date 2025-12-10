#!/bin/bash

# Script rápido para testing local
# Uso: ./quick-test.sh

set -e

BASE_URL_MS1="http://localhost:5000"
BASE_URL_MS2="http://localhost:5001"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Testing Microservices ===${NC}\n"

# Test Health Checks
echo -e "${BLUE}1. Health Checks${NC}"
echo "  MS1: $(curl -s $BASE_URL_MS1/health | jq .status)"
echo "  MS2: $(curl -s $BASE_URL_MS2/health | jq .status)"

# Test GET Items (vacío)
echo -e "\n${BLUE}2. GET /items (antes de crear)${NC}"
curl -s $BASE_URL_MS1/items | jq '.'

# Test POST Item en MS1
echo -e "\n${BLUE}3. POST /items en MS1${NC}"
RESPONSE=$(curl -s -X POST $BASE_URL_MS1/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item 1","description":"Created via MS1"}')
echo "$RESPONSE" | jq '.'
ITEM_ID=$(echo "$RESPONSE" | jq '.data.id')
echo "Item creado con ID: $ITEM_ID"

# Test POST más items
echo -e "\n${BLUE}4. Creando más items${NC}"
curl -s -X POST $BASE_URL_MS1/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item 2","description":"Another test item"}' | jq '.data | {id, name}'

curl -s -X POST $BASE_URL_MS1/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Test Item 3","description":"Third test item"}' | jq '.data | {id, name}'

# Test GET Items
echo -e "\n${BLUE}5. GET /items (después de crear)${NC}"
curl -s $BASE_URL_MS1/items | jq '.data[] | {id, name, description}'

# Test GET específico
echo -e "\n${BLUE}6. GET /items/{id}${NC}"
curl -s "$BASE_URL_MS1/items/$ITEM_ID" | jq '.data | {id, name, description}'

# Test consumo desde MS2
echo -e "\n${BLUE}7. GET /items desde MS2 (consumidor)${NC}"
curl -s $BASE_URL_MS2/items | jq '.data[] | {id, name, description}'

# Test PUT (update)
echo -e "\n${BLUE}8. PUT /items/{id} - Actualizando${NC}"
curl -s -X PUT "$BASE_URL_MS1/items/$ITEM_ID" \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Item","description":"Item actualizado"}' | jq '.data | {id, name, description}'

# Test Status de MS2
echo -e "\n${BLUE}9. Status de MS2 (incluye MS1)${NC}"
curl -s $BASE_URL_MS2/status | jq '.'

# Test Proxy Info
echo -e "\n${BLUE}10. Proxy Info de MS2${NC}"
curl -s $BASE_URL_MS2/proxy/info | jq '.'

# Test DELETE
echo -e "\n${BLUE}11. DELETE /items/{id}${NC}"
curl -s -X DELETE "$BASE_URL_MS1/items/$ITEM_ID" | jq '.'

# Verificar que fue eliminado
echo -e "\n${BLUE}12. Verificar eliminación${NC}"
curl -s "$BASE_URL_MS1/items/$ITEM_ID" | jq '.message'

echo -e "\n${GREEN}✓ Todos los tests completados${NC}\n"
