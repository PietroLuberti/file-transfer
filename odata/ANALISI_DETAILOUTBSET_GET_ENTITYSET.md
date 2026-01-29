# 📋 ANALISI FUNZIONALE E TECNICA
## Metodo: `DETAILOUTBSET_GET_ENTITYSET`

**Repository:** PietroLuberti/file-transfer  
**Percorso:** `/odata/detailoutbset_get_entityset.abap`  
**Versione analizzata:** Commit 1335f137c88a80c0311d1c776ea862b27ff02de9  
**Data analisi:** 2026-01-29

---

## 1. SCOPO FUNZIONALE

Il metodo implementa un servizio OData per l'estrazione dei **dettagli delle consegne in uscita (outbound deliveries)** e **forniture in entrata (inbound deliveries)** nel sistema SAP ECC, con gestione differenziata per materiali a:
- **Quantità (Q)** - gestione standard
- **Partita (P)** - batch management
- **Numero Seriale (S)** - serial number management

### 1.1 Origini del Codice
Il metodo eredita la logica dall'applicazione Fiori **ZMM_FIORI_ACCET_RIS** (Accettazione con Riserva), da cui sono stati copiati e adattati tre metodi:
- `HEADEROUTBSET_GET_ENTITYSET`
- `ITEMOUTBSET_GET_ENTITYSET`
- `DETAILOUTBSET_GET_ENTITYSET`

---

## 2. ARCHITETTURA A TRE LIVELLI

Il metodo implementa un'elaborazione gerarchica su tre livelli:

```
┌─────────────────────────────────────────────┐
│ LIVELLO 1: HEADER (Testata Consegne)       │
│ - Consegne in uscita (008...)              │
│ - Forniture in entrata (018...)            │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ LIVELLO 2: ITEM (Posizioni)                │
│ - Materiali gestiti a partita              │
│ - Materiali gestiti a quantità/seriale     │
└─────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────┐
│ LIVELLO 3: DETAIL (Dettagli)               │
│ - Esplosione per partita/seriale           │
│ - Generazione ID univoco (IDREC)           │
│ - Persistenza su DB (ZMM_CONS_FLAUT)       │
└─────────────────────────────────────────────┘
```

---

## 3. FLUSSO DI ELABORAZIONE

### 3.1 Fase Preparatoria (Righe 34-104)

#### **Input Parameters Processing**
```abap
- it_filter_select_options (Filtri OData)
  ├─ cod_imp  → Codice Impresa (OBBLIGATORIO)
  ├─ budat    → Data registrazione
  └─ lgort    → Magazzino (commentato)
```

#### **Logica dei Filtri**
1. **Tipi Ordine (`rg_bsart`)**: Estratti dal set `ZMM_TIPO_ORDINE` (tabella `SETLEAF`)
2. **Codice Impresa (`rg_codimp`)**: 
   - Se non fornito → **EXIT** immediato (riga 70)
   - Obbligatorio per l'esecuzione
3. **Data Registrazione (`rg_budat`)**:
   - Se fornita → usa il filtro
   - Se assente e `ZMM_CONSEGNE_INVIO_FULL` ≠ 'X' → usa `sy-datum - 1`
   - Se assente e `ZMM_CONSEGNE_INVIO_FULL` = 'X' → nessun filtro (estrazione completa)

---

### 3.2 LIVELLO 1: Estrazione Testata Consegne (Righe 106-299)

#### **Struttura Dati Header**
```abap
ts_head:
  - vbeln          : Numero consegna
  - lfdat          : Data consegna
  - erdat          : Data creazione
  - werks          : Centro
  - lgort          : Magazzino
  - budat          : Data registrazione movimento
  - cod_imp        : Codice impresa
  - vgbel          : Documento di riferimento (ordine)
  - bsart          : Tipo ordine acquisto
  - lfart          : Tipo consegna
  - provenienza    : Origine ("Fornitore" o magazzino)
  - tipo           : Descrizione tipo consegna
```

#### **Query 1: Consegne in Uscita (Outbound - 008...)**
Righe 208-247

**Tabelle coinvolte:**
- `SHP_IDX_GDRC` (a) - Indice consegne
- `LIPS` (s, b) - Posizioni consegna
- `LIKP` (c) - Testata consegna
- `TVLKT` (tvlk) - Testi tipo consegna
- `MKPF` (m) - Testata documenti materiali
- `EKKO` (ek) - Testata ordini acquisto

