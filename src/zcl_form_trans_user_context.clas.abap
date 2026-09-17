"! <p class="shorttext synchronized" lang="EN">Logon language from the platform context</p>
"! Production implementation of {@link zif_form_trans_user_context} and the
"! one place in the package that talks to CL_ABAP_CONTEXT_INFO.
CLASS zcl_form_trans_user_context DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_form_trans_user_context.

ENDCLASS.


CLASS zcl_form_trans_user_context IMPLEMENTATION.
  METHOD zif_form_trans_user_context~language.
    TRY.
        result = cl_abap_context_info=>get_user_language_abap_format( ).
      CATCH cx_abap_context_info_error.
        " Contract of the interface: initial when the platform cannot tell,
        " the consumer picks the fallback language.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
