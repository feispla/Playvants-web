-- ============================================================================
-- VANTS · Espejo de lectura en D1 (base de datos de Cloudflare)
-- ============================================================================
-- Réplica en SQLite (D1) del subconjunto de LECTURA pública de Neon que
-- documenta la guía (Esquema de la base de datos + API pública):
--   · pt_games / pt_torneos / pt_teams / pt_matches / pt_articulos (migra 28)
--   · pt_players (migra 29)
--   · tournament_teams / tournament_matches / presence (migra 17)
--   · players (catálogo ranked S4) + season_player_stats (solo para la vista)
--   · vistas v_en_vivo / v_torneo_equipos / v_torneo_bracket (migra 17)
--
-- El Worker lee AQUÍ primero (binding DB) y cae al proxy vantsdata de Neon
-- si la tabla no existe o falla. Las escrituras siguen por la Data API de
-- Neon con JWT de Auth0 y RLS (decisión de la guía): este espejo es de
-- LECTURA y se rellena con el seed demo o con scripts/sincronizar-d1.mjs.
--
-- Aplicar (desde vants-server/):
--   npx wrangler d1 create vants-db
--   npx wrangler d1 execute vants-db --remote --file=./d1/schema.sql
--   npx wrangler d1 execute vants-db --remote --file=./d1/sembrar-demo.sql
-- Idempotente: se puede reejecutar sin borrar datos.
-- ============================================================================

-- ---------- pt_games (catálogo de juegos, migra 28) ----------
CREATE TABLE IF NOT EXISTS pt_games (
  slug     TEXT PRIMARY KEY,
  nombre   TEXT NOT NULL,
  corto    TEXT,
  activo   INTEGER NOT NULL DEFAULT 1,
  orden    INTEGER NOT NULL DEFAULT 100,
  logo_url TEXT,
  color    TEXT
);

-- ---------- pt_torneos (migra 28) ----------
CREATE TABLE IF NOT EXISTS pt_torneos (
  id             TEXT PRIMARY KEY,
  slug           TEXT NOT NULL UNIQUE,
  source         TEXT NOT NULL DEFAULT 'vants',
  external_id    TEXT,
  game_slug      TEXT NOT NULL REFERENCES pt_games(slug),
  nombre         TEXT NOT NULL,
  descripcion    TEXT,
  estado         TEXT NOT NULL DEFAULT 'upcoming'
                 CHECK (estado IN ('upcoming','ongoing','finished','cancelled')),
  major          INTEGER NOT NULL DEFAULT 0,
  region         TEXT,
  location_type  TEXT CHECK (location_type IS NULL OR location_type IN ('online','lan')),
  prize_value    REAL,
  prize_currency TEXT NOT NULL DEFAULT 'USD',
  fee            REAL NOT NULL DEFAULT 0,
  max_teams      INTEGER,
  starts_at      TEXT,
  ends_at        TEXT,
  logo_url       TEXT,
  banner_url     TEXT,
  formato        TEXT,
  reglas         TEXT,
  is_demo        INTEGER NOT NULL DEFAULT 0,
  created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at),
  UNIQUE (source, external_id)
);
CREATE INDEX IF NOT EXISTS idx_pt_torneos_listado ON pt_torneos (game_slug, estado, starts_at);

