*&---------------------------------------------------------------------*
*& ABAP Dictionary Include: ZPRDISPSF_MSG
*& IDoc Segment: ZS08 Payment Disposition - Message (like BAPIRET2)
*& Levels 1B, 2A, 3A1, 3B1, 4A - Relation 0:N (child of parent segment)
*& Reused as child of: ZPRDISPSF_T, ZPRDISPSF_D, ZPRDISPSF_TRIB,
*&                     ZPRDISPSF_SIC, ZPRDISPSF_SICTRIB
*&---------------------------------------------------------------------*
DATA: BEGIN OF gs_zprdispsf_msg,
        type       TYPE c LENGTH 1,    " Message type (S/I/W/E/A)
        id         TYPE c LENGTH 20,   " Message class ID
        number     TYPE n LENGTH 3,    " Message number
        message    TYPE c LENGTH 220,  " Message text
        message_v1 TYPE c LENGTH 50,   " Message variable 1
        message_v2 TYPE c LENGTH 50,   " Message variable 2
        message_v3 TYPE c LENGTH 50,   " Message variable 3
        message_v4 TYPE c LENGTH 50,   " Message variable 4
      END OF gs_zprdispsf_msg.
