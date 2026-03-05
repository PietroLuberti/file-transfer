CLASS ZCL_ZS08_IDOC_PROCESSOR DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS process_idoc.
ENDCLASS.

CLASS ZCL_ZS08_IDOC_PROCESSOR IMPLEMENTATION.
  METHOD process_idoc.
    DATA lt_edidd TYPE TABLE OF edidd.
    SELECT edidd~mandt, edidd~idoc_type, edidd~sdata INTO TABLE lt_edidd FROM edidd WHERE ... .
    LOOP AT lt_edidd INTO DATA(ls_edidd).
      MOVE-CORRESPONDING ls_edidd TO ... .
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.