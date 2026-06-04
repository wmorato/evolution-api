# History - Evolution API & Chatwoot Integration

## 2026-02-27
- **Troubleshooting Chatwoot Integration:**
  - Identificação do bug "TypeError: t.get is not a function" na v2.3.7 da Evolution API.
  - Downgrade para versão estável v2.2.1.
  - Reconfiguração da rede interna Docker para comunicação entre containers.
  - Ajuste de `FORCE_SSL=false` no Chatwoot para evitar bloqueios de protocolo interno.
  - Atualização de webhooks no banco Postgres do Chatwoot para apontar para o endpoint interno da Evolution.
  - Validação de fluxo de mensagens bidirecional.
  - Geração de documentação de status em `Server/DOCS/status_sistema.md`.

## 2026-03-09
- **Documentação de Uso:**
  - Adicionado guia de envio de mensagens para grupos via API.
  - Mapeamento do endpoint `FETCH_GROUPS` e `SEND_TEXT` para a instância "W4".
  - Disponibilização de comandos `curl` para o usuário.
