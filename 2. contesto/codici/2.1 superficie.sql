-- 5 query

--i più specializzati n generale
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       o.surface AS superficie,
       count(*) AS incontri,
       round(avg(o.elo_avversario), 0) AS elo_medio_avversari,
       round(100.0 * avg(o.esito), 2) AS vittorie_grezze,
       round(100.0 * avg(o.attesa), 2) AS vittorie_attese,
       round(100.0 * avg(o.residuo), 2) AS specializzazione
FROM osservazioni o, player p
WHERE p.player_id = o.player_id
GROUP BY p.player_id, p.first_name, p.last_name, o.surface
HAVING count(*) >= 40
ORDER BY specializzazione DESC
LIMIT 100;


--specialisti di terra
--Troviamo sorpendentemente berrettini, nonostante il suo potente
--servizio potesse far pensare che Matteo renda meglio su cemento
--o su erba (dove ha anche fatto finale a Wimbledon)
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       o.surface AS superficie,
       count(*) AS incontri,
       round(avg(o.elo_avversario), 0) AS elo_medio_avversari,
       round(100.0 * avg(o.esito), 2) AS vittorie_grezze,
       round(100.0 * avg(o.attesa), 2) AS vittorie_attese,
       round(100.0 * avg(o.residuo), 2) AS specializzazione
FROM osservazioni o, player p
WHERE p.player_id = o.player_id
AND o.surface='C'
GROUP BY p.player_id, p.first_name, p.last_name, o.surface
HAVING count(*) >= 40
ORDER BY specializzazione DESC
LIMIT 100;

--specialisti di cemento
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       o.surface AS superficie,
       count(*) AS incontri,
       round(avg(o.elo_avversario), 0) AS elo_medio_avversari,
       round(100.0 * avg(o.esito), 2) AS vittorie_grezze,
       round(100.0 * avg(o.attesa), 2) AS vittorie_attese,
       round(100.0 * avg(o.residuo), 2) AS specializzazione
FROM osservazioni o, player p
WHERE p.player_id = o.player_id
AND o.surface='H'
GROUP BY p.player_id, p.first_name, p.last_name, o.surface
HAVING count(*) >= 40
ORDER BY specializzazione DESC
LIMIT 100;


--specialisti di erba 
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       o.surface AS superficie,
       count(*) AS incontri,
       round(avg(o.elo_avversario), 0) AS elo_medio_avversari,
       round(100.0 * avg(o.esito), 2) AS vittorie_grezze,
       round(100.0 * avg(o.attesa), 2) AS vittorie_attese,
       round(100.0 * avg(o.residuo), 2) AS specializzazione
FROM osservazioni o, player p
WHERE p.player_id = o.player_id
AND o.surface='G'
GROUP BY p.player_id, p.first_name, p.last_name, o.surface
HAVING count(*) >= 40
ORDER BY specializzazione DESC
LIMIT 100;

--specialisti di carpet (ultimo torneo giocato nel 2010)
-- di questo non vediamo i big3 perché solo federer ha dati significativi a riguardo,
-- mentre degli altri due sono registrate troppe poche partite sulla superficie
SELECT full_name(p.first_name, p.last_name) AS giocatore,
       o.surface AS superficie,
       count(*) AS incontri,
       round(avg(o.elo_avversario), 0) AS elo_medio_avversari,
       round(100.0 * avg(o.esito), 2) AS vittorie_grezze,
       round(100.0 * avg(o.attesa), 2) AS vittorie_attese,
       round(100.0 * avg(o.residuo), 2) AS specializzazione
FROM osservazioni o, player p
WHERE p.player_id = o.player_id
AND o.surface='P'
GROUP BY p.player_id, p.first_name, p.last_name, o.surface
HAVING count(*) >= 40
ORDER BY specializzazione DESC
LIMIT 100;