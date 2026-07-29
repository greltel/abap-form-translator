*"* use this source file for your ABAP unit test classes

CLASS lcl_test_wrapper DEFINITION INHERITING FROM zcl_form_translation.
  PUBLIC SECTION.
    DATA mock_data TYPE zcl_form_translation=>translations.

  PROTECTED SECTION.
    METHODS get_translations REDEFINITION.
ENDCLASS.


CLASS lcl_test_wrapper IMPLEMENTATION.
  METHOD get_translations.
    result = mock_data.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_translator_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    TYPES: BEGIN OF label,
             lbl_name TYPE string,
           END OF label.

    TYPES: BEGIN OF form_labels,
             title    TYPE string,
             footer   TYPE string,
             customer TYPE string,
           END OF form_labels.

    DATA cut TYPE REF TO lcl_test_wrapper.

    METHODS setup.
    METHODS test_translation_success       FOR TESTING.
    METHODS test_translation_length        FOR TESTING.
    METHODS test_multiple_and_untouched    FOR TESTING.
    METHODS test_initial_formname          FOR TESTING.
    METHODS test_empty_descr_skipped       FOR TESTING.
    METHODS test_unknown_field_skipped     FOR TESTING.
    METHODS test_no_truncation_no_length   FOR TESTING.
    METHODS test_text_shorter_than_length  FOR TESTING.
ENDCLASS.

