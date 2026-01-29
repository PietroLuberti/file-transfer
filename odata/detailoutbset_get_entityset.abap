METHOD detailoutbset_get_entityset.
**TRY.
*CALL METHOD SUPER->DETAILOUTBSET_GET_ENTITYSET
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

    DATA: ls_cons TYPE zmm_cons_flaut,
          lt_cons TYPE TABLE OF zmm_cons_flaut.

* Questo Odata è stato inizialmente copiato da quello dell'app Accettazione con riserva,
* ZMM_FIORI_ACCET_RIS dal quale ha ereditato le logiche: in particolare sono state
* copiati e riadattati i metodi
* HEADEROUTBSET_GET_ENTITYSET
* ITEMOUTBSET_GET_ENTITYSET
* DETAILOUTBSET_GET_ENTITYSET

    DATA: rg_bsart  TYPE /iwbep/t_cod_select_options,
          rgs_bsart TYPE /iwbep/s_cod_select_option.

    DATA: rg_lgort  TYPE /iwbep/t_cod_select_options,
          rgs_lgort TYPE /iwbep/s_cod_select_option.
    DATA: rg_codimp  TYPE /iwbep/t_cod_select_options,
          rgs_codimp TYPE /iwbep/s_cod_select_option.
*    DATA: rg_erdat  TYPE /iwbep/t_cod_select_options,
*          rgs_erdat TYPE /iwbep/s_cod_select_option.
    DATA: "rg_budat  TYPE /iwbep/t_cod_select_options,
      rgs_budat TYPE /iwbep/s_cod_select_option,
      rg_budat  TYPE RANGE OF mkpf-budat,
      rs_budat  LIKE LINE OF rg_budat.


    DATA: lv_user      TYPE zsuser.

    SELECT valfrom FROM setleaf
          WHERE setname = 'ZMM_TIPO_ORDINE' INTO TABLE @DATA(lt_set).

    rgs_bsart-sign = 'I'.
    rgs_bsart-option = 'EQ'.
    LOOP AT lt_set INTO DATA(ls_set).
      rgs_bsart-low = ls_set-valfrom.
      APPEND rgs_bsart TO rg_bsart.
    ENDLOOP.

*    READ TABLE it_filter_select_options WITH KEY property = 'lgort' ASSIGNING FIELD-SYMBOL(<so>).
*    IF sy-subrc IS INITIAL.
*      rg_lgort[] = <so>-select_options[].
*    ENDIF.

    READ TABLE it_filter_select_options WITH KEY property = 'cod_imp' ASSIGNING FIELD-SYMBOL(<so>).
    IF sy-subrc IS INITIAL.
      rg_codimp[] = <so>-select_options[].
    ELSE.
      EXIT.
    ENDIF.

    SELECT SINGLE low
      FROM tvarvc
      INTO @DATA(lf_full)
     WHERE name EQ 'ZMM_CONSEGNE_INVIO_FULL'.

    READ TABLE it_filter_select_options WITH KEY property = 'budat' ASSIGNING <so>.
    IF sy-subrc IS INITIAL.
*      rgt_budat[] = <so>-select_options[].
      LOOP AT <so>-select_options INTO rgs_budat.
        CLEAR rs_budat.
        MOVE-CORRESPONDING rgs_budat TO rs_budat.
        APPEND rs_budat TO rg_budat.
      ENDLOOP.
    ELSE.
      IF lf_full NE 'X'.
* se il filtro BUDAT non è valorizzato allora imposta di default sy-datum - 1
        rs_budat-sign = 'I'.
        rs_budat-option = 'EQ'.
        rs_budat-low = sy-datum - 1.
        APPEND rs_budat TO rg_budat.
      ENDIF.
    ENDIF.

** per ora SUSER non viene valorizzato
*    READ TABLE it_filter_select_options WITH KEY property = 'suser' ASSIGNING <so>.
*    IF sy-subrc IS INITIAL.
*      READ TABLE <so>-select_options INDEX 1 ASSIGNING FIELD-SYMBOL(<suser>).
*      IF sy-subrc IS INITIAL.
*        MOVE <suser>-low TO lv_user.
*      ENDIF.
*    ENDIF.


