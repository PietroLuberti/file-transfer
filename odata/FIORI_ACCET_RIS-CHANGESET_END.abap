  METHOD /iwbep/if_mgw_appl_srv_runtime~changeset_end.
**TRY.
*CALL METHOD SUPER->/IWBEP/IF_MGW_APPL_SRV_RUNTIME~CHANGESET_END
*    .
** CATCH /iwbep/cx_mgw_busi_exception .
** CATCH /iwbep/cx_mgw_tech_exception .
**ENDTRY.

    TYPES: BEGIN OF ty_charg,
             charg   TYPE string,
             qrsernr TYPE string,                           "GP06/11
             qty     TYPE zmm_ol_ser_02-in_batchqty,
           END OF ty_charg.

    TYPES: BEGIN OF ty_ekpo,
             vgbel TYPE ebeln,
             vgpos TYPE ebelp,
           END OF ty_ekpo.

    TYPES: BEGIN OF ty_tabella,
             vbeln       TYPE lifex_cap,
             posnr       TYPE posnr_vl,
             matnr       TYPE matnr,
             charg       TYPE z_sernr1,
             qrsernr     TYPE zqr_code,
             motivo_rett TYPE zmotivo,
             maktx       TYPE arktx,
             zdate       TYPE datum,
             ztime       TYPE utime,
             werks       TYPE werks_d,
             lgort       TYPE lgort_d,
             xabln       TYPE xabln,
             impresa     TYPE zimprdesc,
             comune      TYPE zcomune,
             zuser       TYPE zsuser,
             type        TYPE zgestmat,
             qta         TYPE zqta_tot,
             qta_acc     TYPE zqta_acc,
             qta_rif     TYPE zqta_rif,
             erfme       TYPE meins,
             stato       TYPE char1,
             acc_ris     TYPE zacc_ris,
           END OF ty_tabella.

    DATA: gs_header TYPE bapi2017_gm_head_01,
          gs_code   TYPE bapi2017_gm_code,
          gt_item   TYPE TABLE OF bapi2017_gm_item_create,
          gt_item2  TYPE TABLE OF bapi2017_gm_item_create,
          gs_item   TYPE bapi2017_gm_item_create,
          gt_sernr  TYPE TABLE OF bapi2017_gm_serialnumber,
          gt_sernr2 TYPE TABLE OF bapi2017_gm_serialnumber,
          gs_sernr  TYPE bapi2017_gm_serialnumber,
          gt_return TYPE TABLE OF bapiret2,
          gs_return TYPE bapiret2,
          i         TYPE i.
    DATA: it_log_bapi TYPE STANDARD TABLE OF zmm_log_bapi,
          wa_log_bapi LIKE LINE OF it_log_bapi.

    DATA: gs_zfiori_ris_tmp        TYPE zfiori_ris_tmp,
          gt_zfiori_ris_tmp        TYPE TABLE OF zfiori_ris_tmp,
          gs_zfiori_mag_qr_tmp     TYPE zfiori_ris_tmp,
          gt_zfiori_mag_qr_tmp     TYPE TABLE OF zfiori_ris_tmp,
          gs_zmm_ol_trackingq      TYPE zmm_ol_trackingq,
          gs_zfiori_mag_locl       TYPE zfiori_mag_locl,
          gs_zfiori_mag_locld      TYPE zfiori_mag_locl,
          gv_flagbatch             TYPE abap_bool,
          gv_qtarif                TYPE zfiori_mag_locl-qta_rif,
          gt_zfiori_mag_locl       TYPE TABLE OF zfiori_mag_locl,
          gs_zmm_mag_imp_cit       TYPE zmm_mag_imp_cit,
          gt_zfiori_ris_tmp_storic TYPE TABLE OF zfiori_ris_tmp.

    DATA: gs_outb02          TYPE zmm_ol_outb_02,
          gt_outb02          TYPE TABLE OF zmm_ol_outb_02,
          gs_vbkok           TYPE vbkok,
          gt_prot            TYPE TABLE OF prott,
          gs_prot            TYPE prott,
          gv_synchr          TYPE xfeld VALUE 'X',
          gv_commit          TYPE xfeld,
          gv_delivery        TYPE vbeln_vl,
          gv_ebeln           TYPE ebeln,
          gs_charg           TYPE ty_charg,
          gt_charg           TYPE TABLE OF ty_charg,
          gs_lips            TYPE lips,
          gs_zfiori_mag_user TYPE zfiori_mag_user,
          gv_lifex           TYPE lifex_cap,
          gv_symsgno         TYPE symsgno,
          gv_vbelnshp        TYPE vbeln_vl,
          gv_suser           TYPE zfiori_ris_tmp-suser,
          gs_tabella         TYPE ty_tabella,
          gt_tabella         TYPE TABLE OF ty_tabella.

    DATA lo_container TYPE REF TO /iwbep/if_message_container.
*FG - Start
    TYPES: BEGIN OF tab,
             tdformat TYPE tdformat,
             tdline   TYPE tdline,
           END OF tab.
    DATA: v_setid  TYPE sethier-setid,
          t_values TYPE TABLE OF rgsb4,
          w_values TYPE rgsb4.
    DATA: lv_ernam TYPE ernam,
          lt_ernam TYPE TABLE OF ernam.
    DATA: lw_usr21 TYPE usr21,
          lw_adr6  TYPE adr6.
    DATA: lt_mailsubject     TYPE sodocchgi1.
    DATA: lt_mailrecipients TYPE STANDARD TABLE OF somlrec90,
          ls_mailrecipients LIKE LINE OF lt_mailrecipients,
          lt_mailtxt        TYPE STANDARD TABLE OF soli,
          ls_mailtxt        LIKE LINE OF lt_mailtxt,
          lt_packing_list   TYPE STANDARD TABLE OF sopcklsti1,
          ls_packing_list   LIKE LINE OF lt_packing_list.
    DATA:    lt_zfiori_mail   TYPE TABLE OF zfiori_mail,
             ls_zfiori_mail   TYPE zfiori_mail,
             lt_zfiori_gruppi TYPE TABLE OF zfiori_gruppi,
             ls_zfiori_gruppi TYPE zfiori_gruppi,
             lv_mtart         TYPE mtart,
             lv_causale       TYPE zid_az.

*MP Inizio modifiche - SAPECC22_PR57 - 09.01.2022
    DATA: w_setid TYPE sethier-setid,
          lt_set  TYPE STANDARD TABLE OF rgsbv.
    DATA: r_tipo_mat  TYPE RANGE OF mtart,
          ra_tipo_mat LIKE LINE OF r_tipo_mat.
*MP Fine modifiche - SAPECC22_PR57 - 09.01.2022

    DATA: it_tab TYPE TABLE OF tab,
          wa_tab LIKE LINE OF it_tab.
    DATA: lv_data(10)   TYPE c,
          lv_ora(8)     TYPE c,
          lv_langu      TYPE sy-langu VALUE 'I',
          v             TYPE i VALUE 0,
          lv_qty        TYPE i,
          lv_qty_accris TYPE i,
          lv_qty_block  TYPE i.
