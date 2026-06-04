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