***************************************************************************************************
********* ESTRAZIONE TESTATA CONSEGNE come da HEADEROUTBSET_GET_ENTITYSET
***************************************************************************************************
    TYPES:
      BEGIN OF ts_head,
        vbeln         TYPE vbeln,
        lfdat         TYPE lfdat,
        erdat         TYPE erdat,
        werks         TYPE werks_d,
        lgort         TYPE lgort_d,
        xabln         TYPE xabln,
        aenam         TYPE aenam,
        flag          TYPE string,
        provenienza   TYPE string,
        tipo          TYPE string,
        labelconsegna TYPE string,
        comune        TYPE zcomune,
        impresa       TYPE zimprdesc,
        lfart         TYPE lfart,
        budat         TYPE budat,
        cod_imp       TYPE lifnr,
        vgbel         TYPE vgbel,
        bsart         TYPE esart,
      END OF ts_head.
    TYPES:
    tt_head TYPE STANDARD TABLE OF ts_head .

    TYPES:
      BEGIN OF ts_maguser,
        swerks TYPE werks_d,
        slgort TYPE lgort_d,
        svstel TYPE vstel,
      END OF ts_maguser.
    TYPES:
    tt_maguser TYPE STANDARD TABLE OF ts_maguser .

    DATA: lt_mag_user        TYPE TABLE OF ts_maguser,
          wa_mag_user        TYPE ts_maguser,
          lt_zmm_mag_imp_cit TYPE TABLE OF zmm_mag_imp_cit,
          wa_zmm_mag_imp_cit TYPE zmm_mag_imp_cit,
          gs_head            TYPE LINE OF tt_head,
          gt_head            TYPE tt_head,
          r_respinti         TYPE RANGE OF lifex_cap.


    SELECT werks lgort zcodice zimpresa zattivita zcodimpresa
        INTO CORRESPONDING FIELDS OF TABLE lt_zmm_mag_imp_cit
        FROM zmm_mag_imp_cit
        WHERE zcodimpresa IN rg_codimp
          AND zattivita LIKE 'CREATION%'
          AND zstato = 'ACTV'
          AND zcluster = 'AG'.

    LOOP AT lt_zmm_mag_imp_cit INTO wa_zmm_mag_imp_cit.
      CLEAR rgs_lgort.
      rgs_lgort-sign = 'I'.
      rgs_lgort-option = 'EQ'.
      rgs_lgort-low = wa_zmm_mag_imp_cit-lgort.
      APPEND rgs_lgort TO rg_lgort.
    ENDLOOP.

    IF rg_lgort[] IS NOT INITIAL.
      SELECT swerks, slgort, svstel
          INTO CORRESPONDING FIELDS OF TABLE @lt_mag_user
          FROM zfiori_mag_user
          WHERE " suser   IN gr_suser and
                slgort IN @rg_lgort .
      SORT lt_mag_user.
      DELETE ADJACENT DUPLICATES FROM lt_mag_user.

      SELECT DISTINCT
             vbeln  AS low,
             'E'    AS sign,
             'EQ'   AS option
        FROM zfiori_mag_locl
        INTO CORRESPONDING FIELDS OF TABLE @r_respinti.
    ENDIF.

    LOOP AT lt_mag_user INTO wa_mag_user.

      CLEAR: gs_head.
*      gs_hea-aenam = wa_zfiori_mag_user-suser.

      CLEAR wa_zmm_mag_imp_cit.
*      SELECT SINGLE zcodice zimpresa zattivita zcodimpresa
*        INTO CORRESPONDING FIELDS OF wa_zmm_mag_imp_cit
*        FROM zmm_mag_imp_cit
*        WHERE werks = wa_mag_user-swerks
*        AND lgort = wa_mag_user-slgort.
      READ TABLE lt_zmm_mag_imp_cit INTO wa_zmm_mag_imp_cit
          WITH KEY werks = wa_mag_user-swerks
                   lgort = wa_mag_user-slgort.

      SELECT SINGLE comune INTO gs_head-comune
        FROM zcomu
        WHERE codice = wa_zmm_mag_imp_cit-zcodice.

      gs_head-impresa = wa_zmm_mag_imp_cit-zimpresa.
      REPLACE ALL OCCURRENCES OF '&' IN gs_head-impresa WITH 'e'.
      gs_head-cod_imp = wa_zmm_mag_imp_cit-zcodimpresa.