*FG - End
    DATA: lobj_check_del TYPE REF TO zcl_mm_stati_mag,
          lv_checkvbeln  TYPE vbeln,
          lv_esito       TYPE char3,
          lv_descrizione TYPE char50,
          lv_mess_desc   TYPE symsgv,
          lv_processo    TYPE zzprocesso.

    DATA lt_lipstemp TYPE TABLE OF ty_ekpo.
    CONSTANTS: c_movstat3 TYPE zmovstat VALUE '3',
               c_movstat4 TYPE zmovstat VALUE '4',
               c_all(3)   TYPE c        VALUE 'All',
               c_qt(2)    TYPE c        VALUE 'QT',
               c_s(1)     TYPE c        VALUE 'S',
               c_p(1)     TYPE c        VALUE 'P',
               c_q(1)     TYPE c        VALUE 'Q'.

    COMMIT WORK.
    lo_container = me->mo_context->get_message_container( ).

    SELECT SINGLE vbeln,suser INTO (@gv_lifex, @gv_suser)
      FROM zfiori_ris_tmp
      WHERE compl = 'X'.

    SELECT SINGLE flag
      FROM zon_enhancement
      INTO @DATA(gv_flagenh)
      WHERE enhancement EQ 'ZENH_NML_DELTA'.

    IF gv_lifex IS INITIAL.

      lo_container->add_message(
               iv_msg_type          = 'S'
               iv_msg_id            = '00'
               iv_msg_number        = '208'
               iv_msg_v1            = 'Consegna respinta.'
               iv_is_leading_message     = abap_true
               iv_add_to_response_header = abap_true ).
    ELSE.

      CLEAR gs_zfiori_ris_tmp.
      SELECT * INTO TABLE gt_zfiori_ris_tmp
        FROM zfiori_ris_tmp
        WHERE vbeln = gv_lifex
        AND qta_rif NE 0.

      IF gv_flagenh EQ 'X'.
        READ TABLE gt_zfiori_ris_tmp INDEX 1 ASSIGNING FIELD-SYMBOL(<rowtmp>).
        IF sy-subrc IS INITIAL.

          CREATE OBJECT lobj_check_del.
          MOVE gv_lifex TO lv_checkvbeln.
          CALL METHOD lobj_check_del->zmm_type_del
            EXPORTING
              i_delivery = lv_checkvbeln
              i_process  = 'X'
            IMPORTING
              e_process  = lv_processo.

          IF lv_processo EQ 'OSYS' OR lv_processo EQ 'SSYS'.

            SELECT vgbel,
                    vgpos
              FROM lips
              INTO CORRESPONDING FIELDS OF TABLE @lt_lipstemp
              WHERE lips~vbeln EQ @gv_lifex.

            SELECT COUNT(*)
              INTO @DATA(lv_countmp)
              FROM ekpo
         JOIN zmm_mag_imp_cit AS mag ON ekpo~werks EQ mag~werks AND ekpo~lgort EQ mag~lgort
              FOR ALL ENTRIES IN @lt_lipstemp
        WHERE ekpo~ebeln EQ @lt_lipstemp-vgbel AND ekpo~ebelp EQ @lt_lipstemp-vgpos
          AND mag~znml EQ 'N'.
            REFRESH lt_lipstemp[].
          ELSE.
            SELECT COUNT(*)
              INTO @lv_countmp
              FROM likp
              JOIN lips ON likp~vbeln EQ lips~vbeln
              JOIN zmm_mag_imp_cit AS mag ON lips~werks EQ mag~werks AND lips~lgort EQ mag~lgort
             WHERE likp~vbeln EQ @gv_lifex
               AND mag~znml EQ 'N'.
          ENDIF.
          IF lv_countmp GT 0.

            CALL METHOD lobj_check_del->zmm_check_del
              EXPORTING
                i_delivery = lv_checkvbeln
*               i_posizione =
                i_azione   = 'EM'
                i_tipo     = 'F'
*               i_ruolo    =
              IMPORTING
                e_esito    = lv_esito
                e_descr    = lv_descrizione.
            IF lv_esito NE 'OK'.
              DELETE FROM zfiori_ris_tmp WHERE vbeln = gv_lifex.
              MOVE lv_descrizione TO lv_mess_desc.
              lo_container->add_message(
               iv_msg_type          = 'E'
               iv_msg_id            = '00'
               iv_msg_number        = '208'
               iv_msg_v1            = lv_mess_desc
               iv_is_leading_message     = abap_true
               iv_add_to_response_header = abap_true ).
              EXIT.
            ELSE.
              CLEAR: lv_esito,
                     lv_descrizione.
              CALL METHOD lobj_check_del->zmm_check_del
                EXPORTING
                  i_delivery = lv_checkvbeln
*                 i_posizione =
                  i_azione   = 'EM'
                  i_tipo     = 'V'
*                 i_ruolo    =
                IMPORTING
                  e_esito    = lv_esito
                  e_descr    = lv_descrizione.
              IF lv_esito NE 'OK'.
                DELETE FROM zfiori_ris_tmp WHERE vbeln = gv_lifex.
                MOVE lv_descrizione TO lv_mess_desc.
                lo_container->add_message(
                 iv_msg_type          = 'E'
                 iv_msg_id            = '00'
                 iv_msg_number        = '208'
                 iv_msg_v1            = lv_mess_desc
                 iv_is_leading_message     = abap_true
                 iv_add_to_response_header = abap_true ).
                EXIT.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
      CLEAR lv_countmp.

* GB Inizio modifiche vbeln relativo inbound
      READ TABLE gt_zfiori_ris_tmp TRANSPORTING NO FIELDS
                                       WITH KEY vbeln = gv_lifex.
      IF sy-subrc IS INITIAL.
        SELECT SINGLE vbeln
          FROM shp_idx_gdrc
          INTO gv_vbelnshp
          WHERE lifex EQ gv_lifex.

        IF sy-subrc IS NOT INITIAL.
          MOVE: gv_lifex TO gv_vbelnshp.
        ENDIF.
      ENDIF.
* GB Fine modifiche vbeln relativo inbound
      SELECT * INTO TABLE gt_zfiori_mag_qr_tmp
        FROM zfiori_ris_tmp
        WHERE vbeln = gv_lifex
*      AND qta_rif EQ 0                           "GP06/11
        AND flag = c_q.


* Recupero tabella per salvataggio storico
      SELECT * INTO TABLE gt_zfiori_ris_tmp_storic
            FROM zfiori_ris_tmp
            WHERE vbeln = gv_lifex.

      DELETE FROM zfiori_ris_tmp WHERE vbeln = gv_lifex.
      COMMIT WORK.

      DATA: ls_storico TYPE zfiori_mag_stori.



      "LM Start archiviazione consegne fase 2 06.03.2024
      DATA ls_mkpf TYPE zmm_mkpf_fields.
      FREE MEMORY ID 'ZFIELDS_MKPF'.
      "LM End archiviazione consegne fase 2 06.03.2024
      LOOP AT gt_zfiori_ris_tmp_storic ASSIGNING FIELD-SYMBOL(<history>).

        MOVE <history>-erfme   TO ls_storico-erfme.
        MOVE sy-datum          TO ls_storico-zdate.
        MOVE sy-uzeit          TO ls_storico-ztime.
        MOVE <history>-maktx   TO ls_storico-maktx.
        MOVE <history>-matnr   TO ls_storico-matnr.
        MOVE <history>-posnr   TO ls_storico-posnr.
        MOVE <history>-vbeln   TO ls_storico-vbeln.
        MOVE <history>-flag    TO ls_storico-gestione.
        MOVE <history>-lfimg   TO ls_storico-qta.
        MOVE <history>-xabln   TO ls_storico-xabln.
        MOVE <history>-charg   TO ls_storico-charg.
        MOVE <history>-qrsernr TO ls_storico-qrsernr.
        MOVE <history>-suser   TO ls_storico-utente.


        "LM Start archiviazione consegne fase 2 06.03.2024
        MOVE <history>-suser TO ls_mkpf-puser.
        EXPORT ls_mkpf FROM ls_mkpf TO MEMORY ID 'ZFIELDS_MKPF'.
        "LM End archiviazione consegne fase 2 06.03.2024


*     if <history>-FLAG eq 'QT'.
*
*       ELSEIF <history>-FLAG eq 'R'.
*         MOVE <history>-charg TO  ls_storico-
*         ELSEIF <history>-FLAG eq 'S'.
*           ELSEIF <history>-FLAG eq 'B'.
*             ENDIF.

        SELECT SINGLE lgort INTO ls_storico-lgort
              FROM lips
          JOIN vbfa
          ON vbfa~vbeln EQ lips~vbeln
              WHERE vbfa~vbelv EQ <history>-vbeln
              AND   vbfa~vbtyp_n EQ '7'.


        IF <history>-motivo IS INITIAL.
          MOVE 'ACCETTATO'         TO ls_storico-motivo_rett.
          MOVE <history>-qta_acc   TO ls_storico-qta_acc.
          MOVE <history>-qta_rif   TO ls_storico-qta_rif.
        ELSE.
          MOVE <history>-motivo    TO ls_storico-motivo_rett.
          MOVE <history>-qta_rif   TO ls_storico-qta_rif.
          MOVE  <history>-qta_acc  TO ls_storico-qta_acc.
        ENDIF.

        MODIFY zfiori_mag_stori FROM ls_storico.
        COMMIT WORK.

        CLEAR ls_storico.
      ENDLOOP.


**! gv_lifex = lifex, gv_ebeln = vbeln
      CLEAR gv_ebeln.
      SELECT SINGLE vbeln INTO gv_ebeln
        FROM shp_idx_gdrc
        WHERE lifex = gv_lifex.
      IF sy-subrc IS NOT INITIAL.
        MOVE: gv_lifex TO gv_ebeln.
      ENDIF.
*      IF sy-subrc EQ 0.

      SELECT SINGLE * INTO gs_outb02
        FROM zmm_ol_outb_02
        WHERE in_idnum = gv_lifex
        AND movstat = c_movstat3
        AND pickstat = abap_true.

      CLEAR gs_vbkok.
      gs_vbkok-vbeln_vl = gv_ebeln.
      gs_vbkok-vbeln = gv_ebeln.
      gs_vbkok-wabuc = abap_true.
      gs_vbkok-wadat_ist = sy-datum.
      gv_commit = abap_true.
      gv_delivery = gv_ebeln.

      CALL FUNCTION 'WS_DELIVERY_UPDATE_2'
        EXPORTING
          vbkok_wa = gs_vbkok
          synchron = gv_synchr
          commit   = gv_commit
          delivery = gv_delivery
        TABLES
          prot     = gt_prot.

      LOOP AT gt_prot INTO gs_prot WHERE msgty CA 'EA'.
        REFRESH gt_zfiori_ris_tmp.
        gv_symsgno = gs_prot-msgno.
        lo_container->add_message(
           iv_msg_type          = gs_prot-msgty
           iv_msg_id            = gs_prot-msgid
           iv_msg_number        = gv_symsgno
           iv_msg_v1            = gs_prot-msgv1
           iv_msg_v2            = gs_prot-msgv2
           iv_msg_v3            = gs_prot-msgv3
           iv_msg_v4            = gs_prot-msgv4
           iv_is_leading_message     = abap_true
           iv_add_to_response_header = abap_true ).

