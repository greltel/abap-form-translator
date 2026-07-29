*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">Tests for the pure validation rules</p>
"! Exercises {@link .lcl_rules} directly. No test doubles, no transactional
"! buffer, no draft - Arrange and Act collapse into a single call for most of
"! these tests, which is why the AAA blocks are not marked out separately.
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

    METHODS given_len_0_then_valid         FOR TESTING.
    METHODS given_len_9999_then_valid      FOR TESTING.
    METHODS given_len_10000_then_invalid   FOR TESTING.
    METHODS given_len_neg_then_invalid     FOR TESTING.
    METHODS given_text_over_len_then_cut   FOR TESTING.
    METHODS given_len_0_then_no_cut        FOR TESTING.
    METHODS given_text_under_len_then_ok   FOR TESTING.
    METHODS given_upper_keys_then_valid    FOR TESTING.
    METHODS given_lower_form_then_invalid  FOR TESTING.
    METHODS given_lower_field_then_invalid FOR TESTING.
    METHODS given_no_target_then_rejected  FOR TESTING.
    METHODS given_same_lang_then_rejected  FOR TESTING.
    METHODS given_key_taken_then_rejected  FOR TESTING.
    METHODS given_free_lang_then_ok        FOR TESTING.
    METHODS given_other_field_then_ok      FOR TESTING.

ENDCLASS.


CLASS ltc_rules IMPLEMENTATION.

  METHOD occupied_with_english.
    result = VALUE #( ( formname    = form
                        fieldname   = field
                        languagekey = 'E' ) ).
  ENDMETHOD.

  METHOD given_len_0_then_valid.
    cl_abap_unit_assert=>assert_true(
        act = lcl_rules=>is_maxlength_valid( 0 )
        msg = 'MaxLength 0 means no length limit and must stay a legal value' ).
  ENDMETHOD.

  METHOD given_len_9999_then_valid.
    cl_abap_unit_assert=>assert_true(
        act = lcl_rules=>is_maxlength_valid( 9999 )
        msg = 'The upper bound of the domain range must be accepted' ).
  ENDMETHOD.

  METHOD given_len_10000_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = lcl_rules=>is_maxlength_valid( 10000 )
        msg = 'The domain range is only enforced on the UI, so OData input must be rejected here' ).
  ENDMETHOD.

  METHOD given_len_neg_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = lcl_rules=>is_maxlength_valid( -1 )
        msg = 'A negative MaxLength has no meaning and must be rejected' ).
  ENDMETHOD.

  METHOD given_text_over_len_then_cut.
    cl_abap_unit_assert=>assert_true(
        act = lcl_rules=>is_text_truncated( description = 'Invoice'
                                            maxlength   = 3 )
        msg = 'Text longer than MaxLength must be flagged as truncated' ).
  ENDMETHOD.

  METHOD given_len_0_then_no_cut.
    cl_abap_unit_assert=>assert_false(
        act = lcl_rules=>is_text_truncated( description = 'A rather long description'
                                            maxlength   = 0 )
        msg = 'MaxLength 0 switches the limit off, so nothing is ever truncated' ).
  ENDMETHOD.

  METHOD given_text_under_len_then_ok.
    cl_abap_unit_assert=>assert_false(
        act = lcl_rules=>is_text_truncated( description = 'Hi'
                                            maxlength   = 50 )
        msg = 'Text shorter than MaxLength must not be flagged' ).
  ENDMETHOD.

  METHOD given_upper_keys_then_valid.
    cl_abap_unit_assert=>assert_true(
        act = lcl_rules=>is_key_upper_case( formname  = 'ZTEST'
                                            fieldname = 'TITLE' )
        msg = 'Upper case technical keys must be accepted' ).
  ENDMETHOD.

  METHOD given_lower_form_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = lcl_rules=>is_key_upper_case( formname  = 'ztest'
                                            fieldname = 'TITLE' )
        msg = 'A lower case form name could never be found at print time' ).
  ENDMETHOD.

  METHOD given_lower_field_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = lcl_rules=>is_key_upper_case( formname  = 'ZTEST'
                                            fieldname = 'title' )
        msg = 'A lower case field name could never be found at print time' ).
  ENDMETHOD.

  METHOD given_no_target_then_rejected.
    " --- ACT
    DATA(rejection) = lcl_rules=>check_copy_request( source_language = 'E'
                                                     target_language = VALUE #( )
                                                     formname        = form
                                                     fieldname       = field
                                                     occupied        = VALUE #( ) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = lcl_rules=>msg_language_missing
        act = rejection
        msg = 'A copy request without a target language must be rejected' ).
  ENDMETHOD.

  METHOD given_same_lang_then_rejected.
    " --- ACT
    DATA(rejection) = lcl_rules=>check_copy_request( source_language = 'E'
                                                     target_language = 'E'
                                                     formname        = form
                                                     fieldname       = field
                                                     occupied        = VALUE #( ) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = lcl_rules=>msg_same_language
        act = rejection
        msg = 'Copying a row onto its own language must be rejected' ).
  ENDMETHOD.

  METHOD given_key_taken_then_rejected.
    " --- ARRANGE
    DATA(occupied) = occupied_with_english( ).

    " --- ACT
    DATA(rejection) = lcl_rules=>check_copy_request( source_language = 'D'
                                                     target_language = 'E'
                                                     formname        = form
                                                     fieldname       = field
                                                     occupied        = occupied ).

    " --- ASSERT
    " Same assertion covers the in-batch case: a target queued earlier in the
    " same call is put into "occupied" and must be rejected identically.
    cl_abap_unit_assert=>assert_equals(
        exp = lcl_rules=>msg_duplicate_key
        act = rejection
        msg = 'A target key that is already taken must be rejected' ).
  ENDMETHOD.

  METHOD given_free_lang_then_ok.
    " --- ARRANGE
    DATA(occupied) = occupied_with_english( ).

    " --- ACT
    DATA(rejection) = lcl_rules=>check_copy_request( source_language = 'E'
                                                     target_language = 'D'
                                                     formname        = form
                                                     fieldname       = field
                                                     occupied        = occupied ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = rejection
        msg = 'A target language that is still free must be accepted' ).
  ENDMETHOD.

  METHOD given_other_field_then_ok.
    " --- ARRANGE
    DATA(occupied) = occupied_with_english( ).

    " --- ACT
    DATA(rejection) = lcl_rules=>check_copy_request( source_language = 'D'
                                                     target_language = 'E'
                                                     formname        = form
                                                     fieldname       = 'FOOTER'
                                                     occupied        = occupied ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = rejection
        msg = 'The same target language on a different field must not be blocked' ).
  ENDMETHOD.

