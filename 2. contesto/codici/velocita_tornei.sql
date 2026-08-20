SELECT 
    t.name AS torneo,
    te.surface AS superficie,
    t.level AS categoria,
    count(es.court_speed) AS edizioni_valutate,
    round(avg(es.court_speed)::numeric, 1) AS velocita_media,
    min(es.court_speed) AS velocita_min,
    max(es.court_speed) AS velocita_max
FROM tournament t, tournament_event te, event_stats es
WHERE t.tournament_id = te.tournament_id
  AND te.tournament_event_id = es.tournament_event_id
  AND es.court_speed IS NOT NULL
GROUP BY t.tournament_id, t.name, t.level, te.surface
ORDER BY velocita_media DESC;