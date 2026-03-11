*&---------------------------------------------------------------------*
*& Class: ZCL_ZS08_ZPRDISPSF_IDOC_PROCES
*&---------------------------------------------------------------------*
CLASS zcl_zs08_zprdispsf_idoc_proces DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_sictrib,
        sictrib     TYPE zs08_zprdispsf_sictrib,
        sictrib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_sictrib_msg WITH DEFAULT KEY,
      END OF ty_sictrib.
    TYPES:
      BEGIN OF ty_sic,
        sic      TYPE zs08_zprdispsf_sic,
        sic_msg  TYPE STANDARD TABLE OF zs08_zprdispsf_sic_msg WITH DEFAULT KEY,
        sictribs TYPE STANDARD TABLE OF ty_sictrib WITH DEFAULT KEY,
      END OF ty_sic.
    TYPES:
      BEGIN OF ty_d_trib,
        d_trib     TYPE zs08_zprdispsf_d_trib,
        d_trib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_trib_msg WITH DEFAULT KEY,
      END OF ty_d_trib.
    TYPES:
      BEGIN OF ty_recipient,
        seg_d     TYPE zs08_zprdispsf_d,
        seg_d_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_msg WITH DEFAULT KEY,
        d_tribs   TYPE STANDARD TABLE OF ty_d_trib WITH DEFAULT KEY,
        sics      TYPE STANDARD TABLE OF ty_sic WITH DEFAULT KEY,
      END OF ty_recipient .
    TYPES:
      BEGIN OF ty_idoc_payload,
        header     TYPE zs08_zprdispsf_t,
        link       TYPE zs08_zprdispsf_t_link,
        header_msg TYPE STANDARD TABLE OF zs08_zprdispsf_t_msg WITH DEFAULT KEY,
        recipients TYPE STANDARD TABLE OF ty_recipient WITH DEFAULT KEY,
      END OF ty_idoc_payload .

    METHODS process_inbound
      IMPORTING
        !iv_idoc_number TYPE edi_docnum
        !in_edidc       TYPE edidc
        !in_edidd       TYPE edidd_tt
      RAISING
        zcx_zs08_idoc_error .
    METHODS parse_idoc_segments
      IMPORTING
        !it_edidd   TYPE edidd_tt
      EXPORTING
        !es_payload TYPE ty_idoc_payload
      RAISING
        zcx_zs08_idoc_error .
  PRIVATE SECTION.

    CONSTANTS gc_segnam_t TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_T' ##NO_TEXT.
    CONSTANTS gc_segnam_t_msg TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_T_MSG' ##NO_TEXT.
    CONSTANTS gc_segnam_t_link TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_T_LINK' ##NO_TEXT.
    CONSTANTS gc_segnam_d TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_D' ##NO_TEXT.
    CONSTANTS gc_segnam_d_msg TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_D_MSG' ##NO_TEXT.
    CONSTANTS gc_segnam_d_trib TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_D_TRIB' ##NO_TEXT.
    CONSTANTS gc_segnam_d_trib_msg TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_D_TRIB_MSG' ##NO_TEXT.
    CONSTANTS gc_segnam_sic TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_SIC' ##NO_TEXT.
    CONSTANTS gc_segnam_sic_msg TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_SIC_MSG' ##NO_TEXT.
    CONSTANTS gc_segnam_sictrib TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_SICTRIB' ##NO_TEXT.
    CONSTANTS gc_segnam_sictrib_msg TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_SICTRIB_MSG' ##NO_TEXT.
    CONSTANTS gc_msgty_in TYPE edi_mestyp VALUE 'ZS08_ZPRDISPSF_DIRECTIN' ##NO_TEXT.
    CONSTANTS gc_status_ok TYPE c VALUE 'S' ##NO_TEXT. " IDoc status: success
    CONSTANTS gc_status_err TYPE c VALUE 'E' ##NO_TEXT. " IDoc status: error

    METHODS check_authority
      RAISING
        zcx_zs08_idoc_error .
    METHODS validate_idoc
      IMPORTING
        !is_header   TYPE zs08_zprdispsf_t
        !is_payload  TYPE ty_idoc_payload
      CHANGING
        !ct_messages TYPE bapiret2_t
      RETURNING
        VALUE(rv_ok) TYPE abap_bool .
    METHODS read_idoc_data
      IMPORTING
        !iv_idoc_number TYPE edi_docnum
      EXPORTING
        !es_edidc       TYPE edidc
        !et_edidd       TYPE edidd_tt
      RAISING
        zcx_zs08_idoc_error .
    METHODS create_payment_disposition
      IMPORTING
        !is_payload TYPE ty_idoc_payload
      EXPORTING
