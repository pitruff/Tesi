--QUERY
WITH carico AS (
    SELECT o.player_id, o.residuo,
           GREATEST((SELECT sum(x.minuti)
                     FROM osservazioni x
                     WHERE x.player_id = o.player_id
                       AND x.minuti IS NOT NULL
                       AND x.data >= o.data - 14
                       AND (
                             --partite dei giorni precedenti: tornei gia' conclusi
                             --o incontri dello stesso torneo con data anteriore
                             x.data <= o.data - 1
                             --turni precedenti del torneo in corso: la data e' la stessa
                             --della partita osservata, quindi il confronto si fa sull'ordine
                             --del turno restituito da ordine_round
                             OR (x.tournament_event_id = o.tournament_event_id
                                 AND ordine_round(x.round::text) < ordine_round(o.round::text))
                           )), 0) AS minuti_14gg
    FROM osservazioni o
    WHERE o.minuti IS NOT NULL
),
totali AS (
    SELECT c.player_id,
           count(*) AS incontri,
           avg(c.minuti_14gg) AS carico_medio,
           regr_slope(c.residuo, c.minuti_14gg) AS pendenza
           --regr_slope è l'aggregato che stima la retta dei minimi quadrati fra i suoi due argomenti, 
           --dove il primo è la variabile dipendente e il secondo quella indipendente: 
           --qui misura di quanto varia il residuo rispetto all'attesa Elo per ogni minuto di carico accumulato 
           --nei quattordici giorni precedenti. 
    FROM carico c
    GROUP BY c.player_id
),
bassi AS (
    SELECT c.player_id, count(*) AS n_bassi, avg(c.residuo) AS scarto
    FROM carico c
    WHERE c.minuti_14gg < 240
    GROUP BY c.player_id
),
alti AS (
    SELECT c.player_id, count(*) AS n_alti, avg(c.residuo) AS scarto
    FROM carico c
    WHERE c.minuti_14gg >= 600
    GROUP BY c.player_id
)
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       t.incontri,
       round(t.carico_medio::numeric, 0) AS carico_medio,
       round(100.0 * b.scarto::numeric, 2) AS scarto_carico_basso, --quanto si vince in più dell'attesa quando c'è un carico di poche partite precedenti o corte
       round(100.0 * a.scarto::numeric, 2) AS scarto_carico_alto,  --quanto si vince in più dell'attesa quando c'è un carico di tante partite precedenti o lunghe
       round(100.0 * t.pendenza::numeric * 100, 3) AS coeff_per_100_minuti
       --Le due moltiplicazioni per 100 traducono il residuo in punti percentuali e riscalano il carico a blocchi di cento minuti, 
       --quindi coeff_per_100_minuti pari a -0,5 significa mezzo punto percentuale di rendimento in meno sotto l'attesa per ogni 
       --cento minuti giocati nella quindicina precedente, mentre un valore positivo indica chi rende meglio quando è più carico.
FROM totali t, bassi b, alti a, player p
WHERE b.player_id = t.player_id
  AND a.player_id = t.player_id
  AND p.player_id = t.player_id
  AND b.n_bassi >= 40
  AND a.n_alti >= 40
ORDER BY coeff_per_100_minuti DESC;