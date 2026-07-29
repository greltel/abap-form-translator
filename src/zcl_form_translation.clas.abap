"! <p class="shorttext synchronized">Form Translation Class</p>
"! Default implementation of {@link zif_form_translation}, reading the texts
"! from ZABAP_FORM_TRANS through a process wide static buffer.
"! <br>
"! The database read lives in the protected get_translations rather than behind
"! an injected reader interface - a deliberate trade off to keep the object
"! count of the package minimal. Tests substitute it by subclassing, which is
"! also why this class is not FINAL.
CLASS zcl_form_translation DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_form_translation.

    ALIASES translate_form FOR zif_form_translation~translate_form.

    CONSTANTS version TYPE string VALUE '1.3.0' ##NEEDED.

    "! <p class="shorttext synchronized">Invalidates the in-memory translation buffer</p>
    "! Call this after maintaining translations in a long living session
    "! (mass print / batch / job server) so hot swapped texts take effect.
    CLASS-METHODS clear_buffer.

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
  METHOD zif_form_translation~translate_form.
    IF formname IS INITIAL.
      RETURN.
    ENDIF.

    DATA(translations) = get_translations( formname        = formname
                                           langu           = langu
                                           enable_fallback = enable_fallback  ).

    IF translations IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT translations ASSIGNING FIELD-SYMBOL(<translation>).

      IF <translation>-descr IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(component_name) = to_upper( <translation>-fieldname ).

      ASSIGN COMPONENT component_name OF STRUCTURE form_elements TO FIELD-SYMBOL(<field_value>).

      IF NOT ( sy-subrc IS INITIAL AND <field_value> IS ASSIGNED ).
        CONTINUE.
      ENDIF.

      TRY.

          DATA(text) = <translation>-descr.

          IF <translation>-length IS NOT INITIAL AND strlen( text ) > <translation>-length.
            text = substring( val = text
                              off = 0
                              len = <translation>-length ).
          ENDIF.

          <field_value> = text.

        CATCH cx_sy_conversion_error.

      ENDTRY.

      CLEAR text.
      UNASSIGN <field_value>.

    ENDLOOP.
  ENDMETHOD.

  METHOD get_translations.
    " HANA compares case sensitively. Callers (and legacy data) may pass the
    " form name in mixed case, so normalise it before both the buffer lookup
    " and the SELECT.
    DATA(form_key) = CONV zabap_form_trans_name( to_upper( formname ) ).

    DATA language TYPE spras.

    TRY.
        language = COND #( WHEN langu IS NOT INITIAL
                           THEN langu
                           ELSE xco_cp=>sy->language( )->value ).
      CATCH cx_abap_context_info_error.
        " If the user language cannot be resolved, fall back to the default
        " language instead of silently returning no translations at all.
        language = default_language.
    ENDTRY.

    DATA(use_fallback) = xsdbool(     language        <> default_language
                                  AND enable_fallback  = abap_true ).

    READ TABLE buffer ASSIGNING FIELD-SYMBOL(<cached>)
          WITH KEY formname     = form_key
                   langu        = language
                   use_fallback = use_fallback.
    IF sy-subrc IS INITIAL AND <cached> IS ASSIGNED.
      result = <cached>-translations.
      RETURN.
    ENDIF.

    SELECT FROM zabap_form_trans
      FIELDS form, fieldname, langu, descr, length
      WHERE form = @form_key
        AND (    langu = @language
              OR ( langu = @default_language AND @use_fallback = @abap_true ) )
      INTO TABLE @DATA(candidates).

    LOOP AT candidates REFERENCE INTO DATA(candidate).

      READ TABLE result ASSIGNING FIELD-SYMBOL(<existing>)
              WITH KEY by_field
              COMPONENTS fieldname = candidate->fieldname.

      IF sy-subrc IS INITIAL AND <existing> IS ASSIGNED.
        IF     <existing>-langu = default_language
           AND candidate->langu = language.
          <existing> = candidate->*.
        ENDIF.
        UNASSIGN <existing>.
        CONTINUE.
      ENDIF.

      INSERT candidate->* INTO TABLE result.

    ENDLOOP.

    " Cache the outcome - including the empty case - so that repeated calls
    " for forms without translations do not re-run the SELECT (negative caching).
    INSERT VALUE #( formname     = form_key
                    langu        = language
                    use_fallback = use_fallback
                    translations = result ) INTO TABLE buffer.
  ENDMETHOD.

  METHOD clear_buffer.
    CLEAR buffer.
  ENDMETHOD.
ENDCLASS.
