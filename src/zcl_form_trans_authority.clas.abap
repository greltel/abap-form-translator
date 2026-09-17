"! <p class="shorttext synchronized" lang="EN">Authority check against ZFORMTRA</p>
"! Production implementation of {@link zif_form_trans_authority}: a thin
"! wrapper around AUTHORITY-CHECK, kept free of logic so that nothing in it
"! needs a unit test. The mapping of operations to activities is tested in the
"! behavior pool with a double of the interface.
CLASS zcl_form_trans_authority DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_form_trans_authority.

ENDCLASS.


CLASS zcl_form_trans_authority IMPLEMENTATION.
  METHOD zif_form_trans_authority~is_allowed.
    AUTHORITY-CHECK OBJECT 'ZFORMTRA'
      ID 'ACTVT' FIELD activity.

    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.
ENDCLASS.
