#!/bin/bash
# ====================================================================
# Monitor Evolution API — Verificação de upstream (dependências)
# Execução: 1x ao dia via cron (03:00)
# Health check rápido roda a cada 1h pelo check_health.sh
# ====================================================================
set -euo pipefail

# === CONFIGURAÇÕES ===
WORK_DIR="/var/www/apps/evolution-api"
LOG_DIR="$WORK_DIR/monitor/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/check_$(date +%Y%m%d).log"

# Grupo de notificação (WhatsApp)
NOTIFICATION_GROUP="120363409484120144@g.us"
NOTIFICATION_GROUP_FALLBACK="5513988506358@s.whatsapp.net"

# Instância Evolution API
API_URL="http://localhost:5030"
INSTANCE="MS_Morato"
TOKEN="F49763A794EB-4ACE-8523-EA1B7FD29216"

# Token GitHub (via env ou extraído do git remote)
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GITHUB_TOKEN" ]; then
    GITHUB_TOKEN=$(cd "$WORK_DIR" && git remote get-url origin 2>/dev/null | sed 's|.*://[^:]*:\([^@]*\)@.*|\1|')
fi

# Versões atuais
CURRENT_BAILEYS="7.0.0-rc13"
CURRENT_EVOLUTION="2.3.7"

# Limites
TIMEOUT_CURL=30
MAX_RETRIES=3

# === FUNÇÕES ===

log() {
    local level="$1"
    local msg="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg" | tee -a "$LOG_FILE"
}

log_info()  { log "INFO" "$1"; }
log_warn()  { log "WARN" "$1"; }
log_error() { log "ERRO" "$1"; }

send_notification() {
    local message="$1"
    local priority="${2:-normal}" # normal ou urgente

    # Tenta grupo, fallback para número pessoal
    local target="$NOTIFICATION_GROUP"
    local target_name="grupo Server_notification"

    local url="$API_URL/message/sendText/$INSTANCE"
    local json_payload
    json_payload=$(python3 -c "import json,sys; print(json.dumps({'number': sys.argv[1], 'text': sys.argv[2]}))" "$target" "$message" 2>/dev/null)

    for attempt in 1 2; do
        response=$(curl -s --max-time 15 -X POST "$url" \
            -H "Content-Type: application/json" \
            -H "apikey: $TOKEN" \
            -d "$json_payload")

        if echo "$response" | grep -q '"status":"PENDING"'; then
            log_info "Notificação enviada para $target_name"
            return 0
        fi

        if [ $attempt -eq 1 ]; then
            log_warn "Falha ao enviar para grupo, tentando fallback..."
            target="$NOTIFICATION_GROUP_FALLBACK"
            target_name="número pessoal"
            json_payload=$(python3 -c "import json,sys; print(json.dumps({'number': sys.argv[1], 'text': sys.argv[2]}))" "$target" "$message" 2>/dev/null)
        fi
    done

    log_error "FALHA CRÍTICA: não foi possível enviar notificação"
    return 1
}

check_http() {
    local url="$1"
    local expected_code="${2:-200}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT_CURL" -H "apikey: $TOKEN" "$url" 2>/dev/null || echo "000")
    [ "$code" = "$expected_code" ]
}

baileys_version_gt() {
    # Compara versões semver-like (rc9 < rc10 < rc13)
    local v1="$1" v2="$2"
    local n1 n2
    n1=$(echo "$v1" | grep -oP '\d+' | head -1)
    n2=$(echo "$v2" | grep -oP '\d+' | head -1)
    [ "$n1" -gt "$n2" ] 2>/dev/null
}

# === VERIFICAÇÕES ===

summary=""
alerts=""

log_info "=== INICIANDO VERIFICAÇÃO DIÁRIA ==="

