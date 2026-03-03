*&---------------------------------------------------------------------*
*& Class: ZCL_ZS08_IDOC_OUTBOUND
*& IDoc ZS08 - Payment Disposition (Disposizione di Pagamento)
*& Outbound IDoc creation: send processing result back to ReGiS
*& Message types: ZS08_DP_DIRECTOUT (full) / ZS08_DP_DIRECTOUT_T (header only)
*& IDoc type: ZPRDISPSF
*&
*& Architecture notes:
*&   - Builds IDoc data segments from typed result structure.
*&   - Uses MASTER_IDOC_DISTRIBUTE to hand off to ALE/EDI layer.
*&   - HANA-optimised: only reads partner profile when needed.
*&   - Full authority check; exception class ZCX_ZS08_IDOC_ERROR.
*&---------------------------------------------------------------------*
CLASS zcl_zs08_idoc_outbound DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Outbound payload type: all data that SF adds on top of the inbound fields
    TYPES:
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

      "! SICOGE invoice tribute — must be defined before ty_sic_out
      BEGIN OF ty_sictrib_out,
        cod_tributo       TYPE c LENGTH 10,
        chiave_banca      TYPE c LENGTH 15,
        codice_gestionale TYPE c LENGTH 10,
        trib_pag          TYPE p LENGTH 9 DECIMALS 2,
        znumopf           TYPE n LENGTH 10,
        zstatoopf         TYPE c LENGTH 3,
        zcroquiet         TYPE d,
        zdata_opf         TYPE n LENGTH 30,
        importo_pag_opf   TYPE p LENGTH 9 DECIMALS 2,
      END OF ty_sictrib_out,

      "! Non-SICOGE tribute — must be defined before ty_recip_out
      BEGIN OF ty_trib_out,
        cod_tributo       TYPE c LENGTH 10,
        chiave_banca      TYPE c LENGTH 15,
        codice_gestionale TYPE c LENGTH 10,
        importo           TYPE p LENGTH 9 DECIMALS 2,
        znumopf           TYPE n LENGTH 10,
        zstatoopf         TYPE c LENGTH 3,
        zcroquiet         TYPE d,
        zdata_opf         TYPE n LENGTH 30,
        importo_pag_opf   TYPE p LENGTH 9 DECIMALS 2,
      END OF ty_trib_out,

      "! SICOGE invoice — must be defined before ty_recip_out
      BEGIN OF ty_sic_out,
        id_fattura        TYPE c LENGTH 20,
        data_pag          TYPE d,
        num_fattura       TYPE c LENGTH 40,
        importo           TYPE p LENGTH 9 DECIMALS 2,
        impivapag         TYPE p LENGTH 9 DECIMALS 2,
        msgs              TYPE STANDARD TABLE OF ty_seg_msg WITH DEFAULT KEY,
        sictribs          TYPE STANDARD TABLE OF ty_sictrib_out WITH DEFAULT KEY,
      END OF ty_sic_out,

      BEGIN OF ty_recip_out,
        " --- fields from inbound mirrored ---
        ziban             TYPE c LENGTH 34,
        numero_tes        TYPE c LENGTH 15,
        taxnum            TYPE c LENGTH 20,
        cod_bp_sf         TYPE c LENGTH 10,
        cig               TYPE c LENGTH 30,
        nota_dest         TYPE c LENGTH 1000,
        codice_gestionale TYPE c LENGTH 10,
        importo           TYPE p LENGTH 9 DECIMALS 2,
        zflag             TYPE c LENGTH 1,
        " --- fields added by SF ---
        znumopf           TYPE n LENGTH 10,
        zstatoopf         TYPE c LENGTH 3,
        zerrore           TYPE c LENGTH 1000,
        zdataopf          TYPE d,
        zcroquiet         TYPE n LENGTH 30,
        zimpagopf         TYPE p LENGTH 10 DECIMALS 2,
        " --- child segments ---
        msgs              TYPE STANDARD TABLE OF ty_seg_msg WITH DEFAULT KEY,
        tributes          TYPE STANDARD TABLE OF ty_trib_out WITH DEFAULT KEY,
        sicoge_docs       TYPE STANDARD TABLE OF ty_sic_out WITH DEFAULT KEY,
      END OF ty_recip_out,

      "! Full outbound DP result type
      BEGIN OF ty_dp_result,
        " Header (ZPRDISPSF_T outbound)
        id_dp        TYPE c LENGTH 10,
        oggetto_pag  TYPE c LENGTH 50,
        grant_nbr    TYPE c LENGTH 20,
        cod_cup      TYPE c LENGTH 15,
        clp          TYPE c LENGTH 80,
        zdescrizione TYPE c LENGTH 1000,
        zimp_tot     TYPE p LENGTH 9 DECIMALS 2,
        zdata_esito  TYPE d,
        znumdp       TYPE c LENGTH 20,
        zstatodp     TYPE c LENGTH 2,
        " Link (ZPRDISPSF_LINK)
        link_sf      TYPE c LENGTH 1000,
        " Messages for header (ZPRDISPSF_MSG, level 1B)
        msgs_hdr     TYPE STANDARD TABLE OF ty_seg_msg WITH DEFAULT KEY,
        " Recipient blocks (ZPRDISPSF_D and children)
        recipients   TYPE STANDARD TABLE OF ty_recip_out WITH DEFAULT KEY,
      END OF ty_dp_result.

    "! Build and dispatch the outbound IDoc for one payment disposition.
    "! @parameter is_result          | Full DP result (header + recipients)
    "! @parameter iv_rcvprn          | Receiver partner number (default = ReGiS port)
    "! @raising   zcx_zs08_idoc_error | Raised when IDoc dispatch fails
    METHODS send_idoc
      IMPORTING is_result TYPE ty_dp_result
                iv_rcvprn TYPE edi_rcvprn OPTIONAL
      RAISING   zcx_zs08_idoc_error.

  PRIVATE SECTION.

    CONSTANTS:
      gc_idoctp         TYPE edi_idoctp  VALUE 'ZPRDISPSF',
      gc_mestyp_full    TYPE edi_mestyp  VALUE 'ZS08_DP_DIRECTOUT',
      gc_mestyp_header  TYPE edi_mestyp  VALUE 'ZS08_DP_DIRECTOUT_T',
      gc_sndprn         TYPE edi_sndprn  VALUE 'SFINANZIARIO',  " adjust to real logical system
      gc_sndprt         TYPE edi_sndprt  VALUE 'LS',
      gc_rcvprt         TYPE edi_rcvprt  VALUE 'LS',
      gc_segnam_t       TYPE edilsegtyp  VALUE 'ZPRDISPSF_T',
      gc_segnam_link    TYPE edilsegtyp  VALUE 'ZPRDISPSF_LINK',
      gc_segnam_msg     TYPE edilsegtyp  VALUE 'ZPRDISPSF_MSG',
      gc_segnam_d       TYPE edilsegtyp  VALUE 'ZPRDISPSF_D',
      gc_segnam_trib    TYPE edilsegtyp  VALUE 'ZPRDISPSF_TRIB',
      gc_segnam_sic     TYPE edilsegtyp  VALUE 'ZPRDISPSF_SIC',
      gc_segnam_sictrib TYPE edilsegtyp  VALUE 'ZPRDISPSF_SICTRIB'.

    "! Build the IDoc control record (EDIDC) for the outbound message.
    "! @parameter iv_mestyp     | Message type (full or header-only)
    "! @parameter iv_rcvprn     | Receiver partner number
    "! @returning VALUE(rs_ctl) | Populated control record
    METHODS build_control_record
      IMPORTING iv_mestyp     TYPE edi_mestyp
                iv_rcvprn     TYPE edi_rcvprn
      RETURNING VALUE(rs_ctl) TYPE edidc.

    "! Build all IDoc data segments (EDIDD) for the given result.
    "! @parameter is_result    | DP result payload
    "! @parameter iv_full      | TRUE = include recipient segments
    "! @returning VALUE(rt_dd) | Ordered list of data records
    METHODS build_data_segments
      IMPORTING is_result    TYPE ty_dp_result
                iv_full      TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(rt_dd) TYPE edidd_tab.

    "! Append one EDIDD record to the segment table.
    "! @parameter iv_segnam  | Segment name
    "! @parameter is_sdata   | Segment data (any flat structure ≤ 1000 chars)
    "! @changing  ct_edidd   | Target EDIDD table (segment appended here)
    METHODS append_segment
      IMPORTING iv_segnam TYPE edilsegtyp
                is_sdata  TYPE any
      CHANGING  ct_edidd  TYPE edidd_tab.