*      !EV_DP_NUMBER type C
        !et_return  TYPE bapiret2_t .
    METHODS update_idoc_status
      IMPORTING
        !iv_idoc_number TYPE edi_docnum
        !iv_status      TYPE edi_status
        !iv_message     TYPE c
        !iv_msgtype     TYPE symsgty .
    METHODS trigger_outbound_idoc
      IMPORTING
        !is_payload TYPE ty_idoc_payload
        !it_return  TYPE bapiret2_t .
    METHODS map_bapiret2_to_msg
      IMPORTING
        !is_bapiret2  TYPE bapiret2
      RETURNING
        VALUE(rs_msg) TYPE zs08_zprdispsf_t_msg .
    METHODS has_errors
      IMPORTING
        !it_return      TYPE bapiret2_t
      RETURNING
        VALUE(rv_error) TYPE abap_bool .
ENDCLASS.



CLASS ZCL_ZS08_ZPRDISPSF_IDOC_PROCES IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->CHECK_AUTHORITY
* +-------------------------------------------------------------------------------------------------+
* | [!CX!] ZCX_ZS08_IDOC_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD check_authority.
*    AUTHORITY-CHECK OBJECT 'Z_ZS08_DP'
*      ID 'ACTVT' FIELD '01'.
*    IF sy-subrc <> 0.
*      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
*        EXPORTING
*          textid = zcx_zs08_idoc_error=>no_authority.
*    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->CREATE_PAYMENT_DISPOSITION
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_PAYLOAD                     TYPE        TY_IDOC_PAYLOAD
* | [<---] ET_RETURN                      TYPE        BAPIRET2_T
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD create_payment_disposition.
    DATA ls_header TYPE zs08_zprdispsf_t.
    FIELD-SYMBOLS <ls_recip> TYPE ty_recipient.
    DATA: ls_d_tribs   TYPE ty_d_trib.
    DATA: ls_sics      TYPE ty_sic.
    DATA: ls_sictribs  TYPE ty_sictrib.
    DATA: ls_d_trib    TYPE ty_d_trib-d_trib.
    DATA: ls_sic       TYPE ty_sic-sic.
    DATA: ls_sictrib   TYPE ty_sictrib-sictrib.

    DATA: lf_numpos(6)    TYPE n,
          lf_numpos_l2(6) TYPE n,
          lf_numpos_l3(6) TYPE n.

    DATA: ls_dispsf TYPE zs08_dispsf.
    DATA: ls_dispsf_pos TYPE zs08_dispsf_pos.
    DATA: lt_dispsf_pos TYPE TABLE OF zs08_dispsf_pos.

    CLEAR et_return.

* header
    ls_header = is_payload-header.
    MOVE-CORRESPONDING ls_header TO ls_dispsf.
    ls_dispsf-erdat = sy-datum.
    ls_dispsf-erzet = sy-uzeit.
    ls_dispsf-ernam = sy-uname.
    ls_dispsf-stato = 'W'.

* items
*    TYPES:
*      BEGIN OF ty_sictrib,
*        sictrib     TYPE zs08_zprdispsf_sictrib,
*        sictrib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_sictrib_msg WITH DEFAULT KEY,
*      END OF ty_sictrib.
*    TYPES:
*      BEGIN OF ty_sic,
*        sic      TYPE zs08_zprdispsf_sic,
*        sic_msg  TYPE STANDARD TABLE OF zs08_zprdispsf_sic_msg WITH DEFAULT KEY,
*        sictribs TYPE STANDARD TABLE OF ty_sictrib WITH DEFAULT KEY,
*      END OF ty_sic.
*    TYPES:
*      BEGIN OF ty_d_trib,
*        d_trib     TYPE zs08_zprdispsf_d_trib,
*        d_trib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_trib_msg WITH DEFAULT KEY,
*      END OF ty_d_trib.
*    TYPES:
*      BEGIN OF ty_recipient,
*        seg_d     TYPE zs08_zprdispsf_d,
*        seg_d_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_msg WITH DEFAULT KEY,
*        d_tribs   TYPE STANDARD TABLE OF ty_d_trib WITH DEFAULT KEY,
*        sics      TYPE STANDARD TABLE OF ty_sic WITH DEFAULT KEY,
*      END OF ty_recipient .
*    TYPES:
*      BEGIN OF ty_idoc_payload,
*        header     TYPE zs08_zprdispsf_t,
*        link       TYPE zs08_zprdispsf_t_link,
*        header_msg TYPE STANDARD TABLE OF zs08_zprdispsf_t_msg WITH DEFAULT KEY,
*        recipients TYPE STANDARD TABLE OF ty_recipient WITH DEFAULT KEY,
*      END OF ty_idoc_payload .


    LOOP AT is_payload-recipients ASSIGNING <ls_recip>.