* estrae le consegne (008... outbound deliv)
      SELECT  a~lifex AS vbeln
              a~lfdat AS lfdat
              b~werks AS werks
              b~lgort AS lgort
              c~erdat AS erdat
              c~xabln AS xabln
              c~lfart AS lfart
              s~lgort AS provenienza
              tvlk~vtext AS tipo
              m~budat AS budat
              s~vgbel AS vgbel
              ek~bsart AS bsart
        INTO CORRESPONDING FIELDS OF gs_head
        FROM shp_idx_gdrc AS a
        INNER JOIN lips AS s
          ON a~lifex = s~vbeln
        INNER JOIN lips AS b
          ON a~vbeln = b~vbeln
        INNER JOIN likp AS c
          ON a~lifex = c~vbeln
        JOIN tvlkt AS tvlk
          ON c~lfart EQ tvlk~lfart
        INNER JOIN mkpf AS m
          ON m~le_vbeln = a~lifex
        INNER JOIN ekko AS ek
          ON ek~ebeln = s~vgbel
        WHERE a~vstel = wa_mag_user-svstel
        AND b~lgort = wa_mag_user-slgort
        AND b~werks = wa_mag_user-swerks
        AND a~lifex IN  r_respinti
        AND tvlk~spras = sy-langu
* per le consegne filtra per la data reg.del movimento di uscita
        AND m~budat IN rg_budat
*        AND c~erdat IN rg_budat
        AND ek~bsart IN rg_bsart.

        APPEND gs_head TO gt_head.

      ENDSELECT.


* estrae le forniture (018... inbound deliv)
      SELECT  a~vbeln     AS vbeln,
              a~lfdat     AS lfdat,
              b~werks     AS werks,
              b~lgort     AS lgort,
              c~erdat     AS erdat,
              c~xabln     AS xabln,
              c~lfart     AS lfart,
              'Fornitore' AS provenienza,
              tvlk~vtext  AS tipo,
              b~vgbel AS vgbel,
              ek~bsart AS bsart
        INTO CORRESPONDING FIELDS OF @gs_head
        FROM shp_idx_gdrc AS a
*        INNER JOIN lips AS s
*          ON a~vbeln = s~vbeln
        INNER JOIN lips AS b
          ON a~vbeln = b~vbeln
        INNER JOIN likp AS c
          ON a~vbeln = c~vbeln
        INNER JOIN zmm_fiori_idser AS i
          ON i~idnum = a~vbeln
        JOIN tvlkt AS tvlk
          ON c~lfart EQ tvlk~lfart
        INNER JOIN ekko AS ek
          ON ek~ebeln = b~vgbel
        WHERE a~vstel  = @wa_mag_user-svstel
        AND b~lgort    = @wa_mag_user-slgort
        AND b~werks    = @wa_mag_user-swerks
        AND i~esito    = 'OK'
        AND a~lifex EQ ''
        AND a~lifnr NE ''
* per le forniture filtra per la data creazione a sistema
        AND c~erdat IN @rg_budat
        AND tvlk~spras = @sy-langu
        AND a~vbeln NOT IN ( SELECT vbeln
                               FROM zfiori_mag_locl )
        AND a~vbeln NOT IN ( SELECT vbeln
                               FROM zfiori_storico )
        AND ek~bsart IN @rg_bsart.

        APPEND gs_head TO gt_head.

      ENDSELECT.
    ENDLOOP.

    CHECK gt_head[] IS NOT INITIAL.

    SORT gt_head.
    DELETE ADJACENT DUPLICATES FROM gt_head.