ENDCLASS.


CLASS zcl_zs08_idoc_outbound IMPLEMENTATION.

  METHOD send_idoc.
    " ---------------------------------------------------------------
    " Authority check: outbound posting requires activity 02 (send)
    " ---------------------------------------------------------------
    AUTHORITY-CHECK OBJECT 'Z_ZS08_DP'
      ID 'ACTVT' FIELD '02'.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING textid = zcx_zs08_idoc_error=>no_authority.
    ENDIF.

    DATA lv_rcvprn TYPE edi_rcvprn.
    lv_rcvprn = COND #( WHEN iv_rcvprn IS SUPPLIED AND iv_rcvprn IS NOT INITIAL
                        THEN iv_rcvprn
                        ELSE 'REGIS' ).          " default ReGiS partner

    " ---------------------------------------------------------------
    " Determine message type:
    "   ZS08_DP_DIRECTOUT_T  – header only (no recipient segments)
    "   ZS08_DP_DIRECTOUT    – full payload (all segments)
    " If status is KO (entire DP failed) we send only header message type.
    " ---------------------------------------------------------------
    DATA lv_mestyp TYPE edi_mestyp.
    DATA lv_full   TYPE abap_bool.
    IF is_result-zstatodp = 'KO' AND is_result-recipients IS INITIAL.
      lv_mestyp = gc_mestyp_header.
      lv_full   = abap_false.
    ELSE.
      lv_mestyp = gc_mestyp_full.
      lv_full   = abap_true.
    ENDIF.

    " ---------------------------------------------------------------
    " Build control record and data segments
    " ---------------------------------------------------------------
    DATA ls_ctl TYPE edidc.
    ls_ctl = build_control_record(
               iv_mestyp = lv_mestyp
               iv_rcvprn = lv_rcvprn ).

    DATA lt_dd TYPE edidd_tab.
    lt_dd = build_data_segments(
               is_result = is_result
               iv_full   = lv_full ).

    " ---------------------------------------------------------------
    " Dispatch IDoc via ALE/EDI standard FM
    " ---------------------------------------------------------------
    TRY.
        CALL FUNCTION 'MASTER_IDOC_DISTRIBUTE'
          EXPORTING  master_idoc_control             = ls_ctl
          TABLES     communication_idoc_control      = DATA(lt_comm_ctl)
                     master_idoc_data                = lt_dd
          EXCEPTIONS error_in_idoc_control           = 1
                     error_writing_idoc_status       = 2
                     error_in_idoc_data              = 3
                     sending_logical_system_unknown  = 4
                     OTHERS                          = 5.

        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_zs08_idoc_error
            EXPORTING
              textid   = zcx_zs08_idoc_error=>idoc_dispatch_failed
              sysubrc  = sy-subrc.
        ENDIF.

        COMMIT WORK AND WAIT.

      CATCH cx_root INTO DATA(lx_root).
        RAISE EXCEPTION TYPE zcx_zs08_idoc_error
          EXPORTING
            textid = zcx_zs08_idoc_error=>idoc_dispatch_failed
            text1  = lx_root->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD build_control_record.
    rs_ctl-idoctp  = gc_idoctp.
    rs_ctl-mestyp  = iv_mestyp.
    rs_ctl-sndprt  = gc_sndprt.
    rs_ctl-sndprn  = gc_sndprn.
    rs_ctl-rcvprt  = gc_rcvprt.
    rs_ctl-rcvprn  = iv_rcvprn.
    rs_ctl-direct  = '1'.        " 1 = outbound
    rs_ctl-credat  = sy-datum.
    rs_ctl-cretim  = sy-uzeit.
  ENDMETHOD.


  METHOD build_data_segments.
    " ---------------------------------------------------------------
    " Segment 1: Header (ZPRDISPSF_T) — mandatory
    " ---------------------------------------------------------------
    DATA: BEGIN OF ls_t_out,
            id_dp        TYPE c LENGTH 10,
            oggetto_pag  TYPE c LENGTH 50,
            grant_nbr    TYPE c LENGTH 20,
            cod_cup      TYPE c LENGTH 15,
            clp          TYPE c LENGTH 80,
            zdescrizione TYPE c LENGTH 1000,
            zimp_tot     TYPE p LENGTH 9 DECIMALS 2,
            zdata_esito  TYPE d,
            znumdp       TYPE c LENGTH 20,
            zstatodp     TYPE c LENGTH 2,
          END OF ls_t_out.

    ls_t_out-id_dp        = is_result-id_dp.
    ls_t_out-oggetto_pag  = is_result-oggetto_pag.
    ls_t_out-grant_nbr    = is_result-grant_nbr.
    ls_t_out-cod_cup      = is_result-cod_cup.
    ls_t_out-clp          = is_result-clp.
    ls_t_out-zdescrizione = is_result-zdescrizione.
    ls_t_out-zimp_tot     = is_result-zimp_tot.
    ls_t_out-zdata_esito  = is_result-zdata_esito.
    ls_t_out-znumdp       = is_result-znumdp.
    ls_t_out-zstatodp     = is_result-zstatodp.
    append_segment( EXPORTING iv_segnam = gc_segnam_t  is_sdata = ls_t_out
                    CHANGING  ct_edidd  = rt_dd ).

    " ---------------------------------------------------------------
    " Segment 1A: Link (ZPRDISPSF_LINK)
    " ---------------------------------------------------------------
    DATA: BEGIN OF ls_link_out,
            link_sf TYPE c LENGTH 1000,
          END OF ls_link_out.
    ls_link_out-link_sf = is_result-link_sf.
    append_segment( EXPORTING iv_segnam = gc_segnam_link  is_sdata = ls_link_out
                    CHANGING  ct_edidd  = rt_dd ).

    " ---------------------------------------------------------------
    " Segments 1B: Header messages (ZPRDISPSF_MSG, 0..N)
    " ---------------------------------------------------------------
    LOOP AT is_result-msgs_hdr ASSIGNING FIELD-SYMBOL(<ls_msg_hdr>).
      append_segment( EXPORTING iv_segnam = gc_segnam_msg  is_sdata = <ls_msg_hdr>
                      CHANGING  ct_edidd  = rt_dd ).
    ENDLOOP.

    " ---------------------------------------------------------------
    " For header-only message type stop here
    " ---------------------------------------------------------------
    IF iv_full = abap_false.
      RETURN.
    ENDIF.

    " ---------------------------------------------------------------
    " Segments 2..4: Recipient blocks
    " ---------------------------------------------------------------
    LOOP AT is_result-recipients ASSIGNING FIELD-SYMBOL(<ls_recip>).

      " Segment 2: Recipient (ZPRDISPSF_D outbound)
      DATA: BEGIN OF ls_d_out,
              ziban             TYPE c LENGTH 34,
              numero_tes        TYPE c LENGTH 15,
              taxnum            TYPE c LENGTH 20,
              cod_bp_sf         TYPE c LENGTH 10,
              cig               TYPE c LENGTH 30,
              nota_dest         TYPE c LENGTH 1000,
              codice_gestionale TYPE c LENGTH 10,
              importo           TYPE p LENGTH 9 DECIMALS 2,
              zflag             TYPE c LENGTH 1,
              znumopf           TYPE n LENGTH 10,
              zstatoopf         TYPE c LENGTH 3,
              zerrore           TYPE c LENGTH 1000,
              zdataopf          TYPE d,
              zcroquiet         TYPE n LENGTH 30,
              zimpagopf         TYPE p LENGTH 10 DECIMALS 2,
            END OF ls_d_out.

      ls_d_out-ziban             = <ls_recip>-ziban.
      ls_d_out-numero_tes        = <ls_recip>-numero_tes.
      ls_d_out-taxnum            = <ls_recip>-taxnum.
      ls_d_out-cod_bp_sf         = <ls_recip>-cod_bp_sf.
      ls_d_out-cig               = <ls_recip>-cig.
      ls_d_out-nota_dest         = <ls_recip>-nota_dest.
      ls_d_out-codice_gestionale = <ls_recip>-codice_gestionale.
      ls_d_out-importo           = <ls_recip>-importo.
      ls_d_out-zflag             = <ls_recip>-zflag.
      ls_d_out-znumopf           = <ls_recip>-znumopf.
      ls_d_out-zstatoopf         = <ls_recip>-zstatoopf.
      ls_d_out-zerrore           = <ls_recip>-zerrore.
      ls_d_out-zdataopf          = <ls_recip>-zdataopf.
      ls_d_out-zcroquiet         = <ls_recip>-zcroquiet.
      ls_d_out-zimpagopf         = <ls_recip>-zimpagopf.
      append_segment( EXPORTING iv_segnam = gc_segnam_d  is_sdata = ls_d_out
                      CHANGING  ct_edidd  = rt_dd ).

      " Segment 2A: Recipient messages
      LOOP AT <ls_recip>-msgs ASSIGNING FIELD-SYMBOL(<ls_msg_d>).
        append_segment( EXPORTING iv_segnam = gc_segnam_msg  is_sdata = <ls_msg_d>
                        CHANGING  ct_edidd  = rt_dd ).
      ENDLOOP.

      " Segment 3A: Non-SICOGE tributes
      LOOP AT <ls_recip>-tributes ASSIGNING FIELD-SYMBOL(<ls_trib>).
        DATA: BEGIN OF ls_trib_out,
                cod_tributo       TYPE c LENGTH 10,
                chiave_banca      TYPE c LENGTH 15,
                codice_gestionale TYPE c LENGTH 10,
                importo           TYPE p LENGTH 9 DECIMALS 2,
                znumopf           TYPE n LENGTH 10,
                zstatoopf         TYPE c LENGTH 3,
                zcroquiet         TYPE d,
                zdata_opf         TYPE n LENGTH 30,
                importo_pag_opf   TYPE p LENGTH 9 DECIMALS 2,
              END OF ls_trib_out.
        ls_trib_out-cod_tributo       = <ls_trib>-cod_tributo.
        ls_trib_out-chiave_banca      = <ls_trib>-chiave_banca.
        ls_trib_out-codice_gestionale = <ls_trib>-codice_gestionale.
        ls_trib_out-importo           = <ls_trib>-importo.
        ls_trib_out-znumopf           = <ls_trib>-znumopf.
        ls_trib_out-zstatoopf         = <ls_trib>-zstatoopf.
        ls_trib_out-zcroquiet         = <ls_trib>-zcroquiet.
        ls_trib_out-zdata_opf         = <ls_trib>-zdata_opf.
        ls_trib_out-importo_pag_opf   = <ls_trib>-importo_pag_opf.
        append_segment( EXPORTING iv_segnam = gc_segnam_trib  is_sdata = ls_trib_out
                        CHANGING  ct_edidd  = rt_dd ).
        CLEAR ls_trib_out.
      ENDLOOP.

      " Segment 3B: SICOGE invoices
      LOOP AT <ls_recip>-sicoge_docs ASSIGNING FIELD-SYMBOL(<ls_sic>).
        DATA: BEGIN OF ls_sic_out,
                id_fattura  TYPE c LENGTH 20,
                data_pag    TYPE d,
                num_fattura TYPE c LENGTH 40,
                importo     TYPE p LENGTH 9 DECIMALS 2,
                impivapag   TYPE p LENGTH 9 DECIMALS 2,
              END OF ls_sic_out.
        ls_sic_out-id_fattura  = <ls_sic>-id_fattura.
        ls_sic_out-data_pag    = <ls_sic>-data_pag.
        ls_sic_out-num_fattura = <ls_sic>-num_fattura.
        ls_sic_out-importo     = <ls_sic>-importo.
        ls_sic_out-impivapag   = <ls_sic>-impivapag.
        append_segment( EXPORTING iv_segnam = gc_segnam_sic  is_sdata = ls_sic_out
                        CHANGING  ct_edidd  = rt_dd ).
        CLEAR ls_sic_out.

        " Segment 3B1: SICOGE invoice messages
        LOOP AT <ls_sic>-msgs ASSIGNING FIELD-SYMBOL(<ls_msg_sic>).
          append_segment( EXPORTING iv_segnam = gc_segnam_msg  is_sdata = <ls_msg_sic>
                          CHANGING  ct_edidd  = rt_dd ).
        ENDLOOP.

        " Segment 4: SICOGE invoice tributes
        LOOP AT <ls_sic>-sictribs ASSIGNING FIELD-SYMBOL(<ls_sictrib>).
          DATA: BEGIN OF ls_sictrib_out,
                  cod_tributo       TYPE c LENGTH 10,
                  chiave_banca      TYPE c LENGTH 15,
                  codice_gestionale TYPE c LENGTH 10,
                  trib_pag          TYPE p LENGTH 9 DECIMALS 2,
                  znumopf           TYPE n LENGTH 10,
                  zstatoopf         TYPE c LENGTH 3,
                  zcroquiet         TYPE d,
                  zdata_opf         TYPE n LENGTH 30,
                  importo_pag_opf   TYPE p LENGTH 9 DECIMALS 2,
                END OF ls_sictrib_out.
          ls_sictrib_out-cod_tributo       = <ls_sictrib>-cod_tributo.
          ls_sictrib_out-chiave_banca      = <ls_sictrib>-chiave_banca.
          ls_sictrib_out-codice_gestionale = <ls_sictrib>-codice_gestionale.
          ls_sictrib_out-trib_pag          = <ls_sictrib>-trib_pag.
          ls_sictrib_out-znumopf           = <ls_sictrib>-znumopf.
          ls_sictrib_out-zstatoopf         = <ls_sictrib>-zstatoopf.
          ls_sictrib_out-zcroquiet         = <ls_sictrib>-zcroquiet.
          ls_sictrib_out-zdata_opf         = <ls_sictrib>-zdata_opf.
          ls_sictrib_out-importo_pag_opf   = <ls_sictrib>-importo_pag_opf.
          append_segment( EXPORTING iv_segnam = gc_segnam_sictrib  is_sdata = ls_sictrib_out
                          CHANGING  ct_edidd  = rt_dd ).
          CLEAR ls_sictrib_out.
        ENDLOOP.

        " Segment 4A: SICOGE tribute messages
        " (reused ZPRDISPSF_MSG as child of SICTRIB — add here if needed)

      ENDLOOP.  " sicoge_docs

      CLEAR: ls_d_out.
    ENDLOOP.  " recipients

  ENDMETHOD.


  METHOD append_segment.
    DATA ls_edidd TYPE edidd.
    ls_edidd-segnam = iv_segnam.
    " Move segment data into the 1000-char SDATA field
    ls_edidd-sdata  = is_sdata.
    APPEND ls_edidd TO ct_edidd.
  ENDMETHOD.

ENDCLASS.
