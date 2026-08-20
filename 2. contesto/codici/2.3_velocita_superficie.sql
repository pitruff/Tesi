-- Il rendimento sui tornei rapidi viene confrontato con quello sui tornei lenti in due letture
-- successive. La prima usa il residuo grezzo e risponde alla domanda "chi va meglio sul veloce":
-- poiche' court_speed e' quasi collineare con la superficie, questa lettura riflette in larga
-- parte la semplice preferenza di superficie. La seconda usa il residuo netto, gia' privato 
-- della media che quel giocatore tiene su quella superficie, e conserva la sola variazione
-- interna alla superficie: dice cioe' se un giocatore renda meglio sui cementi rapidi
-- che su quelli lenti, a prescindere dal fatto che ami il cemento.

SELECT full_name(p.first_name, p.last_name) AS giocatore,
       count(*) AS incontri,
       sum(CASE WHEN o.court_speed >= 55 THEN 1 ELSE 0 END) AS veloci,
       sum(CASE WHEN o.court_speed <= 45 THEN 1 ELSE 0 END) AS lenti,

       -- lettura lorda: scarto medio dall'attesa Elo, effetto della superficie incluso
       round(100.0 * avg(CASE WHEN o.court_speed >= 55 THEN o.residuo END), 2) AS scarto_veloci,
       round(100.0 * avg(CASE WHEN o.court_speed <= 45 THEN o.residuo END), 2) AS scarto_lenti,
       round(corr(o.residuo, o.court_speed)::numeric, 3) AS correlazione,

       -- lettura netta: quanta parte di quel divario sopravvive una volta tolta la superficie
       round(100.0 * avg(CASE WHEN o.court_speed >= 55 THEN o.residuo_netto END), 2) AS scarto_veloci_netto,
       round(100.0 * avg(CASE WHEN o.court_speed <= 45 THEN o.residuo_netto END), 2) AS scarto_lenti_netto


FROM osservazioni o, player p
WHERE p.player_id = o.player_id
  AND o.court_speed IS NOT NULL
GROUP BY p.player_id, p.first_name, p.last_name
-- almeno quaranta incontri per fascia, altrimenti le due medie non sono confrontabili fra loro
HAVING sum(CASE WHEN o.court_speed >= 55 THEN 1 ELSE 0 END) >= 40
   AND sum(CASE WHEN o.court_speed <= 45 THEN 1 ELSE 0 END) >= 40
ORDER BY correlazione DESC
LIMIT 100;