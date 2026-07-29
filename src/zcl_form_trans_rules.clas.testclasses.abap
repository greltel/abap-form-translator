*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">Tests for the pure validation rules</p>
"! Exercises {@link zcl_form_trans_rules} directly. No test doubles, no transactional
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
      RETURNING VALUE(result) TYPE zcl_form_trans_rules=>translation_keys.

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
        act = zcl_form_trans_rules=>is_maxlength_valid( 0 )
        msg = 'MaxLength 0 means no length limit and must stay a legal value' ).
  ENDMETHOD.

  METHOD given_len_9999_then_valid.
    cl_abap_unit_assert=>assert_true(
        act = zcl_form_trans_rules=>is_maxlength_valid( 9999 )
        msg = 'The upper bound of the domain range must be accepted' ).
  ENDMETHOD.

  METHOD given_len_10000_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = zcl_form_trans_rules=>is_maxlength_valid( 10000 )
        msg = 'The domain range is only enforced on the UI, so OData input must be rejected here' ).
  ENDMETHOD.

  METHOD given_len_neg_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = zcl_form_trans_rules=>is_maxlength_valid( -1 )
        msg = 'A negative MaxLength has no meaning and must be rejected' ).
  ENDMETHOD.

  METHOD given_text_over_len_then_cut.
    cl_abap_unit_assert=>assert_true(
        act = zcl_form_trans_rules=>is_text_truncated( description = 'Invoice'
                                            maxlength   = 3 )
        msg = 'Text longer than MaxLength must be flagged as truncated' ).
  ENDMETHOD.

  METHOD given_len_0_then_no_cut.
    cl_abap_unit_assert=>assert_false(
        act = zcl_form_trans_rules=>is_text_truncated( description = 'A rather long description'
                                            maxlength   = 0 )
        msg = 'MaxLength 0 switches the limit off, so nothing is ever truncated' ).
  ENDMETHOD.

  METHOD given_text_under_len_then_ok.
    cl_abap_unit_assert=>assert_false(
        act = zcl_form_trans_rules=>is_text_truncated( description = 'Hi'
                                            maxlength   = 50 )
        msg = 'Text shorter than MaxLength must not be flagged' ).
  ENDMETHOD.

  METHOD given_upper_keys_then_valid.
    cl_abap_unit_assert=>assert_true(
        act = zcl_form_trans_rules=>is_key_upper_case( formname  = 'ZTEST'
                                            fieldname = 'TITLE' )
        msg = 'Upper case technical keys must be accepted' ).
  ENDMETHOD.

  METHOD given_lower_form_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = zcl_form_trans_rules=>is_key_upper_case( formname  = 'ztest'
                                            fieldname = 'TITLE' )
        msg = 'A lower case form name could never be found at print time' ).
  ENDMETHOD.

  METHOD given_lower_field_then_invalid.
    cl_abap_unit_assert=>assert_false(
        act = zcl_form_trans_rules=>is_key_upper_case( formname  = 'ZTEST'
                                            fieldname = 'title' )
        msg = 'A lower case field name could never be found at print time' ).
  ENDMETHOD.

  METHOD given_no_target_then_rejected.
    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request( source_language = 'E'
                                                     target_language = VALUE #( )
                                                     formname        = form
                                                     fieldname       = field
                                                     occupied        = VALUE #( ) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = zcl_form_trans_rules=>msg_language_missing
        act = rejection
        msg = 'A copy request without a target language must be rejected' ).
  ENDMETHOD.

  METHOD given_same_lang_then_rejected.
    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request( source_language = 'E'
                                                     target_language = 'E'
                                                     formname        = form
                                                     fieldname       = field
                                                     occupied        = VALUE #( ) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = zcl_form_trans_rules=>msg_same_language
        act = rejection
        msg = 'Copying a row onto its own language must be rejected' ).
  ENDMETHOD.

  METHOD given_key_taken_then_rejected.
    " --- ARRANGE
    DATA(occupied) = occupied_with_english( ).

    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request( source_language = 'D'
                                                     target_language = 'E'
                                                     formname        = form
                                                     fieldname       = field
                                                     occupied        = occupied ).

    " --- ASSERT
    " Same assertion covers the in-batch case: a target queued earlier in the
    " same call is put into "occupied" and must be rejected identically.
    cl_abap_unit_assert=>assert_equals(
        exp = zcl_form_trans_rules=>msg_duplicate_key
        act = rejection
        msg = 'A target key that is already taken must be rejected' ).
  ENDMETHOD.

  METHOD given_free_lang_then_ok.
    " --- ARRANGE
    DATA(occupied) = occupied_with_english( ).

    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request( source_language = 'E'
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
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request( source_language = 'D'
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