***************************************************************************************************
********* ESTRAZIONE POSIZIONI CONSEGNE come da ITEMOUTBSET_GET_ENTITYSET
***************************************************************************************************
    TYPES: BEGIN OF ty_batch,
             vbeln TYPE lips-vbeln,
             posnr TYPE lips-posnr,
             matnr TYPE lips-matnr,
             arktx TYPE lips-arktx,  "GB maktx TYPE makt-maktx,
             lfimg TYPE lips-lfimg,
             meins TYPE lips-meins,
             mseh3 TYPE t006a-mseh3,
             werks TYPE lips-werks,
             lgort TYPE lips-lgort,
             mtart TYPE lips-mtart,
             xchpf TYPE lips-xchpf,
           END OF ty_batch.

    TYPES: BEGIN OF ty_lips,
             vbeln TYPE lips-vbeln,
             posnr TYPE lips-posnr,
             matnr TYPE lips-matnr,
             arktx TYPE lips-arktx,
             lfimg TYPE lips-lfimg,
             meins TYPE lips-meins,
             mseh3 TYPE t006a-mseh3,
             werks TYPE lips-werks,
             lgort TYPE lips-lgort,
             mtart TYPE lips-mtart,
             xchpf TYPE lips-xchpf,
           END OF ty_lips.

    TYPES:  BEGIN OF ts_ite,
              vbeln   TYPE lips-vbeln,
              posnr   TYPE lips-posnr,
              lfdat   TYPE lfdat,
              matnr   TYPE lips-matnr,
              type(2),
              maktx   TYPE lips-arktx,  "GB maktx TYPE makt-maktx,
              lfimg   TYPE lips-lfimg,
              meins   TYPE meins,
              mseh3   TYPE t006a-mseh3,
            END OF ts_ite .
    TYPES: tt_ite TYPE STANDARD TABLE OF ts_ite .

    DATA: lv_vbeln   TYPE likp-vbeln,
          lv_lfdat   TYPE likp-lfdat,
          gs_item    TYPE LINE OF tt_ite,
          gt_item    TYPE         tt_ite,
          lt_lips    TYPE TABLE OF ty_lips,
          wa_lips    TYPE ty_lips,
          wa_marc    TYPE marc,
          lt_gestmat TYPE TABLE OF zmm_ol_gestmat.

    DATA: lt_lips_batch TYPE TABLE OF ty_batch,
          lv_sum        TYPE lips-lfimg,
          ls_lips       TYPE ty_lips,
          lv_quant      TYPE i,
          r_maktx       TYPE RANGE OF makt-maktx,
          lv_string     TYPE string.

    CONSTANTS: c_vbeln(5) TYPE c VALUE 'vbeln',
               c_lfdat(5) TYPE c VALUE 'lfdat',
               c_maktx(5) TYPE c VALUE 'maktx',
               c_qt(2)    TYPE c VALUE 'QT'.


* Estrazioni Posizioni gestite a Partita
    SELECT lips~vbeln,
           lips~uecha,
           lips~matnr,
           makt~maktx,                   "GB 28.08.2018
           lips~lfimg,
           lips~meins,
           t006a~mseh3,
           lips~werks,
           lips~lgort,
           lips~mtart,
           lips~xchpf
      FROM lips
           JOIN makt
             ON lips~matnr EQ makt~matnr AND
                makt~spras EQ 'IT'
           LEFT JOIN t006a
                  ON t006a~msehi EQ lips~meins
      INTO TABLE @lt_lips_batch
      FOR ALL ENTRIES IN @gt_head
     WHERE vbeln EQ @gt_head-vbeln
       AND t006a~spras EQ @sy-langu
       AND uecha NE ''.

    SORT lt_lips_batch BY vbeln posnr.

* Vengono aggregati gli importi per materiali gestiti a partita
    LOOP AT lt_lips_batch ASSIGNING
                       FIELD-SYMBOL(<batch>).

      lv_sum = lv_sum + <batch>-lfimg.

      AT END OF posnr.
        MOVE-CORRESPONDING <batch> TO ls_lips.
        MOVE: lv_sum TO ls_lips-lfimg.
        APPEND ls_lips TO lt_lips.
        CLEAR lv_sum.
      ENDAT.

    ENDLOOP.


