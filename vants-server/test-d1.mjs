// Prueba de la capa D1 del Worker de VANTS contra SQLite real (node:sqlite).
// Ejecuta el esquema + seed demo y llama al Worker con un binding DB falso
// para validar el contrato de la guía (api-publica) ruta por ruta.
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker from './worker.mjs';

const RAIZ = '/home/z/my-project/Vantsgames/vants-server';

const db = new DatabaseSync(':memory:');
db.exec(readFileSync(RAIZ + '/d1/schema.sql', 'utf8'));
db.exec(readFileSync(RAIZ + '/d1/sembrar-demo.sql', 'utf8'));

// Adaptador D1 sobre node:sqlite (mismo API que usa d1Consulta)
const DB = {
  prepare(sql) {
    const st = db.prepare(sql);
    return {
      bind(...a) {
        return {
          async all() { return { results: st.all(...a) }; },
          async first() { return st.get(...a) ?? null; },
          async run() { st.run(...a); return { success: true }; },
        };
      },
    };
  },
};

const env = { DB };
const ctx = { waitUntil() {} };
const UA = { 'User-Agent': 'vants-test/1.0 (prueba local del espejo D1)' };

let pasan = 0, fallan = 0;
async function probar(nombre, ruta, condicion, envUsar) {
  try {
    const r = await worker.fetch(new Request('https://vants.test' + ruta, { headers: UA }), envUsar || env, ctx);
    const j = await r.json().catch(() => ({}));
    const ok = condicion(j, r);
    if (ok) { pasan++; console.log('OK   ', nombre); }
    else { fallan++; console.log('FALLA', nombre, '->', JSON.stringify(j).slice(0, 180)); }
  } catch (e) {
    fallan++; console.log('ERROR', nombre, '->', e.message);
  }
}

const esArr = (v) => Array.isArray(v);

await probar('GET /api/games (3 juegos activos, valorant primero)',
  '/api/games',
  (j) => j.ok && esArr(j.data) && j.data.length === 3 && j.data[0].slug === 'valorant' && j.data[0].nombre === 'VALORANT');

await probar('GET /api/tournaments?estado=upcoming (2 demo, con game y prize)',
  '/api/tournaments?estado=upcoming',
  (j) => j.ok && j.data.total === 2 && j.data.items.length === 2 && j.data.items.every((t) => t.game && t.slug.startsWith('demo-')));

await probar('GET /api/tournaments?estado=ongoing (liga nocturna)',
  '/api/tournaments?estado=ongoing',
  (j) => j.ok && j.data.items.length === 1 && j.data.items[0].slug === 'demo-liga-nocturna-s5');

await probar('GET /api/tournaments?estado=archive (mapea a finished, copita)',
  '/api/tournaments?estado=archive',
  (j) => j.ok && j.data.items.length === 1 && j.data.items[0].slug === 'demo-copita-cs2-archivada');

await probar('GET /api/tournaments?estado=archive&page=2 (paginación, sin filas)',
  '/api/tournaments?estado=archive&porPagina=10&pag=2',
  (j) => j.ok && j.data.items.length === 0 && j.data.total === 1);

await probar('GET /api/tournaments/:slug (ficha con participantes)',
  '/api/tournaments/demo-copa-comunidad-s5',
  (j) => j.ok && j.data.slug === 'demo-copa-comunidad-s5' && j.data.prize && j.data.prize.value === 500 && esArr(j.data.participantes));

await probar('GET /api/tournaments/:slug inexistente (404)',
  '/api/tournaments/no-existe',
  (j, r) => !j.ok && r.status === 404);

await probar('GET /api/matches?estado=live (partido en vivo de la liga)',
  '/api/matches?estado=live',
  (j) => j.ok && j.data.items.length === 1 && j.data.items[0].equipos.a === 'DEMO · Equipo Fénix');

await probar('GET /api/matches?estado=finished (marcador 2-1)',
  '/api/matches?estado=finished',
  (j) => j.ok && j.data.items.length === 1 && j.data.items[0].score.a === 2 && j.data.items[0].score.b === 1);

await probar('GET /api/teams (4 equipos demo)',
  '/api/teams',
  (j) => j.ok && j.data.length === 4 && j.data.every((t) => t.tag));

await probar('GET /api/teams?juego=cs2 (solo 2 de CS2)',
  '/api/teams?juego=cs2',
  (j) => j.ok && j.data.length === 2);

await probar('GET /api/teams/:slug (ficha con plantilla de 5)',
  '/api/teams/demo-equipo-fenix',
  (j) => j.ok && j.data.slug === 'demo-equipo-fenix' && esArr(j.data.plantilla) && j.data.plantilla.length === 5);

await probar('GET /api/players (ranking rating desc, 5 demo, paginado)',
  '/api/players',
  (j) => j.ok && esArr(j.data.items) && j.data.total === 5 && j.data.items.length === 5 && j.data.items[0].rating >= j.data.items[4].rating && j.data.items.every((p) => p.is_demo));

await probar('GET /api/players?pag=2 (paginación vacía)',
  '/api/players?pag=2',
  (j) => j.ok && j.data.items.length === 0 && j.data.total === 5);

await probar('GET /api/players/:slug (ficha pt_player con equipo)',
  '/api/players/demo-jugador-alex',
  (j) => j.ok && j.data.slug === 'demo-jugador-alex' && j.data.equipo && j.data.equipo.slug === 'demo-equipo-fenix');

await probar('GET /api/articles (2 publicados, más nuevo primero)',
  '/api/articles',
  (j) => j.ok && esArr(j.data.items) && j.data.total === 2 && j.data.items[0].slug === 'demo-como-participar');

await probar('GET /api/articles/:slug (cuerpo completo)',
  '/api/articles/demo-como-participar',
  (j) => j.ok && j.data.cuerpo.includes('DEMOSTRACIÓN') && j.data.autor === 'VANTS');

await probar('GET /api/search?q=copa (encuentra torneo demo)',
  '/api/search?q=copa',
  (j) => j.ok && j.data.torneos.length === 1 && j.data.torneos[0].slug === 'demo-copa-comunidad-s5');

await probar('GET /api/search?q=alex (encuentra jugador)',
  '/api/search?q=alex',
  (j) => j.ok && j.data.jugadores.length >= 1);

await probar('GET /api/en-vivo (vista presente, lista vacía)',
  '/api/en-vivo',
  (j) => j.ok === true || (j.ok === false && esArr(j.jugadores)));

await probar('GET /api/torneos/bracket?torneo=x (degradación documentada)',
  '/api/torneos/bracket?torneo=ascension',
  (j) => j.ok === false);

// Sin D1: el proxy de Neon responde 403 desde aquí → las rutas dan el error
// documentado "Datos no disponibles (proxy 403)". Se usa una clave de caché
// nueva (?v=fallback) para no tropezar con platLectura de la pasada anterior.
console.log('\n--- sin binding D1 (fallback al proxy vantsdata) ---');
const envSinDB = {};
await probar('FALLBACK /api/tournaments sin D1 → proxy 403 documentado',
  '/api/tournaments?estado=upcoming&v=fallback',
  (j) => j.ok === false && /proxy 403/.test(((j.error || {}).message) || ''),
  envSinDB);

console.log('\n' + pasan + ' pasan, ' + fallan + ' fallan');
process.exit(fallan ? 1 : 0);
