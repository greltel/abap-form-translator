"! <p class="shorttext synchronized" lang="EN">Logon language from the platform context</p>
"! Production implementation of {@link zif_form_trans_user_context} and the
"! one place in the package that reads the logon language of the session.
CLASS zcl_form_trans_user_context DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_form_trans_user_context.

ENDCLASS.


CLASS zcl_form_trans_user_context IMPLEMENTATION.
  METHOD zif_form_trans_user_context~language.
    result = xco_cp=>sy->language( )->value.
  ENDMETHOD.
ENDCLASS.
