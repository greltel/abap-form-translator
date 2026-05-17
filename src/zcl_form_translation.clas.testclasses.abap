*"* use this source file for your ABAP unit test classes

CLASS lcl_test_wrapper DEFINITION INHERITING FROM zcl_form_translation.
  PUBLIC SECTION.
    DATA mt_mock_data TYPE zcl_form_translation=>tt_zabap_form_transv.

  PROTECTED SECTION.
    METHODS get_translations REDEFINITION.
ENDCLASS.

CLASS lcl_test_wrapper IMPLEMENTATION.
  METHOD get_translations.
    re_translations = mt_mock_data.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_translator_test DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: mo_cut TYPE REF TO lcl_test_wrapper.

    METHODS:
      setup,
      test_translation_success FOR TESTING,
      test_translation_length FOR TESTING.
ENDCLASS.

CLASS ltc_translator_test IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW lcl_test_wrapper( ).
  ENDMETHOD.

  METHOD test_translation_success.

    TYPES: BEGIN OF ty_dummy,
             lbl_name TYPE string,
           END OF ty_dummy.
    DATA ls_data TYPE ty_dummy.

    ls_data-lbl_name = 'Original'.

    mo_cut->mt_mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E' descr = 'Success!' ) ).

    mo_cut->translate_form( EXPORTING formname = 'ZTEST'
                            CHANGING  form_elements = ls_data ).

    cl_abap_unit_assert=>assert_equals( exp = 'Success!' act = ls_data-lbl_name ).

  ENDMETHOD.

  METHOD test_translation_length.

    TYPES: BEGIN OF ty_dummy,
             lbl_name TYPE string,
           END OF ty_dummy.
    DATA ls_data TYPE ty_dummy.

    ls_data-lbl_name = 'Original'.

    mo_cut->mt_mock_data = VALUE #(
      ( form = 'ZTEST' fieldname = 'LBL_NAME' langu = 'E' descr = 'Success!' length = 3 ) ).

    mo_cut->translate_form( EXPORTING formname = 'ZTEST'
                            CHANGING  form_elements = ls_data ).

    cl_abap_unit_assert=>assert_equals( exp = 'Suc' act = ls_data-lbl_name ).

  ENDMETHOD.

ENDCLASS.
