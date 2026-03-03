*&---------------------------------------------------------------------*
*& ABAP Dictionary Include: ZPRDISPSF_T
*& IDoc Segment: ZS08 Payment Disposition - Header (Testata)
*& Level 1 - Relation 1:1 with IDoc
*& Used by: Inbound message ZS08_DP_DIRECTIN
*&          Outbound messages ZS08_DP_DIRECTOUT, ZS08_DP_DIRECTOUT_T
*&---------------------------------------------------------------------*
*& To activate: Create include structure ZPRDISPSF_T in SE11, then
*& reference it in segment definition via WE31.
*&---------------------------------------------------------------------*

*"* INCLUDE ZPRDISPSF_T
*"* In SE11, create a flat structure ZPRDISPSF_T with the fields below.
*"* This include is referenced by the IDoc segment of the same name.

*------------------------------------------------------------------------*
* Fields present in the INBOUND IDoc (received from ReGiS)
*------------------------------------------------------------------------*
*   ID_DP            CHAR 10   - Unique payment disposition code
*   OGGETTO_PAG      CHAR 50   - Payment object description
*   GRANT_NBR        CHAR 20   - Grant/Financing number
*   COD_CUP          CHAR 15   - Unique project code (CUP)
*   CLP              CHAR 80   - Local project code
*   ZDESCRIZIONE     CHAR 1000 - Description
*   ZIMP_TOT         CURR 15.2 - Total amount to pay

*------------------------------------------------------------------------*
* Additional fields added by Sistema Finanziario (OUTBOUND only)
*------------------------------------------------------------------------*
*   ZDATA_ESITO      DATS 8    - OPF outcome date
*   ZNUMDP           CHAR 20   - DP number created in Sistema Finanziario
*   ZSTATODP         CHAR 2    - Status: OK / KO

*----------------------------------------------------------------------*
* SE11 Data Element / Domain reference guide:
*   ID_DP        -> Domain: CHAR10  (or custom domain ZD_IDDP)
*   GRANT_NBR    -> existing SAP data element GRANT_NBR
*   COD_CUP      -> Domain: CHAR15  (or custom ZD_CUP)
*   ZIMP_TOT     -> Domain: WRTV7 (CURR 15.2) with ref. currency WAERS
*   ZDATA_ESITO  -> Data element: DATS
*   ZNUMDP       -> Domain: CHAR20  (or custom ZD_NUMDP)
*   ZSTATODP     -> Domain: CHAR2   (or custom ZD_STATODP, values: OK/KO)
*----------------------------------------------------------------------*

" =====================================================================
" ABAP dictionary structure definition (SE11 equivalent as source code)
" =====================================================================
DATA: BEGIN OF gs_zprdispsf_t_inbound,
        " --- Fields from ReGiS (both IN and OUT IDocs) ---
        id_dp        TYPE c LENGTH 10,        " Unique DP code
        oggetto_pag  TYPE c LENGTH 50,        " Payment object
        grant_nbr    TYPE c LENGTH 20,        " Financing/grant number
        cod_cup      TYPE c LENGTH 15,        " CUP - unique project code
        clp          TYPE c LENGTH 80,        " Local project code
        zdescrizione TYPE c LENGTH 1000,      " Description
        zimp_tot     TYPE p LENGTH 9 DECIMALS 2, " Total amount (CURR 15.2)
      END OF gs_zprdispsf_t_inbound.

DATA: BEGIN OF gs_zprdispsf_t_outbound,
        " --- Fields from ReGiS (mirrored from inbound) ---
        id_dp        TYPE c LENGTH 10,
        oggetto_pag  TYPE c LENGTH 50,
        grant_nbr    TYPE c LENGTH 20,
        cod_cup      TYPE c LENGTH 15,
        clp          TYPE c LENGTH 80,
        zdescrizione TYPE c LENGTH 1000,
        zimp_tot     TYPE p LENGTH 9 DECIMALS 2,
        " --- Additional fields added by Sistema Finanziario ---
        zdata_esito  TYPE d,                  " Outcome date (DATS 8)
        znumdp       TYPE c LENGTH 20,        " DP number in SF
        zstatodp     TYPE c LENGTH 2,         " Status: OK or KO
      END OF gs_zprdispsf_t_outbound.
