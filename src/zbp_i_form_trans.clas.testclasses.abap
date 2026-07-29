*"* use this source file for your ABAP unit test classes

CLASS ltc_rules DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS form  TYPE zabap_form_trans_name  VALUE 'ZTEST'.
    CONSTANTS field TYPE zabap_form_trans_field VALUE 'TITLE'.

    "! Builds an occupied set in which one target key is already taken.
    "!
    "! @parameter result | Single entry ZTEST / TITLE / E.
    METHODS occupied_with_english
      RETURNING VALUE(result) TYPE lcl_rules=>translation_keys.

    METHODS test_maxlength_zero_valid      FOR TESTING.
    METHODS test_maxlength_upper_bound     FOR TESTING.
    METHODS test_maxlength_above_limit     FOR TESTING.
    METHODS test_maxlength_negative        FOR TESTING.
    METHODS test_truncation_detected       FOR TESTING.
    METHODS test_no_truncation_no_limit    FOR TESTING.
    METHODS test_no_truncation_when_short  FOR TESTING.
    METHODS test_upper_case_accepted       FOR TESTING.
    METHODS test_lower_case_form_rejected  FOR TESTING.
    METHODS test_lower_case_field_rejected FOR TESTING.
    METHODS test_copy_without_language     FOR TESTING.
    METHODS test_copy_to_same_language     FOR TESTING.
    METHODS test_copy_to_occupied_key      FOR TESTING.
    METHODS test_copy_to_free_language     FOR TESTING.
    METHODS test_copy_other_field_is_free  FOR TESTING.

ENDCLASS.


