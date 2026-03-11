FUNCTION zs08_zprdispsf_outbound.
*"----------------------------------------------------------------------
*"*"Interfaccia locale:
*"  IMPORTING
*"     VALUE(IV_ID_DP) TYPE  ZS08_DISPSF-ID_DP
*"  EXPORTING
*"     VALUE(EV_IDOC_NUMBER) TYPE  EDIDC-DOCNUM
*"  EXCEPTIONS
*"     DP_NOT_FOUND
*"     IDOC_GENERATION_ERROR
*"----------------------------------------------------------------------
*
* Purpose: Extracts data for payment disposition IV_ID_DP from tables
*          ZS08_DISPSF (header) and ZS08_DISPSF_POS (positions), builds
*          the hierarchical IDoc payload, and triggers the outbound IDoc
*          via ZCL_ZS08_IDOC_OUTBOUND.
*
* Usage example:
*   CALL FUNCTION 'ZS08_ZPRDISPSF_OUTBOUND'
*     EXPORTING  iv_id_dp         = '0000000042'
*     IMPORTING  ev_idoc_number   = lv_docnum
*     EXCEPTIONS dp_not_found     = 1
*                idoc_generation_error = 2
*                OTHERS           = 3.

  " ── Types ────────────────────────────────────────────────────────────
  TYPES: ty_payload   TYPE zcl_zs08_idoc_outbound=>ty_idoc_payload,
         ty_recipient TYPE zcl_zs08_idoc_outbound=>ty_recipient,
         ty_d_trib    TYPE zcl_zs08_idoc_outbound=>ty_d_trib,
         ty_sic       TYPE zcl_zs08_idoc_outbound=>ty_sic,
         ty_sictrib   TYPE zcl_zs08_idoc_outbound=>ty_sictrib.

  " ── Read DP header ───────────────────────────────────────────────────
  SELECT SINGLE *
    FROM zs08_dispsf
    WHERE id_dp = @iv_id_dp
    INTO @DATA(ls_dispsf).

  IF sy-subrc <> 0.
    RAISE dp_not_found.
  ENDIF.

  " ── Read DP positions ordered for hierarchical reconstruction ────────
  SELECT *
    FROM zs08_dispsf_pos
    WHERE id_dp = @iv_id_dp
    ORDER BY posid
    INTO TABLE @DATA(lt_pos).

  " ── Build IDoc payload ───────────────────────────────────────────────
  DATA ls_payload TYPE ty_payload.

  " Map header table fields → IDoc segment T
  MOVE-CORRESPONDING ls_dispsf TO ls_payload-header.

  " Reconstruct the recipient hierarchy from the flat positions table.
  " Level codes (field LIVELLO):
  "   2-DES     → D segment       (recipient header)
  "   3-DESTRIB → D_TRIB segment  (recipient-level tribute)
  "   3-SIC     → SIC segment     (invoice)
  "   4-SICTRIB → SICTRIB segment (invoice-level tribute)
  DATA ls_recipient  TYPE ty_recipient.
  DATA ls_d_trib     TYPE ty_d_trib.
  DATA ls_sic        TYPE ty_sic.
  DATA ls_sictrib    TYPE ty_sictrib.
  DATA lv_in_recip   TYPE abap_bool VALUE abap_false.
  DATA lv_in_sic     TYPE abap_bool VALUE abap_false.
  DATA lv_posid_recip TYPE zs08_dispsf_pos-posid. " posid of the current recipient
  DATA lv_posid_sic   TYPE zs08_dispsf_pos-posid. " posid of the current SIC

  LOOP AT lt_pos ASSIGNING FIELD-SYMBOL(<ls_pos>).
    CASE <ls_pos>-livello.

      WHEN '2-DES'. " ── New recipient ────────────────────────────────
        " Flush the previous recipient (if any) before starting a new one
        IF lv_in_recip = abap_true.
          IF lv_in_sic = abap_true.
            APPEND ls_sic TO ls_recipient-sics.
            CLEAR ls_sic.
            lv_in_sic = abap_false.
          ENDIF.
          APPEND ls_recipient TO ls_payload-recipients.
          CLEAR ls_recipient.
        ENDIF.
        " Map position fields → D segment (fields have the same names)
        MOVE-CORRESPONDING <ls_pos> TO ls_recipient-seg_d.
        lv_posid_recip = <ls_pos>-posid.
        lv_in_recip    = abap_true.

      WHEN '3-DESTRIB'. " ── D_TRIB child of the current recipient ───
        IF lv_in_recip = abap_false OR <ls_pos>-posid_sup <> lv_posid_recip.
          CONTINUE. " orphaned row – skip
        ENDIF.
        CLEAR ls_d_trib.
        " Explicit field mapping because D_TRIB columns carry the _dtrib suffix
        ls_d_trib-d_trib-cod_tributo       = <ls_pos>-cod_tributo_dtrib.
        ls_d_trib-d_trib-descr_tributo     = <ls_pos>-descr_tributo_dtrib.
        ls_d_trib-d_trib-chiave_banca      = <ls_pos>-chiave_banca_dtrib.
        ls_d_trib-d_trib-codice_gestionale = <ls_pos>-codice_gestionale_dtrib.
        ls_d_trib-d_trib-trib_pag          = <ls_pos>-trib_pag_dtrib.
        ls_d_trib-d_trib-znumopf           = <ls_pos>-znumopf_dtrib.
        ls_d_trib-d_trib-zstatoopf         = <ls_pos>-zstatoopf_dtrib.
        ls_d_trib-d_trib-zdata_opf         = <ls_pos>-zdata_opf_dtrib.
        ls_d_trib-d_trib-zcroquiet         = <ls_pos>-zcroquiet_dtrib.
        ls_d_trib-d_trib-importo_pagato_opf = <ls_pos>-importo_pagato_opf_dtrib.
        APPEND ls_d_trib TO ls_recipient-d_tribs.

      WHEN '3-SIC'. " ── SIC child of the current recipient ───────────
        IF lv_in_recip = abap_false OR <ls_pos>-posid_sup <> lv_posid_recip.
          CONTINUE. " orphaned row – skip
        ENDIF.
        " Flush the previous SIC before starting a new one
        IF lv_in_sic = abap_true.
          APPEND ls_sic TO ls_recipient-sics.
          CLEAR ls_sic.
        ENDIF.
        " SIC columns share their names with the segment fields; only IMPORTO
        " is stored under the alias IMPORTO_SIC in ZS08_DISPSF_POS.
        MOVE-CORRESPONDING <ls_pos> TO ls_sic-sic.
        ls_sic-sic-importo = <ls_pos>-importo_sic.
        lv_posid_sic = <ls_pos>-posid.
        lv_in_sic    = abap_true.

      WHEN '4-SICTRIB'. " ── SICTRIB child of the current SIC ─────────
        IF lv_in_sic = abap_false OR <ls_pos>-posid_sup <> lv_posid_sic.
          CONTINUE. " orphaned row – skip
        ENDIF.
        CLEAR ls_sictrib.
        " Explicit field mapping because SICTRIB columns carry the _sictrib suffix
        ls_sictrib-sictrib-cod_tributo       = <ls_pos>-cod_tributo_sictrib.
        ls_sictrib-sictrib-descr_tributo     = <ls_pos>-descr_tributo_sictrib.
        ls_sictrib-sictrib-chiave_banca      = <ls_pos>-chiave_banca_sictrib.
        ls_sictrib-sictrib-codice_gestionale = <ls_pos>-codice_gestionale_sictrib.
        ls_sictrib-sictrib-trib_pag          = <ls_pos>-trib_pag_sictrib.
        ls_sictrib-sictrib-znumopf           = <ls_pos>-znumopf_sictrib.
        ls_sictrib-sictrib-zstatoopf         = <ls_pos>-zstatoopf_sictrib.
        ls_sictrib-sictrib-zdata_opf         = <ls_pos>-zdata_opf_sictrib.
        ls_sictrib-sictrib-zcroquiet         = <ls_pos>-zcroquiet_sictrib.
        ls_sictrib-sictrib-importo_pagato_opf = <ls_pos>-importo_pagato_opf_sictrib.
        APPEND ls_sictrib TO ls_sic-sictribs.

    ENDCASE.
  ENDLOOP.

  " Flush the last open recipient/SIC after the loop
  IF lv_in_recip = abap_true.
    IF lv_in_sic = abap_true.
      APPEND ls_sic TO ls_recipient-sics.
    ENDIF.
    APPEND ls_recipient TO ls_payload-recipients.
  ENDIF.

  " ── Generate and distribute the outbound IDoc ────────────────────────
  TRY.
      DATA(lo_outbound) = NEW zcl_zs08_idoc_outbound( ).
      lo_outbound->generate_outbound_idoc(
        EXPORTING
          is_payload     = ls_payload
        IMPORTING
          ev_idoc_number = ev_idoc_number ).

    CATCH zcx_zs08_idoc_error.
      RAISE idoc_generation_error.
  ENDTRY.

ENDFUNCTION.
