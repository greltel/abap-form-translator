*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">Stub for the translation reader</p>
"! Replaces the database read of {@link zcl_form_translation} with canned rows,
"! so that the mapping logic of translate_form can be exercised without any
"! persistence. Subclassing is used because the read is a protected method
"! rather than an injected collaborator - a deliberate trade-off to keep the
"! object count of the package minimal.
CLASS ltd_translation_stub DEFINITION INHERITING FROM zcl_form_translation.
  PUBLIC SECTION.
    "! Rows the stub hands back instead of reading the database.
    DATA mock_data TYPE zcl_form_translation=>translations.

  PROTECTED SECTION.
    METHODS get_translations REDEFINITION.
ENDCLASS.


CLASS ltd_translation_stub IMPLEMENTATION.
  METHOD get_translations.
    result = mock_data.
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">Tests for TRANSLATE_FORM</p>
"! Covers how translation rows are mapped onto the components of the caller
"! structure. The database read is stubbed by {@link .ltd_translation_stub},
"! so every test here is pure logic.
CLASS ltc_translate_form DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    TYPES: BEGIN OF label,
             lbl_name TYPE string,
           END OF label.

    TYPES: BEGIN OF form_labels,
             title    TYPE string,
             footer   TYPE string,
             customer TYPE string,
           END OF form_labels.

    DATA cut TYPE REF TO ltd_translation_stub.

    METHODS setup.

    METHODS given_match_then_text_applied  FOR TESTING.
    METHODS given_len_3_then_truncated     FOR TESTING.
    METHODS given_2_rows_then_others_kept  FOR TESTING.
    METHODS given_no_form_then_unchanged   FOR TESTING.
    METHODS given_empty_text_then_kept     FOR TESTING.
    METHODS given_ghost_field_then_skipped FOR TESTING.
    METHODS given_len_0_then_full_text     FOR TESTING.
    METHODS given_short_text_then_kept     FOR TESTING.

ENDCLASS.


