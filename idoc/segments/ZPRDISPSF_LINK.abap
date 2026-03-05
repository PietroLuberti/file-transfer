*&---------------------------------------------------------------------*
*& ABAP Dictionary Include: ZPRDISPSF_LINK
*& IDoc Segment: ZS08 Payment Disposition - Link SF-DP
*& Level 1A - Relation 1:1 with header
*& Sent empty by ReGiS; valorised and returned by Sistema Finanziario
*&---------------------------------------------------------------------*
DATA: BEGIN OF gs_zprdispsf_link,
        link_sf TYPE c LENGTH 1000,  " Link to SF payment disposition
      END OF gs_zprdispsf_link.
