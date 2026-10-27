-- ============================================================================
-- VANTS · Siembra DEMO en D1 (misma que migra 28/29 de VantsBasededatos)
-- ============================================================================
-- Datos claramente ficticios: is_demo=1 y nombres con prefijo "DEMO · ".
-- La web los marca como DEMO (decisión D4 de la guía). Sirve para que la
-- web tenga contenido desde el minuto uno; el contenido real entra con
-- scripts/sincronizar-d1.mjs o desde el panel.
-- Idempotente: ON CONFLICT DO NOTHING.
-- ============================================================================

INSERT OR IGNORE INTO pt_games (slug, nombre, corto, activo, orden) VALUES
  ('valorant', 'VALORANT',         'VALORANT', 1, 10),
  ('cs2',      'COUNTER-STRIKE 2', 'CS2',      1, 20),
  ('dota2',    'DOTA 2',           'DOTA 2',   1, 30),
  ('lol',      'LEAGUE OF LEGENDS','LOL',      0, 40),
  ('r6s',      'RAINBOW SIX SIEGE','R6',       0, 50),
  ('cod',      'CALL OF DUTY',     'COD',      0, 60);

INSERT OR IGNORE INTO pt_torneos
  (slug, source, external_id, game_slug, nombre, descripcion, estado, major, region,
   location_type, prize_value, fee, max_teams, starts_at, ends_at, formato, is_demo)
VALUES
  ('demo-copa-comunidad-s5','demo','demo-copa-comunidad-s5','valorant',
   'DEMO · Copa Comunidad S5','Torneo de demostración para validar la plataforma. Sustituir por un torneo real.',
   'upcoming', 0, 'LATAM','online', 500, 0, 16,
   strftime('%Y-%m-%dT%H:%M:%SZ','now','+20 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','+24 days'), 'Eliminación simple · Bo1', 1),
  ('demo-liga-nocturna-s5','demo','demo-liga-nocturna-s5','valorant',
   'DEMO · Liga Nocturna S5','Torneo de demostración en curso para validar la plataforma.',
   'ongoing', 0, 'LATAM','online', 250, 0, 32,
   strftime('%Y-%m-%dT%H:%M:%SZ','now','-2 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','+5 days'), 'Liga suiza · Bo1', 1),
  ('demo-stratos-major-s5','demo','demo-stratos-major-s5','cs2',
   'DEMO · Stratos Major S5','Torneo demo de CS2 con badge MAJOR para validar la plataforma.',
   'upcoming', 1, 'EU','lan', 1000, 0, 24,
   strftime('%Y-%m-%dT%H:%M:%SZ','now','+28 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','+31 days'), 'Doble eliminación · Bo3', 1),
  ('demo-copita-cs2-archivada','demo','demo-copita-cs2-archivada','cs2',
   'DEMO · Copita CS2 (archivo)','Torneo demo finalizado para poblar el archivo.',
   'finished', 0, 'EU','online', 300, 0, 8,
   strftime('%Y-%m-%dT%H:%M:%SZ','now','-40 days'), strftime('%Y-%m-%dT%H:%M:%SZ','now','-36 days'), 'Eliminación simple · Bo1', 1);

INSERT OR IGNORE INTO pt_teams (slug, nombre, tag, game_slug, region, is_demo) VALUES
  ('demo-equipo-fenix','DEMO · Equipo Fénix','FNX','valorant','LATAM', 1),
  ('demo-equipo-lobo','DEMO · Equipo Lobo','LBO','valorant','LATAM', 1),
  ('demo-equipo-stratos','DEMO · Equipo Stratos','STS','cs2','EU', 1),
  ('demo-equipo-nova','DEMO · Equipo Nova','NVA','cs2','EU', 1);

INSERT OR IGNORE INTO pt_matches
  (id, source, external_id, game_slug, tournament_id, equipo_a, equipo_b, estado, best_of, empieza_at, is_demo)
