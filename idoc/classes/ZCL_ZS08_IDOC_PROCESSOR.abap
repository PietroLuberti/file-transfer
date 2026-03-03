*&---------------------------------------------------------------------*
*& Class: ZCL_ZS08_IDOC_PROCESSOR
*& IDoc ZS08 - Payment Disposition (Disposizione di Pagamento)
*& Inbound processing: receive DP data from ReGiS and create the DP
*& on the financial system (Sistema Finanziario / SAP ECC 6).
*&
*& Architecture:
*&   - All logic encapsulated in an OO class (no global variables,
*&     no FORM routines, following Clean ABAP principles).
*&   - HANA-optimised SQL: Code-to-Data, no SELECT *, precise WHERE.
*&   - Authority checks on entry points.
*&   - Full exception handling with TRY...CATCH / custom exception classes.
*&   - English naming, ABAP Doc comments on every public / complex method.
*&
*& Transactions to configure IDoc customising:
*&   WE31 - Create/maintain segment types (ZPRDISPSF_*)
*&   WE30 - Create/maintain IDoc type ZPRDISPSF
*&   WE81 - Create message type ZS08_DP_DIRECTIN / ZS08_DP_DIRECTOUT
*&   WE82 - Assign message type to IDoc type
*&   WE57 - Assign function module to message type (inbound)
*&   WE20 - Maintain partner profiles
*&---------------------------------------------------------------------*
CLASS zcl_zs08_idoc_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Type: header segment structure for inbound IDoc
    TYPES:
      BEGIN OF ty_seg_t,
        id_dp        TYPE c LENGTH 10,
        oggetto_pag  TYPE c LENGTH 50,
        grant_nbr    TYPE c LENGTH 20,
        cod_cup      TYPE c LENGTH 15,
        clp          TYPE c LENGTH 80,
        zdescrizione TYPE c LENGTH 1000,
        zimp_tot     TYPE p LENGTH 9 DECIMALS 2,
      END OF ty_seg_t,

      "! Type: link segment (sent empty by ReGiS, returned populated)
      BEGIN OF ty_seg_link,
        link_sf TYPE c LENGTH 1000,
      END OF ty_seg_link,

      "! Type: message segment (BAPIRET2-like)
      BEGIN OF ty_seg_msg,
        type       TYPE c LENGTH 1,
        id         TYPE c LENGTH 20,
        number     TYPE n LENGTH 3,
        message    TYPE c LENGTH 220,
        message_v1 TYPE c LENGTH 50,
        message_v2 TYPE c LENGTH 50,
        message_v3 TYPE c LENGTH 50,
        message_v4 TYPE c LENGTH 50,
      END OF ty_seg_msg,

      "! Type: recipient / non-SICOGE justification segment
      BEGIN OF ty_seg_d,
        taxnum            TYPE c LENGTH 16,
        cod_bp_sf         TYPE c LENGTH 10,
        iban              TYPE c LENGTH 34,
        numero_tes        TYPE c LENGTH 15,
        cig               TYPE c LENGTH 30,
        nota_dest         TYPE c LENGTH 1000,
        importo           TYPE p LENGTH 9 DECIMALS 2,
        codice_gestionale TYPE c LENGTH 10,
        zflag             TYPE c LENGTH 1,
      END OF ty_seg_d,

      "! Type: non-SICOGE tribute segment
      BEGIN OF ty_seg_trib,
        cod_tributo       TYPE c LENGTH 10,
        chiave_banca      TYPE c LENGTH 15,
        codice_gestionale TYPE c LENGTH 10,
        trib_pag          TYPE p LENGTH 9 DECIMALS 2,
      END OF ty_seg_trib,

      "! Type: SICOGE invoice segment
      BEGIN OF ty_seg_sic,
        id_fattura  TYPE c LENGTH 20,
        data_pag    TYPE d,
        num_fattura TYPE c LENGTH 40,
        importo     TYPE p LENGTH 9 DECIMALS 2,
      END OF ty_seg_sic,

      "! Type: SICOGE invoice tribute segment
      BEGIN OF ty_seg_sictrib,
        cod_tributo       TYPE c LENGTH 10,
        chiave_banca      TYPE c LENGTH 15,
        codice_gestionale TYPE c LENGTH 10,
        trib_pag          TYPE p LENGTH 9 DECIMALS 2,
      END OF ty_seg_sictrib,

      "! Internal hierarchical representation of one recipient block
      BEGIN OF ty_recipient,
        seg_d          TYPE ty_seg_d,
        msg_d          TYPE STANDARD TABLE OF ty_seg_msg WITH DEFAULT KEY,
        tributes       TYPE STANDARD TABLE OF ty_seg_trib WITH DEFAULT KEY,
        sicoge_docs    TYPE STANDARD TABLE OF ty_seg_sic WITH DEFAULT KEY,
        sicoge_tribs   TYPE STANDARD TABLE OF ty_seg_sictrib WITH DEFAULT KEY,
      END OF ty_recipient,

      "! Full inbound IDoc payload (parsed from EDI_DD / EDIDD segments)
      BEGIN OF ty_idoc_payload,
        header     TYPE ty_seg_t,
        link       TYPE ty_seg_link,
        msgs_hdr   TYPE STANDARD TABLE OF ty_seg_msg WITH DEFAULT KEY,
        recipients TYPE STANDARD TABLE OF ty_recipient WITH DEFAULT KEY,
      END OF ty_idoc_payload.

    "! @parameter iv_idoc_number | IDoc number to process (EDIDC-DOCNUM)
    "! @raising   zcx_zs08_idoc_error | Raised when processing fails
    METHODS process_inbound
      IMPORTING iv_idoc_number TYPE edi_docnum
      RAISING   zcx_zs08_idoc_error.

    "! Parse raw IDoc segments into typed payload structure.
    "! @parameter it_edidd        | IDoc data records (standard EDIDD table)
    "! @parameter es_payload      | Parsed typed payload
    "! @raising   zcx_zs08_idoc_error | Raised on segment parsing error
    METHODS parse_idoc_segments
      IMPORTING it_edidd   TYPE edidd_tab
      EXPORTING es_payload TYPE ty_idoc_payload
      RAISING   zcx_zs08_idoc_error.

  PRIVATE SECTION.

    CONSTANTS:
      gc_segnam_t       TYPE edilsegtyp VALUE 'ZPRDISPSF_T',
      gc_segnam_link    TYPE edilsegtyp VALUE 'ZPRDISPSF_LINK',
      gc_segnam_msg     TYPE edilsegtyp VALUE 'ZPRDISPSF_MSG',
      gc_segnam_d       TYPE edilsegtyp VALUE 'ZPRDISPSF_D',
      gc_segnam_trib    TYPE edilsegtyp VALUE 'ZPRDISPSF_TRIB',
      gc_segnam_sic     TYPE edilsegtyp VALUE 'ZPRDISPSF_SIC',
      gc_segnam_sictrib TYPE edilsegtyp VALUE 'ZPRDISPSF_SICTRIB',
      gc_msgty_in       TYPE edi_mestyp VALUE 'ZS08_DP_DIRECTIN',
      gc_status_ok      TYPE c          VALUE 'S',   " IDoc status: success
      gc_status_err     TYPE c          VALUE 'E'.   " IDoc status: error

    "! Validate authority to process inbound payment IDoc.
    "! @raising zcx_zs08_idoc_error | Raised when authorization is missing
    METHODS check_authority
      RAISING zcx_zs08_idoc_error.

    "! Validate header segment business rules.
    "! @parameter is_header    | Parsed header segment
    "! @parameter ct_messages  | Collected validation messages (RETURN table)
    "! @returning VALUE(rv_ok) | TRUE when validation passed
    METHODS validate_header
      IMPORTING is_header   TYPE ty_seg_t
      CHANGING  ct_messages TYPE bapiret2_t
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    "! Read EDIDC control record and EDIDD data records for one IDoc.
    "! HANA-optimised: single SELECT with exact key, no SELECT *.
    "! @parameter iv_idoc_number | IDoc number
    "! @parameter es_edidc       | Control record
    "! @parameter et_edidd       | Data records ordered by SEGNUM
    "! @raising   zcx_zs08_idoc_error | Raised when IDoc not found
    METHODS read_idoc_data
      IMPORTING iv_idoc_number TYPE edi_docnum
      EXPORTING es_edidc       TYPE edidc
                et_edidd       TYPE edidd_tab
      RAISING   zcx_zs08_idoc_error.

    "! Create payment disposition (DP) via the appropriate BAPI/FM.
    "! Replace with the actual FM that creates DP on the financial system.
    "! @parameter is_payload     | Full parsed IDoc payload
    "! @parameter ev_dp_number   | Created DP number
    "! @parameter et_return      | BAPI return messages
    METHODS create_payment_disposition
      IMPORTING is_payload   TYPE ty_idoc_payload
      EXPORTING ev_dp_number TYPE c
                et_return    TYPE bapiret2_t.

    "! Update IDoc status after processing (success or error).
    "! @parameter iv_idoc_number | IDoc number
    "! @parameter iv_status      | New status code (e.g. '53' ok / '51' err)
    "! @parameter iv_message     | Status message text
    METHODS update_idoc_status
      IMPORTING iv_idoc_number TYPE edi_docnum
                iv_status      TYPE edi_status
                iv_message     TYPE c.

    "! Trigger outbound IDoc after successful inbound processing.
    "! @parameter is_payload     | Full inbound payload (base for outbound)
    "! @parameter iv_dp_number   | DP number assigned by Sistema Finanziario
    "! @parameter it_return      | Processing return messages to embed in MSG segments
    METHODS trigger_outbound_idoc
      IMPORTING is_payload   TYPE ty_idoc_payload
                iv_dp_number TYPE c
                it_return    TYPE bapiret2_t.

    "! Map a BAPIRET2 message to ty_seg_msg (IDoc message segment).
    "! @parameter is_bapiret2    | Source BAPI return message
    "! @returning VALUE(rs_msg)  | IDoc message segment
    METHODS map_bapiret2_to_msg
      IMPORTING is_bapiret2   TYPE bapiret2
      RETURNING VALUE(rs_msg) TYPE ty_seg_msg.

    "! Check whether a BAPIRET2 table contains any error messages.
    "! @parameter it_return      | BAPI return table
    "! @returning VALUE(rv_error)| TRUE when at least one E/A message exists
    METHODS has_errors
      IMPORTING it_return      TYPE bapiret2_t
      RETURNING VALUE(rv_error) TYPE abap_bool.

