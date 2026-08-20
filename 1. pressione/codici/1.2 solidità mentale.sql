--la formula adottata è quella scelta da UTS, che si trova al link:
--https://ultimatetennisstatistics.com/glossary

SELECT giocatore, punti_mentali_vinti, punti_mentali_persi,
       round(punti_mentali_vinti::numeric / punti_mentali_persi, 3) AS solidita_mentale
FROM (
  SELECT full_name(p.first_name, p.last_name) AS giocatore,
         2 * ( GREATEST(f.deciding_sets_won, 0) + GREATEST(f.fifth_sets_won, 0)
             + GREATEST(f.finals_won, 0) )
           + GREATEST(f.tie_breaks_won, 0) + GREATEST(f.deciding_set_tbs_won, 0)
           AS punti_mentali_vinti,
         2 * ( GREATEST(f.deciding_sets_lost, 0) + GREATEST(f.fifth_sets_lost, 0)
             + GREATEST(f.finals_lost, 0) )
           + GREATEST(f.tie_breaks_lost, 0) + GREATEST(f.deciding_set_tbs_lost, 0)
           AS punti_mentali_persi
  FROM player_performance f, player p
  WHERE p.player_id = f.player_id
) t
WHERE punti_mentali_vinti + punti_mentali_persi >= 100
  AND punti_mentali_persi > 0
  
ORDER BY solidita_mentale DESC
LIMIT 100;




