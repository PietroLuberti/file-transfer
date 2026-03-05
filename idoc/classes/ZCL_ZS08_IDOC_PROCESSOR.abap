*----------------------------------------------------------------------*
* Class: ZCL_ZS08_IDOC_PROCESSOR
* ZS08 - Payment Disposition IDoc inbound processor
* Target: SAP ERP 6.0 EHP7 (ECC) - classic ABAP style (no HANA-specific)
*----------------------------------------------------------------------*
CLASS zcl_zs08_idoc_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_seg_t,
             id_dp        TYPE c LENGTH 10,
             oggetto_pag  TYPE c LENGTH 50,
             grant_nbr    TYPE c LENGTH 20,
             cod_cup      TYPE c LENGTH 15,
             clp          TYPE c LENGTH 80,
             zdescrizione TYPE c LENGTH 1000,
             zimp_tot     TYPE p LENGTH 9 DECIMALS 2,
           END OF ty_seg_t.

    TYPES: BEGIN OF ty_seg_link,
             link_sf TYPE c LENGTH 1000,
           END OF ty_seg_link.

    TYPES: BEGIN OF ty_seg_msg,
             type       TYPE c LENGTH 1,
             id         TYPE c LENGTH 20,
             number     TYPE n LENGTH 3,
             message    TYPE c LENGTH 220,
             message_v1 TYPE c LENGTH 50,
             message_v2 TYPE c LENGTH 50,
             message_v3 TYPE c LENGTH 50,
             message_v4 TYPE c LENGTH 50,
           END OF ty_seg_msg.

    TYPES: BEGIN OF ty_seg_d,
             taxnum            TYPE c LENGTH 16,
             cod_bp_sf         TYPE c LENGTH 10,
             iban              TYPE c LENGTH 34,
             numero_tes        TYPE c LENGTH 15,
             cig               TYPE c LENGTH 30,
             nota_dest         TYPE c LENGTH 1000,
             importo           TYPE p LENGTH 9 DECIMALS 2,
             codice_gestionale TYPE c LENGTH 10,
             zflag             TYPE c LENGTH 1,
           END OF ty_seg_d.

    TYPES: BEGIN OF ty_seg_trib,
             cod_tributo       TYPE c LENGTH 10,
             chiave_banca      TYPE c LENGTH 15,
             codice_gestionale TYPE c LENGTH 10,
             trib_pag          TYPE p LENGTH 9 DECIMALS 2,
           END OF ty_seg_trib.

    TYPES: BEGIN OF ty_seg_sic,
             id_fattura  TYPE c LENGTH 20,
             data_pag    TYPE d,
             num_fattura TYPE c LENGTH 40,
             importo     TYPE p LENGTH 9 DECIMALS 2,
           END OF ty_seg_sic.

    TYPES: BEGIN OF ty_seg_sictrib,
             cod_tributo       TYPE c LENGTH 10,
             chiave_banca      TYPE c LENGTH 15,
             codice_gestionale TYPE c LENGTH 10,
             trib_pag          TYPE p LENGTH 9 DECIMALS 2,
           END OF ty_seg_sictrib.

    TYPES: BEGIN OF ty_recipient,
             seg_d        TYPE ty_seg_d,
             msg_d        TYPE STANDARD TABLE OF ty_seg_msg WITH DEFAULT KEY,
             tributes     TYPE STANDARD TABLE OF ty_seg_trib WITH DEFAULT KEY,
             sicoge_docs  TYPE STANDARD TABLE OF ty_seg_sic WITH DEFAULT KEY,
             sicoge_tribs TYPE STANDARD TABLE OF ty_seg_sictrib WITH DEFAULT KEY,
           END OF ty_recipient.

    TYPES: BEGIN OF ty_idoc_payload,
             header     TYPE ty_seg_t,
             link       TYPE ty_seg_link,
             msgs_hdr   TYPE STANDARD TABLE OF ty_seg_msg WITH DEFAULT KEY,
             recipients TYPE STANDARD TABLE OF ty_recipient WITH DEFAULT KEY,
           END OF ty_idoc_payload.

    METHODS process_inbound
      IMPORTING
        iv_idoc_number TYPE edi_docnum
      RAISING
        zcx_zs08_idoc_error.

    METHODS parse_idoc_segments
      IMPORTING
        it_edidd TYPE edidd_tab
      EXPORTING
        es_payload TYPE ty_idoc_payload
      RAISING
        zcx_zs08_idoc_error.

  PRIVATE SECTION.

    CONSTANTS gc_segnam_t       TYPE edilsegtyp VALUE 'ZPRDISPSF_T'.
    CONSTANTS gc_segnam_link    TYPE edilsegtyp VALUE 'ZPRDISPSF_LINK'.
    CONSTANTS gc_segnam_msg     TYPE edilsegtyp VALUE 'ZPRDISPSF_MSG'.
    CONSTANTS gc_segnam_d       TYPE edilsegtyp VALUE 'ZPRDISPSF_D'.
    CONSTANTS gc_segnam_trib    TYPE edilsegtyp VALUE 'ZPRDISPSF_TRIB'.
    CONSTANTS gc_segnam_sic     TYPE edilsegtyp VALUE 'ZPRDISPSF_SIC'.
    CONSTANTS gc_segnam_sictrib TYPE edilsegtyp VALUE 'ZPRDISPSF_SICTRIB'.

    METHODS check_authority
      RAISING zcx_zs08_idoc_error.

    METHODS validate_header
      IMPORTING
        is_header TYPE ty_seg_t
      CHANGING
        ct_messages TYPE bapiret2_t
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

    METHODS read_idoc_data
      IMPORTING
        iv_idoc_number TYPE edi_docnum
      EXPORTING
        es_edidc TYPE edidc
        et_edidd TYPE edidd_tab
      RAISING
        zcx_zs08_idoc_error.

    METHODS create_payment_disposition
      IMPORTING
        is_payload TYPE ty_idoc_payload
      EXPORTING
        ev_dp_number TYPE c
        et_return TYPE bapiret2_t.

    METHODS update_idoc_status
      IMPORTING
        iv_idoc_number TYPE edi_docnum
        iv_status TYPE edi_status
        iv_message TYPE c.

    METHODS trigger_outbound_idoc
      IMPORTING
        is_payload TYPE ty_idoc_payload
        iv_dp_number TYPE c
        it_return TYPE bapiret2_t.

    METHODS map_bapiret2_to_msg
      IMPORTING
        is_bapiret2 TYPE bapiret2
      RETURNING
        VALUE(rs_msg) TYPE ty_seg_msg.

    METHODS has_errors
      IMPORTING
        it_return TYPE bapiret2_t
      RETURNING
        VALUE(rv_error) TYPE abap_bool.

