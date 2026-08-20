--Di questa metrica mostriamo tutto il procedimento visto che è stato quello più complesso
--però ci sembrava istruttivo farlo per vedere l'integrazione di diverse delle fonti censite

-- ----------------------------------------------------------------------------
-- 1. Estrazione delle edizioni di torneo da geocodificare.
--    Una riga per edizione all'aperto, con citta', paese e data di inizio.
-- ----------------------------------------------------------------------------
\copy (SELECT e.tournament_event_id, t.name, t.city, t.country_id, min(m.date) AS dal, max(m.date) AS al FROM tournament_event e, tournament t, match m WHERE t.tournament_id = e.tournament_id AND m.tournament_event_id = e.tournament_event_id AND e.level IN ('G','F','M','O','A','B') AND e.indoor = FALSE AND e.season >= 2000 GROUP BY e.tournament_event_id, t.name, t.city, t.country_id ORDER BY dal) TO '/tmp/eventi.csv' WITH (FORMAT csv, HEADER true)

-- docker cp uts-database:/tmp/eventi.csv C:\tesi\eventi.csv


-- ----------------------------------------------------------------------------
-- 2. Raccolta meteorologica: eseguita fuori dal database con uno script Python, in due fasi.
--    Fase 1: geocodifica delle 81 citta' distinte su geocoding-api.open-meteo.com,
--            output citta.csv con latitudine, longitudine, altitudine. Il paese
--            restituito va confrontato a mano con quello atteso.
--    Fase 2: per ogni edizione, finestra di 14 giorni dalla data di inizio su
--            archive-api.open-meteo.com, variabili temperature_2m_mean,
--            temperature_2m_max, relative_humidity_2m_mean. Output meteo.csv.
-- ----------------------------------------------------------------------------


-- ----------------------------------------------------------------------------
-- 3. Tabella meteorologica e caricamento.
-- ----------------------------------------------------------------------------
CREATE TABLE meteo_giorno (
    tournament_event_id INTEGER NOT NULL,
    data                DATE    NOT NULL,
    latitudine REAL, longitudine REAL, altitudine SMALLINT,
    temp_media REAL, temp_massima REAL, umidita_media REAL,
    PRIMARY KEY (tournament_event_id, data)
);

\copy meteo_giorno FROM '/tmp/meteo.csv' WITH (FORMAT csv, HEADER true, NULL '')


-- ----------------------------------------------------------------------------
-- 4. Derivazione di pressione e densita' dell'aria.
--    La pressione segue la formula dell'atmosfera standard applicata
--    all'altitudine; la densita' segue la legge dei gas applicata separatamente
--    all'aria secca e al vapore acqueo, con tensione di vapore saturo stimata
--    secondo Tetens. 
-- ----------------------------------------------------------------------------
ALTER TABLE meteo_giorno ADD COLUMN pressione REAL, ADD COLUMN densita_aria REAL;

UPDATE meteo_giorno
SET pressione = 1013.25 * power(1 - 2.25577e-5 * altitudine, 5.25588);

UPDATE meteo_giorno
SET densita_aria =
      (pressione * 100 - (umidita_media / 100.0) * 610.78
           * power(10, 7.5 * temp_media / (temp_media + 237.3)))
      / (287.058 * (temp_media + 273.15))
    + ((umidita_media / 100.0) * 610.78
           * power(10, 7.5 * temp_media / (temp_media + 237.3)))
      / (461.495 * (temp_media + 273.15));


-- ----------------------------------------------------------------------------
-- 5. Tennis-Data.co.uk: tabella di appoggio e caricamento.
--    I file annuali 2003-2020 sono stati ridotti alle prime undici colonne,
--    con l'aggiunta della stagione, e uniti in un solo CSV.
--    Il separatore e' il punto e virgola perche' Excel in italiano salva cosi'.
-- ----------------------------------------------------------------------------
CREATE TABLE partite_td (
    stagione SMALLINT, circuito TEXT, location TEXT, torneo TEXT, data DATE,
    serie TEXT, campo TEXT, superficie TEXT, turno TEXT, al_meglio SMALLINT,
    vincitore TEXT, perdente TEXT
);

\copy partite_td FROM '/tmp/partite.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '')

SELECT stagione, count(*) FROM partite_td GROUP BY stagione ORDER BY stagione;


