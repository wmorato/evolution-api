#!/bin/bash

# Test script for Evolution API validation
API_URL="http://localhost:5030"
API_KEY="d44bacf08951f12db28f5e083a7e613c7636e4f6769441ce"
INSTANCE="MS_Morato"
INSTANCE_TOKEN="F49763A794EB-4ACE-8523-EA1B7FD29216"

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

echo -e "\n=== Testando Instância $INSTANCE ==="
INSTANCE_STATUS=$(curl -s -H "apikey: $INSTANCE_TOKEN" "$API_URL/instance/connectionState/$INSTANCE")
if [[ $INSTANCE_STATUS == *"open"* ]]; then
    echo "✅ Instância $INSTANCE conectada (open)"
else
    echo "⚠️ Instância $INSTANCE não está conectada. Status: $INSTANCE_STATUS"
fi

echo -e "\n=== Verificando Logs Recentes ==="
docker logs evolution-api --tail 10
