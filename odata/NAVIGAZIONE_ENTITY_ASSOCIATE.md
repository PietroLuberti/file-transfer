# 📋 GESTIONE DI DUE ENTITY ASSOCIATE IN UN METODO ODATA SAP
## Sintassi e Pattern per la Navigazione tra Entity con Campo Chiave

**Repository:** PietroLuberti/file-transfer  
**Percorso:** `/odata/itemoutbset_get_entityset.abap`  
**Data documento:** 2026-03-11

---

## 1. PROBLEMA E CONTESTO

In un servizio OData SAP (framework IW_BEP / SEGW), è comune avere due entity types
associate fra loro tramite un campo chiave (navigation property). Ad esempio:

- **Entity A** — `HeaderOutbSet` (Testata Consegna): chiave primaria `Vbeln`
- **Entity B** — `ItemOutbSet` (Posizione Consegna): chiave composta `Vbeln` + `Posnr`
- **Associazione**: 1:N — un Header ha N Items, collegati tramite il campo `Vbeln`

La domanda è: **come si gestisce questa associazione in un metodo ABAP**?

---

## 2. COME FUNZIONA LA NAVIGAZIONE IN ODATA SAP (IW_BEP)

Quando un client OData chiama una navigation property, il framework IW_BEP invoca
il metodo `_GET_ENTITYSET` dell'entity di destinazione (Entity B), passando la chiave
dell'entity sorgente (Entity A) nella tabella `IT_KEY_TAB`.

### 2.1 Chiamata tramite Navigation Property

```http
GET /sap/opu/odata/sap/ZSERVIZIO_SRV/HeaderOutbSet(Vbeln='0800012345')/ToItemOutbSet
```

**Cosa accade internamente:**
1. Il framework riconosce il path di navigazione `ToItemOutbSet`
2. Invoca `ITEMOUTBSET_GET_ENTITYSET` nella classe DPC_EXT
3. Popola `IT_KEY_TAB` con la coppia `name = 'Vbeln'`, `value = '0800012345'`

### 2.2 Chiamata diretta con filtro (senza navigazione)

```http
GET /sap/opu/odata/sap/ZSERVIZIO_SRV/ItemOutbSet?$filter=Vbeln eq '0800012345'
```

**Cosa accade internamente:**
1. Il framework invoca direttamente `ITEMOUTBSET_GET_ENTITYSET`
2. Popola `IT_FILTER_SELECT_OPTIONS` con il filtro sul campo `Vbeln`

---

## 3. SINTASSI ABAP — PARAMETRI DEL METODO GET_ENTITYSET

Il metodo OData nella classe DPC_EXT riceve i seguenti parametri rilevanti
per la gestione di entity associate:

| Parametro | Tipo | Utilizzo |
|-----------|------|----------|
| `IT_KEY_TAB` | `TABLE OF /iwbep/s_mgw_tech_pair` | Chiavi entity sorgente (navigazione) |
| `IT_FILTER_SELECT_OPTIONS` | `TABLE OF /iwbep/s_mgw_select_option` | Filtri query string (`$filter=`) |
| `IT_NAVIGATION_PATH` | `TABLE OF /iwbep/s_mgw_navigation_path` | Percorso di navigazione completo |
| `ET_ENTITYSET` | `TABLE` | Risultato da restituire al client |

### Struttura di IT_KEY_TAB

```abap
/iwbep/s_mgw_tech_pair:
  name   TYPE string   " Nome della proprietà chiave (es. 'Vbeln')
  value  TYPE string   " Valore della chiave (es. '0800012345')
```

### Struttura di IT_FILTER_SELECT_OPTIONS

```abap
/iwbep/s_mgw_select_option:
  property        TYPE string          " Nome della proprietà (es. 'Vbeln')
  select_options  TYPE /iwbep/t_cod_select_options  " Range: sign/option/low/high
```

---