*popolo tabella di log su backend in caso di errori
        wa_log_bapi-mandt = sy-mandt.
        wa_log_bapi-in_idnum = gv_ebeln.
        MOVE gs_prot-msgno TO wa_log_bapi-znumber.
        MOVE gs_prot-msgid TO wa_log_bapi-id.
        MOVE gs_prot-msgty TO wa_log_bapi-type.
        MOVE gs_prot-msgv1 TO wa_log_bapi-message_v1.
        MOVE gs_prot-msgv2 TO wa_log_bapi-message_v2.
        MOVE gs_prot-msgv3 TO wa_log_bapi-message_v3.
        CALL FUNCTION 'BAPI_MESSAGE_GETDETAIL'
          EXPORTING
            id         = wa_log_bapi-id
            number     = wa_log_bapi-znumber
            language   = sy-langu
            textformat = 'NON'
            message_v1 = wa_log_bapi-message_v1
            message_v2 = wa_log_bapi-message_v2
            message_v3 = wa_log_bapi-message_v3
          IMPORTING
            message    = wa_log_bapi-message.
        wa_log_bapi-message_v4 = 'WS_DELIVERY_UPDATE per Fiori'.
        wa_log_bapi-datum = sy-datum.
        wa_log_bapi-uzeit = sy-uzeit.
        wa_log_bapi-nome_report = sy-repid.
        MODIFY zmm_log_bapi FROM wa_log_bapi.
        COMMIT WORK AND WAIT.
        EXIT.
        v = 1.
      ENDLOOP.
      IF sy-subrc NE 0.
        LOOP AT gt_zfiori_ris_tmp INTO gs_zfiori_mag_qr_tmp WHERE flag EQ 'Q'.

          CLEAR: gs_outb02, gs_zmm_ol_trackingq.

          SELECT SINGLE * INTO gs_zmm_ol_trackingq
              FROM zmm_ol_trackingq
              WHERE qr_code = gs_zfiori_mag_qr_tmp-qrsernr
              AND  in_sernr1 = gs_zfiori_mag_qr_tmp-charg.
          IF sy-subrc NE 0.
            gs_zmm_ol_trackingq-qr_code = gs_zfiori_mag_qr_tmp-qrsernr.
            gs_zmm_ol_trackingq-in_sernr1 = gs_zfiori_mag_qr_tmp-charg.
          ENDIF.

*          SELECT SINGLE * INTO gs_outb02
*            FROM zmm_ol_outb_02
*            WHERE out_bukrs = 'OF01'
*            AND in_idnum = gs_zfiori_mag_qr_tmp-vbeln    "gv_lifex
*            AND in_iditem = gs_zfiori_mag_qr_tmp-posnr.

          SELECT
          SINGLE lfart
            FROM likp
            INTO @DATA(lv_lfart)
           WHERE vbeln EQ @gs_zfiori_mag_qr_tmp-vbeln.

          IF lv_lfart EQ 'ZEL'.
            CLEAR gs_zmm_ol_trackingq.

            SELECT
            SINGLE vgbel,
                   vgpos,
                   lgort
              INTO (@gs_zmm_ol_trackingq-ponum,
                    @gs_zmm_ol_trackingq-poitem,
                    @gs_zmm_ol_trackingq-lgort)
              FROM lips
             WHERE vbeln EQ @gs_zfiori_mag_qr_tmp-vbeln
               AND posnr EQ @gs_zfiori_mag_qr_tmp-posnr.

            MOVE: gs_zfiori_mag_qr_tmp-vbeln TO gs_zmm_ol_trackingq-zin_idnum,
                 gs_zfiori_mag_qr_tmp-posnr TO gs_zmm_ol_trackingq-zin_iditem.

            SELECT
            SINGLE belnr,
                   buzei,
                   budat
              FROM ekbe
              INTO (@gs_zmm_ol_trackingq-belnr,
                    @gs_zmm_ol_trackingq-buzei,
                    @gs_zmm_ol_trackingq-budat)
             WHERE xblnr EQ @gs_zfiori_mag_qr_tmp-vbeln
               AND ebeln EQ @gs_zmm_ol_trackingq-ponum
               AND ebelp EQ @gs_zmm_ol_trackingq-poitem.

          ELSE.

            SELECT SINGLE ebeln,ebelp
              INTO  @DATA(gs_ekbe)
              FROM ekbe
              WHERE belnr EQ @gs_zfiori_mag_qr_tmp-vbeln
                AND buzei EQ @gs_zfiori_mag_qr_tmp-posnr.

            SELECT SINGLE vbeln_st AS vbeln belnr AS zzzbelnr buzei AS zzzbuzei budat AS zzzbudat
            INTO CORRESPONDING FIELDS OF gs_zmm_ol_trackingq
            FROM ekbe AS a
            WHERE ebeln = gs_ekbe-ebeln
            AND   ebelp = gs_ekbe-ebelp
            AND   xblnr = gs_zfiori_mag_qr_tmp-vbeln
            AND   bwart = '101'.

            SELECT SINGLE vbelp
              INTO gs_zmm_ol_trackingq-vbelp
              FROM ekes
              WHERE ebeln = gs_ekbe-ebeln
              AND ebelp = gs_ekbe-ebelp
              AND vbeln = gs_zmm_ol_trackingq-vbeln.

          ENDIF.

          IF gs_zmm_ol_trackingq-qr_code   IS NOT INITIAL AND
             gs_zmm_ol_trackingq-in_sernr1 IS NOT INITIAL.
            MODIFY zmm_ol_trackingq FROM gs_zmm_ol_trackingq.

          ENDIF.

        ENDLOOP.

        IF gs_outb02 IS NOT INITIAL AND gv_lifex NE gv_vbelnshp.
          UPDATE zmm_ol_outb_02 SET movstat = c_movstat4 WHERE in_idnum = gv_lifex.
        ENDIF.
        COMMIT WORK.

        READ TABLE gt_zfiori_ris_tmp INTO gs_zfiori_ris_tmp WITH KEY vbeln = gv_ebeln.

*************************************************
*INVIO EMAIL
        LOOP AT gt_zfiori_ris_tmp INTO gs_zfiori_ris_tmp. "sono quelle rifiutate
          CLEAR: lv_causale, lv_mtart.
          IF gs_zfiori_ris_tmp-motivo NE 'ACCETTAZ.RISERVA'.
            SELECT
            SINGLE lfart
              FROM likp
              INTO @DATA(lv_lfart_ca)
             WHERE vbeln EQ @gs_zfiori_ris_tmp-vbeln.

            SELECT SINGLE zid_causale INTO lv_causale
              FROM zfiori_causali
             WHERE descrizione = gs_zfiori_ris_tmp-motivo
               AND tipo_consegna = lv_lfart_ca.

            SELECT SINGLE mtart INTO lv_mtart
              FROM mara WHERE matnr = gs_zfiori_ris_tmp-matnr.

            IF lv_mtart NE 'ZABO' AND lv_mtart NE 'ZCDO'.
              SELECT
          SINGLE *
            FROM zmm_deliv_mat
            INTO @DATA(ls_deliv)
            WHERE matnr EQ @gs_zfiori_ris_tmp-matnr.
              IF sy-subrc IS INITIAL.
                CONCATENATE lv_mtart(3) 'O' INTO lv_mtart.
              ENDIF.
            ENDIF.

            SELECT SINGLE * INTO ls_zfiori_mail
              FROM zfiori_mail
              WHERE bukrs = 'OF01'
              AND werks = 'OF01'
              AND app_fiori = 'GR'
              AND zid_causale = lv_causale
              AND mtart = lv_mtart.

            COLLECT ls_zfiori_mail INTO lt_zfiori_mail.
            "LM Start Ticket#2023102099003089 24.10.2023
          ELSE.
            SELECT SINGLE mtart INTO lv_mtart
              FROM mara WHERE matnr = gs_zfiori_ris_tmp-matnr.
            "LM End Ticket#2023102099003089 24.10.2023

          ENDIF.
        ENDLOOP.
        IF lt_zfiori_mail IS NOT INITIAL. "gs_zfiori_ris_tmp-motivo eq 'ACCETTAZ.RISERVA'.
          IF lt_zfiori_mail[] IS NOT INITIAL.
            SELECT * INTO TABLE lt_zfiori_gruppi
              FROM zfiori_gruppi
              FOR ALL ENTRIES IN lt_zfiori_mail
              WHERE z_gruppo = lt_zfiori_mail-z_gruppo.
          ENDIF.
