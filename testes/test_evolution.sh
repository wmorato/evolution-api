#!/bin/bash

# Test script for Evolution API validation
API_URL="http://localhost:5030"
API_KEY="d44bacf08951f12db28f5e083a7e613c7636e4f6769441ce"

echo "=== Verificando Containers Evolution API ==="
docker ps --format "table {{.Names}}\t{{.Status}}" | grep evolution

echo -e "\n=== Testando Conectividade da API ==="
RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -H "apikey: $API_KEY" "$API_URL/instance/fetchInstances")

if [ "$RESPONSE" == "200" ]; then
    echo "✅ API está respondendo corretamente (HTTP 200)"
else
    echo "❌ Falha na conexão com a API (HTTP $RESPONSE)"
    exit 1
fi

echo -e "\n=== Testando Instância W4 ==="
INSTANCE_STATUS=$(curl -s -H "apikey: $API_KEY" "$API_URL/instance/connectionState/W4")
if [[ $INSTANCE_STATUS == *"CONNECTED"* ]]; then
    echo "✅ Instância W4 vinculada e conectada"
else
    echo "⚠️ Instância W4 não está conectada ou não existe. Status: $INSTANCE_STATUS"
fi

echo -e "\n=== Testando Listagem de Grupos em W4 ==="
# Token da conexão W4
W4_TOKEN="DAAFC8A9BD55-4F4E-AFC3-7EA387CC3F65"
GROUPS_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null -H "apikey: $W4_TOKEN" "$API_URL/group/fetchAllGroups/W4?getParticipants=false")
if [ "$GROUPS_RESPONSE" == "200" ]; then
    echo "✅ Listagem de grupos funcionando em W4"
else
    echo "❌ Falha ao listar grupos em W4 (HTTP $GROUPS_RESPONSE)"
fi

echo -e "\n=== Verificando Logs Recentes ==="
docker logs evolution-api --tail 10
