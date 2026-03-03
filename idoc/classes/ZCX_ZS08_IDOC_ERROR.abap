*&---------------------------------------------------------------------*
*& Class: ZCX_ZS08_IDOC_ERROR
*& Custom exception class for IDoc ZS08 processing errors.
*& All exception texts must be maintained in SE91 under message class ZS08.
*&---------------------------------------------------------------------*
CLASS zcx_zs08_idoc_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.
    INTERFACES if_t100_dyn_msg.

    "! Exception identifiers — each maps to a T100 message in class ZS08
    CLASS-DATA:
      "! No authority to process payment IDoc
      no_authority         TYPE scx_t100key VALUE IS INITIAL,
      "! IDoc document number not found in EDIDC
      idoc_not_found       TYPE scx_t100key VALUE IS INITIAL,
      "! IDoc has no data segments in EDIDD
      no_segments          TYPE scx_t100key VALUE IS INITIAL,
      "! Header segment ZPRDISPSF_T is missing
      missing_header_segment TYPE scx_t100key VALUE IS INITIAL,
      "! Header business validation failed (see return table for details)
      validation_failed    TYPE scx_t100key VALUE IS INITIAL,
      "! Payment disposition creation failed
      dp_creation_failed   TYPE scx_t100key VALUE IS INITIAL,
      "! Outbound IDoc dispatch failed
      idoc_dispatch_failed TYPE scx_t100key VALUE IS INITIAL.

    "! IDoc document number that caused the exception
    DATA docnum  TYPE edi_docnum READ-ONLY.
    "! System SY-SUBRC value at time of exception
    DATA sysubrc TYPE sy_subrc   READ-ONLY.
    "! Additional free-text variable
    DATA text1   TYPE string     READ-ONLY.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous                  OPTIONAL
        docnum   TYPE edi_docnum                OPTIONAL
        sysubrc  TYPE sy_subrc                  OPTIONAL
        text1    TYPE string                    OPTIONAL.

ENDCLASS.


CLASS zcx_zs08_idoc_error IMPLEMENTATION.

  METHOD constructor.
    CALL METHOD super->constructor
      EXPORTING
        previous = previous.
    me->docnum  = docnum.
    me->sysubrc = sysubrc.
    me->text1   = text1.
    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
