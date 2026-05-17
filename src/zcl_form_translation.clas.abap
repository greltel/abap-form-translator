"! <p class="shorttext synchronized" lang="en">Form Translation Class</p>
CLASS zcl_form_translation DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS c_version TYPE string VALUE '1.2.0' ##NEEDED.

    "! <p class="shorttext synchronized">Invalidates the in-memory translation buffer</p>
    "! <p>Call this after maintaining translations in a long-living session
    "! (mass print / batch / job server) so hot-swapped texts take effect.</p>
    CLASS-METHODS clear_buffer.

    "! <p class="shorttext synchronized">Translates fields of a structure based on DB configuration</p>
    "! @parameter formname | <p class="shorttext synchronized">Smartform/Form Name (Key in DB)</p>
    "! @parameter langu | <p class="shorttext synchronized">Target Language</p>
    "! @parameter form_elements | <p class="shorttext synchronized">Structure containing fields to be translated</p>
    METHODS translate_form
      IMPORTING
        !formname        TYPE zabap_form_trans_name
        !langu           TYPE zabap_form_trans_langu OPTIONAL
        !enable_fallback TYPE abap_boolean DEFAULT abap_true
      CHANGING
        !form_elements   TYPE any .
  PROTECTED SECTION.
    CONSTANTS c_default_language TYPE spras VALUE 'E'.

    TYPES: BEGIN OF ty_translation,
             form      TYPE zabap_form_trans-form,
             fieldname TYPE zabap_form_trans-fieldname,
             langu     TYPE zabap_form_trans-langu,
             descr     TYPE zabap_form_trans-descr,
             length    TYPE zabap_form_trans-length,
           END OF ty_translation.

    TYPES tt_zabap_form_transv TYPE STANDARD TABLE OF ty_translation WITH EMPTY KEY.

    TYPES: BEGIN OF ty_buffer,
             formname     TYPE zabap_form_trans_name,
             langu        TYPE zabap_form_trans_langu,
             translations TYPE tt_zabap_form_transv,
           END OF ty_buffer.

    CLASS-DATA t_buffer TYPE HASHED TABLE OF ty_buffer
                        WITH UNIQUE KEY formname langu.

    "! <p class="shorttext synchronized"></p>
    "!
    "! @parameter formname | <p class="shorttext synchronized">Smart Forms: Form Name</p>
    "! @parameter langu    | <p class="shorttext synchronized">ABAP System Field: Language Key of Text Environment</p>
    METHODS get_translations
      IMPORTING formname               TYPE zabap_form_trans_name
                langu                  TYPE zabap_form_trans_langu
                enable_fallback        TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(re_translations) TYPE zcl_form_translation=>tt_zabap_form_transv.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_form_translation IMPLEMENTATION.


  METHOD translate_form.

    IF formname IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_translations) = me->get_translations( formname        = formname
                                                  langu           = langu
                                                  enable_fallback = enable_fallback  ).

    IF lt_translations IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_translations REFERENCE INTO DATA(lr_translation).

      ASSIGN COMPONENT lr_translation->*-fieldname OF STRUCTURE form_elements TO FIELD-SYMBOL(<lv_field_value>).

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

        DATA(lv_langu) = COND #( WHEN langu IS NOT INITIAL
                                 THEN langu
                                 ELSE cl_abap_context_info=>get_user_language_abap_format( ) ).

        ASSIGN t_buffer[ formname = formname
                         langu    = lv_langu ] TO FIELD-SYMBOL(<fs_cached>).
        IF syst-subrc IS INITIAL AND <fs_cached> IS ASSIGNED.
          re_translations = <fs_cached>-translations.
          RETURN.
        ENDIF.

        INSERT VALUE #( formname = formname
                        langu    = lv_langu )
               INTO TABLE t_buffer ASSIGNING FIELD-SYMBOL(<fs_buffer>).

        SELECT FROM zabap_form_trans
          FIELDS form, fieldname, langu, descr, length
          WHERE form  = @formname
            AND langu = @lv_langu
          INTO TABLE @<fs_buffer>-translations.

        IF     <fs_buffer>-translations IS INITIAL
           AND lv_langu                 <> c_default_language
           AND enable_fallback        = abap_true.

          SELECT FROM zabap_form_trans
            FIELDS form, fieldname, langu, descr, length
            WHERE form  = @formname
              AND langu = @c_default_language
            INTO TABLE @<fs_buffer>-translations.

        ENDIF.

        re_translations = <fs_buffer>-translations.

      CATCH cx_abap_context_info_error.
    ENDTRY.
  ENDMETHOD.

  METHOD clear_buffer.
    CLEAR t_buffer.
  ENDMETHOD.

ENDCLASS.