CLASS ltc_translate_form IMPLEMENTATION.

  METHOD setup.
    cut = NEW ltd_translation_stub( ).
  ENDMETHOD.

  METHOD given_match_then_text_applied.
    " --- ARRANGE
    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #( ( form      = 'ZTEST'
                                fieldname = 'LBL_NAME'
                                langu     = 'E'
                                descr     = 'Success!' ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = 'ZTEST'
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'Success!'
        act = labels-lbl_name
        msg = 'A matching row must overwrite the component of the same name' ).
  ENDMETHOD.

  METHOD given_len_3_then_truncated.
    " --- ARRANGE
    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #( ( form      = 'ZTEST'
                                fieldname = 'LBL_NAME'
                                langu     = 'E'
                                descr     = 'Success!'
                                length    = 3 ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = 'ZTEST'
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'Suc'
        act = labels-lbl_name
        msg = 'Text longer than LENGTH must be cut at print time' ).
  ENDMETHOD.

  METHOD given_2_rows_then_others_kept.
    " --- ARRANGE
    DATA labels TYPE form_labels.

    labels-title    = 'Original Title'.
    labels-footer   = 'Original Footer'.
    labels-customer = 'Keep Me'.

    cut->mock_data = VALUE #( ( form = 'ZTEST' fieldname = 'TITLE'  langu = 'E' descr = 'New Title' )
                              ( form = 'ZTEST' fieldname = 'FOOTER' langu = 'E' descr = 'New Footer' ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = 'ZTEST'
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'New Title'
        act = labels-title
        msg = 'First translated component was not applied' ).

    cl_abap_unit_assert=>assert_equals(
        exp = 'New Footer'
        act = labels-footer
        msg = 'Second translated component was not applied' ).

    cl_abap_unit_assert=>assert_equals(
        exp = 'Keep Me'
        act = labels-customer
        msg = 'Components without a translation row must stay untouched' ).
  ENDMETHOD.

  METHOD given_no_form_then_unchanged.
    " --- ARRANGE
    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #( ( form      = 'ZTEST'
                                fieldname = 'LBL_NAME'
                                langu     = 'E'
                                descr     = 'Should not apply' ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = VALUE #( )
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'Original'
        act = labels-lbl_name
        msg = 'An initial form name must return before touching the structure' ).
  ENDMETHOD.

  METHOD given_empty_text_then_kept.
    " --- ARRANGE
    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #( ( form      = 'ZTEST'
                                fieldname = 'LBL_NAME'
                                langu     = 'E'
                                descr     = '' ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = 'ZTEST'
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'Original'
        act = labels-lbl_name
        msg = 'A blank description must not silently wipe the default text' ).
  ENDMETHOD.

  METHOD given_ghost_field_then_skipped.
    " --- ARRANGE
    DATA labels TYPE form_labels.

    labels-title = 'Original Title'.

    cut->mock_data = VALUE #( ( form = 'ZTEST' fieldname = 'DOES_NOT_EXIST' langu = 'E' descr = 'Ghost' )
                              ( form = 'ZTEST' fieldname = 'TITLE'          langu = 'E' descr = 'New Title' ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = 'ZTEST'
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'New Title'
        act = labels-title
        msg = 'A row for a non-existing component must be skipped without side effects' ).
  ENDMETHOD.

  METHOD given_len_0_then_full_text.
    " --- ARRANGE
    DATA labels TYPE label.

    cut->mock_data = VALUE #( ( form      = 'ZTEST'
                                fieldname = 'LBL_NAME'
                                langu     = 'E'
                                descr     = 'A rather long description that is not truncated'
                                length    = 0 ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = 'ZTEST'
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'A rather long description that is not truncated'
        act = labels-lbl_name
        msg = 'LENGTH 0 means no limit and must never truncate' ).
  ENDMETHOD.

  METHOD given_short_text_then_kept.
    " --- ARRANGE
    DATA labels TYPE label.

    cut->mock_data = VALUE #( ( form      = 'ZTEST'
                                fieldname = 'LBL_NAME'
                                langu     = 'E'
                                descr     = 'Hi'
                                length    = 50 ) ).

    " --- ACT
    cut->translate_form( EXPORTING formname      = 'ZTEST'
                         CHANGING  form_elements = labels ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'Hi'
        act = labels-lbl_name
        msg = 'Text shorter than LENGTH must be applied unchanged' ).
  ENDMETHOD.

ENDCLASS.


"! <p class="shorttext" lang="EN">Exposes the protected database read</p>
"! Test helper: get_translations is protected, so a subclass is used to reach
"! it from {@link .ltc_get_translations}.
CLASS lth_translation_reader DEFINITION INHERITING FROM zcl_form_translation.
  PUBLIC SECTION.
    "! Calls the protected implementation directly.
    "!
    "! @parameter formname        | Form key to read.
    "! @parameter langu           | Target language.
    "! @parameter enable_fallback | Fall back to the default language.
    "! @parameter result          | Rows found, after per-field deduplication.
    METHODS read
      IMPORTING formname        TYPE zabap_form_trans_name
                langu           TYPE zabap_form_trans_langu
                enable_fallback TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(result)   TYPE zcl_form_translation=>translations.
ENDCLASS.


CLASS lth_translation_reader IMPLEMENTATION.
  METHOD read.
    result = get_translations( formname        = formname
                               langu           = langu
                               enable_fallback = enable_fallback ).
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">Tests for GET_TRANSLATIONS</p>
"! Covers the per-field language fallback and the static buffer, including the
"! negative caching of forms that have no translations at all. The database is
"! replaced by an Open SQL test double, so no real table is touched.
CLASS ltc_get_translations DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.

    CLASS-DATA environment TYPE REF TO if_osql_test_environment.

    DATA cut TYPE REF TO lth_translation_reader.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.

    "! Loads three rows: TITLE in English and German, FOOTER in English only.
    METHODS given_standard_rows.

    METHODS given_both_langs_then_target  FOR TESTING.
    METHODS given_gap_then_default_lang   FOR TESTING.
    METHODS given_no_fallback_then_1_row  FOR TESTING.
    METHODS given_2nd_call_then_buffered  FOR TESTING.
    METHODS given_no_rows_then_cached     FOR TESTING.
    METHODS given_cleared_then_reloads    FOR TESTING.
    METHODS given_lower_form_then_found   FOR TESTING.