ENDCLASS.


"! <p class="shorttext" lang="EN">Save sequence smoke test</p>
"! Proves that the validations are wired into the save sequence and that their
"! messages reach the caller. The rules themselves are covered by
"! {@link .ltc_rules}, without any RAP or test double involvement.
CLASS ltc_form_trans DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES failed_late   TYPE RESPONSE FOR FAILED   LATE zi_form_trans.
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

    "! Asserts that the save sequence raised a specific message.
    "! Entries that only clear a state area carry no message object and are
    "! skipped.
    "!
    "! @parameter reported | Reported table returned by COMMIT ENTITIES.
    "! @parameter expected | Message number that has to be present.
    METHODS assert_save_message
      IMPORTING !reported TYPE reported_late
                expected  TYPE symsgno.

    METHODS given_valid_row_then_saved     FOR TESTING.
    METHODS given_no_text_then_rejected    FOR TESTING.
    METHODS given_len_20000_then_rejected  FOR TESTING.
    METHODS given_len_neg_then_rejected    FOR TESTING.
    METHODS given_long_text_then_saved     FOR TESTING.
    METHODS given_lower_form_then_rejected FOR TESTING.

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

    cl_abap_unit_assert=>assert_true(
        act = found
        msg = |Expected message { expected } was not reported on save| ).
  ENDMETHOD.

  METHOD given_valid_row_then_saved.
    " --- ACT
    create_and_save( IMPORTING failed = DATA(failed) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = failed-translation
        msg = 'A row that satisfies every rule must pass the save sequence' ).
  ENDMETHOD.

  METHOD given_no_text_then_rejected.
    " --- ACT
    create_and_save( EXPORTING description = VALUE #( )
                     IMPORTING failed      = DATA(failed)
                               reported    = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = 'A translation without a description must be rejected' ).

    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_description_empty ).
  ENDMETHOD.

  METHOD given_len_20000_then_rejected.
    " --- ACT
    create_and_save( EXPORTING maxlength = 20000
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = 'MaxLength above the domain range must be rejected on the server side' ).

    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD given_len_neg_then_rejected.
    " --- ACT
    create_and_save( EXPORTING maxlength = -1
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = 'A negative MaxLength must be rejected' ).

    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD given_long_text_then_saved.
    " A description longer than MaxLength is legal - it is only truncated at
    " print time - so the row must still be saved.
    "
    " The warning itself is deliberately not asserted here: the save sequence
    " only propagates messages for instances it rejects, so a non-blocking
    " warning never reaches the caller on this path. In the app the warning is
    " raised by the Prepare determination, which is where the user sees it.
    " Detection of the truncation is covered by LTC_RULES.

    " --- ACT
    create_and_save( EXPORTING description = 'A description that is clearly too long'
                               maxlength   = 5
                     IMPORTING failed      = DATA(failed) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = failed-translation
        msg = 'Truncation is a warning only and must not block the save' ).
  ENDMETHOD.

  METHOD given_lower_form_then_rejected.
    " --- ACT
    create_and_save( EXPORTING formname = 'ztest'
                     IMPORTING failed   = DATA(failed)
                               reported = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = 'A lower case form name must be rejected, it could never be found at print time' ).

    assert_save_message( reported = reported
                         expected = lcl_rules=>msg_key_not_upper ).
  ENDMETHOD.

ENDCLASS.
