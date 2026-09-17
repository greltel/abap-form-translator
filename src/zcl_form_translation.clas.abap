"! <p class="shorttext synchronized">Form Translation Class</p>
"! Default implementation of {@link zif_form_translation}, reading the texts
"! from ZABAP_FORM_TRANS through a process wide static buffer.
"! <br>
"! The database read lives in the protected get_translations rather than behind
"! an injected reader interface - a deliberate trade off to keep the object
"! count of the package minimal. Tests substitute it by subclassing, which is
"! also why this class is not FINAL.
"! <br>
"! The logon language, in contrast, does come in through an injected
"! {@link zif_form_trans_user_context}: it is the one platform dependency of the
"! class, and without the seam the "no language given" path could not be tested.
CLASS zcl_form_translation DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_form_translation.

    ALIASES translate_form FOR zif_form_translation~translate_form.

    CONSTANTS version TYPE string VALUE '2.0.0' ##NEEDED.

    "! <p class="shorttext synchronized">Wires the platform dependencies</p>
    "! Production callers use the parameterless form and get the real platform
    "! context; tests pass a double that returns a fixed language.
    "!
    "! @parameter user_context | Source of the logon language, defaults to {@link zcl_form_trans_user_context}.
    METHODS constructor
      IMPORTING user_context TYPE REF TO zif_form_trans_user_context OPTIONAL.

    "! <p class="shorttext synchronized">Invalidates the in-memory translation buffer</p>
    "! Call this after maintaining translations in a long living session
    "! (mass print / batch / job server) so hot swapped texts take effect.
    CLASS-METHODS clear_buffer.

  PROTECTED SECTION.
    CONSTANTS default_language TYPE zabap_form_trans_langu VALUE 'E'.

    TYPES: BEGIN OF translation,
             form      TYPE zabap_form_trans-form,
             fieldname TYPE zabap_form_trans-fieldname,
             langu     TYPE zabap_form_trans-langu,
             descr     TYPE zabap_form_trans-descr,
             length    TYPE zabap_form_trans-length,
           END OF translation.

    "! One row per field - the text that will be printed for it.
    TYPES translations TYPE SORTED TABLE OF translation WITH UNIQUE KEY fieldname.

    TYPES: BEGIN OF buffer_entry,
             formname     TYPE zabap_form_trans_name,
             langu        TYPE zabap_form_trans_langu,
             use_fallback TYPE abap_boolean,
             translations TYPE translations,
           END OF buffer_entry.

    CLASS-DATA buffer TYPE HASHED TABLE OF buffer_entry
                      WITH UNIQUE KEY formname langu use_fallback.

    "! Returns one row per field: the text in the requested language, or - with
    "! the fallback switched on - the text in the default language for fields
    "! that have no text in the requested one. Results are buffered per form,
    "! language and fallback setting, including the empty outcome.
    "!
    "! @parameter formname        | Form key, matched case insensitively.
    "! @parameter langu           | Target language; the logon language when initial.
    "! @parameter enable_fallback | Fill gaps from the default language.
    "! @parameter result          | Rows found, at most one per field.
    METHODS get_translations
      IMPORTING formname        TYPE zabap_form_trans_name
                langu           TYPE zabap_form_trans_langu
                enable_fallback TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(result)   TYPE translations.

  PRIVATE SECTION.
    "! Rows as read from the database: up to two per field when the fallback is on.
    TYPES candidates TYPE STANDARD TABLE OF translation WITH EMPTY KEY.

    DATA user_context TYPE REF TO zif_form_trans_user_context.

    METHODS resolve_language
      IMPORTING langu         TYPE zabap_form_trans_langu
      RETURNING VALUE(result) TYPE zabap_form_trans_langu.

    METHODS read_candidates
      IMPORTING form_key      TYPE zabap_form_trans_name
                language      TYPE zabap_form_trans_langu
                use_fallback  TYPE abap_boolean
      RETURNING VALUE(result) TYPE candidates.

    METHODS merge_by_field
      IMPORTING candidates    TYPE candidates
                language      TYPE zabap_form_trans_langu
      RETURNING VALUE(result) TYPE translations.

    METHODS printable_text
      IMPORTING translation   TYPE translation
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_form_translation IMPLEMENTATION.
  METHOD constructor.
    me->user_context = COND #( WHEN user_context IS BOUND
                               THEN user_context
                               ELSE NEW zcl_form_trans_user_context( ) ).
  ENDMETHOD.

  METHOD zif_form_translation~translate_form.
    IF formname IS INITIAL.
      RETURN.
    ENDIF.

    DATA(translations) = get_translations( formname        = formname
                                           langu           = langu
                                           enable_fallback = enable_fallback ).

    " A blank text must not wipe the default the caller has already set.
    LOOP AT translations REFERENCE INTO DATA(translation) WHERE descr IS NOT INITIAL.
      DATA(component_name) = to_upper( translation->fieldname ).

      ASSIGN COMPONENT component_name OF STRUCTURE form_elements TO FIELD-SYMBOL(<component>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      TRY.
          <component> = printable_text( translation->* ).
        CATCH cx_sy_conversion_error.
          " A component that cannot hold text (a number, a date) keeps its
          " default rather than aborting the whole print.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_translations.
    " HANA compares case sensitively. Callers (and legacy data) may pass the
    " form name in mixed case, so normalise it before both the buffer lookup
    " and the SELECT.
    DATA(form_key) = CONV zabap_form_trans_name( to_upper( formname ) ).
    DATA(language) = resolve_language( langu ).

    DATA(use_fallback) = xsdbool(     language        <> default_language
                                  AND enable_fallback  = abap_true ).

    DATA(cached) = VALUE buffer_entry( buffer[ formname     = form_key
                                               langu        = language
                                               use_fallback = use_fallback ] OPTIONAL ).
    IF cached IS NOT INITIAL.
      result = cached-translations.
      RETURN.
    ENDIF.

    result = merge_by_field( candidates = read_candidates( form_key     = form_key
                                                           language     = language
                                                           use_fallback = use_fallback )
                             language   = language ).

    " Cache the outcome - including the empty case - so that repeated calls
    " for forms without translations do not re-run the SELECT (negative caching).
    INSERT VALUE #( formname     = form_key
                    langu        = language
                    use_fallback = use_fallback
                    translations = result ) INTO TABLE buffer.
  ENDMETHOD.

  METHOD resolve_language.
    result = COND #( WHEN langu IS NOT INITIAL
                     THEN langu
                     ELSE user_context->language( ) ).

    " If the logon language cannot be resolved, fall back to the default
    " language instead of silently returning no translations at all.
    IF result IS INITIAL.
      result = default_language.
    ENDIF.
  ENDMETHOD.

  METHOD read_candidates.
    " Without fallback the list simply names the target language twice.
    DATA(fallback_language) = COND zabap_form_trans_langu( WHEN use_fallback = abap_true
                                                            THEN default_language
                                                            ELSE language ).

    SELECT FROM zabap_form_trans
      FIELDS form, fieldname, langu, descr, length
      WHERE form  = @form_key
        AND langu IN ( @language, @fallback_language )
      ORDER BY PRIMARY KEY
      INTO TABLE @result.
  ENDMETHOD.

  METHOD merge_by_field.
    " A field keeps the first row seen unless a row in the target language
    " arrives after its default-language fallback - the target language wins
    " whatever the order of the candidates.
    LOOP AT candidates REFERENCE INTO DATA(candidate).
      ASSIGN result[ fieldname = candidate->fieldname ] TO FIELD-SYMBOL(<existing>).

      IF sy-subrc <> 0.
        INSERT candidate->* INTO TABLE result.
      ELSEIF <existing>-langu = default_language AND candidate->langu = language.
        <existing> = candidate->*.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD printable_text.
    result = translation-descr.

    " LENGTH 0 means no limit; anything else cuts the text at print time.
    IF translation-length > 0 AND strlen( result ) > translation-length.
      result = substring( val = result
                          len = translation-length ).
    ENDIF.
  ENDMETHOD.

  METHOD clear_buffer.
    CLEAR buffer.
  ENDMETHOD.
ENDCLASS.
