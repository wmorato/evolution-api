#!/bin/bash
# Rollback script - Evolution API v2.2.1
# Uso: bash rollback.sh

BACKUP_DIR="/var/www/apps/evolution-api/backup"
COMPOSE_DIR="/var/www/apps/evolution-api/docker"

echo "=== Iniciando Rollback para v2.2.1 ==="

# 1. Parar container
echo "Parando evolution-api..."
docker compose -f "$COMPOSE_DIR/docker-compose.yml" stop evolution-api
docker compose -f "$COMPOSE_DIR/docker-compose.yml" rm -f evolution-api

# 2. Restaurar imagem antiga no docker-compose
echo "Restaurando imagem v2.2.1..."
sed -i 's|image: evolution-api-custom:2.3.7-baileys-rc13|image: evoapicloud/evolution-api:v2.2.1|' "$COMPOSE_DIR/docker-compose.yml"
sed -i '/build:/,+1d' "$COMPOSE_DIR/docker-compose.yml"

# 3. Restaurar banco de dados
echo "Restaurando banco PostgreSQL..."
SQL_BACKUP=$(ls -t "$BACKUP_DIR"/evolution_v2.2.1_*.sql | head -1)
if [ -f "$SQL_BACKUP" ]; then
  docker exec evolution-postgres psql -U postgres -c "DROP DATABASE IF EXISTS evolution_api; CREATE DATABASE evolution_api;"
  cat "$SQL_BACKUP" | docker exec -i evolution-postgres psql -U postgres -d evolution_api
  echo "Banco restaurado: $SQL_BACKUP"
else
  echo "ERRO: Backup SQL não encontrado em $BACKUP_DIR"
  exit 1
fi

# 4. Subir container novamente
echo "Iniciando evolution-api v2.2.1..."
docker compose -f "$COMPOSE_DIR/docker-compose.yml" up -d evolution-api

echo "=== Rollback concluído ==="
