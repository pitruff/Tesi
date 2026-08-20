
--creiamo una funzione che calcoli la probabilità di vittoria data dai punteggi Elo, 
--come quella che deuce ha nativamente
CREATE OR REPLACE FUNCTION p_attesa(elo_giocatore INTEGER, elo_avversario INTEGER)
RETURNS NUMERIC AS $$
    SELECT 1.0 / (1.0 + power(10.0, (elo_avversario - elo_giocatore) / 400.0));
$$ LANGUAGE sql IMMUTABLE;



--Nel scrivere la maggior parte di queste metriche, soprattutto della seconda sezione, è stato utile utilizzare in tutte una CTE
--che raccogliesse alcune informazioni specifiche per ogni partita. Seppure ci fosse qualche variazione tra le varie query, 
--l'impianto di queste CTE era in tutte analogo, quindi si è deciso di costruire una tabella a priori

DROP TABLE IF EXISTS osservazioni;

CREATE TABLE osservazioni AS
SELECT v.match_id, v.player_id, v.opponent_id,
       v.date AS data,
       v.season, v.level, v.surface, v.indoor, v.best_of, v.round,
       v.tournament_id, v.tournament_event_id,
       v.p_matches           AS esito,
       v.player_elo_rating   AS elo_giocatore,
       v.opponent_elo_rating AS elo_avversario,
       p_attesa(v.player_elo_rating, v.opponent_elo_rating) AS attesa,
       v.p_matches - p_attesa(v.player_elo_rating, v.opponent_elo_rating) AS residuo,
       (SELECT ms.minutes
        FROM match_stats ms
        WHERE ms.match_id = v.match_id
          AND ms.set = 0) AS minuti,
       (SELECT es.court_speed
        FROM event_stats es
        WHERE es.tournament_event_id = v.tournament_event_id) AS court_speed
FROM player_match_for_stats_v v
WHERE v.level IN ('G','F','L','M','O','A','B')
  AND v.outcome IS NULL
  AND v.surface IS NOT NULL
  AND v.player_elo_rating IS NOT NULL
  AND v.opponent_elo_rating IS NOT NULL;


--indici per velocizzare
CREATE INDEX ON osservazioni (player_id, surface);
CREATE INDEX ON osservazioni (player_id, data);
CREATE INDEX ON osservazioni (match_id);
ANALYZE osservazioni;



--Aggiungiamo due colonne che ci permetteranno di togliere a ogni riga 
-- la media dei residui che quel giocatore ha su quella superficie.
--Se Nadal sulla terra vince in media dieci punti percentuali più di quanto l'Elo generale preveda, 
-- tutte le sue righe di terra vengono abbassate di dieci punti.
--Lo useremo in 2.3 e 2.6 per neutralizzare l'effetto della superficie.
ALTER TABLE osservazioni
    ADD COLUMN residuo_netto NUMERIC,
    ADD COLUMN n_superficie INTEGER;

UPDATE osservazioni o
SET residuo_netto = o.residuo - (SELECT avg(x.residuo)
                                 FROM osservazioni x
                                 WHERE x.player_id = o.player_id
                                   AND x.surface = o.surface),
    n_superficie  = (SELECT count(*)
                     FROM osservazioni x
                     WHERE x.player_id = o.player_id
                       AND x.surface = o.surface);

ANALYZE osservazioni;




--Il turno e' registrato come codice testuale e non ha un ordine intrinseco:
--la funzione lo traduce in un intero crescente dal primo turno alla finale,
--cosi' da poter riconoscere quale incontro sia l'esordio in un torneo.
--Serve per la 2.4 e la 2.5
CREATE OR REPLACE FUNCTION ordine_round(turno TEXT)
RETURNS INTEGER AS $$
    SELECT CASE turno
               WHEN 'RR'   THEN 0   --girone delle Finals, precede la fase a eliminazione
               WHEN 'R128' THEN 1
               WHEN 'R64'  THEN 2
               WHEN 'R32'  THEN 3
               WHEN 'R16'  THEN 4
               WHEN 'QF'   THEN 5
               WHEN 'SF'   THEN 6
               WHEN 'BR'   THEN 7   --finale per il terzo posto, alle Olimpiadi
               WHEN 'F'    THEN 7
           END;
$$ LANGUAGE sql IMMUTABLE;