CLASS ltc_translator_test IMPLEMENTATION.

  METHOD setup.
    cut = NEW lcl_test_wrapper( ).
  ENDMETHOD.

  METHOD test_translation_success.

    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E' descr = 'Success!' ) ).

    cut->translate_form( EXPORTING formname      = 'ZTEST'
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals( exp = 'Success!' act = labels-lbl_name ).

  ENDMETHOD.

  METHOD test_translation_length.

    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E' descr = 'Success!' length = 3 ) ).

    cut->translate_form( EXPORTING formname      = 'ZTEST'
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals( exp = 'Suc'
                                        act = labels-lbl_name ).

  ENDMETHOD.

  METHOD test_multiple_and_untouched.
    " Several fields are translated in one pass; fields that are not part of
    " the translation set must be left untouched.
    DATA labels TYPE form_labels.

    labels-title    = 'Original Title'.
    labels-footer   = 'Original Footer'.
    labels-customer = 'Keep Me'.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'TITLE'  langu = 'E' descr = 'New Title' )
      ( form = 'ZTEST' fieldname = 'FOOTER' langu = 'E' descr = 'New Footer' ) ).

    cut->translate_form( EXPORTING formname      = 'ZTEST'
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals( exp = 'New Title'  act = labels-title ).
    cl_abap_unit_assert=>assert_equals( exp = 'New Footer' act = labels-footer ).
    cl_abap_unit_assert=>assert_equals( exp = 'Keep Me'    act = labels-customer ).
  ENDMETHOD.

  METHOD test_initial_formname.
    " An initial form name returns immediately without touching the structure.
    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E' descr = 'Should not apply' ) ).

    cut->translate_form( EXPORTING formname      = VALUE #( )
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals( exp = 'Original' act = labels-lbl_name ).
  ENDMETHOD.

  METHOD test_empty_descr_skipped.
    " An entry with an empty description leaves the target field unchanged.
    DATA labels TYPE label.

    labels-lbl_name = 'Original'.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E' descr = '' ) ).

    cut->translate_form( EXPORTING formname      = 'ZTEST'
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals( exp = 'Original' act = labels-lbl_name ).
  ENDMETHOD.

  METHOD test_unknown_field_skipped.
    " A field that does not exist in the structure is skipped silently and
    " does not affect the fields that do exist.
    DATA labels TYPE form_labels.

    labels-title = 'Original Title'.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'DOES_NOT_EXIST' langu = 'E' descr = 'Ghost' )
      ( form = 'ZTEST' fieldname = 'TITLE'          langu = 'E' descr = 'New Title' ) ).

    cut->translate_form( EXPORTING formname      = 'ZTEST'
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals( exp = 'New Title' act = labels-title ).
  ENDMETHOD.

  METHOD test_no_truncation_no_length.
    " With length = 0 (no limit) the full text is applied even if long.
    DATA labels TYPE label.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E'
        descr = 'A rather long description that is not truncated' length = 0 ) ).

    cut->translate_form( EXPORTING formname      = 'ZTEST'
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals(
      exp = 'A rather long description that is not truncated'
      act = labels-lbl_name ).
  ENDMETHOD.

  METHOD test_text_shorter_than_length.
    " When the text is shorter than the configured length it is kept as-is.
    DATA labels TYPE label.

    cut->mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E' descr = 'Hi' length = 50 ) ).

    cut->translate_form( EXPORTING formname      = 'ZTEST'
                            CHANGING form_elements = labels ).

    cl_abap_unit_assert=>assert_equals( exp = 'Hi' act = labels-lbl_name ).
  ENDMETHOD.

ENDCLASS.

CLASS lcl_real DEFINITION INHERITING FROM zcl_form_translation.
  PUBLIC SECTION.
    "! Exposes the protected implementation so it can be tested directly.
    METHODS read
      IMPORTING formname        TYPE zabap_form_trans_name
                langu           TYPE zabap_form_trans_langu
                enable_fallback TYPE abap_boolean DEFAULT abap_true
      RETURNING VALUE(result)   TYPE zcl_form_translation=>translations.
ENDCLASS.


CLASS lcl_real IMPLEMENTATION.
  METHOD read.
    result = get_translations( formname        = formname
                               langu           = langu
                               enable_fallback = enable_fallback ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_get_translations DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA environment TYPE REF TO if_osql_test_environment.

    DATA cut TYPE REF TO lcl_real.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS given_standard_rows.

    METHODS test_target_language_wins   FOR TESTING.
    METHODS test_fallback_fills_gap     FOR TESTING.
    METHODS test_fallback_disabled      FOR TESTING.
    METHODS test_buffer_is_used         FOR TESTING.
    METHODS test_negative_caching       FOR TESTING.
    METHODS test_clear_buffer_reloads   FOR TESTING.
    METHODS test_form_name_lower_case   FOR TESTING.

ENDCLASS.


CLASS ltc_get_translations IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_osql_test_environment=>create(
                    i_dependency_list = VALUE #( ( 'ZABAP_FORM_TRANS' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles( ).
    zcl_form_translation=>clear_buffer( ).
    cut = NEW lcl_real( ).
  ENDMETHOD.

  METHOD given_standard_rows.
    DATA rows TYPE STANDARD TABLE OF zabap_form_trans WITH EMPTY KEY.

    rows = VALUE #( ( form = 'ZTEST' fieldname = 'TITLE'  langu = 'E' descr = 'Invoice' )
                    ( form = 'ZTEST' fieldname = 'TITLE'  langu = 'D' descr = 'Rechnung' )
                    ( form = 'ZTEST' fieldname = 'FOOTER' langu = 'E' descr = 'Thank you' ) ).

    environment->insert_test_data( rows ).
  ENDMETHOD.

  METHOD test_target_language_wins.
    given_standard_rows( ).

    DATA(result) = cut->read( formname = 'ZTEST' langu = 'D' ).

    cl_abap_unit_assert=>assert_equals( exp = 'Rechnung'
                                        act = result[ KEY by_field fieldname = 'TITLE' ]-descr ).
  ENDMETHOD.

  METHOD test_fallback_fills_gap.
    given_standard_rows( ).

    DATA(result) = cut->read( formname = 'ZTEST' langu = 'D' ).

    " FOOTER exists in E only and must be served through the fallback.
    cl_abap_unit_assert=>assert_equals( exp = 'Thank you'
                                        act = result[ KEY by_field fieldname = 'FOOTER' ]-descr ).
  ENDMETHOD.

  METHOD test_fallback_disabled.
    given_standard_rows( ).

    DATA(result) = cut->read( formname        = 'ZTEST'
                              langu           = 'D'
                              enable_fallback = abap_false ).

    cl_abap_unit_assert=>assert_equals( exp = 1
                                        act = lines( result ) ).
  ENDMETHOD.

  METHOD test_buffer_is_used.
    given_standard_rows( ).

    cut->read( formname = 'ZTEST' langu = 'E' ).

    " Remove the data: a second call may only succeed from the buffer.
    environment->clear_doubles( ).

    DATA(result) = cut->read( formname = 'ZTEST' langu = 'E' ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( result ) ).
  ENDMETHOD.

  METHOD test_negative_caching.
    DATA(result) = cut->read( formname = 'ZTEST' langu = 'E' ).

    cl_abap_unit_assert=>assert_initial( result ).

    given_standard_rows( ).

    " The empty outcome is cached, so newly inserted rows are not picked up.
    result = cut->read( formname = 'ZTEST' langu = 'E' ).

    cl_abap_unit_assert=>assert_initial( result ).
  ENDMETHOD.

  METHOD test_clear_buffer_reloads.
    cut->read( formname = 'ZTEST' langu = 'E' ).

    given_standard_rows( ).
    zcl_form_translation=>clear_buffer( ).

    DATA(result) = cut->read( formname = 'ZTEST' langu = 'E' ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( result ) ).
  ENDMETHOD.

  METHOD test_form_name_lower_case.
    given_standard_rows( ).

    " A caller passing the form name in lower case must still find the rows.
    DATA(result) = cut->read( formname = 'ztest' langu = 'E' ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( result ) ).
  ENDMETHOD.

ENDCLASS.