* Estrazioni Posizioni Gestite a Quantità e a Seriale
    SELECT lips~vbeln,
           lips~posnr,
           lips~matnr,
           lips~arktx,
           lips~lfimg,
           lips~meins,
           t006a~mseh3,
           lips~werks,
           lips~lgort,
           lips~mtart,
           lips~xchpf
      FROM lips
           LEFT JOIN t006a
                  ON t006a~msehi EQ lips~meins
      INTO TABLE @DATA(lt_lips_serqt)
      FOR ALL ENTRIES IN @gt_head
     WHERE vbeln EQ @gt_head-vbeln
       AND t006a~spras EQ @sy-langu
       AND uecha EQ ''.

    SORT lt_lips_serqt BY vbeln posnr.

* Vengono considerate solo le posizioni a quantità e a seriali
    LOOP AT lt_lips_serqt ASSIGNING
                       FIELD-SYMBOL(<serqt>).

      READ TABLE lt_lips ASSIGNING
                      FIELD-SYMBOL(<lips>)
                          WITH KEY vbeln = <serqt>-vbeln
                                   posnr = <serqt>-posnr.
      IF sy-subrc IS NOT INITIAL.
        MOVE-CORRESPONDING <serqt> TO ls_lips.
        APPEND ls_lips TO lt_lips.
      ENDIF.

    ENDLOOP.

    SORT lt_lips BY vbeln posnr.

    LOOP AT lt_lips INTO wa_lips.

      CLEAR gs_item.

      READ TABLE gt_head INTO gs_head WITH KEY vbeln = wa_lips-vbeln.
      MOVE gs_head-vbeln TO gs_item-vbeln .
      MOVE gs_head-lfdat TO gs_item-lfdat .

      CLEAR wa_marc.
      SELECT SINGLE * INTO wa_marc
        FROM marc
        WHERE matnr = wa_lips-matnr
        AND werks = wa_lips-werks.


      SELECT SINGLE gestmat INTO gs_item-type
        FROM zmm_ol_gestmat
        WHERE out_bukrs = 'OF01' "wa_zfiori_mag_user-sbukrs   RB
        AND out_werks = 'OF01' "wa_zfiori_mag_user-swerks     RB
        AND mtart = wa_lips-mtart
        AND xchpf = wa_lips-xchpf
        AND sernp = wa_marc-sernp.
      IF sy-subrc NE 0.
*      MESSAGE 'error' TYPE 'E'.
      ELSEIF gs_item-type IS INITIAL.
        gs_item-type = c_qt.
      ENDIF.

      MOVE wa_lips-posnr TO gs_item-posnr.
      MOVE wa_lips-matnr TO gs_item-matnr.
      MOVE wa_lips-arktx TO gs_item-maktx.
*      MOVE wa_lips-lfimg TO lv_quant.
*      MOVE lv_quant      TO gs_item-lfimg.
      MOVE wa_lips-lfimg TO gs_item-lfimg.
      MOVE wa_lips-meins TO gs_item-meins.
      MOVE wa_lips-mseh3 TO gs_item-mseh3.
      APPEND gs_item TO gt_item.

    ENDLOOP.

    DELETE gt_item WHERE lfimg EQ 0.

    SORT gt_item BY vbeln posnr.


