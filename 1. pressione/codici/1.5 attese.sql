--Quanto si discostano i risultati di un giocatore dalle attese calcolate con l'Elo?
--Questa metrica offre sia una misura di quanto un giocatore sia capace di sorprendere
--che di quanto sia bene calibrato l'ELo.

--QUERY (NB per vedere chi rende meno rispetto alle attese basta 
--mettere ASC invece che DESC nella ORDER BY)

SELECT full_name(p.first_name, p.last_name) AS giocatore,
       COUNT(*) AS incontri,
       SUM(o.esito) AS vittorie,
       round(SUM(o.attesa), 1)                                   AS vittorie_attese,
       round(sum(o.residuo), 1)                      AS scostamento,
       round(100.0 * avg(o.residuo), 2)               AS scostamento_per_100
FROM player p, osservazioni o
WHERE p.player_id = o.player_id
GROUP BY p.player_id, p.first_name, p.last_name
HAVING count(*) >= 200 --qui è l'unico punto in cui non scegliamo come soglia 40 ma 200:
--il motivo è che nelle carriere brevi l'Elo non è subito calibrato bene, quindi è più facile discostarsi dalle attese.
--E' curioso osservare che con soglia 40 il numero uno è un giovane Jannik Sinner, con sole 45 partite in registro.
ORDER BY scostamento_per_100 DESC
LIMIT 100; 

--E' da tenere presente che l'Elo, su cui è qui calcolata la probabilità di vittoria (siccome abbiamo visto nel capitolo 2 che è un metro
--di paragone molto attendibile) si aggiorna proprio su questi esiti, e chi vince più del previsto vede la propria valutazione salire 
--fino ad annullare lo scarto. Il saldo di carriera tende quindi per costruzione verso lo zero.

--vediamo inoltre che nella classifica dei giocatori che rendono peggio rispetto alla probabilità ci sono quasi solo giocatori di allora
--mentre in quella dei giocatori che overperformano sono quasi tutti recenti.
--potrebbe essere una tendenza dell'ELO negli anni ma di questo non abbiamo trovato evidenze.