***estraggo le utenze cui inviare l'email dal set
*          CALL FUNCTION 'G_SET_GET_ID_FROM_NAME'
*            EXPORTING
*              shortname                = 'Z_USER_MAIL_FIORI'
*            IMPORTING
*              new_setid                = v_setid
*            EXCEPTIONS
*              no_set_found             = 1
*              no_set_picked_from_popup = 2
*              wrong_class              = 3
*              wrong_subclass           = 4
*              table_field_not_found    = 5
*              fields_dont_match        = 6
*              set_is_empty             = 7
*              formula_in_set           = 8
*              set_is_dynamic           = 9
*              OTHERS                   = 10.
*
*          IF sy-subrc EQ 0.
*
*            CALL FUNCTION 'G_SET_GET_ALL_VALUES'
*              EXPORTING
*                setnr         = v_setid
*              TABLES
*                set_values    = t_values
*              EXCEPTIONS
*                set_not_found = 1
*                OTHERS        = 2.
*          ENDIF.
*
*          LOOP AT t_values INTO w_values WHERE field = 'BNAME'.
          LOOP AT lt_zfiori_gruppi INTO ls_zfiori_gruppi.

*            SELECT SINGLE * FROM usr21 INTO lw_usr21 WHERE bname = w_values-from.
            SELECT SINGLE * FROM usr21 INTO lw_usr21 WHERE bname = ls_zfiori_gruppi-utente.
            IF sy-subrc = 0.
              SELECT SINGLE * FROM adr6  INTO lw_adr6
                         WHERE addrnumber = lw_usr21-addrnumber
                           AND persnumber = lw_usr21-persnumber.
              IF sy-subrc = 0.
                ls_mailrecipients-receiver = lw_adr6-smtp_addr.
              ENDIF.
* recipients
              ls_mailrecipients-rec_type  = 'U'.
              COLLECT ls_mailrecipients INTO lt_mailrecipients .
*              APPEND ls_mailrecipients TO lt_mailrecipients.
              CLEAR ls_mailrecipients .
            ENDIF.
          ENDLOOP.
* Subject.
          lt_mailsubject-obj_name = 'TEST'.
          lt_mailsubject-obj_langu = sy-langu.
          SELECT
          SINGLE lfart
            FROM likp
            INTO @DATA(lv_tipoconsegna)
           WHERE vbeln EQ @gv_ebeln.
          IF lv_tipoconsegna EQ 'ZEL'.
            CONCATENATE 'Notifica di Entrata Merci da Fiori - ' gv_ebeln INTO lt_mailsubject-obj_descr RESPECTING BLANKS.
          ELSE.
            lt_mailsubject-obj_descr = 'Notifica di Entrata Merci da Fiori'.
          ENDIF.
          CLEAR lv_tipoconsegna.
          CLEAR wa_tab.
          REFRESH it_tab.

          CALL FUNCTION 'READ_TEXT'
            EXPORTING
*             CLIENT                  = SY-MANDT
              id                      = 'ST'
              language                = 'I'
              name                    = 'ZMM_TESTOMAIL_NOTIFIC_EM'
              object                  = 'TEXT'
            TABLES
              lines                   = it_tab
            EXCEPTIONS
              id                      = 1
              language                = 2
              name                    = 3
              not_found               = 4
              object                  = 5
              reference_check         = 6
              wrong_access_to_archive = 7
              OTHERS                  = 8.
          IF sy-subrc <> 0.
* Implement suitable error handling here
          ENDIF.

** Mail Contents
          IF it_tab[] IS NOT INITIAL.

            LOOP AT it_tab INTO wa_tab.

              CLEAR ls_mailtxt.
              IF wa_tab-tdline CA 'X' OR wa_tab-tdline CA 'Y' OR wa_tab-tdline CA '$' OR wa_tab-tdline CO 'Z' OR wa_tab-tdline CA 'W'.
                CONCATENATE sy-datum+6(2)'/' sy-datum+4(2)'/' sy-datum+0(4) INTO lv_data.
                CONCATENATE sy-uzeit+0(2) ':' sy-uzeit+2(2) ':' sy-uzeit+4(2) INTO lv_ora.
                REPLACE ALL OCCURRENCES OF 'X' IN wa_tab-tdline WITH  lv_data.
                REPLACE ALL OCCURRENCES OF 'Y' IN wa_tab-tdline WITH  lv_ora.
                REPLACE ALL OCCURRENCES OF '$' IN wa_tab-tdline WITH  gv_suser.
                REPLACE ALL OCCURRENCES OF 'Z' IN wa_tab-tdline WITH  gv_lifex.
              ENDIF.
              MOVE wa_tab-tdline TO ls_mailtxt-line.
              APPEND ls_mailtxt TO lt_mailtxt.
            ENDLOOP.
          ENDIF.


          CLEAR ls_packing_list.
          ls_packing_list-head_start = 1.
          ls_packing_list-head_num = 0.
          ls_packing_list-body_start = 1.
          DESCRIBE TABLE lt_mailtxt LINES ls_packing_list-body_num.
          ls_packing_list-doc_type = 'RAW'.
          ls_packing_list-doc_size = ls_packing_list-body_num * 255.
          APPEND ls_packing_list TO lt_packing_list.

          IF lt_mailrecipients[] IS NOT INITIAL.
            CALL FUNCTION 'SO_DOCUMENT_SEND_API1'
              EXPORTING
                document_data              = lt_mailsubject
*               PUT_IN_OUTBOX              = ' '
                sender_address             = 'FIORI_NOTIF'
              TABLES
                packing_list               = lt_packing_list
                contents_txt               = lt_mailtxt
                receivers                  = lt_mailrecipients
              EXCEPTIONS
                too_many_receivers         = 1
                document_not_sent          = 2
                document_type_not_exist    = 3
                operation_no_authorization = 4
                parameter_error            = 5
                x_error                    = 6
                enqueue_error              = 7
                OTHERS                     = 8.
            IF sy-subrc <> 0.
*   Implement suitable error handling here
            ENDIF.
            IF sy-subrc EQ 0.
              COMMIT WORK.

*     Push mail out from SAP outbox
              SUBMIT rsconn01 WITH mode = 'INT' AND RETURN.
            ENDIF.
          ENDIF.
        ENDIF.
*******************************************

* GB Inserimento in tabella zfiori_mag_locl e BAPI solo in caso di successo FM
*        ENDIF.
*      ENDIF.
*    ELSE.
*      REFRESH gt_zfiori_ris_tmp.
*    ENDIF.


        CLEAR gs_zfiori_ris_tmp.

        LOOP AT gt_zfiori_ris_tmp INTO gs_zfiori_ris_tmp. "solo quelle con quantità rifiutata

          CLEAR gs_lips.
          SELECT SINGLE * INTO gs_lips
            FROM lips
            WHERE vbeln = gs_zfiori_ris_tmp-vbeln
            AND posnr = gs_zfiori_ris_tmp-posnr.

          CLEAR gs_zfiori_mag_user.
          SELECT SINGLE * INTO gs_zfiori_mag_user
            FROM zfiori_mag_user
          WHERE slgort = gs_lips-lgort
            AND swerks = gs_lips-werks.
** ZFIORI_MAG_LOCL
          CLEAR gs_charg.
          REFRESH gt_charg.
          IF gs_zfiori_ris_tmp-charg EQ c_all. "se sono tutte scartate le andiamo a prendere da tabella

            CASE gs_zfiori_ris_tmp-flag.
              WHEN c_s.

                SELECT objk~sernr AS charg
                INTO CORRESPONDING FIELDS OF TABLE gt_charg
                  FROM ser01
                  JOIN objk
                    ON ser01~obknr = objk~obknr
                WHERE ser01~lief_nr = gs_zfiori_ris_tmp-vbeln
                   AND ser01~bwart EQ '641'
                   AND ser01~posnr = gs_zfiori_ris_tmp-posnr.

                IF sy-subrc NE 0.
                  gs_charg-charg = space.
                  APPEND gs_charg TO gt_charg.
                ENDIF.

              WHEN c_p.

