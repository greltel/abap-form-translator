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

    DATA cut TYPE REF TO lcl_test_wrapper.

    METHODS setup.
    METHODS test_translation_success FOR TESTING.
    METHODS test_translation_length  FOR TESTING.
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

ENDCLASS.