* destinatario
      ADD 1 TO lf_numpos.
      lf_numpos_l2 = lf_numpos.
      CLEAR ls_dispsf_pos.
      ls_dispsf_pos-id_dp = ls_header-id_dp.
      ls_dispsf_pos-posid = lf_numpos.
      ls_dispsf_pos-livello = '2-DES'.
*
      MOVE-CORRESPONDING <ls_recip>-seg_d TO ls_dispsf_pos.
      APPEND ls_dispsf_pos TO lt_dispsf_pos.

* tributi destinatario
      LOOP AT <ls_recip>-d_tribs INTO ls_d_tribs.
        ADD 1 TO lf_numpos.
        CLEAR ls_dispsf_pos.
        ls_dispsf_pos-id_dp = ls_header-id_dp.
        ls_dispsf_pos-posid = lf_numpos.
        ls_dispsf_pos-livello = '3-DESTRIB'.
        ls_dispsf_pos-posid_sup = lf_numpos_l2.
*
        ls_d_trib = ls_d_tribs-d_trib.
        MOVE ls_d_trib-cod_tributo TO ls_dispsf_pos-cod_tributo_dtrib.
        MOVE ls_d_trib-descr_tributo TO ls_dispsf_pos-descr_tributo_dtrib.
        MOVE ls_d_trib-chiave_banca TO ls_dispsf_pos-chiave_banca_dtrib.
        MOVE ls_d_trib-codice_gestionale TO ls_dispsf_pos-codice_gestionale_dtrib.
        MOVE ls_d_trib-trib_pag TO ls_dispsf_pos-trib_pag_dtrib.
        MOVE ls_d_trib-znumopf TO ls_dispsf_pos-znumopf_dtrib.
        MOVE ls_d_trib-zstatoopf TO ls_dispsf_pos-zstatoopf_dtrib.
        MOVE ls_d_trib-zdata_opf TO ls_dispsf_pos-zdata_opf_dtrib.
        MOVE ls_d_trib-zcroquiet TO ls_dispsf_pos-zcroquiet_dtrib.
        MOVE ls_d_trib-importo_pagato_opf TO ls_dispsf_pos-importo_pagato_opf_dtrib.
        APPEND ls_dispsf_pos TO lt_dispsf_pos.
      ENDLOOP.
* fatture
      LOOP AT <ls_recip>-sics INTO ls_sics.
        ADD 1 TO lf_numpos.
        lf_numpos_l3 = lf_numpos.
        CLEAR ls_dispsf_pos.
        ls_dispsf_pos-id_dp = ls_header-id_dp.
        ls_dispsf_pos-posid = lf_numpos.
        ls_dispsf_pos-livello = '3-SIC'.
        ls_dispsf_pos-posid_sup = lf_numpos_l2.
*
        ls_sic = ls_sics-sic.
        MOVE-CORRESPONDING ls_sic TO ls_dispsf_pos.
        MOVE ls_sic-importo TO ls_dispsf_pos-importo_sic.
        APPEND ls_dispsf_pos TO lt_dispsf_pos.
* tributi fatture
        LOOP AT ls_sics-sictribs INTO ls_sictribs.
          ADD 1 TO lf_numpos.
          CLEAR ls_dispsf_pos.
          ls_dispsf_pos-id_dp = ls_header-id_dp.
          ls_dispsf_pos-posid = lf_numpos.
          ls_dispsf_pos-livello = '4-SICTRIB'.
          ls_dispsf_pos-posid_sup = lf_numpos_l3.
