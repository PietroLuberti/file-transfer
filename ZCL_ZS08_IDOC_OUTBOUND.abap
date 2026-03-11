*&---------------------------------------------------------------------*
*& Class: ZCL_ZS08_IDOC_OUTBOUND
*& Purpose: Builds and distributes an outbound IDoc ZS08_ZPRDISPSF_DIRECTOUT
*&          from a structured payload (ty_idoc_payload).
*&
*& NOTE: Before activating, ensure message type ZS08_ZPRDISPSF_DIRECTOUT
*&       and the corresponding partner profile (WE20) are configured.
*&       Also add the constant IDOC_SEND_FAILED to ZCX_ZS08_IDOC_ERROR.
*&---------------------------------------------------------------------*
CLASS zcl_zs08_idoc_outbound DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "! Nested structure for a SICTRIB (invoice-level tribute) segment.
    TYPES:
      BEGIN OF ty_sictrib,
        sictrib     TYPE zs08_zprdispsf_sictrib,
        sictrib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_sictrib_msg WITH DEFAULT KEY,
      END OF ty_sictrib.

    "! Nested structure for a SIC (single-invoice contribution) segment
    "! together with its child SICTRIB entries.
    TYPES:
      BEGIN OF ty_sic,
        sic      TYPE zs08_zprdispsf_sic,
        sic_msg  TYPE STANDARD TABLE OF zs08_zprdispsf_sic_msg WITH DEFAULT KEY,
        sictribs TYPE STANDARD TABLE OF ty_sictrib WITH DEFAULT KEY,
      END OF ty_sic.

    "! Nested structure for a D_TRIB (recipient-level tribute) segment.
    TYPES:
      BEGIN OF ty_d_trib,
        d_trib     TYPE zs08_zprdispsf_d_trib,
        d_trib_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_trib_msg WITH DEFAULT KEY,
      END OF ty_d_trib.

    "! Full recipient block: D segment + child D_TRIB and SIC entries.
    TYPES:
      BEGIN OF ty_recipient,
        seg_d     TYPE zs08_zprdispsf_d,
        seg_d_msg TYPE STANDARD TABLE OF zs08_zprdispsf_d_msg WITH DEFAULT KEY,
        d_tribs   TYPE STANDARD TABLE OF ty_d_trib WITH DEFAULT KEY,
        sics      TYPE STANDARD TABLE OF ty_sic WITH DEFAULT KEY,
      END OF ty_recipient.

    "! Root payload structure mirroring the inbound counterpart
    "! (ZCL_ZS08_ZPRDISPSF_IDOC_PROCES=>TY_IDOC_PAYLOAD).
    TYPES:
      BEGIN OF ty_idoc_payload,
        header     TYPE zs08_zprdispsf_t,
        link       TYPE zs08_zprdispsf_t_link,
        header_msg TYPE STANDARD TABLE OF zs08_zprdispsf_t_msg WITH DEFAULT KEY,
        recipients TYPE STANDARD TABLE OF ty_recipient WITH DEFAULT KEY,
      END OF ty_idoc_payload.

    "! Generates and distributes a single outbound IDoc from the supplied payload.
    "! @parameter is_payload     | Fully-populated IDoc payload
    "! @parameter ev_idoc_number | Document number assigned to the created IDoc
    "! @raising   zcx_zs08_idoc_error | Authority, data, or ALE distribution error
    METHODS generate_outbound_idoc
      IMPORTING
        !is_payload     TYPE ty_idoc_payload
      EXPORTING
        !ev_idoc_number TYPE edi_docnum
      RAISING
        zcx_zs08_idoc_error.

  PRIVATE SECTION.

    CONSTANTS gc_segnam_t       TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_T'         ##NO_TEXT.
    CONSTANTS gc_segnam_t_link  TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_T_LINK'    ##NO_TEXT.
    CONSTANTS gc_segnam_d       TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_D'         ##NO_TEXT.
    CONSTANTS gc_segnam_d_trib  TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_D_TRIB'    ##NO_TEXT.
    CONSTANTS gc_segnam_sic     TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_SIC'       ##NO_TEXT.
    CONSTANTS gc_segnam_sictrib TYPE edilsegtyp VALUE 'ZS08_ZPRDISPSF_SICTRIB'   ##NO_TEXT.
    CONSTANTS gc_msgty_out      TYPE edi_mestyp VALUE 'ZS08_ZPRDISPSF_DIRECTOUT' ##NO_TEXT.
    CONSTANTS gc_idoc_type      TYPE edi_idoctp VALUE 'ZPRDISPSF'                ##NO_TEXT.
    CONSTANTS gc_rcvprt_ls      TYPE edi_prt    VALUE 'LS'                       ##NO_TEXT. " Logical System

    "! Verifies that the calling user holds the required authorization.
    "! @raising zcx_zs08_idoc_error | Authorization failure
    METHODS check_authority
      RAISING
        zcx_zs08_idoc_error.

    "! Builds the IDoc master-control record (EDIDC) from the payload header.
    "! @parameter is_payload | IDoc payload
    "! @parameter rs_edidc   | Populated control record
    METHODS build_control_record
      IMPORTING
        !is_payload     TYPE ty_idoc_payload
      RETURNING
        VALUE(rs_edidc) TYPE edidc.

    "! Converts the hierarchical payload into a flat sequence of EDIDD segments.
    "! Segment order follows IDoc type ZPRDISPSF:
    "!   T → [T_LINK] → (D → [D_TRIB*] → [SIC → [SICTRIB*]]*)*
    "! @parameter is_payload | IDoc payload
    "! @parameter rt_edidd   | Table of IDoc data segments
    METHODS build_idoc_segments
      IMPORTING
        !is_payload     TYPE ty_idoc_payload
      RETURNING
        VALUE(rt_edidd) TYPE edidd_tt.

    "! Calls MASTER_IDOC_DISTRIBUTE to create and schedule the outbound IDoc.
    "! @parameter is_control     | Populated IDoc control record
    "! @parameter it_data        | Populated EDIDD segment table
    "! @parameter ev_idoc_number | Assigned IDoc document number
    "! @raising   zcx_zs08_idoc_error | ALE distribution error
    METHODS send_idoc
      IMPORTING
        !is_control     TYPE edidc
        !it_data        TYPE edidd_tt
      EXPORTING
        !ev_idoc_number TYPE edi_docnum
      RAISING
        zcx_zs08_idoc_error.

