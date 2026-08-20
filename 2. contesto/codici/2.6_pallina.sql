-- Prestazione per marca di palla, neutralizzata per Elo avversario
-- e per specializzazione di superficie del giocatore.

--qui possiamo solo valutare i numeri provenienti dai tornei maggiori dal 2012 al 2020, perché questa è la copertura maggiore trovata


--tabella delle palle (da speedcourt.com)
CREATE TABLE palla_torneo (
    torneo        TEXT     NOT NULL,
    stagione      SMALLINT NOT NULL,
    marca         TEXT     NOT NULL,
    cambio        BOOLEAN  NOT NULL DEFAULT FALSE,
    tournament_id INTEGER,
    PRIMARY KEY (torneo, stagione)
);

INSERT INTO palla_torneo (torneo, stagione, marca)
SELECT v.torneo, s.stagione, v.marca
FROM (VALUES
    ('Australian Open', 2012, 2018, 'Wilson'),
    ('Australian Open', 2019, 2026, 'Dunlop'),
    ('Indian Wells',    2012, 2019, 'Penn/Head'),
    ('Indian Wells',    2021, 2025, 'Penn/Head'),
    ('Indian Wells',    2026, 2026, 'Dunlop'),
    ('Miami',           2012, 2019, 'Penn/Head'),
    ('Miami',           2021, 2026, 'Dunlop'),
    ('Monte Carlo',     2012, 2019, 'Dunlop'),
    ('Monte Carlo',     2021, 2026, 'Dunlop'),
    ('Madrid',          2012, 2019, 'Dunlop'),
    ('Madrid',          2021, 2026, 'Dunlop'),
    ('Rome',            2012, 2026, 'Dunlop'),
    ('Roland Garros',   2012, 2019, 'Babolat'),
    ('Roland Garros',   2020, 2026, 'Wilson'),
    ('Wimbledon',       2012, 2019, 'Slazenger'),
    ('Wimbledon',       2021, 2026, 'Slazenger'),
    ('Canada',          2012, 2019, 'Penn/Head'),
    ('Canada',          2021, 2022, 'Penn/Head'),
    ('Canada',          2023, 2026, 'Wilson'),
    ('Cincinnati',      2012, 2022, 'Penn/Head'),
    ('Cincinnati',      2023, 2026, 'Wilson'),
    ('US Open',         2012, 2026, 'Wilson'),
    ('Shanghai',        2012, 2017, 'Srixon'),
    ('Shanghai',        2018, 2019, 'Dunlop'),
    ('Shanghai',        2023, 2023, 'Dunlop'),
    ('Shanghai',        2024, 2024, 'Wilson'),
    ('Shanghai',        2025, 2026, 'Yonex'),
    ('Paris',           2012, 2026, 'Penn/Head'),
    ('Tour Finals',     2012, 2018, 'Penn/Head'),
    ('Tour Finals',     2019, 2026, 'Dunlop')
) AS v(torneo, dal, al, marca),
generate_series(v.dal, v.al) AS s(stagione);


UPDATE palla_torneo SET cambio = TRUE
WHERE (torneo, stagione) IN (
    ('Australian Open', 2018), ('Australian Open', 2019), ('Miami', 2019), ('Miami', 2021),
    ('Roland Garros', 2019), ('Roland Garros', 2020), ('Canada', 2022),('Canada', 2023), ('Cincinnati', 2023),
    ('Cincinnati', 2022), ('Shanghai', 2017), ('Shanghai', 2018), ('Tour Finals', 2018), ('Tour Finals', 2019)
);
--segiamo le prime e le ultime edizioni con una nuova marca di pallina  
-- per dagli un peso maggiore, in quanto riteniamo siano le più informative



--tabella
DROP VIEW IF EXISTS perf_palla;

CREATE TEMP VIEW perf_palla AS
WITH incontri_palla AS (
    SELECT o.player_id, o.esito, o.residuo, o.residuo_netto,
           b.marca,
           CASE WHEN b.cambio THEN 1.2 ELSE 1.0 END AS peso 
    FROM osservazioni o, palla_torneo b
    WHERE b.tournament_id = o.tournament_id
      AND b.stagione      = o.season
      AND o.season >= 2012
      AND o.level IN ('G', 'F', 'M')
      AND o.n_superficie >= 40
)
SELECT i.marca, p.player_id,
       full_name(p.first_name, p.last_name) AS giocatore,
       count(*) AS incontri,
       round(100.0 * (sum(i.peso * i.esito) / sum(i.peso)), 2)                    AS vittorie_grezze, --numero di vittorie pesate
       round(100.0 * (sum(i.peso * i.residuo) / sum(i.peso)), 2)                   AS scarto_grezzo,--neutralizzato della probabilità di vittoria data dall'Elo degli avversari
       round(100.0 * (sum(i.peso * (i.residuo_netto)) / sum(i.peso)), 2) AS scarto_neutro --neutralizzato anche della superficie      
FROM incontri_palla i, player p
WHERE p.player_id = i.player_id
GROUP BY i.marca, p.player_id, p.first_name, p.last_name
HAVING count(*) >= 25; --qui siamo costretti ad abbssare la soglia perché con aclune marche verrebbero fuori davvero pochi giocatori con sufficienti partite


--   QUERY
-- Una tabella per marca, ordinata per prestazione.
-- Adatta i nomi a quelli restituiti dalla query qui sopra.
SELECT giocatore, incontri, vittorie_grezze, scarto_grezzo, scarto_neutro
FROM perf_palla WHERE marca = 'Dunlop' ORDER BY scarto_neutro DESC LIMIT 100;

SELECT giocatore, incontri, vittorie_grezze, scarto_grezzo, scarto_neutro
FROM perf_palla WHERE marca = 'Wilson' ORDER BY scarto_neutro DESC LIMIT 100;

SELECT giocatore, incontri, vittorie_grezze, scarto_grezzo, scarto_neutro
FROM perf_palla WHERE marca LIKE '%Head' ORDER BY scarto_neutro DESC LIMIT 100;

SELECT giocatore, incontri, vittorie_grezze, scarto_grezzo, scarto_neutro
FROM perf_palla WHERE marca = 'Slazenger' ORDER BY scarto_neutro DESC LIMIT 100;
