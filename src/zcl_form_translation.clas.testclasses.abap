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
    METHODS test_clear_buffer_runs         FOR TESTING.
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

  METHOD test_clear_buffer_runs.
    " clear_buffer must be callable without side effects on the caller.
    zcl_form_translation=>clear_buffer( ).
    cl_abap_unit_assert=>assert_bound( cut ).
  ENDMETHOD.

ENDCLASS.