ENDCLASS.



CLASS zcl_zs08_idoc_outbound IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_IDOC_OUTBOUND->CHECK_AUTHORITY
* +-------------------------------------------------------------------------------------------------+
* | [!CX!] ZCX_ZS08_IDOC_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD check_authority.
    " Activate when authorization object Z_ZS08_DP is available in the system.
    " Activity '16' = Execute (outbound generation).
*    AUTHORITY-CHECK OBJECT 'Z_ZS08_DP'
*      ID 'ACTVT' FIELD '16'.
*    IF sy-subrc <> 0.
*      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
*        EXPORTING
*          textid = zcx_zs08_idoc_error=>no_authority.
*    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_IDOC_OUTBOUND->BUILD_CONTROL_RECORD
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_PAYLOAD                     TYPE        TY_IDOC_PAYLOAD
* | [<-()] RS_EDIDC                       TYPE        EDIDC
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD build_control_record.
    CLEAR rs_edidc.
    rs_edidc-direct = '1'.             " 1 = Outbound
    rs_edidc-mestyp = gc_msgty_out.
    rs_edidc-idoctp = gc_idoc_type.
    rs_edidc-rcvprt = gc_rcvprt_ls.    " Receiver partner type: Logical System
    " rcvprn (receiver partner number) and rcvpfc are resolved by the
    " partner profile configured in WE20 for message type gc_msgty_out.
    " The sending logical system (sndprn/sndprt) is filled automatically
    " by MASTER_IDOC_DISTRIBUTE using the own logical system.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_IDOC_OUTBOUND->BUILD_IDOC_SEGMENTS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_PAYLOAD                     TYPE        TY_IDOC_PAYLOAD
