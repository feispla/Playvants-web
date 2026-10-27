# VANTS GAMES — Arena Competitiva

Worker de Cloudflare que sirve la web estática y envía notificaciones a Discord vía REST API.

## Arquitectura

- **Web estática**: se sirve desde `public/` (poner `index.html` ahí)
- **API**: endpoint `POST /api/discord/notify` que envía embeds a un canal de Discord
- **Runtime**: Cloudflare Workers (V8 isolates, no Node.js)

## Tipos de notificación

| Tipo | Color | Descripción |
|------|-------|-------------|
| `torneo_inscripcion` | 🔴 Rojo | Nueva inscripción a torneo |
| `membresia` | 💜 Violeta | Nueva membresía activada |
| `live` | 🟣 Twitch | Stream en directo |
| `campeon` | 🟡 Oro | Nuevo campeón de torneo |

## Ejemplo de petición

```bash
curl -X POST https://vants.geimerjhoan099.workers.dev/api/discord/notify \
  -H "Content-Type: application/json" \
  -d '{
    "type": "torneo_inscripcion",
    "data": {
      "team": "Los Pro",
      "tag": "LPRO",
      "tournament": "Copa VANTS 2026"
    }
  }'

## Capa de lectura D1 (base de datos de Cloudflare)

Las lecturas públicas (`/api/games`, `/api/tournaments`, `/api/matches`,
`/api/teams`, `/api/players`, `/api/articles` y `/api/search`) intentan
SIEMPRE primero el binding D1 (`env.DB`) y, si no está configurado o falla,
caen al proxy `vantsdata` de Neon, igual que hasta ahora.

- Esquema y seed demo: `d1/schema.sql` y `d1/sembrar-demo.sql` (réplica del
  subconjunto de lectura de las migraciones 28/29/17 de VantsBasededatos).
- El seed demo lleva `is_demo=1` y nombres `DEMO · ` (decisión D4: la web
  los marca como DEMO).
- Prueba local sin Cloudflare (SQLite real con node:sqlite, 22 checks del
  contrato de la guía): `node test-d1.mjs` (requiere copiar worker.js a
  worker.mjs en la misma carpeta para poder importarlo como ESM).
- Puesta en marcha: ver el bloque `[[d1_databases]]` comentado en
  `wrangler.toml`. Datos reales después: `node ../scripts/sincronizar-d1.mjs`
  (lee vantsdata y hace upsert en D1; necesita CF_API_TOKEN, CF_ACCOUNT_ID y
  CF_D1_ID).
- La ruta `GET /api/articles/:slug` estaba inalcanzable en el dispatch
  (condición exacta sobre `/api/articles`); corregida para cumplir la guía.
