"! <p class="shorttext synchronized" lang="en">Form Translation Class</p>
CLASS zcl_form_translation DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS version TYPE string VALUE '1.2.0' ##NEEDED.

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
    CONSTANTS default_language TYPE spras VALUE 'E'.

    TYPES: BEGIN OF translation,
             form      TYPE zabap_form_trans-form,
             fieldname TYPE zabap_form_trans-fieldname,
             langu     TYPE zabap_form_trans-langu,
             descr     TYPE zabap_form_trans-descr,
             length    TYPE zabap_form_trans-length,
           END OF translation.

    TYPES translations TYPE STANDARD TABLE OF translation WITH EMPTY KEY
                   WITH NON-UNIQUE SORTED KEY by_field COMPONENTS fieldname.

    TYPES: BEGIN OF buffer_entry,
             formname     TYPE zabap_form_trans_name,
             langu        TYPE zabap_form_trans_langu,
             use_fallback TYPE abap_boolean,
             translations TYPE translations,
           END OF buffer_entry.

    CLASS-DATA buffer TYPE HASHED TABLE OF buffer_entry
                      WITH UNIQUE KEY formname langu use_fallback.

    METHODS get_translations
      IMPORTING formname        TYPE zabap_form_trans_name
                langu           TYPE zabap_form_trans_langu
                enable_fallback TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(result)   TYPE zcl_form_translation=>translations.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_form_translation IMPLEMENTATION.
  METHOD translate_form.
    IF formname IS INITIAL.
      RETURN.
    ENDIF.

    DATA(translations) = get_translations( formname        = formname
                                           langu           = langu
                                           enable_fallback = enable_fallback  ).

    IF translations IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT translations REFERENCE INTO DATA(translation).

      IF translation->*-descr IS INITIAL.
        CONTINUE.
      ENDIF.

      ASSIGN COMPONENT translation->*-fieldname OF STRUCTURE form_elements TO FIELD-SYMBOL(<field_value>).

      IF NOT ( syst-subrc IS INITIAL AND <field_value> IS ASSIGNED ).
        CONTINUE.
      ENDIF.

      TRY.

          DATA(text) = translation->*-descr.

          IF translation->*-length IS NOT INITIAL AND strlen( text ) > translation->*-length.
            text = substring( val = text
                              off = 0
                              len = translation->*-length ).
          ENDIF.

          <field_value> = text.

        CATCH cx_root.

      ENDTRY.

      CLEAR text.
      UNASSIGN <field_value>.

    ENDLOOP.
  ENDMETHOD.

  METHOD get_translations.
    TRY.

        DATA(language) = COND #( WHEN langu IS NOT INITIAL
                                 THEN langu
                                 ELSE cl_abap_context_info=>get_user_language_abap_format( ) ).

        DATA(use_fallback) = xsdbool(     language        <> default_language
                                      AND enable_fallback  = abap_true ).

        ASSIGN buffer[ formname     = formname
                       langu        = language
                       use_fallback = use_fallback ] TO FIELD-SYMBOL(<cached>).
        IF syst-subrc IS INITIAL AND <cached> IS ASSIGNED.
          result = <cached>-translations.
          RETURN.
        ENDIF.

        SELECT FROM zabap_form_trans
          FIELDS form, fieldname, langu, descr, length
          WHERE form = @formname
            AND (    langu = @language
                  OR ( langu = @default_language AND @use_fallback = @abap_true ) )
          INTO TABLE @DATA(candidates).

        LOOP AT candidates REFERENCE INTO DATA(candidate).

          ASSIGN result[ KEY by_field
                         fieldname = candidate->fieldname ] TO FIELD-SYMBOL(<existing>).

          IF syst-subrc IS INITIAL AND <existing> IS ASSIGNED.
            IF     <existing>-langu = default_language
               AND candidate->langu = language.
              <existing> = candidate->*.
            ENDIF.
            UNASSIGN <existing>.
            CONTINUE.
          ENDIF.

          INSERT candidate->* INTO TABLE result.

        ENDLOOP.

        IF result IS NOT INITIAL.
          INSERT VALUE #( formname     = formname
                          langu        = language
                          use_fallback = use_fallback
                          translations = result ) INTO TABLE buffer.
        ENDIF.

      CATCH cx_abap_context_info_error.
    ENDTRY.
  ENDMETHOD.

  METHOD clear_buffer.
    CLEAR buffer.
  ENDMETHOD.

ENDCLASS.
