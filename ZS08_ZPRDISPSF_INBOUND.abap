FUNCTION zs08_zprdispsf_inbound.
*"----------------------------------------------------------------------
*"*"Interfaccia locale:
*"  IMPORTING
*"     VALUE(INPUT_METHOD) LIKE  BDWFAP_PAR-INPUTMETHD
*"     VALUE(MASS_PROCESSING) LIKE  BDWFAP_PAR-MASS_PROC
*"  EXPORTING
*"     VALUE(WORKFLOW_RESULT) LIKE  BDWF_PARAM-RESULT
*"     VALUE(APPLICATION_VARIABLE) LIKE  BDWF_PARAM-APPL_VAR
*"     VALUE(IN_UPDATE_TASK) LIKE  BDWFAP_PAR-UPDATETASK
*"     VALUE(CALL_TRANSACTION_DONE) LIKE  BDWFAP_PAR-CALLTRANS
*"  TABLES
*"      IDOC_CONTRL STRUCTURE  EDIDC
*"      IDOC_DATA STRUCTURE  EDIDD
*"      IDOC_STATUS STRUCTURE  BDIDOCSTAT
*"      RETURN_VARIABLES STRUCTURE  BDWFRETVAR
*"      SERIALIZATION_INFO STRUCTURE  BDI_SER
*"  EXCEPTIONS
*"      WRONG_FUNCTION_CALLED
*"----------------------------------------------------------------------

  DATA lo_processor TYPE REF TO zcl_zs08_zprdispsf_idoc_proces.
  FIELD-SYMBOLS <ls_ctrl>      TYPE edidc.
  FIELD-SYMBOLS <ls_idoc_ctrl> TYPE edidc.
  FIELD-SYMBOLS <ls_idoc_data> TYPE edidd.
  DATA: lt_idoc_data TYPE edidd_tt.

  READ TABLE idoc_contrl INDEX 1 ASSIGNING <ls_ctrl>.
  IF sy-subrc <> 0.
    RAISE wrong_function_called.
  ENDIF.

  IF <ls_ctrl>-mestyp <> 'ZS08_ZPRDISPSF_DIRECTIN'.
    RAISE wrong_function_called.
  ENDIF.

  CREATE OBJECT lo_processor.

  LOOP AT idoc_contrl ASSIGNING <ls_idoc_ctrl>.
    CLEAR lt_idoc_data[].
    LOOP AT idoc_data ASSIGNING <ls_idoc_data>
        WHERE docnum = <ls_idoc_ctrl>-docnum.
      APPEND <ls_idoc_data> TO lt_idoc_data.
    ENDLOOP.
    TRY.
        CALL METHOD lo_processor->process_inbound
          EXPORTING
            iv_idoc_number = <ls_idoc_ctrl>-docnum
            in_edidc       = <ls_idoc_ctrl>
            in_edidd       = lt_idoc_data.

      CATCH zcx_zs08_idoc_error INTO DATA(lx_error).
        APPEND VALUE bdidocstat(
          docnum  = <ls_idoc_ctrl>-docnum
          status  = '51'
          msgid   = '00'
          msgno   = '208'
          msgv1   = lx_error->get_text( )
          uname   = sy-uname
          repid   = sy-repid
        ) TO idoc_status.
    ENDTRY.
  ENDLOOP.

ENDFUNCTION.