***************************************************************************************************
********* ESTRAZIONE DETTAGLIO POSIZIONI CONSEGNE come da DETAILOUTBSET_GET_ENTITYSET
***************************************************************************************************
    DATA: gs_det             TYPE LINE OF zcl_zmm_consegne_invio_mpc=>tt_detailoutb,
          gt_det             TYPE zcl_zmm_consegne_invio_mpc=>tt_detailoutb,
          lv_posnr           TYPE posnr,
          lv_matnr           TYPE matnr,
          lv_type(2)         TYPE c,
          gv_ser             TYPE gernr,
          gv_lfimg           TYPE lfimg,
          gv_qr              TYPE zqr_code,
          lt_zfiori_mag_user TYPE TABLE OF zfiori_mag_user,
          wa_zfiori_mag_user TYPE zfiori_mag_user,
          wa_zmm_ol_ser_02   TYPE zmm_ol_ser_02,
          lv_int             TYPE i,
          lv_codice          TYPE c LENGTH 30,
          lv_serial          TYPE c LENGTH 30,
          lv_bwart           TYPE mseg-bwart,
          lv_idrec           TYPE zidrec,
          lv_idrec_det       TYPE zidrec,
          lv_sydatum         TYPE datum,
          lv_syuzeit         TYPE uzeit.

    CONSTANTS: c_posnr(5) TYPE c VALUE 'posnr',
               c_matnr(5) TYPE c VALUE 'matnr',
               c_type(4)  TYPE c VALUE 'type',
               c_s(1)     TYPE c VALUE 'S',
               c_p(1)     TYPE c VALUE 'P',
               c_q(1)     TYPE c VALUE 'Q'.


    lv_sydatum = sy-datum.
    lv_syuzeit = sy-uzeit.

    CLEAR: gt_det[], lt_cons[].

    LOOP AT gt_item INTO gs_item.

      READ TABLE gt_head INTO gs_head WITH KEY vbeln = gs_item-vbeln.

      CLEAR: gs_det, lv_idrec, ls_cons.

      gs_det-name1 = gs_head-impresa.
      gs_det-zcodimpresa = gs_head-cod_imp.
      gs_det-lgort = gs_head-lgort.
      gs_det-vbeln = gs_item-vbeln.
      gs_det-posnr = gs_item-posnr.
      gs_det-matnr = gs_item-matnr.
      gs_det-tipo_gest = gs_item-type.
      gs_det-maktx = gs_item-maktx.
      gs_det-erfme = gs_item-mseh3.
      gs_det-vtext = gs_head-tipo.
      IF gs_head-budat IS INITIAL.
* per le forniture mette la data consegna
        gs_det-budat = gs_head-lfdat.
      ELSE.
