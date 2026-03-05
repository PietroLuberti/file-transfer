*&---------------------------------------------------------------------*
*& Function Module: ZFM_ZPRDISPSF_INBOUND
*& Entry point registered in WE57 for inbound IDoc processing.
*& Message type: ZS08_DP_DIRECTIN
*& IDoc type:    ZPRDISPSF
*&
*& SAP calls this FM when an inbound IDoc with message type
*& ZS08_DP_DIRECTIN arrives. It delegates immediately to the
*& OO class ZCL_ZS08_IDOC_PROCESSOR, keeping this FM as thin
*& as possible (adapter pattern).
*&
*& Registration in WE57:
*&   FM Name    : ZFM_ZPRDISPSF_INBOUND
*&   Direction  : 1 (Inbound)
*&   Message tp : ZS08_DP_DIRECTIN
*&   Basic type : ZPRDISPSF
*&   Process Cd : ZS08IN    (create in WE42 with processing type 'F')
*&---------------------------------------------------------------------*
FUNCTION zfm_zprdispsf_inbound.
*"----------------------------------------------------------------------
*"*"Global interface:
*"  IMPORTING
*"     VALUE(INPUT_METHOD) LIKE  BDWFAP_PAR-INPUTMETHD
*"     VALUE(MASS_PROCESSING) LIKE  BDWFAP_PAR-MASS_PROC
*"  TABLES
*"      IDOC_CONTRL STRUCTURE  EDIDC
*"      IDOC_DATA   STRUCTURE  EDIDD
*"      IDOC_STATUS STRUCTURE  BDIDOCSTAT
*"      RETURN_VARIABLES STRUCTURE  BDWFRETVAR
*"      SERIALIZATION_INFO STRUCTURE  BDI_SER
*"  EXCEPTIONS
*"      WRONG_FUNCTION_CALLED
*"----------------------------------------------------------------------

  " Verify this FM is called for the correct message type
  READ TABLE idoc_contrl INDEX 1 ASSIGNING FIELD-SYMBOL(<ls_ctrl>).
  IF sy-subrc <> 0.
    RAISE wrong_function_called.
  ENDIF.

  IF <ls_ctrl>-mestyp <> 'ZS08_DP_DIRECTIN'.
    RAISE wrong_function_called.
  ENDIF.

  " Delegate each IDoc in the bundle to the processor class
  DATA lo_processor TYPE REF TO zcl_zs08_idoc_processor.
  lo_processor = NEW zcl_zs08_idoc_processor( ).

  LOOP AT idoc_contrl ASSIGNING FIELD-SYMBOL(<ls_idoc_ctrl>).
    TRY.
        lo_processor->process_inbound(
          iv_idoc_number = <ls_idoc_ctrl>-docnum ).

      CATCH zcx_zs08_idoc_error INTO DATA(lx_error).
        " Build a status record to return the error to the IDoc framework
        APPEND VALUE bdidocstat(
          docnum  = <ls_idoc_ctrl>-docnum
          status  = '51'                         " Application document not posted
          stamid  = 'ZS08'
          stamno  = '099'
          stapa1  = lx_error->get_text( )
          uname   = sy-uname
          repid   = sy-repid
        ) TO idoc_status.
    ENDTRY.
  ENDLOOP.

ENDFUNCTION.
