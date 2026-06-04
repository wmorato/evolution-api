# Análise de Implementação - Evolution API

## 1. Objetivo
Implementar a Evolution API integrada ao Chatwoot para permitir o uso de WhatsApp via Baileys (WhatsApp Web) ou WhatsApp Cloud API, mantendo a arquitetura Docker-first e a organização centralizada de segredos.

## 2. Arquitetura

| Componente | Detalhe |
|------------|---------|
| **API** | Evolution API (Node.js) |
| **Banco de Dados** | PostgreSQL 16 (Container dedicado) |
| **Cache/Sessões** | Redis 7 (Container dedicado) |
| **Proxy** | Nginx (Proxy reverso) |
| **Integração** | Chatwoot (via Webhooks e API) |

## 3. Configuração de Rede e Portas

| Serviço | Porta Interna | Porta Externa (Host) |
|---------|---------------|----------------------|
| Evolution API | 8080 | 5030 |
| PostgreSQL | 5432 | 5436 |
| Redis | 6379 | 6382 |

## 4. Subdomínio e SSL

- **URL:** `https://evolution.moratosolucoes.com.br`
- **SSL:** Let's Encrypt (Pendente de apontamento DNS)
- **Status DNS:** ⚠️ Necessário criar entrada TIPO A para `evolution.moratosolucoes.com.br` apontando para `161.97.161.109`.

## 5. Integração com Chatwoot

A integração é feita no momento da criação da instância na Evolution API.
As credenciais necessárias já foram mapeadas:
- **Chatwoot URL:** `https://chat.moratosolucoes.com.br`
- **Account ID:** 1
- **Access Token:** [Extraído do banco de dados]

## 6. Próximos Passos
1. Concluir o pull da imagem estável `v2.1.1` (a versão `latest` apresenta bug de loop de desconexão do Redis).
2. Aguardar apontamento DNS pelo usuário para `evolution.moratosolucoes.com.br` (IP: `161.97.161.109`).
3. Gerar certificado SSL (`certbot`).
4. Criar a primeira instância de WhatsApp e configurar Chatwoot.
5. Validar recepção de mensagens no Chatwoot.

## 7. Status Atual
- ✅ **API:** Operacional na versão `v2.1.1` (estável).
- ✅ **Redis/Postgres:** Conectados e saudáveis.
- ✅ **Manager:** Disponível em `https://evolution.moratosolucoes.com.br/manager`.
- ✅ **SSL:** Certificado Let's Encrypt ativo para o domínio principal.

## 8. Guia de Uso Rápido
1. Acesse o **Manager** via URL acima.
2. Use a **API Key** configurada (veja README) para autenticar.
3. Crie uma instância e no menu de integração, selecione **Chatwoot**.

## 9. Troubleshooting (2026-02-27)
- **Problema 1 (SSL/EPROTO):** Mensagens enviadas pelo Chatwoot não chegavam na Evolution (Erro `[object Object]` na interface).
- **Causa:** `FORCE_SSL=true` no Chatwoot forçava HTTPS na rede interna Docker, quebrando a comunicação.
- **Solução:** `FORCE_SSL` alterado para `false`. Segurança mantida pelo Nginx externo.

- **Problema 2 (SDK Bug v2.3.7):** Erro `TypeError: t.get is not a function` impedia criação de conversas em grupos.
- **Causa:** Bug nativo na versão `latest` (v2.3.7) da Evolution API.
- **Solução:** Realizado downgrade para a versão estável **v2.2.1**.

- **Problema 3 (Rede Interna):** Lentidão e falhas intermitentes via Cloudflare.
- **Solução:** Configurado `CHATWOOT_GLOBAL_URL=http://chatwoot-rails:3000` e Webhook no Chatwoot DB apontando para `http://evolution-api:8080`. Tráfego agora é 100% interno.

## 11. Guia de Mensagens em Grupos

Para enviar mensagens para grupos, é necessário o **JID** do grupo (finalizado em `@g.us`).

### 11.1 Como obter o JID do Grupo
Use este comando para listar todos os grupos e identificar o JID do grupo "Vendas":

```bash
curl --location 'https://evolution.moratosolucoes.com.br/group/fetchAllGroups/W4?getParticipants=false' \
--header 'apikey: DAAFC8A9BD55-4F4E-AFC3-7EA387CC3F65'
```

### 11.2 Como enviar mensagem para o Grupo
Substitua `JID_DO_GRUPO` pelo valor obtido no passo anterior:

```bash
curl --location 'https://evolution.moratosolucoes.com.br/message/sendText/W4' \
--header 'Content-Type: application/json' \
--header 'apikey: DAAFC8A9BD55-4F4E-AFC3-7EA387CC3F65' \
--data '{
    "number": "JID_DO_GRUPO@g.us",
    "text": "Mensagem de teste enviada via Evolution API"
}'
```

---

## 12. Status Final
- ✅ **Comunicação Bidirecional:** WhatsApp <=> Evolution <=> Chatwoot.
- ✅ **Estabilidade:** Versão v2.2.1 rodando sem erros de SDK.
- ✅ **Documentação:** Atualizada com comandos de grupo e JID.