*
          ls_sictrib = ls_sictribs-sictrib.
          MOVE ls_sictrib-cod_tributo TO ls_dispsf_pos-cod_tributo_sictrib.
          MOVE ls_sictrib-descr_tributo TO ls_dispsf_pos-descr_tributo_sictrib.
          MOVE ls_sictrib-chiave_banca TO ls_dispsf_pos-chiave_banca_sictrib.
          MOVE ls_sictrib-codice_gestionale TO ls_dispsf_pos-codice_gestionale_sictrib.
          MOVE ls_sictrib-trib_pag TO ls_dispsf_pos-trib_pag_sictrib.
          MOVE ls_sictrib-znumopf TO ls_dispsf_pos-znumopf_sictrib.
          MOVE ls_sictrib-zstatoopf TO ls_dispsf_pos-zstatoopf_sictrib.
          MOVE ls_sictrib-zdata_opf TO ls_dispsf_pos-zdata_opf_sictrib.
          MOVE ls_sictrib-zcroquiet TO ls_dispsf_pos-zcroquiet_sictrib.
          MOVE ls_sictrib-importo_pagato_opf TO ls_dispsf_pos-importo_pagato_opf_sictrib.
          APPEND ls_dispsf_pos TO lt_dispsf_pos.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.

    IF ls_dispsf IS NOT INITIAL.
      MODIFY zs08_dispsf FROM ls_dispsf.
    ENDIF.

    IF lt_dispsf_pos[] IS NOT INITIAL.
      MODIFY zs08_dispsf_pos FROM TABLE lt_dispsf_pos.
    ENDIF.

    IF sy-subrc = 0.
      COMMIT WORK AND WAIT.
    ELSE.
    ENDIF.

    IF me->has_errors( et_return ) = abap_false.
      APPEND INITIAL LINE TO et_return ASSIGNING FIELD-SYMBOL(<ls_ret_s>).
      <ls_ret_s>-type    = 'S'.
      <ls_ret_s>-id      = '00'.
      <ls_ret_s>-number  = '208'.
*      CONCATENATE 'Payment disposition created: ' ev_dp_number INTO <ls_ret_s>-message.
      <ls_ret_s>-message = 'Payment disposition saved'.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->HAS_ERRORS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_RETURN                      TYPE        BAPIRET2_T
* | [<-()] RV_ERROR                       TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD has_errors.
    FIELD-SYMBOLS <ls_ret> TYPE bapiret2.
    rv_error = abap_false.

    LOOP AT it_return ASSIGNING <ls_ret>.
      IF <ls_ret>-type = 'E' OR <ls_ret>-type = 'A'.
        rv_error = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->MAP_BAPIRET2_TO_MSG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_BAPIRET2                    TYPE        BAPIRET2
* | [<-()] RS_MSG                         TYPE        ZS08_ZPRDISPSF_T_MSG
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD map_bapiret2_to_msg.
    CLEAR rs_msg.
    rs_msg-type       = is_bapiret2-type.
*    rs_msg-id         = is_bapiret2-id.
*    rs_msg-number     = is_bapiret2-number.
    rs_msg-message    = is_bapiret2-message.
*    rs_msg-message_v1 = is_bapiret2-message_v1.
*    rs_msg-message_v2 = is_bapiret2-message_v2.
*    rs_msg-message_v3 = is_bapiret2-message_v3.
*    rs_msg-message_v4 = is_bapiret2-message_v4.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->PARSE_IDOC_SEGMENTS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IT_EDIDD                       TYPE        EDIDD_TT
* | [<---] ES_PAYLOAD                     TYPE        TY_IDOC_PAYLOAD
* | [!CX!] ZCX_ZS08_IDOC_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD parse_idoc_segments.
    DATA ls_seg_t       TYPE zs08_zprdispsf_t.
    DATA ls_seg_d       TYPE zs08_zprdispsf_d.
    DATA ls_seg_d_trib  TYPE zs08_zprdispsf_d_trib.
    DATA ls_seg_sic     TYPE zs08_zprdispsf_sic.
    DATA ls_seg_sictrib TYPE zs08_zprdispsf_sictrib.

