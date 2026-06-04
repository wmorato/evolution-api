# AGENTS.md - evolution-api

**WhatsApp (Baileys) + Chatwoot via Evolution API**

## Critical Pins & Versions
- **Image**: `evolution-api-custom:2.3.7-baileys-rc13` (custom build com Baileys rc13)
- **Base**: `evoapicloud/evolution-api:v2.3.7` — última versão sem licenciamento obrigatório
- **Baileys**: `7.0.0-rc13` (bump manual via Dockerfile.evolution)
- **GitHub fork**: `wmorato/evolution-api` (branch `main` = source, `production` = deploy)
- **Node**: `NODE_OPTIONS="--dns-result-order=ipv4first"` required in env

## Stack (Docker)
| Service | Container | Host Port |
|---|---|---|
| Evolution API | `evolution-api` | `127.0.0.1:5030` |
| Manager (UI) | `evolution-manager` | `127.0.0.1:5031` |
| PostgreSQL 16 | `evolution-postgres` | `127.0.0.1:5436` |
| Redis 7 | `evolution-redis` | `127.0.0.1:6382` |

## Network
- **Internal network**: `evolution-network` (auto-created)
- **External dependency**: `chatwoot-network` (`external: true`, real name `docker_chatwoot-network`) — created by the Chatwoot stack, not here
- All host ports bound to `127.0.0.1` only (Nginx reverse proxy handles public access)

## Chatwoot Integration
- `FORCE_SSL=false` in Chatwoot is **required** — otherwise internal container communication breaks (SSL/EPROTO)
- Use internal URLs between containers (`http://chatwoot-rails:3000`, not public HTTPS)
- Chatwoot webhooks in DB must point to `http://evolution-api:8080`

## Commands
```bash
# From /var/www/apps/evolution-api/docker/
docker compose logs -f evolution-api
docker compose restart evolution-api
docker compose up -d --force-recreate

# Health check
bash /var/www/apps/evolution-api/testes/test_evolution.sh

# Rollback (se necessário)
bash /var/www/apps/evolution-api/docker/rollback.sh

# Rebuild custom image (após alterar Dockerfile.evolution)
docker compose build evolution-api

# Nginx reload (after changing /var/www/apps/evolution-api/doc/evolution-nginx.conf)
sudo nginx -t && sudo systemctl reload nginx
```

## Nginx & DNS
- **Config**: `/var/www/apps/evolution-api/doc/evolution-nginx.conf`
- **Domain**: `evolution.moratosolucoes.com.br` → `161.97.161.109` (DNS A record required)
- **SSL**: Let's Encrypt (auto-renew via Nginx)

## Manutenção Contínua
- **Bump Baileys**: Editar `docker/Dockerfile.evolution` e rebuildar imagem
- **Monitorar LID**: Logs podem mostrar `@lid` — normal, v2.3.7 lida com isso
- **Upstream**: Não seguir v2.4.0+ (licenciamento obrigatório)

## Sensitive Files
- `docker/evolution-api.env` — API keys, DB passwords, Redis passwords
- DO NOT commit these; they reference `/var/www/secrets/` symlinks