ENDCLASS.


CLASS ltc_get_translations IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZABAP_FORM_TRANS' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    zcl_form_translation=>clear_buffer( ).
    cut = NEW lth_translation_reader( ).
  ENDMETHOD.

  METHOD given_standard_rows.
    DATA rows TYPE STANDARD TABLE OF zabap_form_trans WITH EMPTY KEY.

    rows = VALUE #( ( form = 'ZTEST' fieldname = 'TITLE'  langu = 'E' descr = 'Invoice' )
                    ( form = 'ZTEST' fieldname = 'TITLE'  langu = 'D' descr = 'Rechnung' )
                    ( form = 'ZTEST' fieldname = 'FOOTER' langu = 'E' descr = 'Thank you' ) ).

    environment->insert_test_data( rows ).
  ENDMETHOD.

  METHOD given_both_langs_then_target.
    " --- ARRANGE
    given_standard_rows( ).

    " --- ACT
    DATA(result) = cut->read( formname = 'ZTEST' langu = 'D' ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'Rechnung'
        act = result[ KEY by_field fieldname = 'TITLE' ]-descr
        msg = 'When both languages exist the target language must win' ).
  ENDMETHOD.

  METHOD given_gap_then_default_lang.
    " --- ARRANGE
    given_standard_rows( ).

    " --- ACT
    DATA(result) = cut->read( formname = 'ZTEST' langu = 'D' ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 'Thank you'
        act = result[ KEY by_field fieldname = 'FOOTER' ]-descr
        msg = 'A field missing in the target language must fall back to English' ).
  ENDMETHOD.

  METHOD given_no_fallback_then_1_row.
    " --- ARRANGE
    given_standard_rows( ).

    " --- ACT
    DATA(result) = cut->read( formname        = 'ZTEST'
                              langu           = 'D'
                              enable_fallback = abap_false ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( result )
        msg = 'With the fallback switched off only the German row may be returned' ).
  ENDMETHOD.

  METHOD given_2nd_call_then_buffered.
    " --- ARRANGE
    given_standard_rows( ).
    cut->read( formname = 'ZTEST' langu = 'E' ).
    environment->clear_doubles( ).

    " --- ACT
    DATA(result) = cut->read( formname = 'ZTEST' langu = 'E' ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 2
        act = lines( result )
        msg = 'With the data removed a second call can only succeed from the buffer' ).
  ENDMETHOD.

  METHOD given_no_rows_then_cached.
    " --- ARRANGE
    DATA(first_result) = cut->read( formname = 'ZTEST' langu = 'E' ).

    cl_abap_unit_assert=>assert_initial(
        act = first_result
        msg = 'An unknown form must return no rows' ).

    given_standard_rows( ).

    " --- ACT
    DATA(second_result) = cut->read( formname = 'ZTEST' langu = 'E' ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = second_result
        msg = 'The empty outcome is cached, so newly inserted rows must not appear' ).
  ENDMETHOD.

  METHOD given_cleared_then_reloads.
    " --- ARRANGE
    cut->read( formname = 'ZTEST' langu = 'E' ).
    given_standard_rows( ).
    zcl_form_translation=>clear_buffer( ).

    " --- ACT
    DATA(result) = cut->read( formname = 'ZTEST' langu = 'E' ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 2
        act = lines( result )
        msg = 'clear_buffer must discard the cached empty result and read again' ).
  ENDMETHOD.

  METHOD given_lower_form_then_found.
    " --- ARRANGE
    given_standard_rows( ).

    " --- ACT
    DATA(result) = cut->read( formname = 'ztest' langu = 'E' ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 2
        act = lines( result )
        msg = 'A caller passing the form name in lower case must still find the rows' ).
  ENDMETHOD.

ENDCLASS.