*    TYPES:
*      BEGIN OF ty_sictrib,
*        sictrib     TYPE zs08_zprdispsf_sictrib,
*        sictrib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_sictrib_msg WITH DEFAULT KEY,
*      END OF ty_sictrib.
*    TYPES:
*      BEGIN OF ty_sic,
*        sic      TYPE zs08_zprdispsf_sic,
*        sic_msg  TYPE STANDARD TABLE OF zs08_zprdispsf_sic_msg WITH DEFAULT KEY,
*        sictribs TYPE STANDARD TABLE OF ty_sictrib WITH DEFAULT KEY,
*      END OF ty_sic.
*    TYPES:
*      BEGIN OF ty_d_trib,
*        d_trib     TYPE zs08_zprdispsf_d_trib,
*        d_trib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_trib_msg WITH DEFAULT KEY,
*      END OF ty_d_trib.
*    TYPES:
*      BEGIN OF ty_recipient,
*        seg_d     TYPE zs08_zprdispsf_d,
*        seg_d_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_msg WITH DEFAULT KEY,
*        d_tribs   TYPE STANDARD TABLE OF ty_d_trib WITH DEFAULT KEY,
*        sics      TYPE STANDARD TABLE OF ty_sic WITH DEFAULT KEY,
*      END OF ty_recipient .

    DATA ls_recipient  TYPE ty_recipient.
    DATA ls_sictrib    TYPE ty_sictrib.
    DATA ls_sic        TYPE ty_sic.
    DATA ls_d_trib     TYPE ty_d_trib.

    DATA lv_in_recip   TYPE abap_bool.
    DATA lv_in_sic     TYPE abap_bool.

    FIELD-SYMBOLS <ls_edidd> TYPE edidd.

    CLEAR es_payload.
    CLEAR: ls_recipient, ls_sic.

    lv_in_recip     = abap_false.
    lv_in_sic       = abap_false.

    LOOP AT it_edidd ASSIGNING <ls_edidd>.
      CASE <ls_edidd>-segnam.

        WHEN gc_segnam_t.
          CLEAR ls_seg_t.
          ls_seg_t = <ls_edidd>-sdata.
          es_payload-header = ls_seg_t.

        WHEN gc_segnam_d.
          IF lv_in_recip = abap_true.
            IF lv_in_sic = abap_true.
              APPEND ls_sic TO ls_recipient-sics.
              CLEAR ls_sic.
              lv_in_sic          = abap_false.
            ENDIF.
            APPEND ls_recipient TO es_payload-recipients.
            CLEAR  ls_recipient.
          ENDIF.
          CLEAR ls_seg_d.
          ls_seg_d = <ls_edidd>-sdata.
          ls_recipient-seg_d = ls_seg_d.
          lv_in_recip        = abap_true.

        WHEN gc_segnam_d_trib.
          CLEAR: ls_seg_d_trib, ls_d_trib.
          ls_seg_d_trib = <ls_edidd>-sdata.
          ls_d_trib-d_trib = ls_seg_d_trib.
          APPEND ls_d_trib TO ls_recipient-d_tribs.

        WHEN gc_segnam_sic.
          IF lv_in_sic = abap_true.
            APPEND ls_sic TO ls_recipient-sics.
            CLEAR ls_sic.
          ENDIF.
          CLEAR ls_seg_sic.
          ls_seg_sic  = <ls_edidd>-sdata.
          ls_sic-sic  = ls_seg_sic.
          lv_in_sic   = abap_true.

        WHEN gc_segnam_sictrib.
          CLEAR: ls_seg_sictrib, ls_sictrib.
          ls_seg_sictrib = <ls_edidd>-sdata.
          ls_sictrib-sictrib = ls_seg_sictrib.
          APPEND ls_sictrib TO ls_sic-sictribs.

        WHEN OTHERS.

      ENDCASE.
    ENDLOOP.

    IF lv_in_recip = abap_true.
      IF lv_in_sic = abap_true.
        APPEND ls_sic TO ls_recipient-sics.
      ENDIF.
      APPEND ls_recipient TO es_payload-recipients.
    ENDIF.

    IF es_payload-header IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>missing_header_segment.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->PROCESS_INBOUND
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_IDOC_NUMBER                 TYPE        EDI_DOCNUM
* | [--->] IN_EDIDC                       TYPE        EDIDC
* | [--->] IN_EDIDD                       TYPE        EDIDD_TT
* | [!CX!] ZCX_ZS08_IDOC_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD process_inbound.
    DATA ls_edidc   TYPE edidc.
    DATA lt_edidd   TYPE edidd_tt.
    DATA ls_payload TYPE ty_idoc_payload.
    DATA lt_return  TYPE bapiret2_t.
    DATA lv_valid   TYPE abap_bool.
    DATA lv_dp      TYPE c LENGTH 20.

    CALL METHOD me->check_authority.

*    CALL METHOD me->read_idoc_data
*      EXPORTING
*        iv_idoc_number = iv_idoc_number
*      IMPORTING
*        es_edidc       = ls_edidc
*        et_edidd       = lt_edidd.
    ls_edidc = in_edidc.
    lt_edidd[] = in_edidd[].

    CALL METHOD me->parse_idoc_segments
      EXPORTING
        it_edidd   = lt_edidd
      IMPORTING
        es_payload = ls_payload.


