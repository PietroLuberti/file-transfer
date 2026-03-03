*&---------------------------------------------------------------------*
*& ABAP Dictionary Include: ZPRDISPSF_SIC
*& IDoc Segment: ZS08 Payment Disposition - SICOGE Invoice
*& Level 3B - Relation 0:N (child of ZPRDISPSF_D)
*& Contains accounting document (SICOGE invoice) information
*&---------------------------------------------------------------------*
DATA: BEGIN OF gs_zprdispsf_sic_inbound,
        " --- Fields from ReGiS ---
        id_fattura   TYPE c LENGTH 20,  " SICOGE invoice ID
        data_pag     TYPE d,            " SICOGE invoice payment date (DATS 8)
        num_fattura  TYPE c LENGTH 40,  " SICOGE invoice number
        importo      TYPE p LENGTH 9 DECIMALS 2, " Amount to pay (CURR 15.2)
      END OF gs_zprdispsf_sic_inbound.

DATA: BEGIN OF gs_zprdispsf_sic_outbound,
        " --- Fields from ReGiS (mirrored) ---
        id_fattura   TYPE c LENGTH 20,
        data_pag     TYPE d,
        num_fattura  TYPE c LENGTH 40,
        importo      TYPE p LENGTH 9 DECIMALS 2,
        " --- Additional field added by Sistema Finanziario ---
        impivapag    TYPE p LENGTH 9 DECIMALS 2, " VAT amount paid (CURR 15.2)
      END OF gs_zprdispsf_sic_outbound.