ENDCLASS.


CLASS zcl_zs08_idoc_processor IMPLEMENTATION.

  METHOD process_inbound.
    " ----------------------------------------------------------------
    " 1. Authority check
    " ----------------------------------------------------------------
    check_authority( ).

    " ----------------------------------------------------------------
    " 2. Read IDoc control + data records from DB (HANA-optimised)
    " ----------------------------------------------------------------
    DATA: ls_edidc TYPE edidc,
          lt_edidd TYPE edidd_tab.
    read_idoc_data(
      EXPORTING iv_idoc_number = iv_idoc_number
      IMPORTING es_edidc       = ls_edidc
                et_edidd       = lt_edidd ).

    " ----------------------------------------------------------------
    " 3. Parse raw IDoc segments into typed payload
    " ----------------------------------------------------------------
    DATA ls_payload TYPE ty_idoc_payload.
    parse_idoc_segments(
      EXPORTING it_edidd   = lt_edidd
      IMPORTING es_payload = ls_payload ).

    " ----------------------------------------------------------------
    " 4. Validate header business rules
    " ----------------------------------------------------------------
    DATA lt_return TYPE bapiret2_t.
    DATA lv_valid TYPE abap_bool.
    lv_valid = validate_header(
                 EXPORTING is_header   = ls_payload-header
                 CHANGING  ct_messages = lt_return ).

    IF lv_valid = abap_false.
      " Validation failure: update IDoc status to error and stop
      update_idoc_status(
        iv_idoc_number = iv_idoc_number
        iv_status      = '51'
        iv_message     = 'Header validation failed' ).
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>validation_failed
          docnum = iv_idoc_number.
    ENDIF.

    " ----------------------------------------------------------------
    " 5. Create the payment disposition on Sistema Finanziario
    " ----------------------------------------------------------------
    DATA lv_dp_number TYPE c LENGTH 20.
    create_payment_disposition(
      EXPORTING is_payload   = ls_payload
      IMPORTING ev_dp_number = lv_dp_number
                et_return    = lt_return ).

    IF has_errors( lt_return ) = abap_true.
      update_idoc_status(
        iv_idoc_number = iv_idoc_number
        iv_status      = '51'
        iv_message     = 'Error during DP creation' ).
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>dp_creation_failed
          docnum = iv_idoc_number.
    ENDIF.

    " ----------------------------------------------------------------
    " 6. Populate link segment with SF URL / reference
    " ----------------------------------------------------------------
    ls_payload-link-link_sf = lv_dp_number.   " Extend with full URL if needed

    " ----------------------------------------------------------------
    " 7. Trigger outbound IDoc back to ReGiS (ZS08_DP_DIRECTOUT)
    " ----------------------------------------------------------------
    trigger_outbound_idoc(
      iv_dp_number = lv_dp_number
      is_payload   = ls_payload
      it_return    = lt_return ).

    " ----------------------------------------------------------------
    " 8. Set IDoc to status 53 (Application document posted)
    " ----------------------------------------------------------------
    update_idoc_status(
      iv_idoc_number = iv_idoc_number
      iv_status      = '53'
      iv_message     = 'Payment disposition created successfully' ).

    COMMIT WORK AND WAIT.

  ENDMETHOD.


  METHOD check_authority.
    " Authorisation object Z_ZS08_DP - activity 01 (process inbound DP)
    AUTHORITY-CHECK OBJECT 'Z_ZS08_DP'
      ID 'ACTVT' FIELD '01'.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>no_authority.
    ENDIF.
  ENDMETHOD.


  METHOD read_idoc_data.
    " HANA Code-to-Data: read only required columns, exact key lookup
    SELECT SINGLE
        docnum, direct, idoctp, cimtyp, mestyp, mescod,
        mesfct, std,    stdvrs, stdmes, sndprt, sndpor,
        sndpfc, sndprn, sndlad, rcvprt, rcvpor, rcvpfc,
        rcvprn, rcvlad, credat, cretim, outmod, exprss,
        test,   docrel, status, direct, serial
      FROM edidc
      INTO @es_edidc
      WHERE docnum = @iv_idoc_number.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>idoc_not_found
          docnum = iv_idoc_number.
    ENDIF.

    " Retrieve all data segments ordered by hierarchy (SEGNUM ascending)
    SELECT segnum, segnam, mandt, docnum, dtint2, sdata
      FROM edidd
      INTO TABLE @et_edidd
      WHERE docnum = @iv_idoc_number
      ORDER BY segnum.

    IF sy-subrc <> 0 OR et_edidd IS INITIAL.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>no_segments
          docnum = iv_idoc_number.
    ENDIF.
  ENDMETHOD.


  METHOD parse_idoc_segments.
    " ---------------------------------------------------------------
    " Walk through segments in order (SEGNUM ascending, already sorted)
    " and populate the typed payload hierarchy.
    " ---------------------------------------------------------------
    DATA: ls_seg_t       TYPE ty_seg_t,
          ls_seg_link    TYPE ty_seg_link,
          ls_seg_msg     TYPE ty_seg_msg,
          ls_seg_d       TYPE ty_seg_d,
          ls_seg_trib    TYPE ty_seg_trib,
          ls_seg_sic     TYPE ty_seg_sic,
          ls_seg_sictrib TYPE ty_seg_sictrib,
          ls_recipient   TYPE ty_recipient,
          lv_in_recip    TYPE abap_bool VALUE abap_false,
          lv_in_sic      TYPE abap_bool VALUE abap_false.

    LOOP AT it_edidd ASSIGNING FIELD-SYMBOL(<ls_edidd>).
      CASE <ls_edidd>-segnam.

        WHEN gc_segnam_t.
          " Header segment (level 1) — exactly one per IDoc
          ls_seg_t = CORRESPONDING #( <ls_edidd>-sdata ).
          es_payload-header = ls_seg_t.
          lv_in_recip = abap_false.
          lv_in_sic   = abap_false.

        WHEN gc_segnam_link.
          " Link segment (level 1A)
          ls_seg_link = CORRESPONDING #( <ls_edidd>-sdata ).
          es_payload-link = ls_seg_link.

        WHEN gc_segnam_msg.
          " Message segment — context-sensitive child.
          " In inbound IDocs, MSG segments carry feedback/validation info.
          " Append to the nearest active parent message collection.
          ls_seg_msg = CORRESPONDING #( <ls_edidd>-sdata ).
          IF lv_in_recip = abap_true.
            APPEND ls_seg_msg TO ls_recipient-msg_d.
          ELSE.
            APPEND ls_seg_msg TO es_payload-msgs_hdr.
          ENDIF.

        WHEN gc_segnam_d.
          " Recipient segment (level 2): save previous recipient if any
          IF lv_in_recip = abap_true.
            APPEND ls_recipient TO es_payload-recipients.
            CLEAR ls_recipient.
          ENDIF.
          ls_seg_d = CORRESPONDING #( <ls_edidd>-sdata ).
          ls_recipient-seg_d = ls_seg_d.
          lv_in_recip = abap_true.
          lv_in_sic   = abap_false.

        WHEN gc_segnam_trib.
          " Non-SICOGE tribute segment (level 3A)
          ls_seg_trib = CORRESPONDING #( <ls_edidd>-sdata ).
          IF lv_in_recip = abap_true.
            APPEND ls_seg_trib TO ls_recipient-tributes.
          ENDIF.
          lv_in_sic = abap_false.

        WHEN gc_segnam_sic.
          " SICOGE invoice segment (level 3B)
          ls_seg_sic = CORRESPONDING #( <ls_edidd>-sdata ).
          IF lv_in_recip = abap_true.
            APPEND ls_seg_sic TO ls_recipient-sicoge_docs.
          ENDIF.
          lv_in_sic = abap_true.

        WHEN gc_segnam_sictrib.
          " SICOGE invoice tribute segment (level 4)
          ls_seg_sictrib = CORRESPONDING #( <ls_edidd>-sdata ).
          IF lv_in_recip = abap_true AND lv_in_sic = abap_true.
            APPEND ls_seg_sictrib TO ls_recipient-sicoge_tribs.
          ENDIF.

        WHEN OTHERS.
          " Unknown segment — log and continue
          MESSAGE ID 'ZS08' TYPE 'W' NUMBER '001'
            WITH <ls_edidd>-segnam INTO DATA(lv_dummy).

      ENDCASE.
    ENDLOOP.

    " Flush last open recipient block
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

    " Rule 1: Unique DP code must be present
    IF is_header-id_dp IS INITIAL.
      rv_ok = abap_false.
      APPEND VALUE bapiret2(
        type    = 'E'
        id      = 'ZS08'
        number  = '001'
        message = 'ID_DP is mandatory and cannot be blank'
      ) TO ct_messages.
    ENDIF.

    " Rule 2: Total amount must be positive
    IF is_header-zimp_tot <= 0.
      rv_ok = abap_false.
      APPEND VALUE bapiret2(
        type       = 'E'
        id         = 'ZS08'
        number     = '002'
        message    = 'Total amount ZIMP_TOT must be greater than zero'
        message_v1 = CONV #( is_header-id_dp )
      ) TO ct_messages.
    ENDIF.

    " Rule 3: GRANT_NBR must be present
    IF is_header-grant_nbr IS INITIAL.
      rv_ok = abap_false.
      APPEND VALUE bapiret2(
        type       = 'E'
        id         = 'ZS08'
        number     = '003'
        message    = 'GRANT_NBR is mandatory'
        message_v1 = CONV #( is_header-id_dp )
      ) TO ct_messages.
    ENDIF.
  ENDMETHOD.


  METHOD create_payment_disposition.
    " ---------------------------------------------------------------
    " This method orchestrates the creation of a payment disposition
    " (DP) on Sistema Finanziario using the appropriate BAPI/FM.
    " Replace the placeholder call below with the real BAPI when known.
    " ---------------------------------------------------------------
    " In production this would call e.g.:
    "   CALL FUNCTION 'Z_CREATE_DISP_PAGAMENTO'
    "     EXPORTING  is_header     = is_payload-header
    "                it_recipients = is_payload-recipients
    "     IMPORTING  ev_dp_number  = ev_dp_number
    "     TABLES     et_return     = et_return.

    TRY.
        " --- Placeholder: assemble header data ---
        DATA(ls_header) = is_payload-header.

        " Authority check for financial posting
        AUTHORITY-CHECK OBJECT 'Z_ZS08_DP'
          ID 'ACTVT' FIELD '06'.                   " activity 06 = post
        IF sy-subrc <> 0.
          APPEND VALUE bapiret2(
            type    = 'E'
            id      = 'ZS08'
            number  = '010'
            message = 'No authorization to create payment disposition'
          ) TO et_return.
          RETURN.
        ENDIF.

        " Validate each recipient: amounts must not be modified
        LOOP AT is_payload-recipients ASSIGNING FIELD-SYMBOL(<ls_recip>).
          IF <ls_recip>-seg_d-importo <= 0.
            APPEND VALUE bapiret2(
              type       = 'E'
              id         = 'ZS08'
              number     = '011'
              message    = 'Recipient amount must be greater than zero'
              message_v1 = <ls_recip>-seg_d-taxnum
            ) TO et_return.
          ENDIF.
        ENDLOOP.

        IF has_errors( et_return ) = abap_false.
          " TODO: Replace with real BAPI call
          " For now, generate a dummy DP number for illustration
          ev_dp_number = |ZDP{ sy-datum }{ sy-uzeit }|.
          APPEND VALUE bapiret2(
            type    = 'S'
            id      = 'ZS08'
            number  = '020'
            message = |Payment disposition created: { ev_dp_number }|
          ) TO et_return.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        APPEND VALUE bapiret2(
          type    = 'E'
          id      = 'ZS08'
          number  = '099'
          message = lx_root->get_text( )
        ) TO et_return.
    ENDTRY.
  ENDMETHOD.


  METHOD update_idoc_status.
    " Write a status record to EDIDS for the given IDoc
    DATA: lt_status  TYPE STANDARD TABLE OF bdidocstat WITH DEFAULT KEY,
          ls_status  TYPE bdidocstat.

    ls_status-docnum  = iv_idoc_number.
    ls_status-status  = iv_status.
    ls_status-stamid  = 'ZS08'.
    ls_status-stamno  = '000'.
    ls_status-stapa1  = CONV #( iv_message(50) ).
    ls_status-uname   = sy-uname.
    ls_status-repid   = sy-repid.
    ls_status-stamqty = 1.
    APPEND ls_status TO lt_status.

    CALL FUNCTION 'IDOC_STATUS_WRITE_TO_DATABASE'
      TABLES
        idoc_status   = lt_status
      EXCEPTIONS
        db_error      = 1
        OTHERS        = 2.

    IF sy-subrc <> 0.
      " Non-critical: log and continue
      MESSAGE ID 'ZS08' TYPE 'W' NUMBER '002'
        WITH iv_idoc_number iv_status.
    ENDIF.
  ENDMETHOD.


  METHOD trigger_outbound_idoc.
    " ---------------------------------------------------------------
    " Constructs and sends an outbound IDoc of type ZS08_DP_DIRECTOUT
    " back to ReGiS with the processing outcome.
    " ---------------------------------------------------------------
    DATA: lo_outbound TYPE REF TO zcl_zs08_idoc_outbound,
          ls_result   TYPE zcl_zs08_idoc_outbound=>ty_dp_result.

    lo_outbound = NEW zcl_zs08_idoc_outbound( ).

    " Map inbound payload to outbound result
    ls_result-id_dp        = is_payload-header-id_dp.
    ls_result-oggetto_pag  = is_payload-header-oggetto_pag.
    ls_result-grant_nbr    = is_payload-header-grant_nbr.
    ls_result-cod_cup      = is_payload-header-cod_cup.
    ls_result-clp          = is_payload-header-clp.
    ls_result-zdescrizione = is_payload-header-zdescrizione.
    ls_result-zimp_tot     = is_payload-header-zimp_tot.
    ls_result-znumdp       = iv_dp_number.
    ls_result-link_sf      = is_payload-link-link_sf.
    ls_result-zstatodp     = COND #( WHEN has_errors( it_return ) = abap_false
                                     THEN 'OK'
                                     ELSE 'KO' ).
    ls_result-zdata_esito  = sy-datum.

    " Map return messages to header message segments
    LOOP AT it_return ASSIGNING FIELD-SYMBOL(<ls_ret>).
      APPEND map_bapiret2_to_msg( <ls_ret> ) TO ls_result-msgs_hdr.
    ENDLOOP.

    " Map recipients (mirroring inbound, adding SF-computed fields)
    ls_result-recipients = is_payload-recipients.

    TRY.
        lo_outbound->send_idoc( is_result = ls_result ).
      CATCH zcx_zs08_idoc_error INTO DATA(lx_out).
        " Log and continue — outbound failure must not roll back inbound
        MESSAGE lx_out->get_text( ) TYPE 'W'.
    ENDTRY.
  ENDMETHOD.


  METHOD map_bapiret2_to_msg.
    rs_msg-type       = is_bapiret2-type.
    rs_msg-id         = is_bapiret2-id.
    rs_msg-number     = CONV #( is_bapiret2-number ).
    rs_msg-message    = is_bapiret2-message.
    rs_msg-message_v1 = is_bapiret2-message_v1.
    rs_msg-message_v2 = is_bapiret2-message_v2.
    rs_msg-message_v3 = is_bapiret2-message_v3.
    rs_msg-message_v4 = is_bapiret2-message_v4.
  ENDMETHOD.


  METHOD has_errors.
    rv_error = COND #(
      WHEN line_exists( it_return[ type = 'E' ] ) OR
           line_exists( it_return[ type = 'A' ] )
      THEN abap_true
      ELSE abap_false ).
  ENDMETHOD.

ENDCLASS.