-- ----------------------------------------------------------------------------
-- 6. Riconciliazione delle date reali.
--    L'abbinamento prescinde dal nome del torneo, che le due fonti scrivono in
--    modo incompatibile, e si regge su stagione, coppia di contendenti,
--    superficie, ambiente e formato. Il DISTINCT ON con l'ordinamento finale
--    risolve le rare ambiguita' scegliendo la data piu' vicina all'inizio.
--    L'espressione regolare toglie le iniziali finali: Federer R. -> Federer.
-- ----------------------------------------------------------------------------
CREATE TABLE match_data_reale (
    match_id   BIGINT PRIMARY KEY,
    data_reale DATE NOT NULL
);

INSERT INTO match_data_reale (match_id, data_reale)
SELECT DISTINCT ON (m.match_id) m.match_id, q.data
FROM partite_td q, tournament_event e, match m, player pv, player pp
WHERE e.season = q.stagione
  AND m.tournament_event_id = e.tournament_event_id
  AND q.data >= e.date - 3
  AND q.data <= e.date + 20
  AND m.best_of = q.al_meglio
  AND m.indoor = (q.campo = 'Indoor')
  AND m.surface = CASE q.superficie WHEN 'Hard'   THEN 'H'
                                    WHEN 'Clay'   THEN 'C'
                                    WHEN 'Grass'  THEN 'G'
                                    WHEN 'Carpet' THEN 'P' END::surface
  AND pv.player_id = m.winner_id
  AND pp.player_id = m.loser_id
  AND lower(pv.last_name) = lower(regexp_replace(q.vincitore, '\s+([A-Za-z]\.)+$', ''))
  AND lower(pp.last_name) = lower(regexp_replace(q.perdente,  '\s+([A-Za-z]\.)+$', ''))
ORDER BY m.match_id, abs(q.data - e.date);


-- ----------------------------------------------------------------------------
-- 7. Calendario definitivo.
--    offset_turno stima, per ampiezza di tabellone e turno, di quanti giorni
--    l'incontro dista mediamente dall'inizio del torneo, calibrandosi sulle sole
--    date reali. match_giorno combina le due fonti e conserva la provenienza.
-- ----------------------------------------------------------------------------
CREATE TABLE offset_turno AS
SELECT coalesce(e.draw_size, 32) AS tabellone, m.round,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY d.data_reale - e.date))::INTEGER AS offset_giorni
FROM match_data_reale d, match m, tournament_event e
WHERE m.match_id = d.match_id
  AND e.tournament_event_id = m.tournament_event_id
GROUP BY 1, 2
HAVING count(*) >= 20;

ALTER TABLE offset_turno ADD PRIMARY KEY (tabellone, round);

CREATE TABLE match_giorno AS
SELECT m.match_id,
       coalesce((SELECT d.data_reale FROM match_data_reale d WHERE d.match_id = m.match_id),
                e.date + o.offset_giorni) AS giorno,
       CASE WHEN EXISTS (SELECT 1 FROM match_data_reale d WHERE d.match_id = m.match_id)
            THEN 'reale' ELSE 'stimata' END AS fonte
FROM match m, tournament_event e, offset_turno o
WHERE e.tournament_event_id = m.tournament_event_id
  AND o.tabellone = coalesce(e.draw_size, 32)
  AND o.round = m.round;

ALTER TABLE match_giorno ADD PRIMARY KEY (match_id);
CREATE INDEX ON match_giorno (giorno);


-- ----------------------------------------------------------------------------
-- 8. Verifiche di coerenza.
--    8a. Lo scostamento dall'inizio del torneo deve crescere ordinatamente dal
--        primo turno alla finale: se l'ordine e' incoerente, l'abbinamento ha
--        prodotto collisioni fra settimane vicine.
--    8b. La densita' dell'aria deve stare nell'intervallo fisico atteso.
--    8c. Quota di incontri a data certa.
-- ----------------------------------------------------------------------------
SELECT m.round, count(*) AS incontri,
       round(avg(d.data_reale - e.date)::numeric, 2)    AS giorni_medi,
       round(stddev(d.data_reale - e.date)::numeric, 2) AS scarto_tipo
FROM match_data_reale d, match m, tournament_event e
WHERE m.match_id = d.match_id
  AND e.tournament_event_id = m.tournament_event_id
GROUP BY m.round ORDER BY giorni_medi;

SELECT round(min(densita_aria)::numeric, 3) AS minima,
       round(avg(densita_aria)::numeric, 3) AS media,
       round(max(densita_aria)::numeric, 3) AS massima
FROM meteo_giorno;

SELECT fonte, count(*) FROM match_giorno GROUP BY fonte;

