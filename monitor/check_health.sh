#!/bin/bash
# ====================================================================
# Monitor Evolution API — Health check rápido
# Execução: a cada 1 hora via cron
# NOTA: O monitor 1-minuto via Google Apps Script está em:
#   Google Sheets → Extensões → Apps Script (ecossistema-monitoramento)
#   Esse script envia notificações para o Telegram E WhatsApp
# ====================================================================
set -euo pipefail

WORK_DIR="/var/www/apps/evolution-api"
LOG_DIR="$WORK_DIR/monitor/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/health_$(date +%Y%m%d).log"

NOTIFICATION_GROUP="120363409484120144@g.us"
NOTIFICATION_GROUP_FALLBACK="5513988506358@s.whatsapp.net"

API_URL="http://localhost:5030"
INSTANCE="MS_Morato"
TOKEN="F49763A794EB-4ACE-8523-EA1B7FD29216"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2" | tee -a "$LOG_FILE"; }
log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERRO" "$1"; }

send_notification() {
    local message="$1"
    local target="$NOTIFICATION_GROUP"
    local target_name="grupo Server_notification"
    local json_payload
    json_payload=$(python3 -c "import json,sys; print(json.dumps({'number': sys.argv[1], 'text': sys.argv[2]}))" "$target" "$message")

    for attempt in 1 2; do
        response=$(curl -s --max-time 15 -X POST "$API_URL/message/sendText/$INSTANCE" \
            -H "Content-Type: application/json" \
            -H "apikey: $TOKEN" \
            -d "$json_payload")
        if echo "$response" | grep -q '"status":"PENDING"'; then
            log_info "Notificação enviada para $target_name"
            return 0
        fi
        if [ $attempt -eq 1 ]; then
            log_warn "Falha no grupo, tentando fallback..."
            target="$NOTIFICATION_GROUP_FALLBACK"
            target_name="número pessoal"
            json_payload=$(python3 -c "import json,sys; print(json.dumps({'number': sys.argv[1], 'text': sys.argv[2]}))" "$target" "$message")
        fi
    done
    log_error "FALHA CRÍTICA: não foi possível enviar notificação"
    return 1
}

alerts=""

# 1. API health
if curl -s -o /dev/null -w "%{http_code}" --max-time 10 -H "apikey: $TOKEN" "$API_URL/" | grep -q 200; then
    log_info "✅ API respondendo"
else
    log_error "❌ API não respondeu"
    send_notification "🔴 EMERGÊNCIA: Evolution API parou de responder!"
    exit 1
fi

# 2. Instância WhatsApp
state=$(curl -s --max-time 10 -H "apikey: $TOKEN" "$API_URL/instance/connectionState/$INSTANCE" | grep -oP '"state"\s*:\s*"\K[^"]+')
if [ "$state" = "open" ]; then
    log_info "✅ Instância $INSTANCE: conectada"
else
    log_warn "⚠️ Instância $INSTANCE: $state"
    alerts="${alerts}⚠️ WhatsApp $INSTANCE desconectado (estado: $state)\n"
fi

# 3. Containers
for c in evolution-api evolution-postgres evolution-redis; do
    status=$(docker ps --filter "name=$c" --format "{{.Status}}" 2>/dev/null | head -1)
    if [ -z "$status" ]; then
        log_error "❌ Container $c parado"
        alerts="${alerts}🔴 Container $c não está rodando!\n"
    fi
done
[ -z "$alerts" ] && log_info "✅ Todos os containers rodando"

# 4. Disco
disk=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$disk" -gt 85 ]; then
    log_warn "⚠️ Disco em $disk%"
    alerts="${alerts}⚠️ Disco: $disk% usado\n"
else
    log_info "✅ Disco: $disk% usado"
fi

# Notificar se algo errado
if [ -n "$alerts" ]; then
    msg="📡 Health Check — $(date '+%d/%m/%Y %H:%M')\n${alerts}Ação necessária."
    send_notification "$msg"
fi
exit 0
