"! <p class="shorttext synchronized" lang="en">Form Translation Class</p>
CLASS zcl_form_translation DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS c_version TYPE string VALUE '1.2.0' ##NEEDED.

    "! <p class="shorttext synchronized">Translates fields of a structure based on DB configuration</p>
    "! @parameter iv_formname | <p class="shorttext synchronized">Smartform/Form Name (Key in DB)</p>
    "! @parameter iv_langu | <p class="shorttext synchronized">Target Language</p>
    "! @parameter cs_form_elements | <p class="shorttext synchronized">Structure containing fields to be translated</p>
    METHODS translate_form
      IMPORTING
        !iv_formname        TYPE zabap_form_trans_name
        !iv_langu           TYPE zabap_form_trans_langu OPTIONAL
        !iv_enable_fallback TYPE abap_boolean DEFAULT abap_true
      CHANGING
        !cs_form_elements   TYPE any .
  PROTECTED SECTION.

    CONSTANTS c_sign_include     TYPE ddsign     VALUE 'I'.
    CONSTANTS c_options_equal    TYPE ddoption   VALUE 'EQ'.
    CONSTANTS c_default_language TYPE syst_langu VALUE 'E'.

    TYPES tt_zabap_form_transv TYPE STANDARD TABLE OF zabap_form_trans WITH EMPTY KEY.

    TYPES: BEGIN OF ty_buffer,
             formname     TYPE zabap_form_trans_name,
             langu        TYPE zabap_form_trans_langu,
             translations TYPE tt_zabap_form_transv,
           END OF ty_buffer.

    CLASS-DATA t_buffer TYPE STANDARD TABLE OF ty_buffer WITH EMPTY KEY.

    "! <p class="shorttext synchronized" lang="en"></p>
    "!
    "! @parameter iv_formname | <p class="shorttext synchronized" lang="en">Smart Forms: Form Name</p>
    "! @parameter iv_langu    | <p class="shorttext synchronized" lang="en">ABAP System Field: Language Key of Text Environment</p>
    METHODS get_translations
      IMPORTING
                !iv_formname           TYPE zabap_form_trans_name
                !iv_langu              TYPE zabap_form_trans_langu
                !iv_enable_fallback    TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(re_translations) TYPE zcl_form_translation=>tt_zabap_form_transv.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_FORM_TRANSLATION IMPLEMENTATION.


  METHOD translate_form.

    IF iv_formname IS INITIAL.
      RETURN.
    ENDIF.

    TRY.

        DATA(lt_translations) = me->get_translations( iv_formname        = iv_formname
                                                      iv_langu           = iv_langu
                                                      iv_enable_fallback = iv_enable_fallback  ).

      CATCH cx_sy_move_cast_error.
    ENDTRY.

    IF lt_translations IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_translations REFERENCE INTO DATA(lr_translation).

      ASSIGN COMPONENT lr_translation->*-fieldname OF STRUCTURE cs_form_elements TO FIELD-SYMBOL(<lv_field_value>).

      IF syst-subrc IS INITIAL AND <lv_field_value> IS ASSIGNED.

        TRY.

            DATA(lv_text) = lr_translation->*-descr.

            IF lr_translation->*-length IS NOT INITIAL AND strlen( lv_text ) GT lr_translation->*-length.
              lv_text = substring( val = lv_text
                                   off = 0
                                   len = lr_translation->*-length ).
            ENDIF.

            <lv_field_value> = lv_text.

          CATCH cx_root.
            CONTINUE.
        ENDTRY.

        CLEAR lv_text.
        UNASSIGN <lv_field_value>.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_translations.

    TRY.

        DATA(lv_langu) = COND #( WHEN iv_langu IS NOT INITIAL THEN iv_langu
                                 ELSE cl_abap_context_info=>get_user_language_abap_format( ) ).

        ASSIGN t_buffer[ formname = iv_formname langu = lv_langu ] TO FIELD-SYMBOL(<fs_cached>).
        IF syst-subrc IS INITIAL AND <fs_cached> IS ASSIGNED.
          re_translations = <fs_cached>-translations.
          RETURN.
        ENDIF.

        APPEND INITIAL LINE TO t_buffer ASSIGNING FIELD-SYMBOL(<fs_buffer>).
        <fs_buffer>-formname = iv_formname.
        <fs_buffer>-langu    = lv_langu.

        SELECT FROM zabap_form_trans
          FIELDS mandt,form,fieldname,langu,descr,length
          WHERE form  EQ @iv_formname
            AND langu EQ @lv_langu
          INTO CORRESPONDING FIELDS OF TABLE @<fs_buffer>-translations.

        IF    <fs_buffer>-translations IS INITIAL
          AND lv_langu NE c_default_language
          AND iv_enable_fallback EQ abap_true.

          SELECT FROM zabap_form_trans
            FIELDS mandt,form,fieldname,langu,descr,length
            WHERE form  EQ @iv_formname
              AND langu EQ @c_default_language
            INTO CORRESPONDING FIELDS OF TABLE @<fs_buffer>-translations.

        ENDIF.

        re_translations = <fs_buffer>-translations.

      CATCH cx_abap_context_info_error.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