**Condizioni chiave:**
```sql
WHERE a.vstel = wa_mag_user-svstel         -- Punto di spedizione
  AND b.lgort = wa_mag_user-slgort          -- Magazzino utente
  AND b.werks = wa_mag_user-swerks          -- Centro utente
  AND a.lifex IN r_respinti                 -- Consegne NON rifiutate
  AND m.budat IN rg_budat                   -- Filtro data registrazione
  AND ek.bsart IN rg_bsart                  -- Filtro tipo ordine
```

**Note:**
- Usa `m.budat` (data registrazione movimento) come filtro temporale
- `r_respinti` è popolato con consegne presenti in `ZFIORI_MAG_LOCL` (segno 'E' = esclusione)

#### **Query 2: Forniture in Entrata (Inbound - 018...)**
Righe 250-293

**Differenze rispetto alle consegne:**
- `a.lifex EQ ''` - nessuna consegna in uscita associata
- `a.lifnr NE ''` - deve avere fornitore
- `i.esito = 'OK'` - controllo su tabella custom `ZMM_FIORI_IDSER`
- Filtro su `c.erdat` (data creazione) invece di `m.budat`
- Esclusione da `ZFIORI_MAG_LOCL` e `ZFIORI_STORICO`
- `provenienza = 'Fornitore'` (hardcoded)

**Output:** Tabella `gt_head[]` con tutte le consegne/forniture

---

### 3.3 LIVELLO 2: Estrazione Posizioni (Righe 305-492)

#### **Gestione Duplice: Partite vs Quantità/Seriale**

##### **Query 1: Materiali a Partita (Batch)**
Righe 369-390

```sql
SELECT lips.vbeln, lips.uecha, lips.matnr, makt.maktx, lips.lfimg...
  FROM lips
  JOIN makt ON lips.matnr = makt.matnr
  WHERE vbeln IN gt_head[]
    AND uecha NE ''              -- Indica gestione a partita
```

**Aggregazione quantità:**
- Le posizioni con stesso `vbeln/posnr` sono aggregate (righe 395-407)
- Somma delle quantità (`lv_sum`) per ottenere il totale

##### **Query 2: Materiali a Quantità/Seriale**
Righe 411-429

```sql
SELECT lips.vbeln, lips.posnr, lips.matnr, lips.arktx...
  FROM lips
  WHERE vbeln IN gt_head[]
    AND uecha EQ ''              -- NO gestione a partita
```

#### **Determinazione Tipo Gestione**
Righe 465-476

```abap
SELECT SINGLE gestmat INTO gs_item-type
  FROM zmm_ol_gestmat
  WHERE out_bukrs = 'OF01'       -- Hardcoded
    AND out_werks = 'OF01'       -- Hardcoded
    AND mtart = wa_lips-mtart    -- Tipo materiale
    AND xchpf = wa_lips-xchpf    -- Indicatore partita
```

**Valori tipo gestione:**
- `'Q'` - Quantità
- `'S'` - Seriale
- `'P'` - Partita

**Output:** Tabella `gt_item[]` con posizioni aggregate

---

### 3.4 LIVELLO 3: Dettaglio ed Esplosione (Righe 495-744)

#### **Generazione ID Record (IDREC)**
Righe 555-562

```abap
CONCATENATE gs_item-vbeln     -- Numero consegna
            gs_item-posnr     -- Posizione
            gs_head-budat     -- Data registrazione (⚠️ PROBLEMA!)
            gs_item-type      -- Tipo gestione
            gs_item-matnr     -- Codice materiale
       INTO lv_idrec.
```

**⚠️ PROBLEMA IDENTIFICATO:**
- `gs_head-budat` può variare tra esecuzioni
- Non garantisce univocità stabile nel tempo

#### **Elaborazione per Tipo Gestione**

##### **TIPO Q - Quantità** (Righe 576-586)
```abap
- Singolo record senza esplosione
- IDREC = concatenazione base
- Quantità = valore intero da lfimg
```

##### **TIPO S - Numero Seriale** (Righe 588-618)
```abap
- Estrazione seriali da SER01 + OBJK
- Tipo movimento: '101' per ZEL, '641' per altri
- UN record per ogni seriale
- IDREC_DET = lv_idrec + gv_ser (serial number)
- Quantità sempre = 1
```

**Query seriali:**
```sql
SELECT objk.sernr
  FROM ser01
  JOIN objk ON ser01.obknr = objk.obknr
  WHERE ser01.lief_nr = gs_item.vbeln
    AND ser01.bwart = lv_bwart
    AND ser01.posnr = gs_item.posnr
```