SELECT 'demo-m1','demo','demo-m1','valorant', t.id,'DEMO · Equipo Fénix','DEMO · Equipo Lobo','live',1,
       strftime('%Y-%m-%dT%H:%M:%SZ','now','-30 minutes'), 1
FROM pt_torneos t WHERE t.slug='demo-liga-nocturna-s5';

INSERT OR IGNORE INTO pt_matches
  (id, source, external_id, game_slug, tournament_id, equipo_a, equipo_b, estado, best_of, empieza_at, is_demo)
SELECT 'demo-m2','demo','demo-m2','valorant', t.id,'DEMO · Equipo Lobo','DEMO · Equipo Fénix','upcoming',1,
       strftime('%Y-%m-%dT%H:%M:%SZ','now','+2 hours'), 1
FROM pt_torneos t WHERE t.slug='demo-copa-comunidad-s5';

INSERT OR IGNORE INTO pt_matches
  (id, source, external_id, game_slug, equipo_a, equipo_b, score_a, score_b, estado, best_of, empieza_at, termino_at, is_demo)
VALUES ('demo-m3','demo','demo-m3','cs2','DEMO · Equipo Stratos','DEMO · Equipo Nova',2,1,'finished',3,
        strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 day'), strftime('%Y-%m-%dT%H:%M:%SZ','now','-22 hours'), 1);

INSERT OR IGNORE INTO pt_articulos (slug, titulo, resumen, cuerpo, autor, game_slug, estado, publicado_at, is_demo) VALUES
  ('demo-como-participar','DEMO · Cómo participar en los torneos de VANTS',
   'Artículo de demostración que explica el flujo de inscripción de la plataforma.',
   'Este artículo es una DEMOSTRACIÓN para validar el sistema de noticias.

Flujo real de inscripción: crea tu cuenta, inscribe tu equipo desde la sección Torneos, espera la confirmación del organizador y juega. Los resultados se registran en el bracket y tu VANTS RATING se mueve con cada partida oficial.

Cuando el equipo publique su primer anuncio real, este artículo se sustituye o retira.',
   'VANTS','valorant','published', strftime('%Y-%m-%dT%H:%M:%SZ','now','-3 days'), 1),
  ('demo-calendario-s5','DEMO · Calendario de la Temporada 5',
   'Artículo de demostración con el calendario previsto de la temporada.',
   'Este artículo es una DEMOSTRACIÓN para validar el sistema de noticias.

La Temporada 5 contempla copas mensuales, ligas nocturnas y un major de cierre. Fechas, premios y sedes se anuncian por Discord y en esta sección cuando se confirmen.',
   'VANTS','cs2','published', strftime('%Y-%m-%dT%H:%M:%SZ','now','-10 days'), 1);

-- Plantillas de 5 jugadores por equipo demo (migra 29)
INSERT OR IGNORE INTO pt_players (slug, source, external_id, nombre, game_slug, team_slug, rol, pais, is_demo) VALUES
  ('demo-jugador-alex','demo','demo-p1','DEMO · Alex «Fx» Morales','valorant','demo-equipo-fenix','IGL','VE',1),
  ('demo-jugador-kira','demo','demo-p2','DEMO · Kira «K9» Rojas','valorant','demo-equipo-fenix','Duelista','MX',1),
  ('demo-jugador-tavo','demo','demo-p3','DEMO · Tavo «TV» Núñez','valorant','demo-equipo-fenix','Controlador','CO',1),
  ('demo-jugador-mila','demo','demo-p4','DEMO · Mila «ML» Torres','valorant','demo-equipo-fenix','Sentinela','AR',1),
  ('demo-jugador-reno','demo','demo-p5','DEMO · Reno «RN» Silva','valorant','demo-equipo-fenix','Flexible','CL',1),
  ('demo-jugador-bruno','demo','demo-p6','DEMO · Bruno «B7» Cano','valorant','demo-equipo-lobo','IGL','PE',1),
  ('demo-jugador-dani','demo','demo-p7','DEMO · Dani «DN» Vera','valorant','demo-equipo-lobo','Duelista','EC',1),
  ('demo-jugador-gael','demo','demo-p8','DEMO · Gael «GL» Ríos','valorant','demo-equipo-lobo','Controlador','MX',1),
  ('demo-jugador-iris','demo','demo-p9','DEMO · Iris «IR» Paz','valorant','demo-equipo-lobo','Sentinela','BO',1),
  ('demo-jugador-jony','demo','demo-p10','DEMO · Jony «JY» Mesa','valorant','demo-equipo-lobo','Flexible','UY',1),
  ('demo-jugador-koldo','demo','demo-p11','DEMO · Koldo «KD» Sáez','cs2','demo-equipo-stratos','IGL','ES',1),
  ('demo-jugador-lena','demo','demo-p12','DEMO · Lena «LN» Vidal','cs2','demo-equipo-stratos','AWPer','ES',1),
  ('demo-jugador-marco','demo','demo-p13','DEMO · Marco «MC» Duarte','cs2','demo-equipo-stratos','Entry','PT',1),
  ('demo-jugador-nico','demo','demo-p14','DEMO · Nico «NC» Bauza','cs2','demo-equipo-stratos','Lurker','UY',1),
  ('demo-jugador-olga','demo','demo-p15','DEMO · Olga «OG» Ferrer','cs2','demo-equipo-stratos','Support','AR',1),
  ('demo-jugador-pau','demo','demo-p16','DEMO · Pau «P4» Gil','cs2','demo-equipo-nova','IGL','ES',1),
  ('demo-jugador-quim','demo','demo-p17','DEMO · Quim «QM» Sala','cs2','demo-equipo-nova','AWPer','MX',1),
  ('demo-jugador-raul','demo','demo-p18','DEMO · Raúl «R2» Ibáñez','cs2','demo-equipo-nova','Entry','CL',1),
  ('demo-jugador-sara','demo','demo-p19','DEMO · Sara «SR» Leiva','cs2','demo-equipo-nova','Lurker','CO',1),
  ('demo-jugador-tito','demo','demo-p20','DEMO · Tito «T5» Campos','cs2','demo-equipo-nova','Support','PE',1);

-- Perfiles ranked de demostración para /api/players (marcados DEMO, D4)
INSERT OR IGNORE INTO players (id, username, display_name, nombre, country, region, role, game, verified, rating, tipo, is_demo) VALUES
  ('demo-r1','DEMO · Fx','DEMO · Alex «Fx» Morales','Alex Morales','VE','LATAM','IGL','valorant',1,2530,'competitivo',1),
  ('demo-r2','DEMO · K9','DEMO · Kira «K9» Rojas','Kira Rojas','MX','LATAM','Duelista','valorant',1,2410,'competitivo',1),
  ('demo-r3','DEMO · KD','DEMO · Koldo «KD» Sáez','Koldo Sáez','ES','EU','IGL','cs2',1,2280,'competitivo',1),
  ('demo-r4','DEMO · LN','DEMO · Lena «LN» Vidal','Lena Vidal','ES','EU','AWPer','cs2',0,2150,'competitivo',1),
  ('demo-r5','DEMO · ML','DEMO · Mila «ML» Torres','Mila Torres','AR','LATAM','Sentinela','valorant',0,2040,'competitivo',1);

-- ---------- Inventario final (queda en el log del workflow) ----------
SELECT 'pt_games' AS tabla, COUNT(*) AS filas FROM pt_games
UNION ALL SELECT 'pt_torneos', COUNT(*) FROM pt_torneos
UNION ALL SELECT 'pt_teams', COUNT(*) FROM pt_teams
UNION ALL SELECT 'pt_matches', COUNT(*) FROM pt_matches
UNION ALL SELECT 'pt_articulos', COUNT(*) FROM pt_articulos
UNION ALL SELECT 'pt_players', COUNT(*) FROM pt_players
UNION ALL SELECT 'players', COUNT(*) FROM players;
