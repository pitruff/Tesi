# Il tennis attraverso i dati aperti

Interrogazioni SQL, tabelle di appoggio e file dei risultati della tesi di laurea *Il tennis attraverso i dati aperti: le fonti, gli usi consolidati e le nuove metriche* (Politecnico di Torino, Corso di Laurea in Matematica per l'Ingegneria, A.A. 2025-2026), di Pietro Ruffatti Vitrotti.

Le undici metriche del terzo capitolo misurano il rendimento di un giocatore al variare delle condizioni di pressione e di contesto. Salvo poche eccezioni non si parte dall'esito secco della partita, ma dallo scarto fra quell'esito e la probabilità di vittoria che le valutazioni Elo antecedenti l'incontro assegnavano al giocatore.

## Struttura

- `0.setup.sql` — funzione di conversione Elo/probabilità, tabella `osservazioni` su cui poggiano tutte le metriche, funzione di ordinamento dei turni.
- `1. pressione/` — codici e risultati delle metriche 1.1-1.5 (rimonta, solidità mentale, punti da difendere, rivincita e conferma, scostamento dalle attese).
- `2. contesto/` — codici e risultati delle metriche 2.1-2.6 (superficie, clima, velocità del campo, costo di adattamento, carico di calendario, marca della palla).
- `big 3/` — dentro ciascuna cartella dei risultati, i valori di Djokovic, Nadal e Federer per quella metrica.

## Come riprodurre

1. Avviare il database di Ultimate Tennis Statistics, distribuito come immagine Docker già popolata (`mcekovic/uts-database`), e collegarvisi con `psql`.
2. Eseguire `0.setup.sql` una sola volta.
3. Eseguire il file della metrica desiderata ed esportare il risultato in CSV.


## Fonti e licenze

- **Ultimate Tennis Statistics / tennis-crystal-ball** di Mileta Čeković, da cui provengono lo schema relazionale, le valutazioni Elo, i punti per edizione e il Court Speed Index. Codice distribuito con licenza Apache 2.0.
- **Jeff Sackmann, `tennis_atp`**, che alimenta il database di cui sopra. Dati distribuiti con licenza Creative Commons Attribuzione - Non commerciale - Condividi allo stesso modo 4.0 Internazionale (CC BY-NC-SA 4.0).
- **Tennis-Data.co.uk**, da cui provengono le date di gara impiegate nella metrica climatica.
- **Rianalisi ERA5 del Copernicus Climate Change Service**, interrogata attraverso la Historical Weather API di Open-Meteo (dati con licenza CC BY 4.0) e la Geocoding API della medesima piattaforma, basata su GeoNames (licenza CC BY-NC 4.0). Né la Commissione europea né l'ECMWF rispondono dell'uso qui fatto dei dati Copernicus.
- **Courtspeed** (<https://courtspeed.com>), da cui è tratto l'abbinamento storico fra torneo e marca di palla trascritto in `2.6_pallina.sql`.

## Licenza

I file di questo archivio derivano da dati distribuiti con licenza CC BY-NC-SA 4.0 e sono quindi rilasciati alle stesse condizioni: <https://creativecommons.org/licenses/by-nc-sa/4.0/deed.it>. L'uso commerciale non è consentito.