##### **TIPO P - Partita** (Righe 620-671)
```abap
- Due logiche in base al tipo consegna (lfart):
  
  1. ZSS/ZOS: usa lips.charg diretto
     WHERE lips.vbeln = gs_item.vbeln
       AND lips.posnr = gs_item.posnr
  
  2. Altri: usa lips.uecha (posizione superiore)
     WHERE lips.vbeln = gs_item.vbeln
       AND lips.uecha = gs_item.posnr
  
- UN record per ogni partita
- IDREC_DET = lv_idrec + gv_ser (batch)
- Quantità = lfimg della partita
```

##### **TIPO Q con QR Code** (Righe 672-733)
```abap
- Estrazione seriali + QR code da ZMM_OL_TRACKINGQ
- Chiamata a FM ZMM_SERIALI_QRCODE per conversione
- IDREC_DET = lv_idrec + lv_codice + gv_ser
- Campi popolati:
  * charg = codice QR convertito
  * qrsernr = serial number originale
```

---

### 3.5 Persistenza Dati (Righe 739-740)

```abap
MODIFY zmm_cons_flaut FROM TABLE lt_cons.
COMMIT WORK AND WAIT.
```

**Tabella Custom `ZMM_CONS_FLAUT`:**
- Storicizza tutti i dettagli elaborati
- Include timestamp di inserimento (`erdat_ins`, `erzet_ins`)
- Chiave primaria: `idrec`

---

## 4. TABELLE SAP COINVOLTE

| Tabella | Descrizione | Utilizzo |
|---------|-------------|----------|
| `SHP_IDX_GDRC` | Indice consegne | Ricerca consegne/forniture |
| `LIPS` | Posizioni consegna | Dettagli materiali |
| `LIKP` | Testata consegna | Date e riferimenti |
| `MKPF` | Testata documento materiale | Data registrazione (`budat`) |
| `EKKO` | Testata ordini acquisto | Tipo ordine (`bsart`) |
| `SER01` | Dati master seriali | Numero seriale |
| `OBJK` | Oggetti collegati | Link seriali |
| `MAKT` | Testi materiali | Descrizione materiale |
| `MARC` | Dati materiale per centro | Profilo numero seriale |
| `TVLKT` | Testi tipo consegna | Descrizione tipo consegna |
| `T006A` | Unità di misura | Conversione unità |
| `SETLEAF` | Valori set | Tipi ordine ammessi |
| `TVARVC` | Variabili tabella | Flag estrazione completa |

---

## 5. TABELLE CUSTOM Z

| Tabella | Descrizione | Ruolo |
|---------|-------------|-------|
| `ZMM_CONS_FLAUT` | Storico consegne | **Output finale** |
| `ZMM_MAG_IMP_CIT` | Magazzini imprese | Filtro autorizzazioni |
| `ZFIORI_MAG_USER` | Utenti magazzino | Autorizzazioni utente |
| `ZFIORI_MAG_LOCL` | Consegne localizzate | Esclusioni |
| `ZFIORI_STORICO` | Storico elaborazioni | Esclusioni forniture |
| `ZMM_FIORI_IDSER` | Seriali Fiori | Validazione forniture |
| `ZMM_OL_GESTMAT` | Gestione materiali | Determinazione tipo gestione |
| `ZMM_OL_TRACKINGQ` | Tracking QR | Link QR code - seriali |
| `ZCOMU` | Comuni | Descrizione comune |

---

## 6. PUNTI CRITICI E ANOMALIE

### 6.1 ⚠️ **BUG: IDREC Non Stabile**
**Localizzazione:** Righe 555-562

**Problema:**
```abap
CONCATENATE gs_item-vbeln
            gs_item-posnr
            gs_head-budat     -- ⚠️ Può variare!
            gs_item-type
            gs_item-matnr
       INTO lv_idrec.
```

**Impatto:**
- Stesso record logico ottiene `idrec` diversi in esecuzioni diverse
- Possibili duplicazioni in `ZMM_CONS_FLAUT`
- Perdita di tracciabilità

**Soluzione:**
```abap
CONCATENATE gs_item-vbeln
            gs_item-posnr
            gs_item-matnr
            gs_item-type
       INTO lv_idrec.
```

### 6.2 ⚠️ **Valori Hardcoded**
- **`out_bukrs = 'OF01'`** (riga 467)
- **`out_werks = 'OF01'`** (riga 468)
- **`provenienza = 'Fornitore'`** (riga 258)

**Raccomandazione:** Parametrizzare tramite tabella di configurazione