CLASS ltc_rules IMPLEMENTATION.
  METHOD occupied_with_english.
    result = VALUE #( ( formname    = form
                        fieldname   = field
                        languagekey = 'E' ) ).
  ENDMETHOD.

  METHOD test_maxlength_zero_valid.
    " 0 means "no length limit" and must stay a legal value.
    cl_abap_unit_assert=>assert_true( lcl_rules=>is_maxlength_valid( 0 ) ).
  ENDMETHOD.

  METHOD test_maxlength_upper_bound.
    cl_abap_unit_assert=>assert_true( lcl_rules=>is_maxlength_valid( 9999 ) ).
  ENDMETHOD.

  METHOD test_maxlength_above_limit.
    " The domain range is only enforced on the UI, so values arriving through
    " OData or an API call have to be rejected here.
    cl_abap_unit_assert=>assert_false( lcl_rules=>is_maxlength_valid( 10000 ) ).
  ENDMETHOD.

  METHOD test_maxlength_negative.
    cl_abap_unit_assert=>assert_false( lcl_rules=>is_maxlength_valid( -1 ) ).
  ENDMETHOD.

  METHOD test_truncation_detected.
    cl_abap_unit_assert=>assert_true( lcl_rules=>is_text_truncated( description = 'Invoice'
                                                                    maxlength   = 3 ) ).
  ENDMETHOD.

  METHOD test_no_truncation_no_limit.
    cl_abap_unit_assert=>assert_false( lcl_rules=>is_text_truncated( description = 'A rather long description'
                                                                     maxlength   = 0 ) ).
  ENDMETHOD.

  METHOD test_no_truncation_when_short.
    cl_abap_unit_assert=>assert_false( lcl_rules=>is_text_truncated( description = 'Hi'
                                                                     maxlength   = 50 ) ).
  ENDMETHOD.

  METHOD test_upper_case_accepted.
    cl_abap_unit_assert=>assert_true( lcl_rules=>is_key_upper_case( formname  = 'ZTEST'
                                                                    fieldname = 'TITLE' ) ).
  ENDMETHOD.

  METHOD test_lower_case_form_rejected.
    cl_abap_unit_assert=>assert_false( lcl_rules=>is_key_upper_case( formname  = 'ztest'
                                                                     fieldname = 'TITLE' ) ).
  ENDMETHOD.

  METHOD test_lower_case_field_rejected.
    cl_abap_unit_assert=>assert_false( lcl_rules=>is_key_upper_case( formname  = 'ZTEST'
                                                                     fieldname = 'title' ) ).
  ENDMETHOD.

  METHOD test_copy_without_language.
    cl_abap_unit_assert=>assert_equals( exp = lcl_rules=>msg_language_missing
                                        act = lcl_rules=>check_copy_request( source_language = 'E'
                                                                             target_language = VALUE #( )
                                                                             formname        = form
                                                                             fieldname       = field
                                                                             occupied        = VALUE #( ) ) ).
  ENDMETHOD.

  METHOD test_copy_to_same_language.
    cl_abap_unit_assert=>assert_equals( exp = lcl_rules=>msg_same_language
                                        act = lcl_rules=>check_copy_request( source_language = 'E'
                                                                             target_language = 'E'
                                                                             formname        = form
                                                                             fieldname       = field
                                                                             occupied        = VALUE #( ) ) ).
  ENDMETHOD.

  METHOD test_copy_to_occupied_key.
    " Same assertion covers the in-batch case: a target queued earlier in the
    " same call is put into "occupied" and must be rejected identically.
    cl_abap_unit_assert=>assert_equals(
        exp = lcl_rules=>msg_duplicate_key
        act = lcl_rules=>check_copy_request( source_language = 'D'
                                             target_language = 'E'
                                             formname        = form
                                             fieldname       = field
                                             occupied        = occupied_with_english( ) ) ).
  ENDMETHOD.

  METHOD test_copy_to_free_language.
    cl_abap_unit_assert=>assert_initial( lcl_rules=>check_copy_request( source_language = 'E'
                                                                        target_language = 'D'
                                                                        formname        = form
                                                                        fieldname       = field
                                                                        occupied        = occupied_with_english( ) ) ).
  ENDMETHOD.

  METHOD test_copy_other_field_is_free.
    " The same target language on a different field must not be blocked.
    cl_abap_unit_assert=>assert_initial( lcl_rules=>check_copy_request( source_language = 'D'
                                                                        target_language = 'E'
                                                                        formname        = form
                                                                        fieldname       = 'FOOTER'
                                                                        occupied        = occupied_with_english( ) ) ).
  ENDMETHOD.
ENDCLASS.


"! Integration smoke test: proves that the validations are wired into the save
"! sequence and that their messages reach the caller. The rules themselves are
"! covered by LTC_RULES, without any RAP or test double involvement.
CLASS ltc_form_trans DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES failed_late   TYPE RESPONSE FOR FAILED LATE zi_form_trans.
    TYPES reported_late TYPE RESPONSE FOR REPORTED LATE zi_form_trans.

    CLASS-DATA cds_environment   TYPE REF TO if_cds_test_environment.
    CLASS-DATA draft_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    "! Runs a CREATE through the full save sequence so that the ON SAVE
    "! validations are executed, and hands back their outcome.
    "! Every parameter defaults to a valid row, so a test only has to override
    "! the one value it wants to make invalid.
    "!
    "! @parameter formname    | Form key, defaults to a valid upper case name.
    "! @parameter fieldname   | Field key, defaults to a valid upper case name.
    "! @parameter languagekey | Language of the text, defaults to English.
    "! @parameter description | Text to store, defaults to a non-empty value.
    "! @parameter maxlength   | Length limit, defaults to 0 for no limit.
    "! @parameter failed      | Instances rejected by the save sequence.
    "! @parameter reported    | Messages raised by the save sequence.
    METHODS create_and_save
      IMPORTING formname     TYPE zabap_form_trans_name   DEFAULT 'ZTEST'
                fieldname    TYPE zabap_form_trans_field  DEFAULT 'TITLE'
                languagekey  TYPE zabap_form_trans_langu  DEFAULT 'E'
                !description TYPE zabap_form_trans_descr  DEFAULT 'Invoice'
                maxlength    TYPE zabap_form_trans_maxlen DEFAULT 0
      EXPORTING !failed      TYPE failed_late
                !reported    TYPE reported_late.

    METHODS assert_save_message
      IMPORTING !reported TYPE reported_late
                expected  TYPE symsgno.

    METHODS test_valid_row_is_saved        FOR TESTING.
    METHODS test_empty_description         FOR TESTING.
    METHODS test_maxlength_above_limit     FOR TESTING.
    METHODS test_maxlength_negative        FOR TESTING.
    METHODS test_truncation_does_not_block FOR TESTING.
    METHODS test_lower_case_key            FOR TESTING.

ENDCLASS.


CLASS ltc_form_trans IMPLEMENTATION.
  METHOD class_setup.
    " READ ENTITIES is served through the CDS entity, not through the table,
    " so a plain table double stays invisible to the managed runtime.
    " i_select_base_dependencies additionally doubles ZABAP_FORM_TRANS, which
    " keeps the managed CREATE and the direct SELECT in validateUniqueKey on
    " the same data.
    cds_environment = cl_cds_test_environment=>create_for_multiple_cds(
                          i_for_entities = VALUE #( ( i_for_entity               = 'ZI_FORM_TRANS'
                                                      i_select_base_dependencies = abap_true ) ) ).

    " The draft table is declared in the BDEF, not in the CDS entity, so it is
    " not covered by the base dependencies above.
    draft_environment = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZABAP_FORM_DRFT' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    cds_environment->destroy( ).
    draft_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    cds_environment->clear_doubles( ).
    draft_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD create_and_save.
    MODIFY ENTITIES OF zi_form_trans
           ENTITY translation
           CREATE FIELDS ( formname fieldname languagekey description maxlength )
           WITH VALUE #( ( %cid        = 'CID1'
                           formname    = formname
                           fieldname   = fieldname
                           languagekey = languagekey
                           description = description
                           maxlength   = maxlength ) ).

    COMMIT ENTITIES RESPONSE OF zi_form_trans
           FAILED   DATA(commit_failed)
           REPORTED DATA(commit_reported).

    failed   = commit_failed.
    reported = commit_reported.
  ENDMETHOD.

  METHOD assert_save_message.
    DATA found TYPE abap_boolean.

    LOOP AT reported-translation INTO DATA(entry).
      " State area clearing entries carry no message object.
      IF entry-%msg IS BOUND AND entry-%msg->if_t100_message~t100key-msgno = expected.
        found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true( act = found
                                      msg = |Expected message { expected } was not reported on save| ).
  ENDMETHOD.

  METHOD test_valid_row_is_saved.
    create_and_save( IMPORTING failed = DATA(failed) ).

    cl_abap_unit_assert=>assert_initial( failed-translation ).
  ENDMETHOD.

  METHOD test_empty_description.
    create_and_save( EXPORTING description = VALUE #( )
                     IMPORTING failed      = DATA(failed)
                               reported    = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_description_empty ).
  ENDMETHOD.

  METHOD test_maxlength_above_limit.
    create_and_save( EXPORTING maxlength = 20000
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD test_maxlength_negative.
    create_and_save( EXPORTING maxlength = -1
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD test_truncation_does_not_block.
    " A description longer than MaxLength is legal - it is only truncated at
    " print time - so the row must still be saved.
    "
    " The warning itself is deliberately not asserted here: the save sequence
    " only propagates messages for instances it rejects, so a non-blocking
    " warning never reaches the caller on this path. In the app the warning is
    " raised by the Prepare determination, which is where the user sees it.
    " Detection of the truncation is covered by LTC_RULES.
    create_and_save( EXPORTING description = 'A description that is clearly too long'
                               maxlength   = 5
                     IMPORTING failed      = DATA(failed) ).

    cl_abap_unit_assert=>assert_initial( failed-translation ).
  ENDMETHOD.

  METHOD test_lower_case_key.
    create_and_save( EXPORTING formname = 'ztest'
                     IMPORTING failed   = DATA(failed)
                               reported = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_key_not_upper ).
  ENDMETHOD.
ENDCLASS.
