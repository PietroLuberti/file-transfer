*&---------------------------------------------------------------------*
*& ABAP Dictionary Include: ZPRDISPSF_SICTRIB
*& IDoc Segment: ZS08 Payment Disposition - SICOGE Invoice Tributes
*& Level 4 - Relation 0:N (child of ZPRDISPSF_SIC)
*& Contains tribute/tax info for SICOGE accounting documents
*&---------------------------------------------------------------------*
DATA: BEGIN OF gs_zprdispsf_sictrib_inbound,
        " --- Fields from ReGiS ---
        cod_tributo       TYPE c LENGTH 10,  " Tax/tribute key
        chiave_banca      TYPE c LENGTH 15,  " Bank key
        codice_gestionale TYPE c LENGTH 10,  " Management code
        trib_pag          TYPE p LENGTH 9 DECIMALS 2, " Tax amount to pay (CURR 15.2)
      END OF gs_zprdispsf_sictrib_inbound.

DATA: BEGIN OF gs_zprdispsf_sictrib_outbound,
        " --- Fields from ReGiS (mirrored) ---
        cod_tributo       TYPE c LENGTH 10,
        chiave_banca      TYPE c LENGTH 15,
        codice_gestionale TYPE c LENGTH 10,
        trib_pag          TYPE p LENGTH 9 DECIMALS 2,
        " --- Additional fields added by Sistema Finanziario ---
        znumopf           TYPE n LENGTH 10,  " OPF number
        zstatoopf         TYPE c LENGTH 3,   " OPF status
        zcroquiet         TYPE d,            " CRO/TNR/Receipt
        zdata_opf         TYPE n LENGTH 30,  " OPF date
        " Importo pagato OPF
        importo_pag_opf   TYPE p LENGTH 9 DECIMALS 2, " OPF paid tribute amount
      END OF gs_zprdispsf_sictrib_outbound.