## 4. PATTERN COMPLETO — LETTURA IT_KEY_TAB

Questo è il pattern standard per gestire in un metodo le due chiamate
(navigazione e filtro diretto):

```abap
METHOD itemoutbset_get_entityset.

  DATA: lv_vbeln TYPE vbeln_vl.

  " ---------------------------------------------------------------
  " CASO 1: Chiamata via navigazione
  "         GET /HeaderOutbSet(Vbeln='...')/ToItemOutbSet
  "         La chiave è in IT_KEY_TAB
  " ---------------------------------------------------------------
  READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Vbeln'.
  IF sy-subrc = 0.
    lv_vbeln = ls_key-value.
  ENDIF.

  " ---------------------------------------------------------------
  " CASO 2 (Fallback): Chiamata diretta con filtro query string
  "         GET /ItemOutbSet?$filter=Vbeln eq '...'
  "         Il campo chiave è in IT_FILTER_SELECT_OPTIONS
  " ---------------------------------------------------------------
  IF lv_vbeln IS INITIAL.
    READ TABLE it_filter_select_options
      WITH KEY property = 'Vbeln'
      ASSIGNING FIELD-SYMBOL(<so_vbeln>).
    IF sy-subrc = 0.
      READ TABLE <so_vbeln>-select_options INDEX 1 INTO DATA(ls_range).
      IF sy-subrc = 0.
        lv_vbeln = ls_range-low.
      ENDIF.
    ENDIF.
  ENDIF.

  CHECK lv_vbeln IS NOT INITIAL.

  " ---------------------------------------------------------------
  " Lettura Entity B (Item) filtrata per il campo chiave
  " che la associa a Entity A (Header)
  " ---------------------------------------------------------------
  SELECT vbeln, posnr, matnr, arktx, lfimg, meins, werks, lgort
    FROM lips
    INTO CORRESPONDING FIELDS OF TABLE @et_entityset
    WHERE vbeln = @lv_vbeln.

ENDMETHOD.
```

---

## 5. DEFINIZIONE DELL'ASSOCIAZIONE NEL MODEL PROVIDER (MPC)

Per far funzionare la navigation property, è necessario dichiararla nel
**Model Provider Class** (MPC_EXT), nel metodo `DEFINE`:

```abap
METHOD define.

  DATA: lo_entity_type_header TYPE REF TO /iwbep/if_mgw_odata_entity_typ,
        lo_entity_type_item   TYPE REF TO /iwbep/if_mgw_odata_entity_typ,
        lo_association        TYPE REF TO /iwbep/if_mgw_odata_assoc,
        lo_assoc_set          TYPE REF TO /iwbep/if_mgw_odata_assoc_set,
        lo_nav_property       TYPE REF TO /iwbep/if_mgw_odata_nav_prop.

  CALL METHOD SUPER->DEFINE.

  " Recupera le entity type già definite
  lo_entity_type_header = model->get_entity_type( iv_entity_name = 'HeaderOutb' ).
  lo_entity_type_item   = model->get_entity_type( iv_entity_name = 'ItemOutb' ).

  " Crea l'associazione 1:N tra Header e Item
  " con il campo chiave VBELN come campo di collegamento
  lo_association = model->create_association(
    iv_association_name       = 'toItemOutb'          " Nome navigazione
    iv_principal_entity_name  = 'HeaderOutb'          " Entity A (1)
    iv_principal_cardinality  = /iwbep/if_mgw_cont_annot_types=>gc_cardinality-one
    iv_dependent_entity_name  = 'ItemOutb'            " Entity B (N)
    iv_dependent_cardinality  = /iwbep/if_mgw_cont_annot_types=>gc_cardinality-many
  ).

  " Mappa il campo chiave: Vbeln di Header --> Vbeln di Item
  lo_association->create_mapping(
    iv_principal_property_name = 'Vbeln'   " Proprietà in Entity A
    iv_dependent_property_name = 'Vbeln'   " Proprietà in Entity B (stessa)
  ).

  " Crea l'Association Set
  lo_assoc_set = model->create_association_set(
    iv_assoc_set_name  = 'toItemOutb_set'
    iv_association_name = 'toItemOutb'
    iv_principal_entity_set_name = 'HeaderOutbSet'
    iv_dependent_entity_set_name = 'ItemOutbSet'
  ).

  " Aggiunge la Navigation Property all'entity type Header
  lo_nav_property = lo_entity_type_header->create_navigation_property(
    iv_property_name    = 'ToItemOutbSet'   " Nome usato nell'URL OData
    iv_association_name = 'toItemOutb'
    iv_fromrole_name    = 'fromRole_HeaderOutb'
    iv_torole_name      = 'toRole_ItemOutb'
  ).

ENDMETHOD.
```