*                SELECT in_sernr1 AS charg in_batchqty AS qty  INTO CORRESPONDING FIELDS OF TABLE gt_charg
*                  FROM zmm_ol_ser_02
*                  WHERE out_bukrs = 'OF01' "gs_zfiori_mag_user-sbukrs RB
*                  AND out_werks = 'OF01' "gs_zfiori_mag_user-swerks RB
**                    AND out_lgort = gs_zfiori_mag_user-slgort        RB
*                  AND in_idnum = gs_zfiori_ris_tmp-vbeln
*                  AND in_iditem = gs_zfiori_ris_tmp-posnr
*                  AND in_matnr = gs_zfiori_ris_tmp-matnr.

                SELECT lips~charg AS charg lips~lfimg AS qty
                  INTO CORRESPONDING FIELDS OF TABLE gt_charg
                  FROM lips
                 WHERE lips~vbeln = gs_zfiori_ris_tmp-vbeln
                   AND lips~uecha = gs_zfiori_ris_tmp-posnr
                   AND lips~matnr = gs_zfiori_ris_tmp-matnr.

                IF sy-subrc NE 0.
                  gs_charg-charg = space.
                  APPEND gs_charg TO gt_charg.
                ENDIF.

              WHEN c_q.

*                  SELECT zqr_code AS charg INTO CORRESPONDING FIELDS OF TABLE gt_charg     "GP06/11
*                SELECT in_sernr1 AS charg zqr_code AS qrsernr INTO CORRESPONDING FIELDS OF TABLE gt_charg    "GP06/11
*                  FROM zmm_ol_ser_02
*                  WHERE out_bukrs = 'OF01' "gs_zfiori_mag_user-sbukrs RB
*                  AND out_werks = 'OF01' "gs_zfiori_mag_user-swerks   RB
**                    AND out_lgort = gs_zfiori_mag_user-slgort          RB
*                  AND in_idnum = gs_zfiori_ris_tmp-vbeln
*                  AND in_iditem = gs_zfiori_ris_tmp-posnr
*                  AND in_matnr = gs_zfiori_ris_tmp-matnr.

                SELECT objk~sernr AS charg zmm_ol_trackingq~qr_code AS qrsernr
                  INTO CORRESPONDING FIELDS OF TABLE gt_charg
                  FROM ser01
                  JOIN objk
                    ON ser01~obknr = objk~obknr
                  JOIN zmm_ol_trackingq
                    ON zmm_ol_trackingq~zou_iditem = ser01~posnr
                   AND zmm_ol_trackingq~zou_idnum = ser01~lief_nr
                   AND zmm_ol_trackingq~in_sernr1 = objk~sernr
                 WHERE ser01~lief_nr = gs_zfiori_ris_tmp-vbeln
                   AND ser01~bwart EQ '641'
                   AND ser01~posnr = gs_zfiori_ris_tmp-posnr.

                IF sy-subrc NE 0.
                  gs_charg-charg = space.
                  APPEND gs_charg TO gt_charg.
                ENDIF.

              WHEN c_qt.

                gs_charg-charg = space.
                APPEND gs_charg TO gt_charg.

            ENDCASE.
          ELSE.

            gs_charg-charg = gs_zfiori_ris_tmp-charg.
            gs_charg-qrsernr = gs_zfiori_ris_tmp-qrsernr.             "GP06/11
            gs_charg-qty   = gs_zfiori_ris_tmp-lfimg.
            APPEND gs_charg TO gt_charg.

          ENDIF.

          LOOP AT gt_charg INTO gs_charg.
            CLEAR gs_zfiori_mag_locl.
            gs_zfiori_mag_locl-vbeln = gs_zfiori_ris_tmp-vbeln.
            gs_zfiori_mag_locl-posnr = gs_zfiori_ris_tmp-posnr.
            gs_zfiori_mag_locl-matnr = gs_zfiori_ris_tmp-matnr.
            gs_zfiori_mag_locl-xabln = gs_zfiori_ris_tmp-xabln.
            gs_zfiori_mag_locl-charg = gs_charg-charg.                   "GP06/11
            IF gs_zfiori_ris_tmp-flag EQ c_q.
              gs_zfiori_mag_locl-qrsernr = gs_charg-qrsernr.             "GP06/11
*                gs_zfiori_mag_locl-qrsernr = gs_charg-charg.              "GP06/11
*                gs_zfiori_mag_locl-charg   = gs_zfiori_ris_tmp-qrsernr.   "GP06/11

*                gs_zfiori_mag_locl-qta_rif = gs_zfiori_ris_tmp-qta_rif.   "GP06/11
*              ELSEIF gs_zfiori_ris_tmp-flag EQ c_s.                       "GP06/11
*                gs_zfiori_mag_locl-charg   = gs_charg-charg.              "GP06/11
*                gs_zfiori_mag_locl-qta_rif = gs_zfiori_ris_tmp-qta_rif.   "GP06/11
*              ELSEIF gs_zfiori_ris_tmp-flag EQ c_p.                       "GP06/11
*                gs_zfiori_mag_locl-charg   = gs_charg-charg.              "GP06/11
*                gs_zfiori_mag_locl-qta_rif = gs_zfiori_ris_tmp-qta_rif.   "GP06/11
            ENDIF.
            gs_zfiori_mag_locl-maktx = gs_zfiori_ris_tmp-maktx.
            gs_zfiori_mag_locl-zdate = sy-datum.
            gs_zfiori_mag_locl-ztime = sy-uzeit.
            gs_zfiori_mag_locl-zuser = gs_zfiori_ris_tmp-suser.
            gs_zfiori_mag_locl-type = gs_zfiori_ris_tmp-flag.
            gs_zfiori_mag_locl-qta = gs_zfiori_ris_tmp-lfimg.
            gs_zfiori_mag_locl-qta_acc = gs_zfiori_ris_tmp-qta_acc.
            gs_zfiori_mag_locl-motivo_rett = gs_zfiori_ris_tmp-motivo.
            gs_zfiori_mag_locl-qta_rif = gs_zfiori_ris_tmp-qta_rif.
            gs_zfiori_mag_locl-erfme = gs_zfiori_ris_tmp-erfme.
            gs_zfiori_mag_locl-stato = '1'.
            IF gs_zfiori_ris_tmp-motivo EQ 'ACCETTAZ.RISERVA'.
              gs_zfiori_mag_locl-acc_ris = 'X'.
            ENDIF.

            SELECT SINGLE b~werks b~lgort "a~xabln
              INTO CORRESPONDING FIELDS OF gs_zfiori_mag_locl
              FROM likp AS a
              INNER JOIN lips AS b
                ON a~vbeln = b~vbeln
              WHERE a~vbeln = gv_vbelnshp
              AND b~posnr = gs_zfiori_ris_tmp-posnr.

            CLEAR gs_zmm_mag_imp_cit.
            SELECT SINGLE * INTO CORRESPONDING FIELDS OF gs_zmm_mag_imp_cit
              FROM zmm_mag_imp_cit
              WHERE werks = gs_zfiori_mag_locl-werks
              AND lgort = gs_zfiori_mag_locl-lgort.

            SELECT SINGLE comune INTO gs_zfiori_mag_locl-comune
              FROM zcomu
              WHERE codice = gs_zmm_mag_imp_cit-zcodice.
            gs_zfiori_mag_locl-impresa = gs_zmm_mag_imp_cit-zimpresa.

*           INIZIO MODIFICHE PER PARTITE DUMMY NML RR

            MOVE-CORRESPONDING gs_zfiori_mag_locl TO gs_zfiori_mag_locld. "SENZA NML QUESTA RIGA VA TENUTA
            gv_flagbatch = abap_false.
            IF gv_flagenh EQ 'X'.
              SELECT SINGLE znml
                FROM zmm_mag_imp_cit
                INTO @DATA(gv_flagnml)
                WHERE lgort EQ @gs_zfiori_mag_locld-lgort.

              IF gv_flagnml EQ 'N'.

                IF gs_zfiori_mag_locld-type EQ 'P'." AND gs_zfiori_mag_locld-motivo_rett NE 'RESPINTO' .

*MP Inizio modifiche - SAPECC22_PR57 - 09.01.2022

                  CALL FUNCTION 'G_SET_GET_ID_FROM_NAME'
                    EXPORTING
*                     CLIENT                   =
                      shortname                = 'ZMM_TIPODOC_AG'
*                     OLD_SETID                =
*                     TABNAME                  =
*                     FIELDNAME                =
*                     KOKRS                    =
*                     KTOPL                    =
*                     LIB                      =
*                     RNAME                    =
*                     SETCLASS                 =
*                     CHECK_SET_EMPTY          = ' '
*                     SUPRESS_POPUP            = ' '
*                     NO_DYNAMIC_SETS          = ' '
                    IMPORTING
                      new_setid                = w_setid
*                     SET_INFO                 =
* TABLES
*                     T_SETS                   =
                    EXCEPTIONS
                      no_set_found             = 1
                      no_set_picked_from_popup = 2
                      wrong_class              = 3
                      wrong_subclass           = 4
                      table_field_not_found    = 5
                      fields_dont_match        = 6
                      set_is_empty             = 7
                      formula_in_set           = 8
                      set_is_dynamic           = 9
                      OTHERS                   = 10.
                  IF sy-subrc <> 0.
