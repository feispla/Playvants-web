#!/usr/bin/env node
// ============================================================================
// sincronizar-d1.mjs · Copia los datos REALES de vantsdata (Neon) a D1
// ============================================================================
// vantsdata es el proxy público de lectura de la guía (funciona desde las
// runners de GitHub y desde redes residenciales; el WAF de Neon bloquea
// algunas IPs de datacenter). Este script la lee y sube las filas al espejo
// D1 con la API REST de Cloudflare. Idempotente (upsert por slug/id).
//
// Variables de entorno requeridas:
//   CF_API_TOKEN     token de Cloudflare con permiso D1:Edit
//   CF_ACCOUNT_ID    id de la cuenta de Cloudflare
//   CF_D1_ID         id de la base D1 (wrangler d1 create vants-db)
// Opcionales:
//   VANTSDATA_URL    por defecto el endpoint de producción
//
// Uso:  CF_API_TOKEN=... CF_ACCOUNT_ID=... CF_D1_ID=... node scripts/sincronizar-d1.mjs
// ============================================================================

const PROXY = process.env.VANTSDATA_URL || 'https://br-sweet-shape-b42xhogj-vantsdata.compute.c-6.us-east-2.aws.neon.tech/';
const API = 'https://api.cloudflare.com/client/v4';
const UA = 'Mozilla/5.0 (compatible; VANTS-sync/1.0; +https://vants.vants.workers.dev)';

const TOKEN = process.env.CF_API_TOKEN;
const ACCOUNT = process.env.CF_ACCOUNT_ID;
const D1 = process.env.CF_D1_ID;
if (!TOKEN || !ACCOUNT || !D1) {
  console.error('Faltan CF_API_TOKEN, CF_ACCOUNT_ID o CF_D1_ID en el entorno.');
  process.exit(1);
}

// Tablas espejadas: fuente vantsdata → tabla D1 + columnas a copiar (el orden
// DEBE coincidir con los placeholders del INSERT). clave = columna única.
const TABLAS = [
  { fuente: 'pt_games', tabla: 'pt_games', clave: 'slug',
    cols: ['slug', 'nombre', 'corto', 'activo', 'orden', 'logo_url', 'color'] },
  { fuente: 'pt_torneos', tabla: 'pt_torneos', clave: 'slug',
    cols: ['id', 'slug', 'source', 'external_id', 'game_slug', 'nombre', 'descripcion', 'estado', 'major', 'region', 'location_type', 'prize_value', 'prize_currency', 'fee', 'max_teams', 'starts_at', 'ends_at', 'logo_url', 'banner_url', 'formato', 'reglas', 'is_demo'] },
  { fuente: 'pt_teams', tabla: 'pt_teams', clave: 'slug',
    cols: ['id', 'slug', 'nombre', 'tag', 'game_slug', 'region', 'logo_url', 'is_demo'] },
  { fuente: 'pt_matches', tabla: 'pt_matches', clave: 'id',
    cols: ['id', 'source', 'external_id', 'game_slug', 'tournament_id', 'equipo_a', 'equipo_b', 'score_a', 'score_b', 'estado', 'best_of', 'empieza_at', 'termino_at', 'is_demo'] },
  { fuente: 'pt_articulos', tabla: 'pt_articulos', clave: 'slug',
    cols: ['id', 'slug', 'titulo', 'resumen', 'cuerpo', 'autor', 'game_slug', 'estado', 'publicado_at', 'is_demo'] },
  { fuente: 'pt_players', tabla: 'pt_players', clave: 'slug',
    cols: ['id', 'slug', 'source', 'external_id', 'nombre', 'game_slug', 'team_slug', 'rol', 'pais', 'bio', 'avatar_url', 'is_demo'] },
  { fuente: 'players', tabla: 'players', clave: 'id',
    cols: ['id', 'username', 'display_name', 'nombre', 'avatar_url', 'country', 'region', 'role', 'game', 'verified', 'rating', 'tipo'] },
];

async function leerTabla(fuente) {
  const filas = [];
  let offset = 0;
  while (true) {
    const u = new URL(PROXY);
    u.searchParams.set('table', fuente);
    u.searchParams.set('limit', '1000');
    u.searchParams.set('offset', String(offset));
    const r = await fetch(u, { headers: { Accept: 'application/json', 'User-Agent': UA } });
    if (!r.ok) throw new Error(fuente + ' → HTTP ' + r.status);
    const lote = await r.json();
    if (!Array.isArray(lote) || !lote.length) break;
    filas.push(...lote);
    if (lote.length < 1000) break;
    offset += 1000;
  }
  return filas;
}

async function d1(sql, params) {
  const r = await fetch(`${API}/accounts/${ACCOUNT}/d1/database/${D1}/query`, {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + TOKEN, 'Content-Type': 'application/json' },
    body: JSON.stringify({ sql, params }),
  });
  const j = await r.json();
  if (!r.ok || j.success === false) throw new Error('D1 → ' + JSON.stringify(j.errors || j).slice(0, 300));
  return j;
}

function normaliza(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === 'boolean') return v ? 1 : 0;
  if (typeof v === 'object') return JSON.stringify(v);
  return v;
}

let total = 0;
for (const t of TABLAS) {
  let filas;
  try {
    filas = await leerTabla(t.fuente);
  } catch (e) {
    console.warn('· ' + t.fuente + ': no se pudo leer (' + e.message + '), se salta');
    continue;
  }
  for (const fila of filas) {
    if (!fila || fila[t.clave] == null) continue;
    const valores = t.cols.map((c) => normaliza(fila[c]));
    const placeholders = t.cols.map(() => '?').join(', ');
    const actualiza = t.cols.filter((c) => c !== t.clave).map((c) => c + ' = excluded.' + c).join(', ');
    await d1(
      'INSERT INTO ' + t.tabla + ' (' + t.cols.join(', ') + ') VALUES (' + placeholders + ') ' +
      'ON CONFLICT(' + t.clave + ') DO UPDATE SET ' + (actualiza || t.clave + ' = excluded.' + t.clave),
      valores
    );
  }
  console.log('· ' + t.fuente + ' → ' + t.tabla + ': ' + filas.length + ' filas');
  total += filas.length;
}

console.log('Sincronización completa: ' + total + ' filas en D1.');
