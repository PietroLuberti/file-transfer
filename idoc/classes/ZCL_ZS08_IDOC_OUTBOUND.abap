<?xml version="1.0" encoding="UTF-8"?>

CLASS ZCL_ZS08_IDOC_OUTBOUND DEFINITION
  INHERITING FROM CL_ABAP_OBJECT
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_my_interface.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS ZCL_ZS08_IDOC_OUTBOUND IMPLEMENTATION.
  METHOD if_my_interface~my_method.

    DATA lv_variable TYPE string.
    " Example processing
    lv_variable = 'Hello World'.
    WRITE: / lv_variable.

  ENDMETHOD.
ENDCLASS.