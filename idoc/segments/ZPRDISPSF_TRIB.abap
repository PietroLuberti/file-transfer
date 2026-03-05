*&---------------------------------------------------------------------*
*& ABAP Dictionary Include: ZPRDISPSF_TRIB
*& IDoc Segment: ZS08 Payment Disposition - Non-SICOGE Tributes
*& Level 3A - Relation 0:N (child of ZPRDISPSF_D)
*& Contains tribute/tax info for non-SICOGE justifications
*&---------------------------------------------------------------------*
DATA: BEGIN OF gs_zprdispsf_trib_inbound,
        " --- Fields from ReGiS ---
        cod_tributo       TYPE c LENGTH 10,  " Tax/tribute key
        chiave_banca      TYPE c LENGTH 15,  " Bank key
        codice_gestionale TYPE c LENGTH 10,  " Management code
        trib_pag          TYPE p LENGTH 9 DECIMALS 2, " Tax amount to pay (CURR 15.2)
      END OF gs_zprdispsf_trib_inbound.

DATA: BEGIN OF gs_zprdispsf_trib_outbound,
        " --- Fields from ReGiS (mirrored) ---
        cod_tributo       TYPE c LENGTH 10,
        chiave_banca      TYPE c LENGTH 15,
        codice_gestionale TYPE c LENGTH 10,
        importo           TYPE p LENGTH 9 DECIMALS 2, " Amount (outbound uses IMPORTO)
        " --- Additional fields added by Sistema Finanziario ---
        znumopf           TYPE n LENGTH 10,  " OPF number
        zstatoopf         TYPE c LENGTH 3,   " OPF status
        zcroquiet         TYPE d,            " CRO/TNR/Receipt (date type per doc)
        zdata_opf         TYPE n LENGTH 30,  " OPF date (numc per doc)
        " Importo pagato OPF
        importo_pag_opf   TYPE p LENGTH 9 DECIMALS 2, " OPF paid tribute amount
      END OF gs_zprdispsf_trib_outbound.
