CREATE INDEX IF NOT EXISTS ptr_event_idx ON player_tournament_event_result (tournament_event_id);
ANALYZE player_tournament_event_result;

WITH partecipazioni AS (
    SELECT r.player_id,
           e.tournament_id,
           e.season,
           e.level,
           GREATEST(r.rank_points, 0) AS punti
    FROM player_tournament_event_result r, tournament_event e
           
    WHERE e.level IN ('G', 'M', 'A', 'B')
    AND e.tournament_event_id = r.tournament_event_id
    AND e.season BETWEEN 2000 AND 2021 --non vediamo gli anni prima del 2000 perché i punti assegnati ai vari tornei erano molto più variabili allora
),
scala AS ( --andiamo a normalizzare sui punti in palio di ogni torneo perché nel 2009 sono stati raddoppiati i punti, quindi chiunque quell'anno avrebbeun tasso di riconferma altissimo
    SELECT season, level, max(punti) AS punti_titolo
    FROM partecipazioni
    GROUP BY season, level
),
quote AS ( 
    SELECT p.player_id,
           p.tournament_id,
           p.season,
           p.punti / nullif(s.punti_titolo, 0)::numeric AS quota
    FROM partecipazioni p, scala s
    WHERE s.season = p.season
    AND s.level  = p.level
),
confronto AS ( --per orni stagione per ogni torneo e per ogni giocatore, abbiamo la quota dei punti che ha conquistato e quella dei punti che aveva conquistato l'anno prima (da difendere)
    SELECT c.player_id,
           c.season,
           c.quota,
           prec.quota AS quota_da_difendere
    FROM quote c, quote prec
    WHERE prec.player_id     = c.player_id
    AND prec.tournament_id = c.tournament_id
    AND prec.season        = c.season - 1
)
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       count(*) AS edizioni_confrontate,
       round(100 * avg(c.quota_da_difendere), 1) AS quota_media_in_scadenza,
       round(100 * avg(c.quota), 1)              AS quota_media_riconquistata,
       round(100 * sum(c.quota) / nullif(sum(c.quota_da_difendere), 0), 1)
                                                 AS tasso_conservazione
       
FROM confronto c, player p 
WHERE c.quota_da_difendere > 0
AND p.player_id = c.player_id
GROUP BY p.player_id, p.first_name, p.last_name
HAVING count(*) >= 40
ORDER BY tasso_conservazione DESC
LIMIT 100;