* | [<-()] RT_EDIDD                       TYPE        EDIDD_TT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD build_idoc_segments.
    DATA ls_edidd TYPE edidd.

    CLEAR rt_edidd.

    " ── Segment T (header) ──────────────────────────────────────────────
    CLEAR ls_edidd.
    ls_edidd-segnam = gc_segnam_t.
    ls_edidd-sdata  = is_payload-header.
    APPEND ls_edidd TO rt_edidd.

    " ── Optional segment T_LINK ─────────────────────────────────────────
    IF is_payload-link IS NOT INITIAL.
      CLEAR ls_edidd.
      ls_edidd-segnam = gc_segnam_t_link.
      ls_edidd-sdata  = is_payload-link.
      APPEND ls_edidd TO rt_edidd.
    ENDIF.

    " ── Recipient segments (D / D_TRIB / SIC / SICTRIB) ─────────────────
    LOOP AT is_payload-recipients ASSIGNING FIELD-SYMBOL(<ls_recip>).

      " Segment D (recipient header)
      CLEAR ls_edidd.
      ls_edidd-segnam = gc_segnam_d.
      ls_edidd-sdata  = <ls_recip>-seg_d.
      APPEND ls_edidd TO rt_edidd.

      " Segments D_TRIB (recipient-level tributes)
      LOOP AT <ls_recip>-d_tribs ASSIGNING FIELD-SYMBOL(<ls_dtrib>).
        CLEAR ls_edidd.
        ls_edidd-segnam = gc_segnam_d_trib.
        ls_edidd-sdata  = <ls_dtrib>-d_trib.
        APPEND ls_edidd TO rt_edidd.
      ENDLOOP.

      " Segments SIC (invoices) and their SICTRIB children
      LOOP AT <ls_recip>-sics ASSIGNING FIELD-SYMBOL(<ls_sic>).

        CLEAR ls_edidd.
        ls_edidd-segnam = gc_segnam_sic.
        ls_edidd-sdata  = <ls_sic>-sic.
        APPEND ls_edidd TO rt_edidd.

        LOOP AT <ls_sic>-sictribs ASSIGNING FIELD-SYMBOL(<ls_strib>).
          CLEAR ls_edidd.
          ls_edidd-segnam = gc_segnam_sictrib.
          ls_edidd-sdata  = <ls_strib>-sictrib.
          APPEND ls_edidd TO rt_edidd.
        ENDLOOP.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCL_ZS08_IDOC_OUTBOUND->SEND_IDOC
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_CONTROL                     TYPE        EDIDC
* | [--->] IT_DATA                        TYPE        EDIDD_TT
* | [<---] EV_IDOC_NUMBER                 TYPE        EDI_DOCNUM
* | [!CX!] ZCX_ZS08_IDOC_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD send_idoc.
    DATA lt_comm_numbers TYPE STANDARD TABLE OF edidc WITH DEFAULT KEY.

    CLEAR ev_idoc_number.

    CALL FUNCTION 'MASTER_IDOC_DISTRIBUTE'
      EXPORTING
        master_idoc_control            = is_control
      TABLES
        communication_idoc_number      = lt_comm_numbers
        master_idoc_data               = it_data
      EXCEPTIONS
        error_in_idoc_control          = 1
        error_writing_idoc_status      = 2
        error_in_idoc_data             = 3
        sending_logical_system_unknown = 4
        OTHERS                         = 5.

    IF sy-subrc <> 0.
      " TODO: add constant IDOC_SEND_FAILED to ZCX_ZS08_IDOC_ERROR and
      "       replace DP_CREATION_FAILED below with IDOC_SEND_FAILED.
      RAISE EXCEPTION TYPE zcx_zs08_idoc_error
        EXPORTING
          textid = zcx_zs08_idoc_error=>dp_creation_failed.
    ENDIF.

    " Return the document number of the first (and typically only) created IDoc.
    READ TABLE lt_comm_numbers INTO DATA(ls_comm) INDEX 1.
    IF sy-subrc = 0.
      ev_idoc_number = ls_comm-docnum.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCL_ZS08_IDOC_OUTBOUND->GENERATE_OUTBOUND_IDOC
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_PAYLOAD                     TYPE        TY_IDOC_PAYLOAD
* | [<---] EV_IDOC_NUMBER                 TYPE        EDI_DOCNUM
* | [!CX!] ZCX_ZS08_IDOC_ERROR
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD generate_outbound_idoc.

    CLEAR ev_idoc_number.

    me->check_authority( ).

    DATA(ls_control) = me->build_control_record( is_payload ).
    DATA(lt_data)    = me->build_idoc_segments(  is_payload ).

    me->send_idoc(
      EXPORTING
        is_control     = ls_control
        it_data        = lt_data
      IMPORTING
        ev_idoc_number = ev_idoc_number ).

    COMMIT WORK AND WAIT.

  ENDMETHOD.

ENDCLASS.
