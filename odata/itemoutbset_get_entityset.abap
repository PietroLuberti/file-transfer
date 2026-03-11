  METHOD itemoutbset_get_entityset.
**TRY.
*CALL METHOD SUPER->ITEMOUTBSET_GET_ENTITYSET
*  EXPORTING
*    IV_ENTITY_NAME           =
*    IV_ENTITY_SET_NAME       =
*    IV_SOURCE_NAME           =
*    IT_FILTER_SELECT_OPTIONS =
*    IS_PAGING                =
*    IT_KEY_TAB               =
*    IT_NAVIGATION_PATH       =
*    IT_ORDER                 =
*    IV_FILTER_STRING         =
*    IV_SEARCH_STRING         =
**    io_tech_request_context  =
**  IMPORTING
**    et_entityset             =
**    es_response_context      =
*    .
** CATCH /iwbep/cx_mgw_busi_exception .
** CATCH /iwbep/cx_mgw_tech_exception .
**ENDTRY.

* =====================================================================================
* SINTASSI PER GESTIRE DUE ENTITY ASSOCIATE TRAMITE UN CAMPO CHIAVE IN UN METODO ODATA
* =====================================================================================
*
* Scenario:
*   Entity A = HeaderOutbSet  (Chiave: Vbeln)
*   Entity B = ItemOutbSet    (Chiave: Vbeln + Posnr)
*   Associazione (Navigation Property): HeaderOutbSet --[1:N]--> ItemOutbSet via VBELN
*
* Chiamate OData supportate:
*   (1) Navigazione:   GET /HeaderOutbSet(Vbeln='0800012345')/ToItemOutbSet
*       La chiave dell'entity sorgente (Header) è disponibile in IT_KEY_TAB
*
*   (2) EntitySet con filtro diretto:
*       GET /ItemOutbSet?$filter=Vbeln eq '0800012345'
*       Il campo chiave è disponibile in IT_FILTER_SELECT_OPTIONS
* =====================================================================================

**! ABAP Doc: Struttura per le posizioni consegna (Entity B - ItemOutbSet)
    TYPES: BEGIN OF ty_item,
             vbeln  TYPE lips-vbeln,   " Campo chiave di associazione con Header
             posnr  TYPE lips-posnr,   " Chiave posizione
             matnr  TYPE lips-matnr,
             arktx  TYPE lips-arktx,
             lfimg  TYPE lips-lfimg,
             meins  TYPE lips-meins,
             werks  TYPE lips-werks,
             lgort  TYPE lips-lgort,
             charg  TYPE lips-charg,
             xchpf  TYPE lips-xchpf,
             mtart  TYPE lips-mtart,
             type   TYPE zgestmat,
           END OF ty_item.

    DATA: lt_item  TYPE TABLE OF ty_item,
          ls_item  TYPE ty_item.

**! ABAP Doc: Campo chiave di associazione tra Entity A (Header) e Entity B (Item)
    DATA: lv_vbeln TYPE vbeln_vl.

* -------------------------------------------------------------------------------------
* PASSO 1: Recupero del campo chiave dall'entity sorgente (Entity A)
*
* Quando il metodo è invocato tramite navigazione OData, la tabella IT_KEY_TAB
* contiene le coppie nome/valore delle chiavi dell'entity sorgente (Header).
* Il campo 'name' corrisponde al nome della proprietà definita nel MPC (Model Provider).
* -------------------------------------------------------------------------------------
    READ TABLE it_key_tab INTO DATA(ls_key) WITH KEY name = 'Vbeln'.
    IF sy-subrc = 0.
**! ABAP Doc: Chiave Vbeln trovata in IT_KEY_TAB: provenienza da navigazione OData
      lv_vbeln = ls_key-value.
    ENDIF.

* -------------------------------------------------------------------------------------
* PASSO 2 (Fallback): Se non trovato via navigazione, cerca nei filtri diretti
*
* Quando il metodo è invocato come EntitySet con filtro query string ($filter),
* i valori filtro sono in IT_FILTER_SELECT_OPTIONS con sign/option/low/high.
* -------------------------------------------------------------------------------------
    IF lv_vbeln IS INITIAL.
      READ TABLE it_filter_select_options
        WITH KEY property = 'Vbeln'
        ASSIGNING FIELD-SYMBOL(<so_vbeln>).
      IF sy-subrc = 0.
        READ TABLE <so_vbeln>-select_options INDEX 1 INTO DATA(ls_vbeln_filter).
        IF sy-subrc = 0.
          lv_vbeln = ls_vbeln_filter-low.
        ENDIF.
      ENDIF.
    ENDIF.

* -------------------------------------------------------------------------------------
* PASSO 3: Verifica campo chiave e uscita anticipata se non valorizzato
* -------------------------------------------------------------------------------------
    IF lv_vbeln IS INITIAL.
      RETURN.
    ENDIF.

* -------------------------------------------------------------------------------------
* PASSO 4: Lettura Entity B (ItemOutbSet) filtrata per il campo chiave
*          che la associa all'Entity A (HeaderOutbSet)
*
* Il campo VBELN è il campo chiave di associazione:
*   - In Entity A (Header) è la chiave primaria
*   - In Entity B (Item)   è la foreign key (parte della chiave composta)
* -------------------------------------------------------------------------------------
    SELECT lips~vbeln,
           lips~posnr,
           lips~matnr,
           lips~arktx,
           lips~lfimg,
           lips~meins,
           lips~werks,
           lips~lgort,
           lips~charg,
           lips~xchpf,
           lips~mtart
      FROM lips
      INTO CORRESPONDING FIELDS OF TABLE @lt_item
      WHERE lips~vbeln = @lv_vbeln
        AND lips~uecha = ''.       " Solo posizioni principali (non sotto-posizioni partite)

* -------------------------------------------------------------------------------------
* PASSO 5: Arricchimento Entity B con il tipo di gestione materiale
*          (campo derivato che non è sulla tabella LIPS ma su tabella custom)
*
* Per ogni posizione, determina il tipo di gestione (Q=Quantità, S=Seriale, P=Partita)
* tramite la tabella di configurazione ZMM_OL_GESTMAT, usando i campi
* MTART e XCHPF come chiave di ricerca.
* -------------------------------------------------------------------------------------
    LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<ls_item>).
      SELECT SINGLE gestmat
        INTO @<ls_item>-type
        FROM zmm_ol_gestmat
        WHERE out_bukrs = 'OF01'
          AND out_werks = 'OF01'
          AND mtart     = @<ls_item>-mtart
          AND xchpf     = @<ls_item>-xchpf.
    ENDLOOP.

* -------------------------------------------------------------------------------------
* PASSO 6: Trasferimento risultato nell'entityset di output
* -------------------------------------------------------------------------------------
    MOVE-CORRESPONDING lt_item TO et_entityset.

  ENDMETHOD.
