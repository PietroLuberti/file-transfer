*&---------------------------------------------------------------------*
*& ABAP Dictionary Include: ZPRDISPSF_D
*& IDoc Segment: ZS08 Payment Disposition - Recipient/Destinatario
*& Level 2 - Relation 1:N (child of ZPRDISPSF_T)
*& Contains recipient info and non-SICOGE justifications
*&---------------------------------------------------------------------*
DATA: BEGIN OF gs_zprdispsf_d_inbound,
        " --- Fields from ReGiS ---
        taxnum            TYPE c LENGTH 16,   " VAT number / Tax code
        cod_bp_sf         TYPE c LENGTH 10,   " Business Partner code in SF
        iban              TYPE c LENGTH 34,   " IBAN
        numero_tes        TYPE c LENGTH 15,   " TES number
        cig               TYPE c LENGTH 30,   " CIG code
        nota_dest         TYPE c LENGTH 1000, " Recipient note
        importo           TYPE p LENGTH 9 DECIMALS 2, " Amount to pay (CURR 15.2)
        codice_gestionale TYPE c LENGTH 10,   " Management code
        zflag             TYPE c LENGTH 1,    " Activation flag
      END OF gs_zprdispsf_d_inbound.

DATA: BEGIN OF gs_zprdispsf_d_outbound,
        " --- Fields from ReGiS (mirrored) ---
        ziban             TYPE c LENGTH 34,   " IBAN (outbound uses ZIBAN)
        numero_tes        TYPE c LENGTH 15,   " TES number
        taxnum            TYPE c LENGTH 20,   " VAT number / Tax code
        cod_bp_sf         TYPE c LENGTH 10,   " Business Partner code in SF
        cig               TYPE c LENGTH 30,   " CIG code
        nota_dest         TYPE c LENGTH 1000, " Recipient note
        codice_gestionale TYPE c LENGTH 10,   " Management code
        importo           TYPE p LENGTH 9 DECIMALS 2, " Amount to pay
        zflag             TYPE c LENGTH 1,    " Activation flag
        " --- Additional fields added by Sistema Finanziario ---
        znumopf           TYPE n LENGTH 10,   " OPF number
        zstatoopf         TYPE c LENGTH 3,    " OPF status
        zerrore           TYPE c LENGTH 1000, " Error description / rejection reason
        zdataopf          TYPE d,             " OPF date
        zcroquiet         TYPE n LENGTH 30,   " CRO/TNR/Receipt number
        zimpagopf         TYPE p LENGTH 10 DECIMALS 2, " OPF paid amount (CURR 17.2)
      END OF gs_zprdispsf_d_outbound.