---

## 6. TABELLA RIEPILOGATIVA — DOVE TROVARE IL CAMPO CHIAVE

| Tipo di chiamata OData | Dove leggere il campo chiave | Struttura usata |
|------------------------|------------------------------|-----------------|
| Navigazione: `/EntityA(key)/ToEntityBSet` | `IT_KEY_TAB` | `READ TABLE it_key_tab WITH KEY name = 'Vbeln'` |
| Filtro diretto: `/EntityBSet?$filter=Vbeln eq '...'` | `IT_FILTER_SELECT_OPTIONS` | `READ TABLE it_filter_select_options WITH KEY property = 'Vbeln'` |
| Chiave entità: `/EntityBSet(Vbeln='...',Posnr='...')` | `IT_KEY_TAB` (metodo GET_ENTITY) | `READ TABLE it_key_tab WITH KEY name = 'Vbeln'` |

---

## 7. RELAZIONE CON IL CODICE ESISTENTE NEL REPOSITORY

Il metodo `DETAILOUTBSET_GET_ENTITYSET` (`/odata/detailoutbset_get_entityset.abap`)
gestisce tre livelli gerarchici in un unico metodo (Header → Item → Detail),
usando lo stesso pattern:

```
LIVELLO 1 (Header): SELECT da SHP_IDX_GDRC/LIPS/LIKP → gt_head[]
     ↓ campo chiave: VBELN
LIVELLO 2 (Item):   SELECT da LIPS WHERE vbeln IN gt_head[] → gt_item[]
     ↓ campo chiave: VBELN + POSNR
LIVELLO 3 (Detail): SELECT da SER01/LIPS WHERE vbeln = gs_item-vbeln → et_entityset[]
```

La differenza rispetto al pattern mostrato in questo documento è che
`DETAILOUTBSET_GET_ENTITYSET` risolve tutti e tre i livelli internamente
(senza usare `IT_KEY_TAB`), mentre il pattern con `IT_KEY_TAB` è quello
standard per metodi che vengono chiamati anche via navigation property OData.

---

## 8. BEST PRACTICE

1. **Gestire entrambi i casi** (navigazione + filtro diretto) nello stesso metodo
2. **Usare `CHECK` o `RETURN`** se il campo chiave non è valorizzato, per evitare
   SELECT senza filtri che restituirebbero tutti i record
3. **Il nome del campo in `IT_KEY_TAB`** corrisponde al nome della proprietà
   definita nel MPC (case-sensitive, tipicamente PascalCase: `'Vbeln'`)
4. **Il nome del campo in `IT_FILTER_SELECT_OPTIONS`** corrisponde al nome
   della proprietà nel MPC (solitamente lowercase: `'vbeln'`) — verificare
   la configurazione del proprio servizio

---

## Autore e Data
- **Data documento:** 11 Marzo 2026
- **Metodo:** `ITEMOUTBSET_GET_ENTITYSET`
- **Framework:** SAP IW_BEP (SEGW)
- **Modulo:** MM (Materials Management)
- **Applicazione:** Web app BTP per gestione consegne