* Implement suitable error handling here
                  ENDIF.

                  CALL FUNCTION 'G_SET_FETCH'
                    EXPORTING
*                     CLASS           = ' '
*                     LANGU           =
*                     NO_AUTHORITY_CHECK        = ' '
                      setnr           = w_setid
*                     SOURCE_CLIENT   =
*                     TABLE           = ' '
*                     NO_TITLES       = ' '
*                     NO_SETID_CONVERSION       = 'X'
* IMPORTING
*                     SET_HEADER      =
                    TABLES
*                     FORMULA_LINES   =
                      set_lines_basic = lt_set
*                     SET_LINES_DATA  =
*                     SET_LINES_MULTI =
*                     SET_LINES_SINGLE          =
                    EXCEPTIONS
                      no_authority    = 1
                      set_is_broken   = 2
                      set_not_found   = 3
                      OTHERS          = 4.
                  IF sy-subrc <> 0.
* Implement suitable error handling here
                  ENDIF.

                  IF lt_set[] IS NOT INITIAL.
                    LOOP AT lt_set ASSIGNING FIELD-SYMBOL(<set>).
                      CLEAR ra_tipo_mat.
                      ra_tipo_mat-sign = 'E'.
                      ra_tipo_mat-option = 'EQ'.
                      ra_tipo_mat-low = <set>-from.
                      APPEND ra_tipo_mat TO r_tipo_mat.
                    ENDLOOP.
                  ENDIF.

                  IF lv_mtart IN r_tipo_mat.

*                    SELECT SINGLE charg
*                      FROM znml_mov_stock
**                     into @data(gv_dummycharg)
*                      WHERE bwart EQ '101'

                    SELECT SINGLE charg
                      FROM znml_mov_stock
                      INTO @DATA(gv_dummycharg)
                      WHERE bwart EQ '101'
                      AND mtart IN @r_tipo_mat.
*MP Fine modifiche - SAPECC22_PR57 - 09.01.2022

                    gs_zfiori_mag_locld-charg_original = gs_zfiori_mag_locld-charg.  "MODIFICA 26/08 PER TENER TRACCIA DEL BATCH ORIGINALE


                    gs_zfiori_mag_locld-charg = gv_dummycharg.
                    gv_flagbatch = abap_true.
*                  SELECT SINGLE kcmeng
*                    FROM lips
*                    INTO @gs_zfiori_mag_locld-qta
*                    WHERE vbeln EQ @gs_zfiori_mag_locld-vbeln
*                    AND posnr EQ @gs_zfiori_mag_locld-posnr
*                    AND matnr EQ @gs_zfiori_mag_locld-matnr.
*
*                  SELECT SINGLE *
*                    FROM zfiori_mag_locl
*                    INTO @DATA(gs_rowlocl)
*                    WHERE vbeln EQ @gs_zfiori_mag_locld-vbeln
*                    AND posnr EQ @gs_zfiori_mag_locld-posnr
*                    AND matnr EQ @gs_zfiori_mag_locld-matnr
*                    AND charg EQ @gv_dummycharg
*                    AND motivo_rett EQ @gs_zfiori_mag_locld-motivo_rett.
*
*                  IF sy-subrc IS INITIAL.
*                    gs_zfiori_mag_locld-qta_rif = gs_zfiori_mag_locld-qta_rif + gs_rowlocl-qta_rif.
*                    CLEAR gs_rowlocl.
*                  ENDIF.
                    MODIFY zfiori_mag_locl FROM gs_zfiori_mag_locld.
                    COMMIT WORK.

*MP Inizio modifiche - SAPECC22_PR57 - 09.01.2022
                  ENDIF.
*MP Fine modifiche - SAPECC22_PR57 - 09.01.2022

*                  SELECT SUM( qta_rif )
*                    INTO @gv_qtarif
*                    FROM zfiori_mag_locl
*                    WHERE vbeln EQ @gs_zfiori_mag_locld-vbeln
*                    AND posnr EQ @gs_zfiori_mag_locld-posnr
*                    AND matnr EQ @gs_zfiori_mag_locld-matnr
*                    AND charg EQ @gv_dummycharg.
*
*                  SELECT *
*                    FROM zfiori_mag_locl
*                    INTO TABLE @DATA(gt_rowlocl)
*                    WHERE vbeln EQ @gs_zfiori_mag_locld-vbeln
*                    AND posnr EQ @gs_zfiori_mag_locld-posnr
*                    AND matnr EQ @gs_zfiori_mag_locld-matnr
*                    AND charg EQ @gv_dummycharg.
*
*                  LOOP AT gt_rowlocl ASSIGNING FIELD-SYMBOL(<rowlocl>).
*                    <rowlocl>-qta_acc = <rowlocl>-qta - gv_qtarif.
*                  ENDLOOP.
*                  IF gv_qtarif IS NOT INITIAL AND gt_rowlocl IS NOT INITIAL.
*                    MODIFY zfiori_mag_locl FROM TABLE gt_rowlocl.
*                    COMMIT WORK.
*                  ENDIF.

                  CLEAR: gv_dummycharg, gv_qtarif.
*                  CLEAR gt_rowlocl.
                ENDIF.
              ENDIF.
              CLEAR gv_flagnml.
            ENDIF.
            IF gv_flagbatch EQ abap_false.
*              MODIFICA RR 15/10
              IF gs_zfiori_mag_locld-type EQ 'P'.
                gs_zfiori_mag_locld-charg_original = gs_zfiori_mag_locld-charg.
              ENDIF.
*              FINE MODIFICA RR 15/10
              MODIFY zfiori_mag_locl FROM gs_zfiori_mag_locld.       "SENZA NML QUESTA RIGA VA TENUTA
            ENDIF.
            CLEAR gs_zfiori_mag_locld.
            gv_flagbatch = abap_false.
*            FINE MODIFICHE PER PARTITE DUMMY NML RR

          ENDLOOP.
        ENDLOOP.
        COMMIT WORK.
**QR CODE
        LOOP AT gt_zfiori_mag_qr_tmp INTO gs_zfiori_mag_qr_tmp.
*          IF gs_outb02 IS NOT INITIAL.
          CLEAR: gs_zmm_ol_trackingq, gs_lips.

          SELECT
          SINGLE lfart
            FROM likp
            INTO @lv_lfart
           WHERE vbeln EQ @gs_zfiori_mag_qr_tmp-vbeln.

          IF lv_lfart EQ 'ZEL'.
            CLEAR gs_zmm_ol_trackingq.

            SELECT SINGLE * INTO gs_zmm_ol_trackingq
              FROM zmm_ol_trackingq
              WHERE qr_code = gs_zfiori_mag_qr_tmp-qrsernr
              AND  in_sernr1 = gs_zfiori_mag_qr_tmp-charg.
            IF sy-subrc NE 0.
              gs_zmm_ol_trackingq-qr_code = gs_zfiori_mag_qr_tmp-qrsernr.
              gs_zmm_ol_trackingq-in_sernr1 = gs_zfiori_mag_qr_tmp-charg.
            ENDIF.

            SELECT
            SINGLE vgbel,
                   vgpos,
                   lgort
              INTO (@gs_zmm_ol_trackingq-ponum,
                    @gs_zmm_ol_trackingq-poitem,
                    @gs_zmm_ol_trackingq-lgort)
              FROM lips
             WHERE vbeln EQ @gs_zfiori_mag_qr_tmp-vbeln
               AND posnr EQ @gs_zfiori_mag_qr_tmp-posnr.

            MOVE: gs_zfiori_mag_qr_tmp-vbeln TO gs_zmm_ol_trackingq-zin_idnum,
                 gs_zfiori_mag_qr_tmp-posnr TO gs_zmm_ol_trackingq-zin_iditem.

            SELECT
            SINGLE belnr,
                   buzei,
                   budat
              FROM ekbe
              INTO (@gs_zmm_ol_trackingq-belnr,
                    @gs_zmm_ol_trackingq-buzei,
                    @gs_zmm_ol_trackingq-budat)
             WHERE xblnr EQ @gs_zfiori_mag_qr_tmp-vbeln
               AND ebeln EQ @gs_zmm_ol_trackingq-ponum
               AND ebelp EQ @gs_zmm_ol_trackingq-poitem.

          ELSE.


            SELECT SINGLE * INTO gs_lips
            FROM lips
            WHERE vbeln = gs_zfiori_mag_qr_tmp-vbeln
            AND posnr = gs_zfiori_mag_qr_tmp-posnr.

            SELECT SINGLE * INTO gs_zmm_ol_trackingq                           "GP06/11
            FROM zmm_ol_trackingq                                            "GP06/11
            WHERE qr_code = gs_zfiori_mag_qr_tmp-qrsernr                     "GP06/11
            AND  in_sernr1 = gs_zfiori_mag_qr_tmp-charg.                     "GP06/11
            IF sy-subrc NE 0.                                                  "GP06/11
              gs_zmm_ol_trackingq-qr_code = gs_zfiori_mag_qr_tmp-qrsernr.      "GP06/11
              gs_zmm_ol_trackingq-in_sernr1 = gs_zfiori_mag_qr_tmp-charg.      "GP06/11
