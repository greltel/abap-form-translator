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

    "! Builds an ambiguity set in which the Greek target of the standard field
    "! is claimed by more than one selected row.
    "!
    "! @parameter result | Single entry ZTEST / TITLE / G.
    METHODS ambiguous_with_greek
      RETURNING VALUE(result) TYPE zcl_form_trans_rules=>translation_keys.

    "! Builds one copy request for the standard form.
    "!
    "! @parameter fieldname | Field of the row that is being copied.
    "! @parameter source    | Language the row currently carries.
    "! @parameter target    | Language requested in the popup.
    "! @parameter result    | The assembled request.
    METHODS request
      IMPORTING !fieldname    TYPE zabap_form_trans_field
                !source       TYPE zabap_form_trans_langu
                !target       TYPE zabap_form_trans_langu
      RETURNING VALUE(result) TYPE zcl_form_trans_rules=>copy_request.

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

    METHODS given_2_sources_then_ambiguous FOR TESTING.
    METHODS given_3_sources_then_1_entry   FOR TESTING.
    METHODS given_2_fields_then_not_ambig  FOR TESTING.
    METHODS given_2_targets_then_not_ambig FOR TESTING.
    METHODS given_1_source_then_not_ambig  FOR TESTING.
    METHODS given_no_target_then_not_ambig FOR TESTING.
    METHODS given_self_copy_then_not_ambig FOR TESTING.
    METHODS given_ambiguous_then_rejected  FOR TESTING.
    METHODS given_ambig_and_taken_then_amb FOR TESTING.
    METHODS given_ambig_other_then_ok      FOR TESTING.

ENDCLASS.