-- ---------- pt_teams (migra 28) ----------
CREATE TABLE IF NOT EXISTS pt_teams (
  id         TEXT PRIMARY KEY,
  slug       TEXT NOT NULL UNIQUE,
  nombre     TEXT NOT NULL,
  tag        TEXT,
  game_slug  TEXT REFERENCES pt_games(slug),
  region     TEXT,
  logo_url   TEXT,
  is_demo    INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

-- ---------- pt_matches (migra 28) ----------
CREATE TABLE IF NOT EXISTS pt_matches (
  id            TEXT PRIMARY KEY,
  source        TEXT NOT NULL DEFAULT 'vants',
  external_id   TEXT,
  game_slug     TEXT NOT NULL REFERENCES pt_games(slug),
  tournament_id TEXT,
  equipo_a      TEXT NOT NULL,
  equipo_b      TEXT NOT NULL,
  score_a       INTEGER,
  score_b       INTEGER,
  estado        TEXT NOT NULL DEFAULT 'upcoming'
                CHECK (estado IN ('upcoming','live','finished','cancelled')),
  best_of       INTEGER,
  empieza_at    TEXT,
  termino_at    TEXT,
  is_demo       INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  UNIQUE (source, external_id)
);
CREATE INDEX IF NOT EXISTS idx_pt_matches_listado ON pt_matches (game_slug, estado, empieza_at);

-- ---------- pt_articulos (migra 28) ----------
CREATE TABLE IF NOT EXISTS pt_articulos (
  id           TEXT PRIMARY KEY,
  slug         TEXT NOT NULL UNIQUE,
  titulo       TEXT NOT NULL,
  resumen      TEXT,
  cuerpo       TEXT NOT NULL,
  autor        TEXT,
  game_slug    TEXT REFERENCES pt_games(slug),
  estado       TEXT NOT NULL DEFAULT 'published' CHECK (estado IN ('draft','published')),
  publicado_at TEXT,
  is_demo      INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_pt_articulos_publicados ON pt_articulos (estado, publicado_at DESC);

-- ---------- pt_players (migra 29) ----------
CREATE TABLE IF NOT EXISTS pt_players (
  id          TEXT PRIMARY KEY,
  slug        TEXT NOT NULL UNIQUE,
  source      TEXT NOT NULL DEFAULT 'vants',
  external_id TEXT,
  nombre      TEXT NOT NULL,
  game_slug   TEXT REFERENCES pt_games(slug),
  team_slug   TEXT,
  rol         TEXT,
  pais        TEXT,
  bio         TEXT,
  avatar_url  TEXT,
  is_demo     INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  UNIQUE (source, external_id)
);
CREATE INDEX IF NOT EXISTS idx_pt_players_equipo ON pt_players (team_slug);
CREATE INDEX IF NOT EXISTS idx_pt_players_juego  ON pt_players (game_slug);

-- ---------- players (catálogo ranked S4; columnas que lee la web) ----------
CREATE TABLE IF NOT EXISTS players (
  id           TEXT PRIMARY KEY,
  username     TEXT,
  display_name TEXT,
  nombre       TEXT,
  avatar_url   TEXT,
  country      TEXT,
  region       TEXT,
  role         TEXT,
  game         TEXT,
  verified     INTEGER NOT NULL DEFAULT 0,
  rating       REAL,
  tipo         TEXT,
  is_demo      INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_players_ranking ON players (rating);

-- ---------- season_player_stats (solo mmr para v_en_vivo) ----------
CREATE TABLE IF NOT EXISTS season_player_stats (
  player_id  TEXT REFERENCES players(id),
  mmr        REAL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

-- ---------- presence (migra 17) ----------
CREATE TABLE IF NOT EXISTS presence (
  player_id   TEXT PRIMARY KEY REFERENCES players(id),
  estado      TEXT NOT NULL DEFAULT 'online'
              CHECK (estado IN ('online','jugando','ausente')),
  juego       TEXT,
  actualizado TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

-- ---------- tournament_teams (migra 17) ----------
CREATE TABLE IF NOT EXISTS tournament_teams (
  id            TEXT PRIMARY KEY,
  tournament_id TEXT NOT NULL,
  game          TEXT NOT NULL DEFAULT 'valorant',
  name          TEXT NOT NULL,
  tag           TEXT NOT NULL,
  captain       TEXT,
  region        TEXT,
  auth0_sub     TEXT,
  player_id     TEXT,
  status        TEXT NOT NULL DEFAULT 'pendiente'
                CHECK (status IN ('pendiente','confirmado','rechazado')),
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
  CHECK (length(trim(name)) BETWEEN 2 AND 32),
  CHECK (length(trim(tag))  BETWEEN 2 AND 4)
);
CREATE INDEX IF NOT EXISTS tt_torneo_estado_idx ON tournament_teams (tournament_id, status, created_at);

-- ---------- tournament_matches (migra 17) ----------
CREATE TABLE IF NOT EXISTS tournament_matches (
  id            TEXT PRIMARY KEY,
  tournament_id TEXT NOT NULL,
  game          TEXT NOT NULL DEFAULT 'valorant',
  ronda         TEXT NOT NULL CHECK (ronda IN ('q','s','f','l1','l2','lf')),
  slot          INTEGER NOT NULL DEFAULT 0 CHECK (slot BETWEEN 0 AND 3),
  team_a        TEXT,
  team_b        TEXT,
  score_a       INTEGER,
  score_b       INTEGER,
  estado        TEXT NOT NULL DEFAULT 'pendiente'
                CHECK (estado IN ('pendiente','en_curso','final')),
  ganador       TEXT,
  updated_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
CREATE INDEX IF NOT EXISTS tm_torneo_idx ON tournament_matches (tournament_id, ronda, slot);

-- ============================================================================
-- VISTAS PÚBLICAS (migra 17, sin PII)
-- ============================================================================

CREATE VIEW IF NOT EXISTS v_en_vivo AS
SELECT pr.player_id,
       p.username, p.display_name, p.avatar_url, p.country, p.region,
       p.role, p.verified, p.rating,
       s.mmr,
       pr.estado, pr.juego, pr.actualizado
FROM presence pr
JOIN players p ON p.id = pr.player_id
LEFT JOIN (
  SELECT player_id, mmr, created_at
  FROM season_player_stats
  ORDER BY created_at DESC
) s ON s.player_id = pr.player_id
WHERE pr.actualizado > strftime('%Y-%m-%dT%H:%M:%SZ','now','-120 seconds')
  AND pr.estado <> 'ausente';

CREATE VIEW IF NOT EXISTS v_torneo_equipos AS
SELECT id, tournament_id, game, name, tag, captain, region, status, created_at
FROM tournament_teams
WHERE status <> 'rechazado';

CREATE VIEW IF NOT EXISTS v_torneo_bracket AS
SELECT tournament_id, game, ronda, slot, team_a, team_b,
       score_a, score_b, estado, ganador, updated_at
FROM tournament_matches;