*              gs_zmm_ol_trackingq-in_sernr1 = gs_zfiori_mag_qr_tmp-qrsernr.    "GP06/11
            ENDIF.                                                             "GP06/11

            SELECT SINGLE vbeln_st AS vbeln belnr AS zzzbelnr buzei AS zzzbuzei budat AS zzzbudat
            INTO CORRESPONDING FIELDS OF gs_zmm_ol_trackingq
            FROM ekbe AS a
            WHERE ebeln = gs_lips-vgbel
            AND ebelp   = gs_lips-vgpos
            AND xblnr = gs_zfiori_mag_qr_tmp-vbeln
            AND bwart = '101'.

            SELECT SINGLE vbelp
              INTO gs_zmm_ol_trackingq-vbelp
              FROM ekes
              WHERE ebeln = gs_lips-vgbel
              AND ebelp   = gs_lips-vgpos
              AND vbeln = gs_zmm_ol_trackingq-vbeln.
          ENDIF.

          IF gs_zmm_ol_trackingq-qr_code   IS NOT INITIAL AND
             gs_zmm_ol_trackingq-in_sernr1 IS NOT INITIAL.
            MODIFY zmm_ol_trackingq FROM gs_zmm_ol_trackingq.

          ENDIF.
*          ENDIF.
        ENDLOOP.
**BAPI
        CLEAR: gs_header, gs_code, gs_item, gs_sernr, gs_return.
        CLEAR: gt_item[], gt_item2[], gt_sernr[], gt_sernr2[], gt_return[].
        gs_header-pstng_date = sy-datum.
        gs_header-doc_date = sy-datum.
        gs_header-ref_doc_no = gs_zfiori_mag_locl-vbeln.
        gs_header-gr_gi_slip_no = gs_zfiori_mag_locl-xabln.
        gs_code  = '04'.

        CLEAR gs_zfiori_mag_locl.
        CLEAR i.
        SELECT * INTO CORRESPONDING FIELDS OF TABLE gt_tabella" gt_zfiori_mag_locl
        FROM zfiori_mag_locl
        WHERE vbeln = gv_lifex
        ORDER BY vbeln posnr matnr.


        LOOP AT gt_tabella ASSIGNING FIELD-SYMBOL(<asterischi>).

          MOVE-CORRESPONDING <asterischi> TO  gs_zfiori_mag_locl.

          lv_qty = lv_qty + 1.


          IF gs_zfiori_mag_locl-type EQ 'P'.

            gs_item-material = gs_zfiori_mag_locl-matnr.
            gs_item-plant    = gs_zfiori_mag_locl-werks.
            gs_item-stge_loc = gs_zfiori_mag_locl-lgort.
            gs_item-batch    = gs_zfiori_mag_locl-charg.

            IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.
              gs_item-move_type  = '322'.
            ELSE.
              gs_item-move_type  = '344'.
            ENDIF.


            CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'             "GP06/11
              EXPORTING                                             "GP06/11
                input          = gs_zfiori_mag_locl-erfme     "GP06/11
                language       = lv_langu                     "GP06/11
              IMPORTING                                             "GP06/11
                output         = gs_item-entry_uom            "GP06/11
              EXCEPTIONS                                            "GP06/11
                unit_not_found = 1                            "GP06/11
                OTHERS         = 2.

            IF sy-subrc = 1.                                        "GP06/11
              gs_item-entry_uom = gs_zfiori_mag_locl-erfme.         "GP06/11
            ENDIF.


            CONCATENATE gs_zfiori_mag_locl-vbeln gs_zfiori_mag_locl-posnr INTO gs_item-item_text.


            MOVE gs_zfiori_mag_locl-qta_rif TO gs_item-entry_qnt.


            IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.

              APPEND gs_item TO gt_item2.

            ELSE.

              APPEND gs_item TO gt_item.

            ENDIF.

          ENDIF.

          IF gs_zfiori_mag_locl-type EQ 'QT'.

            gs_item-material = gs_zfiori_mag_locl-matnr.
            gs_item-plant    = gs_zfiori_mag_locl-werks.
            gs_item-stge_loc = gs_zfiori_mag_locl-lgort.
*            gs_item-batch    = gs_zfiori_mag_locl-charg.

            IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.
              gs_item-move_type  = '322'.
            ELSE.
              gs_item-move_type  = '344'.
            ENDIF.

            gs_item-entry_qnt  = gs_zfiori_mag_locl-qta_rif.


            CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'             "GP06/11
              EXPORTING                                             "GP06/11
                input          = gs_zfiori_mag_locl-erfme     "GP06/11
                language       = lv_langu                     "GP06/11
              IMPORTING                                             "GP06/11
                output         = gs_item-entry_uom            "GP06/11
              EXCEPTIONS                                            "GP06/11
                unit_not_found = 1                            "GP06/11
                OTHERS         = 2.

            IF sy-subrc = 1.                                        "GP06/11
              gs_item-entry_uom = gs_zfiori_mag_locl-erfme.         "GP06/11
            ENDIF.


            CONCATENATE gs_zfiori_mag_locl-vbeln gs_zfiori_mag_locl-posnr INTO gs_item-item_text.


            MOVE gs_zfiori_mag_locl-qta_rif TO gs_item-entry_qnt.


            IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.

              APPEND gs_item TO gt_item2.

            ELSE.

              APPEND gs_item TO gt_item.

            ENDIF.

          ENDIF.

          AT END OF matnr.


            i = i + 1.
*          ENDAT.



            gs_item-material = gs_zfiori_mag_locl-matnr.
            gs_item-plant  = gs_zfiori_mag_locl-werks.
            gs_item-stge_loc = gs_zfiori_mag_locl-lgort.
            IF gs_zfiori_mag_locl-type = c_p.
              gs_item-batch = gs_zfiori_mag_locl-charg.
            ELSE.
              CLEAR gs_item-batch.
            ENDIF.
            IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.
              gs_item-move_type  = '322'.
            ELSE.
              gs_item-move_type  = '344'.
            ENDIF.

            IF gs_zfiori_mag_locl-type =  'Q' OR gs_zfiori_mag_locl-type = 'S'.
              gs_item-entry_qnt = lv_qty.
            ELSE.
              gs_item-entry_qnt  = gs_zfiori_mag_locl-qta_rif.
            ENDIF.

            LOOP AT gt_tabella ASSIGNING
                            FIELD-SYMBOL(<sumqty>)
                                  WHERE werks = gs_zfiori_mag_locl-werks
                                    AND lgort = gs_zfiori_mag_locl-lgort
                                    AND matnr = gs_zfiori_mag_locl-matnr
                                    AND posnr = gs_zfiori_mag_locl-posnr "RR R&G 01/07/2020
                                    AND  ( type = 'Q' OR type = 'S' ).

              IF <sumqty>-motivo_rett EQ 'ACCETTAZ.RISERVA'.
                lv_qty_accris = lv_qty_accris + 1.
              ELSE.
                lv_qty_block = lv_qty_block + 1.
              ENDIF.

            ENDLOOP.

            lv_qty = 0.

            CALL FUNCTION 'CONVERSION_EXIT_CUNIT_INPUT'             "GP06/11
              EXPORTING                                             "GP06/11
                input          = gs_zfiori_mag_locl-erfme     "GP06/11
                language       = lv_langu                     "GP06/11
              IMPORTING                                             "GP06/11
                output         = gs_item-entry_uom            "GP06/11
              EXCEPTIONS                                            "GP06/11
                unit_not_found = 1                            "GP06/11
                OTHERS         = 2                            "GP06/11
              .                                             "GP06/11
            IF sy-subrc = 1.                                        "GP06/11
              gs_item-entry_uom = gs_zfiori_mag_locl-erfme.         "GP06/11
            ENDIF.                                                  "GP06/11
*            gs_item-entry_uom  = gs_zfiori_mag_locl-erfme.         "GP06/11
*gs_item-MVT_IND = space.
            CONCATENATE gs_zfiori_mag_locl-vbeln gs_zfiori_mag_locl-posnr INTO gs_item-item_text.

            IF gs_zfiori_mag_locl-type NE 'P'.

              IF lv_qty_accris GT 0.
                MOVE: lv_qty_accris TO gs_item-entry_qnt.
                MOVE: '322'         TO gs_item-move_type.
                APPEND gs_item TO gt_item2.
              ENDIF.

              IF lv_qty_block GT 0.
                MOVE: lv_qty_block TO gs_item-entry_qnt.
                MOVE: '344'        TO gs_item-move_type.
                APPEND gs_item TO gt_item.
              ENDIF.

              lv_qty_accris = 0.
              lv_qty_block  = 0.


