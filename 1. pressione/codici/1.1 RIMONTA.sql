

WITH occasioni AS (  --restituisce una tupla per ogni primo set perso dal giocatore 
    SELECT o.player_id,
           o.esito AS rimontato --se il giocatore vince la partita (ha rimontato) vale 1, se la perde (non è riuscito)
    FROM osservazioni o, set_score s
    WHERE s.match_id = o.match_id
      AND s.set = 1
      AND o.best_of = 3
      AND ( (o.esito = 1 AND s.w_games < s.l_games)
         OR (o.esito = 0 AND s.l_games < s.w_games) )
)
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       count(*) AS primi_set_persi,
       sum(o.rimontato) AS rimonte_riuscite, --sto sommando tutte le volte in cui è riuscito (tutti i valori 1)
       round(100.0 * sum(o.rimontato) / count(*), 1) AS pct_rimonta
FROM occasioni o, player p
WHERE p.player_id = o.player_id
GROUP BY p.player_id, p.first_name, p.last_name
HAVING count(*) >= 40
ORDER BY pct_rimonta DESC
LIMIT 100;

--notiamo che contro Rod Laver, con un campione di 150 partite in cui ha perso il primo set,
--anche se vinci il primo, sei praticamente pari.