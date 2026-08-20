-- Poiché ogni incontro registra un vincitore e un perdente, la stessa coppia ricorre in ordine invertito a seconda dell'esito;
-- `least` e `greatest`, che restituiscono rispettivamente il minore e il maggiore fra due valori, ne producono perciò una chiave 
-- indipendente dall'ordine. L'indice principale è costruito su tale chiave seguita da data e identificativo, 
-- così da reperire i confronti precedenti per uguaglianza e già in sequenza cronologica. 
--Due indici per giocatore servono ai raggruppamenti finali, mentre le tabelle temporanee evitano di ripetere il calcolo a ogni riferimento.


-- INDICI e TABELLE preparatorie:
DROP TABLE IF EXISTS sfide;

CREATE TABLE sfide AS
SELECT v.match_id, v.data,
       v.player_id AS winner_id, s.player_id AS loser_id,
       v.elo_giocatore AS winner_elo, s.elo_giocatore AS loser_elo,
       least(v.player_id, s.player_id)    AS g1,
       greatest(v.player_id, s.player_id) AS g2
FROM osservazioni v, osservazioni s
WHERE s.match_id = v.match_id
  AND v.esito = 1
  AND s.esito = 0;

CREATE INDEX ON sfide (g1, g2, data, match_id);
ANALYZE sfide;

CREATE TEMP TABLE coppie AS
SELECT c.winner_id         AS vincitore_attuale,
       p.winner_id         AS vincitore_precedente,
       p.loser_id          AS perdente_precedente,
       c.winner_elo AS elo_vincitore,
       c.loser_elo AS elo_perdente
FROM sfide c, sfide p
WHERE p.g1 = c.g1
  AND p.g2 = c.g2
  AND p.data <= c.data
  AND (p.data < c.data OR p.match_id < c.match_id)
  AND NOT EXISTS (
          SELECT 1
          FROM sfide x
          WHERE x.g1 = c.g1
            AND x.g2 = c.g2
            AND x.data >= p.data
            AND x.data <= c.data
            AND (x.data > p.data OR x.match_id > p.match_id)
            AND (x.data < c.data OR x.match_id < c.match_id)
      );

CREATE INDEX ON coppie (perdente_precedente);
CREATE INDEX ON coppie (vincitore_precedente);
ANALYZE coppie;



--QUERY:
WITH riv_ok AS (
    SELECT perdente_precedente AS player_id,
           count(*) AS n,
           sum(p_attesa(elo_vincitore, elo_perdente)) AS attese
    FROM coppie
    WHERE vincitore_attuale = perdente_precedente
    GROUP BY perdente_precedente
),
riv_ko AS (
    SELECT perdente_precedente AS player_id,
           count(*) AS n,
           sum(p_attesa(elo_perdente, elo_vincitore)) AS attese
    FROM coppie
    WHERE vincitore_attuale = vincitore_precedente
    GROUP BY perdente_precedente
),
conf_ok AS (
    SELECT vincitore_precedente AS player_id,
           count(*) AS n,
           sum(p_attesa(elo_vincitore, elo_perdente)) AS attese
    FROM coppie
    WHERE vincitore_attuale = vincitore_precedente
    GROUP BY vincitore_precedente
),
conf_ko AS (
    SELECT vincitore_precedente AS player_id,
           count(*) AS n,
           sum(p_attesa(elo_perdente, elo_vincitore)) AS attese
    FROM coppie
    WHERE vincitore_attuale = perdente_precedente
    GROUP BY vincitore_precedente
)
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       ro.n + rk.n AS rivincite_tentate,
       ro.n AS rivincite_riuscite,
       round(100.0 * ro.n / (ro.n + rk.n), 2) AS pct_dopo_sconfitta,
       round(100.0 * (ro.attese + rk.attese) / (ro.n + rk.n), 2) AS pct_attesa_rivincite,
       round(100.0 * (ro.n - ro.attese - rk.attese) / (ro.n + rk.n), 2) AS effetto_rivincita,
       co.n + ck.n AS conferme_tentate,
       co.n AS conferme_riuscite,
       round(100.0 * co.n / (co.n + ck.n), 2) AS pct_dopo_vittoria,
       round(100.0 * (co.attese + ck.attese) / (co.n + ck.n), 2) AS pct_attesa_conferme,
       round(100.0 * (co.n - co.attese - ck.attese) / (co.n + ck.n), 2) AS effetto_conferma
FROM player p, riv_ok ro, riv_ko rk, conf_ok co, conf_ko ck
WHERE ro.player_id = p.player_id
  AND rk.player_id = p.player_id
  AND co.player_id = p.player_id
  AND ck.player_id = p.player_id
  AND ro.n + rk.n >= 40
  AND co.n + ck.n >= 40
ORDER BY effetto_rivincita DESC
LIMIT 100;

--è interessante osservare che giocatori come Struff, con un alto effetto rivincita e anche conferma,
--probabilmente giocano meglio con un avversario che già conoscono. 