*              IF gs_zfiori_mag_locl-type EQ 'QT'.
*
*                IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.
*
*                  APPEND gs_item TO gt_item2.
*
*                ELSE.
*
*                  APPEND gs_item TO gt_item.
*
*                ENDIF.
*
*              ENDIF.
*              IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.
*
*                APPEND gs_item TO gt_item2.
*
*              ELSE.
*
*                APPEND gs_item TO gt_item.
*
*              ENDIF.

            ENDIF.


          ENDAT.


          IF gs_zfiori_mag_locl-motivo_rett EQ 'ACCETTAZ.RISERVA'.




            IF gs_zfiori_mag_locl-type EQ c_s.

              DESCRIBE TABLE gt_item2 LINES DATA(lv_tfill2).
              lv_tfill2 = lv_tfill2 + 1.


              AT END OF matnr.
                DESCRIBE TABLE gt_item2 LINES lv_tfill2.
              ENDAT.

              gs_sernr-matdoc_itm = lv_tfill2.
              gs_sernr-serialno = gs_zfiori_mag_locl-charg.
              APPEND gs_sernr TO gt_sernr2.
            ELSEIF gs_zfiori_mag_locl-type EQ c_q.
              DESCRIBE TABLE gt_item2 LINES lv_tfill2.
              lv_tfill2 = lv_tfill2 + 1.
              AT END OF matnr.
                DESCRIBE TABLE gt_item2 LINES lv_tfill2.
              ENDAT.
              gs_sernr-matdoc_itm = lv_tfill2.
              gs_sernr-serialno = gs_zfiori_mag_locl-charg.
              APPEND gs_sernr TO gt_sernr2.
            ENDIF.
            CLEAR gs_sernr.


          ELSE.




            IF gs_zfiori_mag_locl-type EQ c_s.
              DESCRIBE TABLE gt_item LINES DATA(lv_tfill).
              lv_tfill = lv_tfill + 1.

              AT END OF matnr.
                DESCRIBE TABLE gt_item LINES lv_tfill.
              ENDAT.
              gs_sernr-matdoc_itm = lv_tfill.
              gs_sernr-serialno = gs_zfiori_mag_locl-charg.
              APPEND gs_sernr TO gt_sernr.
            ELSEIF gs_zfiori_mag_locl-type EQ c_q.
              DESCRIBE TABLE gt_item LINES lv_tfill.
              lv_tfill = lv_tfill + 1.
              AT END OF matnr.
                DESCRIBE TABLE gt_item LINES lv_tfill.
              ENDAT.
              gs_sernr-matdoc_itm = lv_tfill.
              gs_sernr-serialno = gs_zfiori_mag_locl-charg.
              APPEND gs_sernr TO gt_sernr.
            ENDIF.
            CLEAR gs_sernr.

          ENDIF.


        ENDLOOP.

        COMMIT WORK AND WAIT.
        WAIT UP TO 1 SECONDS.

        IF gt_item IS NOT INITIAL. "almeno una posizione rifiutata
          CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
            EXPORTING
              goodsmvt_header       = gs_header
              goodsmvt_code         = gs_code
            TABLES
              goodsmvt_item         = gt_item
              goodsmvt_serialnumber = gt_sernr
              return                = gt_return.

*FG - Start
          IF gt_return[] IS NOT INITIAL.
            LOOP AT gt_return INTO gs_return WHERE type CA 'EA'.
              MOVE-CORRESPONDING gs_return TO wa_log_bapi.
              wa_log_bapi-mandt = sy-mandt.
              wa_log_bapi-in_idnum = gv_ebeln.
*                wa_log_bapi-in_iditem = tb_rec_corretti-in_iditem.
              MOVE gs_return-number TO wa_log_bapi-znumber.
              "messaggio errore a fiori
              lo_container->add_message(
            iv_msg_type          = gs_prot-msgty
            iv_msg_id            = wa_log_bapi-id
            iv_msg_number        = wa_log_bapi-znumber
            iv_msg_v1            = wa_log_bapi-message_v1
            iv_msg_v2            = wa_log_bapi-message_v2
            iv_msg_v3            = wa_log_bapi-message_v3
            iv_msg_v4            = 'BAPI_GOODSMVT_CREATE per Fiori'
            iv_is_leading_message     = abap_true
            iv_add_to_response_header = abap_true ).

*popolo tabella di log su backend in caso di errori
              CALL FUNCTION 'BAPI_MESSAGE_GETDETAIL'
                EXPORTING
                  id         = wa_log_bapi-id
                  number     = wa_log_bapi-znumber
                  language   = sy-langu
                  textformat = 'NON'
                  message_v1 = wa_log_bapi-message_v1
                  message_v2 = wa_log_bapi-message_v2
                  message_v3 = wa_log_bapi-message_v3
                IMPORTING
                  message    = wa_log_bapi-message.

              wa_log_bapi-message_v4 = 'BAPI_GOODSMVT_CREATE per Fiori'.
              wa_log_bapi-datum = sy-datum.
              wa_log_bapi-uzeit = sy-uzeit.
              wa_log_bapi-nome_report = sy-repid.
              MODIFY zmm_log_bapi FROM wa_log_bapi.
              COMMIT WORK.
              v = 1.
            ENDLOOP.

          ELSE.
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                wait = 'X'.
*GB In caso di esito positivo aggiornare stato=2
*            ENDIF.  "GB
*FG - End
*            IF sy-subrc NE 0. "GB
            UPDATE zfiori_mag_locl SET stato = '2' WHERE vbeln = gv_lifex.


          ENDIF.
        ENDIF.

        CLEAR: gt_return[],gs_return.

        IF gt_item2 IS NOT INITIAL..
          CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
            EXPORTING
              goodsmvt_header       = gs_header
              goodsmvt_code         = gs_code
            TABLES
              goodsmvt_item         = gt_item2
              goodsmvt_serialnumber = gt_sernr2
              return                = gt_return.

*FG - Start
          IF gt_return[] IS NOT INITIAL.
            LOOP AT gt_return INTO gs_return WHERE type CA 'EA'.
              MOVE-CORRESPONDING gs_return TO wa_log_bapi.
              wa_log_bapi-mandt = sy-mandt.
              wa_log_bapi-in_idnum = gv_ebeln.
*                wa_log_bapi-in_iditem = tb_rec_corretti-in_iditem.
              MOVE gs_return-number TO wa_log_bapi-znumber.
              "messaggio errore a fiori
              lo_container->add_message(
            iv_msg_type          = gs_prot-msgty
            iv_msg_id            = wa_log_bapi-id
            iv_msg_number        = wa_log_bapi-znumber
            iv_msg_v1            = wa_log_bapi-message_v1
            iv_msg_v2            = wa_log_bapi-message_v2
            iv_msg_v3            = wa_log_bapi-message_v3
            iv_msg_v4            = 'BAPI_GOODSMVT_CREATE per Fiori'
            iv_is_leading_message     = abap_true
            iv_add_to_response_header = abap_true ).

*popolo tabella di log su backend in caso di errori
              CALL FUNCTION 'BAPI_MESSAGE_GETDETAIL'
                EXPORTING
                  id         = wa_log_bapi-id
                  number     = wa_log_bapi-znumber
                  language   = sy-langu
                  textformat = 'NON'
                  message_v1 = wa_log_bapi-message_v1
                  message_v2 = wa_log_bapi-message_v2
                  message_v3 = wa_log_bapi-message_v3
                IMPORTING
                  message    = wa_log_bapi-message.

              wa_log_bapi-message_v4 = 'BAPI_GOODSMVT_CREATE per Fiori'.
              wa_log_bapi-datum = sy-datum.
              wa_log_bapi-uzeit = sy-uzeit.
              wa_log_bapi-nome_report = sy-repid.
              MODIFY zmm_log_bapi FROM wa_log_bapi.
              COMMIT WORK.
              v = 1.
            ENDLOOP.

          ELSE.
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                wait = 'X'.
*GB In caso di esito positivo aggiornare stato=2
*            ENDIF.  "GB
*FG - End
*            IF sy-subrc NE 0. "GB
            UPDATE zfiori_mag_locl SET stato = '2' WHERE vbeln = gv_lifex.


          ENDIF.
          IF v EQ 0.
            lo_container->add_message(
           iv_msg_type          = 'S'
           iv_msg_id            = 'ZMM'
           iv_msg_number        = 039
           iv_msg_v1            = ''
           iv_is_leading_message     = abap_true
           iv_add_to_response_header = abap_true ).
          ENDIF.
        ENDIF.

*    GB
      ENDIF.
*      ELSE.
*        REFRESH gt_zfiori_ris_tmp.
*      ENDIF.


    ENDIF.

    DELETE FROM zfiori_ris_tmp WHERE vbeln = gv_lifex.
    COMMIT WORK.

  ENDMETHOD.