ENDCLASS.

CLASS zcl_zs08_idoc_processor IMPLEMENTATION.

  METHOD process_inbound.
    DATA: ls_edidc   TYPE edidc,
          lt_edidd   TYPE edidd_tab,
          ls_payload TYPE ty_idoc_payload,
          lt_return  TYPE bapiret2_t,
          lv_valid   TYPE abap_bool,
          lv_dp_num  TYPE c LENGTH 20.

    me->check_authority( ).

    me->read_idoc_data(
      EXPORTING
        iv_idoc_number = iv_idoc_number
      IMPORTING
        es_edidc       = ls_edidc
        et_edidd       = lt_edidd ).

    me->parse_idoc_segments(
      EXPORTING
        it_edidd   = lt_edidd
      IMPORTING
        es_payload = ls_payload ).

    lv_valid = me->validate_header(
                 EXPORTING
                   is_header   = ls_payload-header
                 CHANGING
                   ct_messages = lt_return ).

    IF lv_valid = abap_false.
      me->update_idoc_status(
        EXPORTING
          iv_idoc_number = iv_idoc_number
          iv_status      = '51'
          iv_message     = 'Header validation failed' ).

      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>validation_failed
          docnum = iv_idoc_number.
    ENDIF.

    me->create_payment_disposition(
      EXPORTING
        is_payload   = ls_payload
      IMPORTING
        ev_dp_number = lv_dp_num
        et_return    = lt_return ).

    IF me->has_errors( lt_return ) = abap_true.
      me->update_idoc_status(
        EXPORTING
          iv_idoc_number = iv_idoc_number
          iv_status      = '51'
          iv_message     = 'Error during DP creation' ).

      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>dp_creation_failed
          docnum = iv_idoc_number.
    ENDIF.

    ls_payload-link-link_sf = lv_dp_num.

    me->trigger_outbound_idoc(
      EXPORTING
        is_payload   = ls_payload
        iv_dp_number = lv_dp_num
        it_return    = lt_return ).

    me->update_idoc_status(
      EXPORTING
        iv_idoc_number = iv_idoc_number
        iv_status      = '53'
        iv_message     = 'Payment disposition created successfully' ).

    COMMIT WORK AND WAIT.

  ENDMETHOD.

  METHOD check_authority.
    AUTHORITY-CHECK OBJECT 'Z_ZS08_DP'
      ID 'ACTVT' FIELD '01'.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>no_authority.
    ENDIF.
  ENDMETHOD.

  METHOD read_idoc_data.
    CLEAR: es_edidc.
    REFRESH: et_edidd.

    SELECT SINGLE *
      FROM edidc
      INTO es_edidc
      WHERE docnum = iv_idoc_number.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>idoc_not_found
          docnum = iv_idoc_number.
    ENDIF.

    SELECT *
      FROM edidd
      INTO TABLE et_edidd
      WHERE docnum = iv_idoc_number
      ORDER BY segnum.

    IF sy-subrc <> 0 OR et_edidd IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>no_segments
          docnum = iv_idoc_number.
    ENDIF.
  ENDMETHOD.

  METHOD parse_idoc_segments.
    DATA: ls_seg_t       TYPE ty_seg_t,
          ls_seg_link    TYPE ty_seg_link,
          ls_seg_msg     TYPE ty_seg_msg,
          ls_seg_d       TYPE ty_seg_d,
          ls_seg_trib    TYPE ty_seg_trib,
          ls_seg_sic     TYPE ty_seg_sic,
          ls_seg_sictrib TYPE ty_seg_sictrib,
          ls_recipient   TYPE ty_recipient,
          lv_in_recip    TYPE abap_bool,
          lv_in_sic      TYPE abap_bool.

    CLEAR es_payload.
    lv_in_recip = abap_false.
    lv_in_sic   = abap_false.

    LOOP AT it_edidd INTO DATA(ls_edidd).
      CASE ls_edidd-segnam.
        WHEN gc_segnam_t.
          ls_seg_t = ls_edidd-sdata.
          es_payload-header = ls_seg_t.
          lv_in_recip = abap_false.
          lv_in_sic   = abap_false.

        WHEN gc_segnam_link.
          ls_seg_link = ls_edidd-sdata.
          es_payload-link = ls_seg_link.

        WHEN gc_segnam_msg.
          ls_seg_msg = ls_edidd-sdata.
          IF lv_in_recip = abap_true.
            APPEND ls_seg_msg TO ls_recipient-msg_d.
          ELSE.
            APPEND ls_seg_msg TO es_payload-msgs_hdr.
          ENDIF.

        WHEN gc_segnam_d.
          IF lv_in_recip = abap_true.
            APPEND ls_recipient TO es_payload-recipients.
            CLEAR ls_recipient.
          ENDIF.
          ls_seg_d = ls_edidd-sdata.
          ls_recipient-seg_d = ls_seg_d.
          lv_in_recip = abap_true;
          lv_in_sic   = abap_false.

        WHEN gc_segnam_trib.
          ls_seg_trib = ls_edidd-sdata.
          IF lv_in_recip = abap_true.
            APPEND ls_seg_trib TO ls_recipient-tributes.
          ENDIF.
          lv_in_sic = abap_false.

        WHEN gc_segnam_sic.
          ls_seg_sic = ls_edidd-sdata.
          IF lv_in_recip = abap_true.
            APPEND ls_seg_sic TO ls_recipient-sicoge_docs.
          ENDIF.
          lv_in_sic = abap_true.

        WHEN gc_segnam_sictrib.
          ls_seg_sictrib = ls_edidd-sdata.
          IF lv_in_recip = abap_true AND lv_in_sic = abap_true.
            APPEND ls_seg_sictrib TO ls_recipient-sicoge_tribs.
          ENDIF.

        WHEN OTHERS.
          MESSAGE ID 'ZS08' TYPE 'W' NUMBER '001'
            WITH ls_edidd-segnam.
      ENDCASE.
    ENDLOOP.

    IF lv_in_recip = abap_true.
      APPEND ls_recipient TO es_payload-recipients.
    ENDIF.

    IF es_payload-header IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>missing_header_segment.
    ENDIF.
  ENDMETHOD.

  METHOD validate_header.
    rv_ok = abap_true.

    IF is_header-id_dp IS INITIAL.
      rv_ok = abap_false.
      APPEND VALUE bapiret2( type = 'E' id = 'ZS08' number = '001'
                             message = 'ID_DP is mandatory and cannot be blank' )
        TO ct_messages.
    ENDIF.

    IF is_header-zimp_tot <= 0.
      rv_ok = abap_false.
      APPEND VALUE bapiret2( type = 'E' id = 'ZS08' number = '002'
                             message = 'Total amount ZIMP_TOT must be greater than zero' )
        TO ct_messages.
    ENDIF.

    IF is_header-grant_nbr IS INITIAL.
      rv_ok = abap_false.
      APPEND VALUE bapiret2( type = 'E' id = 'ZS08' number = '003'
                             message = 'GRANT_NBR is mandatory' )
        TO ct_messages.
    ENDIF.
  ENDMETHOD.

  METHOD create_payment_disposition.
    " Placeholder as requested (kept as-is conceptually)
    TRY.
        AUTHORITY-CHECK OBJECT 'Z_ZS08_DP'
          ID 'ACTVT' FIELD '06'.

        IF sy-subrc <> 0.
          APPEND VALUE bapiret2( type = 'E' id = 'ZS08' number = '010'
                                 message = 'No authorization to create payment disposition' )
            TO et_return.
          RETURN.
        ENDIF.

        LOOP AT is_payload-recipients ASSIGNING FIELD-SYMBOL(<ls_recip>).
          IF <ls_recip>-seg_d-importo <= 0.
            APPEND VALUE bapiret2( type = 'E' id = 'ZS08' number = '011'
                                   message = 'Recipient amount must be greater than zero'
                                   message_v1 = <ls_recip>-seg_d-taxnum )
              TO et_return.
          ENDIF.
        ENDLOOP.

        IF me->has_errors( et_return ) = abap_false.
          ev_dp_number = |ZDP{ sy-datum }{ sy-uzeit }|.
          APPEND VALUE bapiret2( type = 'S' id = 'ZS08' number = '020'
                                 message = |Payment disposition created: { ev_dp_number }| )
            TO et_return.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE bapiret2( type = 'E' id = 'ZS08' number = '099'
                               message = lx_root->get_text( ) )
          TO et_return.
    ENDTRY.
  ENDMETHOD.

  METHOD update_idoc_status.
    DATA: lt_status TYPE STANDARD TABLE OF bdidocstat,
          ls_status TYPE bdidocstat.

    CLEAR ls_status.
    ls_status-docnum = iv_idoc_number.
    ls_status-status = iv_status.
    ls_status-stamid = 'ZS08'.
    ls_status-stamno = '000'.
    ls_status-stapa1 = iv_message.
    ls_status-uname  = sy-uname.
    ls_status-repid  = sy-repid.
    ls_status-stamqty = 1.
    APPEND ls_status TO lt_status.

    CALL FUNCTION 'IDOC_STATUS_WRITE_TO_DATABASE'
      TABLES
        idoc_status = lt_status
      EXCEPTIONS
        db_error    = 1
        OTHERS      = 2.

    IF sy-subrc <> 0.
      MESSAGE ID 'ZS08' TYPE 'W' NUMBER '002'
        WITH iv_idoc_number iv_status.
    ENDIF.
  ENDMETHOD.

  METHOD trigger_outbound_idoc.
    DATA: lo_outbound TYPE REF TO zcl_zs08_idoc_outbound,
          ls_result   TYPE zcl_zs08_idoc_outbound=>ty_dp_result.

    CREATE OBJECT lo_outbound.

    CLEAR ls_result.
    ls_result-id_dp        = is_payload-header-id_dp.
    ls_result-oggetto_pag  = is_payload-header-oggetto_pag.
    ls_result-grant_nbr    = is_payload-header-grant_nbr.
    ls_result-cod_cup      = is_payload-header-cod_cup.
    ls_result-clp          = is_payload-header-clp.
    ls_result-zdescrizione = is_payload-header-zdescrizione.
    ls_result-zimp_tot     = is_payload-header-zimp_tot.
    ls_result-znumdp       = iv_dp_number.
    ls_result-link_sf      = is_payload-link-link_sf.

    IF me->has_errors( it_return ) = abap_true.
      ls_result-zstatodp = 'KO'.
    ELSE.
      ls_result-zstatodp = 'OK'.
    ENDIF.

    ls_result-zdata_esito = sy-datum.

    LOOP AT it_return INTO DATA(ls_ret).
      APPEND me->map_bapiret2_to_msg( ls_ret ) TO ls_result-msgs_hdr.
    ENDLOOP.

    " Note: outbound class expects outbound-typed recipients; here we keep the
    " previous behavior (placeholder) and send header-only when KO if needed.

    TRY.
        lo_outbound->send_idoc( is_result = ls_result ).
      CATCH zcx_zs08_idoc_error INTO DATA(lx_out).
        MESSAGE lx_out->get_text( ) TYPE 'W'.
    ENDTRY.
  ENDMETHOD.

  METHOD map_bapiret2_to_msg.
    CLEAR rs_msg.
    rs_msg-type       = is_bapiret2-type.
    rs_msg-id         = is_bapiret2-id.
    rs_msg-number     = is_bapiret2-number.
    rs_msg-message    = is_bapiret2-message.
    rs_msg-message_v1 = is_bapiret2-message_v1.
    rs_msg-message_v2 = is_bapiret2-message_v2.
    rs_msg-message_v3 = is_bapiret2-message_v3.
    rs_msg-message_v4 = is_bapiret2-message_v4.
  ENDMETHOD.

  METHOD has_errors.
    rv_error = abap_false.
    READ TABLE it_return WITH KEY type = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      rv_error = abap_true.
      RETURN.
    ENDIF.

    READ TABLE it_return WITH KEY type = 'A' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      rv_error = abap_true.
    ENDIF.
  ENDMETHOD.

ENDCLASS.