* controlli per validazione
    lv_valid = me->validate_idoc(
      EXPORTING
        is_header   = ls_payload-header
        is_payload  = ls_payload
      CHANGING
        ct_messages = lt_return ).

    IF lv_valid = abap_false.
      CALL METHOD me->update_idoc_status
        EXPORTING
          iv_idoc_number = iv_idoc_number
          iv_msgtype     = 'E'
          iv_status      = '51'
          iv_message     = 'Header validation failed'.

      CALL METHOD me->trigger_outbound_idoc
        EXPORTING
          is_payload = ls_payload
          it_return  = lt_return.

      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>validation_failed
          docnum = iv_idoc_number.
    ENDIF.

    CALL METHOD me->create_payment_disposition
      EXPORTING
        is_payload = ls_payload
      IMPORTING
        et_return  = lt_return.

    IF me->has_errors( lt_return ) = abap_true.
      CALL METHOD me->update_idoc_status
        EXPORTING
          iv_idoc_number = iv_idoc_number
          iv_status      = '51'
          iv_msgtype     = 'E'
          iv_message     = 'Error during DP creation'.

      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>dp_creation_failed
          docnum = iv_idoc_number.
    ENDIF.

    CALL METHOD me->update_idoc_status
      EXPORTING
        iv_idoc_number = iv_idoc_number
        iv_status      = '53'
        iv_msgtype     = 'S'
        iv_message     = 'Idoc received successfully'.

    COMMIT WORK AND WAIT.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->READ_IDOC_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_IDOC_NUMBER                 TYPE        EDI_DOCNUM
* | [<---] ES_EDIDC                       TYPE        EDIDC
* | [<---] ET_EDIDD                       TYPE        EDIDD_TT
* | [!CX!] ZCX_ZS08_IDOC_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD read_idoc_data.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->TRIGGER_OUTBOUND_IDOC
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_PAYLOAD                     TYPE        TY_IDOC_PAYLOAD
* | [--->] IT_RETURN                      TYPE        BAPIRET2_T
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD trigger_outbound_idoc.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->UPDATE_IDOC_STATUS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_IDOC_NUMBER                 TYPE        EDI_DOCNUM
* | [--->] IV_STATUS                      TYPE        EDI_STATUS
* | [--->] IV_MESSAGE                     TYPE        C
* | [--->] IV_MSGTYPE                     TYPE        SYMSGTY
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD update_idoc_status.
    DATA lt_status TYPE STANDARD TABLE OF bdidocstat WITH DEFAULT KEY.
    DATA ls_status TYPE bdidocstat.

    CLEAR lt_status.
    CLEAR ls_status.

    ls_status-docnum  = iv_idoc_number.
    ls_status-status  = iv_status.
    ls_status-msgty  = iv_msgtype.
    ls_status-msgid  = '00'.
    ls_status-msgno  = '208'.
    ls_status-msgv1  = iv_message.
    ls_status-uname   = sy-uname.
    ls_status-repid   = sy-repid.

    APPEND ls_status TO lt_status.

    CALL FUNCTION 'IDOC_STATUS_WRITE_TO_DATABASE'
      TABLES
        idoc_status = lt_status
      EXCEPTIONS
        db_error    = 1
        OTHERS      = 2.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_ZPRDISPSF_IDOC_PROCES->VALIDATE_IDOC
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_HEADER                      TYPE        ZS08_ZPRDISPSF_T
* | [--->] IS_PAYLOAD                     TYPE        TY_IDOC_PAYLOAD
* | [<-->] CT_MESSAGES                    TYPE        BAPIRET2_T
* | [<-()] RV_OK                          TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD validate_idoc.
    rv_ok = abap_true.

*    IF is_header-id_dp IS INITIAL.
*      rv_ok = abap_false.
*      APPEND INITIAL LINE TO ct_messages ASSIGNING FIELD-SYMBOL(<ls_ret1>).
*      <ls_ret1>-type    = 'E'.
*      <ls_ret1>-id      = 'ZS08'.
*      <ls_ret1>-number  = '001'.
*      <ls_ret1>-message = 'ID_DP is mandatory and cannot be blank'.
*    ENDIF.
*

  ENDMETHOD.
ENDCLASS.