-- -----------------------------------------------------------------------------------------------------------------------------------
-- 9. Metrica individuale, neutralizzata per superficie.
--    9a. Una riga per giocatore-incontro, con il residuo rispetto all'attesa Elo
--        e le tre variabili ambientali agganciate al giorno di gara.
--    9b. Sottrazione della media del giocatore su quella superficie: il residuo
--        netto ha media nulla dentro ogni coppia giocatore-superficie, cosicche'
--        nessuna correlazione residua possa essere specializzazione di superficie.
--    9c. Aggregazione. Soglia di 40 incontri per fascia termica.
-- ----------------------------------------------------------------------------
CREATE TEMP TABLE oss_clima AS
SELECT v.player_id, v.surface, v.p_matches AS esito,
       v.p_matches - 1.0 / (1.0 + power(10.0, (v.opponent_elo_rating - v.player_elo_rating) / 400.0)) AS residuo,
       w.temp_media, w.umidita_media, w.densita_aria
FROM player_match_for_stats_v v, match_giorno g, meteo_giorno w
WHERE g.match_id = v.match_id
  AND w.tournament_event_id = v.tournament_event_id
  AND w.data = g.giorno
  AND v.level IN ('G','F','L','M','O','A','B')
  AND v.outcome IS NULL
  AND v.indoor = FALSE
  AND v.surface IS NOT NULL
  AND v.player_elo_rating IS NOT NULL
  AND v.opponent_elo_rating IS NOT NULL;

CREATE TEMP TABLE oss_netta AS
SELECT c.*,
       c.residuo - avg(c.residuo) OVER (PARTITION BY c.player_id, c.surface) AS residuo_netto,
       count(*) OVER (PARTITION BY c.player_id, c.surface) AS n_superficie
FROM oss_clima c;

SELECT full_name(p.first_name, p.last_name) AS giocatore,
       count(*) AS incontri,
       round(avg(n.temp_media)::numeric, 1) AS temperatura_media,
       round(100.0 * (avg(CASE WHEN n.temp_media >= 26 THEN n.residuo_netto END)
                    - avg(CASE WHEN n.temp_media <= 18 THEN n.residuo_netto END))::numeric, 2) AS effetto_caldo,
       round(corr(n.residuo_netto, n.temp_media)::numeric, 3)    AS corr_temperatura,
       round(corr(n.residuo_netto, n.umidita_media)::numeric, 3) AS corr_umidita,
       round(corr(n.residuo_netto, n.densita_aria)::numeric, 3)  AS corr_densita
FROM oss_netta n, player p
WHERE p.player_id = n.player_id
  AND n.n_superficie >= 40
GROUP BY p.player_id, p.first_name, p.last_name
HAVING sum(CASE WHEN n.temp_media >= 26 THEN 1 ELSE 0 END) >= 40
   AND sum(CASE WHEN n.temp_media <= 18 THEN 1 ELSE 0 END) >= 40
ORDER BY effetto_caldo DESC;


-- ----------------------------------------------------------------------------
-- 10. Verifica aggregata: frequenza di ace per fascia termica e superficie.
--     Numerosita' di due ordini di grandezza superiore alla metrica individuale.
--     Le fasce 0 e 7 sono le classi aperte di width_bucket e vanno scartate,
--     insieme a quelle con meno di 200 incontri.
--     Il risultato serve sia come misura dell'effetto fisico sia come
--     validazione della ricostruzione del giorno di gara.
-- ----------------------------------------------------------------------------
SELECT m.surface AS superficie,
       width_bucket(w.temp_media, 10, 34, 6) AS fascia,
       round(min(w.temp_media)::numeric, 0) AS da,
       round(max(w.temp_media)::numeric, 0) AS a,
       count(*) AS incontri,
       round(100.0 * sum(s.w_ace + s.l_ace)::numeric / sum(s.w_sv_pt + s.l_sv_pt), 2) AS pct_ace
FROM match m, match_stats s, match_giorno g, meteo_giorno w
WHERE s.match_id = m.match_id AND s.set = 0
  AND g.match_id = m.match_id
  AND w.tournament_event_id = m.tournament_event_id
  AND w.data = g.giorno
  AND m.indoor = FALSE
  AND m.surface IN ('H','C','G')
  AND s.w_sv_pt IS NOT NULL
  AND m.outcome IS NULL
GROUP BY m.surface, fascia
HAVING count(*) >= 200
   AND width_bucket(w.temp_media, 10, 34, 6) BETWEEN 1 AND 6
ORDER BY m.surface, fascia;