# 1. Verificar nova versão do Baileys no npm
log_info "Verificando Baileys npm..."
baileys_latest=$(npm view baileys version 2>/dev/null || echo "erro")
baileys_rc_latest=$(npm view baileys versions --json 2>/dev/null | python3 -c "
import sys, json
vers = json.load(sys.stdin)
rcs = [v for v in vers if 'rc' in v]
print(rcs[-1] if rcs else 'none')
" 2>/dev/null || echo "erro")

if [ "$baileys_rc_latest" != "erro" ] && [ "$baileys_rc_latest" != "none" ]; then
    if [ "$baileys_rc_latest" != "$CURRENT_BAILEYS" ]; then
        log_warn "⚠️ Novo Baileys disponível: $baileys_rc_latest (atual: $CURRENT_BAILEYS)"
        alerts="${alerts}⚠️ Novo Baileys: $baileys_rc_latest (atual: $CURRENT_BAILEYS)\n"
    else
        log_info "✅ Baileys atualizado ($CURRENT_BAILEYS)"
    fi
fi

# 2. Verificar novas releases do Evolution API no GitHub
log_info "Verificando GitHub Evolution API..."
gh_releases=$(curl -s --max-time "$TIMEOUT_CURL" \
    -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/evolution-foundation/evolution-api/releases?per_page=5" 2>/dev/null)

if [ -n "$gh_releases" ]; then
    latest_tag=$(echo "$gh_releases" | python3 -c "
import sys, json
try:
    releases = json.load(sys.stdin)
    for r in releases:
        tag = r.get('tag_name', '')
        if not tag.startswith('2.4'):  # Ignorar v2.4+ (licenciamento)
            print(tag)
            break
except: pass
" 2>/dev/null)

    if [ -n "$latest_tag" ] && [ "$latest_tag" != "$CURRENT_EVOLUTION" ]; then
        log_warn "⚠️ Nova versão Evolution disponível: $latest_tag (atual: $CURRENT_EVOLUTION)"
        alerts="${alerts}⚠️ Nova Evolution API: $latest_tag\n"
    else
        log_info "✅ Evolution API atualizada ($CURRENT_EVOLUTION)"
    fi
fi

# 3. Verificar CVE / issues críticas no Baileys
log_info "Verificando issues críticas no Baileys..."
cve_check=$(curl -s --max-time "$TIMEOUT_CURL" \
    "https://api.github.com/search/issues?q=repo:WhiskeySockets/Baileys+label:bug+state:open&per_page=3" 2>/dev/null)

cve_count=$(echo "$cve_check" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('total_count', 0))
except: print(0)
" 2>/dev/null)

# 4. Verificar logs por erros recentes (ignorar primeiras 2h pós-restart)
log_info "Verificando logs por erros..."
container_start=$(docker inspect evolution-api --format '{{.State.StartedAt}}' 2>/dev/null | cut -d'.' -f1)
container_epoch=$(date -d "$container_start" +%s 2>/dev/null || echo 0)
now_epoch=$(date +%s)
uptime_hours=$(( (now_epoch - container_epoch) / 3600 ))

if [ "$uptime_hours" -gt 2 ]; then
    recent_errors=$(docker logs evolution-api --since 24h 2>&1 | grep -cE "(Error|error|fail|critical)" 2>/dev/null || echo 0)
    if [ "$recent_errors" -gt 100 ]; then
        log_warn "⚠️ $recent_errors erros nas últimas 24h (pode ser ruído pós-restart)"
        alerts="${alerts}⚠️ $recent_errors erros nos logs (24h)\n"
    else
        log_info "✅ Logs limpos ($recent_errors erros)"
    fi
else
    log_info "⏳ Container rodando há ${uptime_hours}h — pulando verificação de logs"
fi

# === RESUMO E NOTIFICAÇÃO ===

if [ -n "$alerts" ]; then
    summary="📡 Monitor Evolution API — $(date '+%d/%m/%Y %H:%M')
${alerts}Ação necessária para continuidade do serviço."
    log_warn "=== INTERVENÇÃO NECESSÁRIA ==="
    echo -e "$alerts"
    send_notification "$summary" "urgente"
else
    summary="📡 Upstream Check — $(date '+%d/%m/%Y %H:%M')
✅ Baileys: $CURRENT_BAILEYS (atualizado)
✅ Evolution: $CURRENT_EVOLUTION
✅ Logs: sem anomalias
Nenhuma intervenção necessária."
    log_info "=== TUDO OK ==="
    # Notificação silenciosa só no log (pode descomentar abaixo se quiser notificar mesmo sem alertas)
    # send_notification "$summary"
fi

log_info "=== VERIFICAÇÃO CONCLUÍDA ==="
exit 0