* per le consegne mette la data reg. del mov.merce
        gs_det-budat = gs_head-budat.
      ENDIF.

      CONCATENATE "lv_sydatum
                  "lv_syuzeit
                  gs_item-vbeln
                  gs_item-posnr
                  gs_head-budat
                  gs_item-type
                  gs_item-matnr
                 INTO lv_idrec.

      MOVE-CORRESPONDING gs_head TO ls_cons.
      ls_cons-zcodimpresa = gs_head-cod_imp.
      ls_cons-suser = lv_user.

      MOVE-CORRESPONDING gs_item TO ls_cons.
      ls_cons-erfme = gs_item-mseh3.
      ls_cons-flag  = gs_item-type.

      ls_cons-erdat_ins = lv_sydatum.
      ls_cons-erzet_ins = lv_syuzeit.

      CASE gs_det-tipo_gest.
        WHEN c_q.

          CLEAR lv_int.
          MOVE gs_item-lfimg TO lv_int.
          MOVE lv_int TO gs_det-lfimg.
          gs_det-idrec = lv_idrec;
          APPEND gs_det TO gt_det.

          ls_cons-lfimg = lv_int.
          ls_cons-idrec = lv_idrec.
          APPEND ls_cons TO lt_cons.

        WHEN c_s.

          IF gs_head-lfart EQ 'ZEL'.
            lv_bwart = '101'.
          ELSE.
            lv_bwart = '641'.
          ENDIF.

          CLEAR gv_ser.
          SELECT objk~sernr
            INTO gv_ser
            FROM ser01
            JOIN objk
              ON ser01~obknr = objk~obknr
           WHERE ser01~lief_nr = gs_item-vbeln
             AND ser01~bwart EQ lv_bwart
             AND ser01~posnr = gs_item-posnr.

            CLEAR lv_idrec_det.
            MOVE gv_ser TO gs_det-charg.
            MOVE 1 TO gs_det-lfimg .
            CONCATENATE lv_idrec gv_ser INTO lv_idrec_det.
            gs_det-idrec = lv_idrec_det.
            APPEND gs_det TO gt_det.

            MOVE 1 TO ls_cons-lfimg.
            ls_cons-charg  = gv_ser.
            ls_cons-idrec = lv_idrec_det.
            APPEND ls_cons TO lt_cons.

          ENDSELECT.

        WHEN c_p.

          CLEAR: gv_ser.

          IF gs_head-lfart EQ 'ZSS' OR gs_head-lfart EQ 'ZOS'.
            SELECT lips~charg lips~lfimg
              INTO (gv_ser, gv_lfimg)
              FROM lips
             WHERE lips~vbeln = gs_item-vbeln
               AND lips~posnr = gs_item-posnr
               AND lips~matnr = gs_item-matnr.

              CLEAR lv_idrec_det.
              CLEAR lv_int.
              MOVE gv_ser TO gs_det-charg.
              MOVE gv_lfimg TO lv_int.
              MOVE lv_int TO gs_det-lfimg.
              CONCATENATE lv_idrec gv_ser INTO lv_idrec_det.
              gs_det-idrec = lv_idrec_det.
              APPEND gs_det TO gt_det.

              MOVE lv_int TO ls_cons-lfimg.
              ls_cons-charg  = gv_ser.
              ls_cons-idrec = lv_idrec_det.
              APPEND ls_cons TO lt_cons.

            ENDSELECT.
          ELSE.

            SELECT lips~charg lips~lfimg
             INTO (gv_ser, gv_lfimg)
             FROM lips
            WHERE lips~vbeln = gs_item-vbeln
              AND lips~uecha = gs_item-posnr
              AND lips~matnr = gs_item-matnr.

              CLEAR lv_idrec_det.
              CLEAR lv_int.
              MOVE gv_ser TO gs_det-charg.
              MOVE gv_lfimg TO lv_int.
              MOVE lv_int TO gs_det-lfimg.
              CONCATENATE lv_idrec gv_ser INTO lv_idrec_det.
              gs_det-idrec = lv_idrec_det.
              APPEND gs_det TO gt_det.

              MOVE lv_int TO ls_cons-lfimg.
              ls_cons-charg  = gv_ser.
              ls_cons-idrec = lv_idrec_det.
              APPEND ls_cons TO lt_cons.

            ENDSELECT.
          ENDIF.
        WHEN c_q.

          IF gs_head-lfart EQ 'ZEL'.
            lv_bwart = '101'.
          ELSE.
            lv_bwart = '641'.
          ENDIF.

          CLEAR: gv_ser, gv_qr.

          SELECT objk~sernr, zmm_ol_trackingq~qr_code
            INTO (@gv_ser,@gv_qr)
            FROM ser01
            JOIN objk
              ON ser01~obknr = objk~obknr
            LEFT
            JOIN zmm_ol_trackingq
              ON zmm_ol_trackingq~zou_iditem = ser01~posnr
             AND zmm_ol_trackingq~zou_idnum = ser01~lief_nr
             AND zmm_ol_trackingq~in_sernr1 = objk~sernr
           WHERE ser01~lief_nr = @gs_item-vbeln
             AND ser01~bwart EQ @lv_bwart
             AND ser01~posnr = @gs_item-posnr.

            MOVE gv_ser TO lv_serial.

            CALL FUNCTION 'ZMM_SERIALI_QRCODE'
              EXPORTING
                in_tipoconversione      = 'Q'
                in_matnr                = gs_item-matnr
                in_codice               = lv_serial
              IMPORTING
                out_codice              = lv_codice
*               OUT_MATNR               =
*               OUT_MESSAGGIO           =
              EXCEPTIONS
                tipo_invalido           = 1
                lunghezzaqr_errata      = 2
                matnr_diverso           = 3
                matnr_error             = 4
                lunghezzaseriale_errata = 5
                OTHERS                  = 6.
            IF sy-subrc <> 0.
* Implement suitable error handling here
            ENDIF.


            CLEAR lv_idrec_det.
            MOVE lv_codice  TO gs_det-charg.
            MOVE gv_ser TO gs_det-qrsernr."AB Aggiunta qr Sernr
            MOVE 1 TO gs_det-lfimg .
            CONCATENATE lv_idrec lv_codice gv_ser INTO lv_idrec_det.
            gs_det-idrec = lv_idrec_det.
            APPEND gs_det TO gt_det.

            MOVE 1 TO ls_cons-lfimg.
            ls_cons-charg  = lv_codice.
            ls_cons-qrsernr  = gv_ser.
            ls_cons-idrec = lv_idrec_det.
            APPEND ls_cons TO lt_cons.

          ENDSELECT.

      ENDCASE.

    ENDLOOP.

    MODIFY zmm_cons_flaut FROM TABLE lt_cons.
    COMMIT WORK AND WAIT.

    et_entityset[] = gt_det[].


  ENDMETHOD.