# Evolution API - Integração WhatsApp & Chatwoot

API de integração para WhatsApp baseada em Baileys e WhatsApp Cloud API, integrada ao Chatwoot.

## 🚀 Acesso e Credenciais

- **URL API:** `https://evolution.moratosolucoes.com.br`
- **Dashboard/Manager:** `https://evolution.moratosolucoes.com.br/manager`
- **API Key:** `d44bacf08951f12db28f5e083a7e613c7636e4f6769441ce`

## 🛠️ Comandos Úteis

```bash
# Navegar até o diretório do docker
cd /var/www/apps/evolution-api/docker

# Ver logs em tempo real
docker compose logs -f evolution-api

# Reiniciar serviços
docker compose restart evolution-api

# Atualizar configuração (após mudar docker-compose.yml)
docker compose up -d --force-recreate
```

## 📂 Estrutura de Diretórios

- `docker/`: Arquivos de configuração do Docker Compose.
- `data/`: Snapshots de schema e dados.
- `secrets/`: Variáveis de ambiente (link para `/var/www/secrets/`).
- `testes/`: Scripts de validação de saúde da API.
- `doc/`: Documentação técnica e Nginx configs.
- `monitor/`: Script de verificação automática (execução diária 03:00).

## 📡 Monitor Automático

Dois scripts de monitoramento via cron:

| Script | Frequência | Verifica | Notifica |
|---|---|---|---|
| `monitor/check_health.sh` | **A cada 1 hora** | API, instância WhatsApp, containers, disco | ⚠️ Só se algo falhar |
| `monitor/check_upstream.sh` | **1x ao dia (03:00)** | Baileys npm, GitHub releases, CVE, logs | ⚠️ Só se precisar de update |

**Notificações** enviadas no grupo `Server_notification` (WhatsApp). Fallback para número pessoal se o grupo falhar.

```bash
# Executar manualmente
bash /var/www/apps/evolution-api/monitor/check_health.sh
bash /var/www/apps/evolution-api/monitor/check_upstream.sh

# Logs do monitor
ls -la /var/www/apps/evolution-api/monitor/logs/
```

### 🟢 Monitor 1-minuto (Google Apps Script)

O script `monitor/gs_monitor.gs` roda no Google Sheets e verifica todos os serviços a cada 1 minuto via `https://moratosolucoes.com.br/api/v1/health-aggregator`. Envia notificações para **Telegram** e **WhatsApp** (grupo Server_notification).

**Para instalar/atualizar:**
1. Abra a planilha do monitoramento no Google Sheets
2. Extensões → Apps Script
3. Cole o conteúdo de `monitor/gs_monitor.gs`
4. Disparadores → Ativar → `checkServerHealth` → a cada 1 minuto
5. Execute uma vez para autorizar permissões

## 🔗 Integração Chatwoot

A integração com o Chatwoot já está pré-configurada globalmente. Para conectar uma instância de WhatsApp ao Chatwoot:

1. Crie uma Inbox do tipo **API** no Chatwoot.
2. Na Evolution API, ao criar a instância, habilite a integração Chatwoot informando a URL e o Token.
> **Aviso:** Evite usar URLs internas (ex: `http://chatwoot-rails:3000`) se o Chatwoot contiver a diretriz `FORCE_SSL=true`, pois haverá falha de redirecionamento interno. Sempre utilize a URL pública `https://chat.moratosolucoes.com.br`.

### 📝 Modelo de Integração via API (cURL)

Caso precise configurar manualmente uma instância existente via terminal:

```bash
curl -X POST http://localhost:5030/chatwoot/set/NOME_DA_INSTANCIA \
  -H "apikey: d44bacf08951f12db28f5e083a7e613c7636e4f6769441ce" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "url": "https://chat.moratosolucoes.com.br",
    "accountId": "1",
    "token": "VrzmnmHXKABJ2diSQMcLLnoY",
    "signMsg": true,
    "reopenConversation": true,
    "conversationPending": false,
    "importContacts": true,
    "importMessages": true,
    "daysLimitImportMessages": 7
  }'
```

## ⚠️ Manutenção de DNS
Este serviço requer que o subdomínio `evolution.moratosolucoes.com.br` esteja apontado para o IP `161.97.161.109`. Após o apontamento, o SSL será renovado automaticamente.

quando eu clico em QRCODE para ler nao abre para leitura, precisa confirmar se a variavel do whatsapp é compativel com a versao atual Versão 2.3000.1034030014 ( ou versao superior)