CLASS ltc_rules IMPLEMENTATION.

  METHOD occupied_with_english.
    result = VALUE #( ( formname    = form
                        fieldname   = field
                        languagekey = 'E' ) ).
  ENDMETHOD.

  METHOD ambiguous_with_greek.
    result = VALUE #( ( formname    = form
                        fieldname   = field
                        languagekey = 'G' ) ).
  ENDMETHOD.

  METHOD request.
    result = VALUE #( formname        = form
                      fieldname       = fieldname
                      source_language = source
                      target_language = target ).
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
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'E'
                          target_language = VALUE #( )
                          formname        = form
                          fieldname       = field
                          ambiguous       = VALUE #( )
                          occupied        = VALUE #( ) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = zcl_form_trans_rules=>msg_language_missing
        act = rejection
        msg = 'A copy request without a target language must be rejected' ).
  ENDMETHOD.

  METHOD given_same_lang_then_rejected.
    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'E'
                          target_language = 'E'
                          formname        = form
                          fieldname       = field
                          ambiguous       = VALUE #( )
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
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'D'
                          target_language = 'E'
                          formname        = form
                          fieldname       = field
                          ambiguous       = VALUE #( )
                          occupied        = occupied ).

    " --- ASSERT
    " Covers the persisted target keys, active as well as draft. Two selected
    " rows competing for one target are caught earlier, by the ambiguity rule.
    cl_abap_unit_assert=>assert_equals(
        exp = zcl_form_trans_rules=>msg_duplicate_key
        act = rejection
        msg = 'A target key that is already taken must be rejected' ).
  ENDMETHOD.

  METHOD given_free_lang_then_ok.
    " --- ARRANGE
    DATA(occupied) = occupied_with_english( ).

    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'E'
                          target_language = 'D'
                          formname        = form
                          fieldname       = field
                          ambiguous       = VALUE #( )
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
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'D'
                          target_language = 'E'
                          formname        = form
                          fieldname       = 'FOOTER'
                          ambiguous       = VALUE #( )
                          occupied        = occupied ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = rejection
        msg = 'The same target language on a different field must not be blocked' ).
  ENDMETHOD.

  METHOD given_2_sources_then_ambiguous.
    " --- ARRANGE
    " The English and the French row of one field both ask for Greek.
    DATA(requests) = VALUE zcl_form_trans_rules=>copy_requests(
                         ( request( fieldname = field source = 'E' target = 'G' ) )
                         ( request( fieldname = field source = 'F' target = 'G' ) ) ).

    " --- ACT
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets( requests ).

    " --- ASSERT
    " Comparing the whole table covers both halves of the rule at once: the
    " contested key has to be reported, and nothing else may be.
    cl_abap_unit_assert=>assert_equals(
        exp = ambiguous_with_greek( )
        act = ambiguous
        msg = 'Two rows competing for one target key must yield exactly that key, and only it' ).
  ENDMETHOD.

  METHOD given_3_sources_then_1_entry.
    " --- ARRANGE
    DATA(requests) = VALUE zcl_form_trans_rules=>copy_requests(
                         ( request( fieldname = field source = 'E' target = 'G' ) )
                         ( request( fieldname = field source = 'F' target = 'G' ) )
                         ( request( fieldname = field source = 'D' target = 'G' ) ) ).

    " --- ACT
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets( requests ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( ambiguous )
        msg = 'A contested target key must be reported once, however many rows compete for it' ).
  ENDMETHOD.

  METHOD given_2_fields_then_not_ambig.
    " --- ARRANGE
    DATA(requests) = VALUE zcl_form_trans_rules=>copy_requests(
                         ( request( fieldname = field    source = 'E' target = 'G' ) )
                         ( request( fieldname = 'FOOTER' source = 'E' target = 'G' ) ) ).

    " --- ACT
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets( requests ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = ambiguous
        msg = 'Rows of different fields write different keys and never compete' ).
  ENDMETHOD.

  METHOD given_2_targets_then_not_ambig.
    " --- ARRANGE
    DATA(requests) = VALUE zcl_form_trans_rules=>copy_requests(
                         ( request( fieldname = field source = 'E' target = 'G' ) )
                         ( request( fieldname = field source = 'F' target = 'D' ) ) ).

    " --- ACT
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets( requests ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = ambiguous
        msg = 'Two rows of one field are fine as long as they aim at different languages' ).
  ENDMETHOD.

  METHOD given_1_source_then_not_ambig.
    " --- ARRANGE
    DATA(requests) = VALUE zcl_form_trans_rules=>copy_requests(
                         ( request( fieldname = field source = 'E' target = 'G' ) ) ).

    " --- ACT
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets( requests ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = ambiguous
        msg = 'A single selected row can never be ambiguous' ).
  ENDMETHOD.

  METHOD given_no_target_then_not_ambig.
    " --- ARRANGE
    DATA(requests) = VALUE zcl_form_trans_rules=>copy_requests(
                         ( request( fieldname = field source = 'E' target = VALUE #( ) ) )
                         ( request( fieldname = field source = 'F' target = VALUE #( ) ) ) ).

    " --- ACT
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets( requests ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = ambiguous
        msg = 'A missing target language is reported as such and must not form a group' ).
  ENDMETHOD.

  METHOD given_self_copy_then_not_ambig.
    " --- ARRANGE
    " The French row would be copied onto itself, so only the English row is a
    " real candidate for the French target.
    DATA(requests) = VALUE zcl_form_trans_rules=>copy_requests(
                         ( request( fieldname = field source = 'F' target = 'F' ) )
                         ( request( fieldname = field source = 'E' target = 'F' ) ) ).

    " --- ACT
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets( requests ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = ambiguous
        msg = 'A row copied onto its own language leaves only one candidate for the target' ).
  ENDMETHOD.

  METHOD given_ambiguous_then_rejected.
    " --- ARRANGE
    DATA(ambiguous) = ambiguous_with_greek( ).

    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'E'
                          target_language = 'G'
                          formname        = form
                          fieldname       = field
                          ambiguous       = ambiguous
                          occupied        = VALUE #( ) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = zcl_form_trans_rules=>msg_ambiguous_source
        act = rejection
        msg = 'Every row of a contested group must be rejected, none may win silently' ).
  ENDMETHOD.

  METHOD given_ambig_and_taken_then_amb.
    " --- ARRANGE
    DATA(ambiguous) = ambiguous_with_greek( ).

    DATA(occupied) = VALUE zcl_form_trans_rules=>translation_keys(
                         ( formname    = form
                           fieldname   = field
                           languagekey = 'G' ) ).

    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'E'
                          target_language = 'G'
                          formname        = form
                          fieldname       = field
                          ambiguous       = ambiguous
                          occupied        = occupied ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = zcl_form_trans_rules=>msg_ambiguous_source
        act = rejection
        msg = 'Ambiguity is the more actionable reason and must win over the duplicate message' ).
  ENDMETHOD.

  METHOD given_ambig_other_then_ok.
    " --- ARRANGE
    DATA(ambiguous) = ambiguous_with_greek( ).

    " --- ACT
    DATA(rejection) = zcl_form_trans_rules=>check_copy_request(
                          source_language = 'E'
                          target_language = 'G'
                          formname        = form
                          fieldname       = 'FOOTER'
                          ambiguous       = ambiguous
                          occupied        = VALUE #( ) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = rejection
        msg = 'A contested group on one field must not block another field' ).
  ENDMETHOD.

ENDCLASS.
