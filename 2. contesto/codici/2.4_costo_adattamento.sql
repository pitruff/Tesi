WITH primo_evento AS (
    SELECT player_id, season, surface, min(data) AS data_primo
    FROM osservazioni
    GROUP BY player_id, season, surface
),
transizione AS (
    SELECT o.*, pe.data_primo
    FROM osservazioni o, primo_evento pe
    WHERE o.player_id = pe.player_id
      AND o.season = pe.season
      AND o.surface = pe.surface
),
esordio AS (
    --Fra gli incontri del primo torneo sulla nuova superficie prendiamo il turno
    --piu' basso: quell'incontro e' la prima partita in assoluto della transizione
    --Si sfrutta qui la funzione ordine_round definita nel setup
    SELECT player_id, season, surface, min(ordine_round(round::text)) AS turno_esordio
    FROM transizione
    WHERE data = data_primo
    GROUP BY player_id, season, surface
)
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       t.surface AS superficie,
        sum(CASE WHEN t.data = t.data_primo AND ordine_round(t.round::text) = es.turno_esordio 
                        THEN 1 ELSE 0 END) AS n_esordi,  
        --andiamo a vedere la differenza tra l'esito del primo incontro del primo torneo sulla nuova superficie e quello 
        -- delle altre partite del giocatore sulla medesima superficie

        round(100.0 * avg(CASE WHEN t.data =  t.data_primo AND ordine_round(t.round::text) =  es.turno_esordio 
                        THEN t.residuo END), 2) AS scarto_transizione,
        round(100.0 * avg(CASE WHEN t.data <> t.data_primo OR ordine_round(t.round::text) <> es.turno_esordio 
                        THEN t.residuo END), 2) AS scarto_a_regime,
        round(100.0 * ((avg(CASE WHEN t.data <> t.data_primo OR ordine_round(t.round::text) <> es.turno_esordio
                             THEN t.residuo END)
                     - avg(CASE WHEN t.data =  t.data_primo AND ordine_round(t.round::text) =  es.turno_esordio
                             THEN t.residuo END))), 2) AS costo_adattamento      
FROM transizione t, esordio es, player p
WHERE p.player_id = t.player_id
AND es.player_id = t.player_id
AND es.season    = t.season
AND es.surface   = t.surface
GROUP BY p.player_id, p.first_name, p.last_name, t.surface
HAVING sum(CASE WHEN t.data = t.data_primo AND ordine_round(t.round::text) = es.turno_esordio 
                        THEN 1 ELSE 0 END) >= 10 --in ogni superficie si esordisce circa una volta a stagione, quindi è impensabile richiedere 40 esordi
AND sum(CASE WHEN t.data <> t.data_primo OR ordine_round(t.round::text) <> es.turno_esordio 
                        THEN 1 ELSE 0 END) >= 40
ORDER BY costo_adattamento DESC
LIMIT 100;