### 6.3 ⚠️ **Gestione Errori Assente**
- Nessun `TRY-CATCH` per le SELECT
- Nessuna validazione su `cod_imp` obbligatorio
- Chiamata a FM `ZMM_SERIALI_QRCODE` senza gestione eccezioni efficace (righe 714-716)

### 6.4 ⚠️ **Performance**
- **SELECT in loop** per seriali e partite (righe 597-618, 625-646, 649-670, 682-733)
- Mancano indici su tabelle custom
- Nessun uso di `FOR ALL ENTRIES` per dettagli

### 6.5 ⚠️ **Variabili Inutilizzate**
- `lv_sydatum` e `lv_syuzeit` (righe 526-527) valorizzate ma commentate in `lv_idrec`
- `lv_user` dichiarato ma mai valorizzato (riga 566)

---

## 7. DIPENDENZE ESTERNE

### 7.1 Function Modules
- **`ZMM_SERIALI_QRCODE`** (righe 698-716)
  - Conversione serial number ↔ QR code
  - Parametri:
    * `in_tipoconversione = 'Q'`
    * `in_matnr`, `in_codice`
  - Eccezioni: 6 tipi non gestiti correttamente

### 7.2 Configurazione Sistema
- **Set `ZMM_TIPO_ORDINE`**: Tipi ordine ammessi
- **Variabile `ZMM_CONSEGNE_INVIO_FULL`**: Controllo estrazione completa
- **Tabella `ZMM_MAG_IMP_CIT`**: 
  - Deve avere `zcluster = 'AG'`
  - Deve avere `zstato = 'ACTV'`
  - Deve avere `zattivita LIKE 'CREATION%'

---

## 8. CASI D'USO

### 8.1 Scenario Standard
```
INPUT:
  - cod_imp = '0001234567'
  - budat = '20260128'

OUTPUT:
  - et_entityset[] con dettagli consegne/forniture
  - ZMM_CONS_FLAUT aggiornata con nuovi record
```

### 8.2 Estrazione Completa
```
INPUT:
  - cod_imp = '0001234567'
  - budat non fornito
  - ZMM_CONSEGNE_INVIO_FULL = 'X'

COMPORTAMENTO:
  - Nessun filtro temporale
  - Estrazione di TUTTE le consegne storiche
```

### 8.3 Gestione Materiali Misti
```
CONSEGNA 0800012345:
  ├─ Posizione 10 - Materiale MAT001 (Tipo Q) → 1 record
  ├─ Posizione 20 - Materiale MAT002 (Tipo S) → N record (1 per seriale)
  └─ Posizione 30 - Materiale MAT003 (Tipo P) → M record (1 per partita)
```

---

## 9. METRICHE CODICE

| Metrica | Valore |
|---------|--------|
| Righe totali | 745 |
| Righe commentate | ~50 |
| SELECT statements | 15 |
| SELECT in loop | 5 |
| Livelli nesting massimi | 4 |
| Complessità ciclomatica | Alta |
| Function calls | 1 (ZMM_SERIALI_QRCODE) |
| Tabelle DB accedute | 20+ |

---

## 10. RACCOMANDAZIONI

### 10.1 **Priorità ALTA**
1. ✅ **Correggere formula `idrec`** per garantire stabilità
2. ✅ **Aggiungere gestione errori** con `TRY-CATCH`
3. ✅ **Validare `cod_imp`** prima di procedere
4. ✅ **Ottimizzare SELECT in loop** con `FOR ALL ENTRIES`

### 10.2 **Priorità MEDIA**
5. 🔄 Parametrizzare valori hardcoded
6. 🔄 Aggiungere logging dettagliato
7. 🔄 Documentare tabelle custom
8. 🔄 Creare unit test

### 10.3 **Priorità BASSA**
9. 📝 Rifattorizzare in metodi privati (singola responsabilità)
10. 📝 Migrare a CDS Views per performance
11. 📝 Implementare caching per tabelle di configurazione

---

## 11. CONCLUSIONI

Il metodo implementa una logica complessa di estrazione dati multi-livello con gestione differenziata per tipologie di materiali. Nonostante l'architettura funzionalmente corretta, presenta criticità tecniche che richiedono interventi correttivi, in particolare sulla **stabilità dell'identificatore univoco `idrec`** e sulle **performance** delle query annidate.

**Complessità stimata refactoring:** 📊 **Media-Alta** (40-60 ore sviluppo + testing)

---

**Documento generato da:** GitHub Copilot  
**Per conto di:** @PietroLuberti  
**Link repository:** [PietroLuberti/file-transfer](https://github.com/PietroLuberti/file-transfer)