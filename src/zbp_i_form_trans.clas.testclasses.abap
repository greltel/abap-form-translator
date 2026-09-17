*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">Save sequence smoke test</p>
"! Proves that the validations are wired into the save sequence and that their
"! messages reach the caller. The rules themselves are covered by
"! {@link zcl_form_trans_rules} unit tests, without any RAP or test double involvement.
CLASS ltc_form_trans DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES failed_late   TYPE RESPONSE FOR FAILED   LATE zi_form_trans.
    TYPES reported_late TYPE RESPONSE FOR REPORTED LATE zi_form_trans.

    CLASS-DATA cds_environment   TYPE REF TO if_cds_test_environment.
    CLASS-DATA draft_environment TYPE REF TO if_osql_test_environment.

    DATA authority TYPE REF TO zif_form_trans_authority.

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
    draft_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZABAP_FORM_DRFT' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    cds_environment->destroy( ).
    draft_environment->destroy( ).
  ENDMETHOD.

  METHOD setup.
    cds_environment->clear_doubles( ).
    draft_environment->clear_doubles( ).

    " The save sequence asks the global authorization; these tests are about
    " the validations, so every activity is granted.
    authority = CAST zif_form_trans_authority( cl_abap_testdouble=>create( 'zif_form_trans_authority' ) ).
    cl_abap_testdouble=>configure_call( authority
      )->ignore_all_parameters(
      )->returning( abap_true ).
    authority->is_allowed( VALUE #( ) ).
    lcl_form_trans_factory=>inject_authority( authority ).
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
    lcl_form_trans_factory=>inject_authority( VALUE #( ) ).
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
        msg = `A row that satisfies every rule must pass the save sequence` ).
  ENDMETHOD.

  METHOD given_no_text_then_rejected.
    " --- ACT
    create_and_save( EXPORTING description = VALUE #( )
                     IMPORTING failed      = DATA(failed)
                               reported    = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = `A translation without a description must be rejected` ).

    assert_save_message( reported = reported
                         expected = zcl_form_trans_rules=>msg_description_empty ).
  ENDMETHOD.

  METHOD given_len_20000_then_rejected.
    " --- ACT
    create_and_save( EXPORTING maxlength = 20000
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = `MaxLength above the domain range must be rejected on the server side` ).

    assert_save_message( reported = reported
                         expected = zcl_form_trans_rules=>msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD given_len_neg_then_rejected.
    " --- ACT
    create_and_save( EXPORTING maxlength = -1
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = `A negative MaxLength must be rejected` ).

    assert_save_message( reported = reported
                         expected = zcl_form_trans_rules=>msg_maxlength_invalid ).
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
        msg = `Truncation is a warning only and must not block the save` ).
  ENDMETHOD.

  METHOD given_lower_form_then_rejected.
    " --- ACT
    create_and_save( EXPORTING formname = 'ztest'
                     IMPORTING failed   = DATA(failed)
                               reported = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_not_initial(
        act = failed-translation
        msg = `A lower case form name must be rejected, it could never be found at print time` ).

    assert_save_message( reported = reported
                         expected = zcl_form_trans_rules=>msg_key_not_upper ).
  ENDMETHOD.

ENDCLASS.


"! <p class="shorttext" lang="EN">Tests for the global authorization</p>
"! Calls the handler method directly with a double of the authority check, so
"! the mapping of every operation to its ZFORMTRA activity and the denial
"! messages can be asserted without roles or a save sequence.
CLASS ltc_authorizations DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES auth_result TYPE STRUCTURE FOR GLOBAL AUTHORIZATION RESULT zi_form_trans\\translation.
    TYPES reported_early TYPE RESPONSE FOR REPORTED EARLY zi_form_trans.

    DATA cut       TYPE REF TO lhc_translation.
    DATA authority TYPE REF TO zif_form_trans_authority.

    METHODS setup.
    METHODS teardown.

    "! Grants exactly one activity on the double; every other activity is denied.
    "!
    "! @parameter activity | Activity the double reports as allowed.
    METHODS given_only
      IMPORTING activity TYPE zif_form_trans_authority=>activity.

    "! Asserts that the global message with the given number was reported.
    "!
    "! @parameter reported | Reported response returned by the handler.
    "! @parameter expected | Message number that has to be present.
    METHODS assert_global_message
      IMPORTING !reported TYPE reported_early
                expected  TYPE symsgno.

    METHODS when_create_allowed_then_ok    FOR TESTING.
    METHODS when_create_denied_then_msg008 FOR TESTING.
    METHODS when_update_denied_then_msg009 FOR TESTING.
    METHODS when_copy_then_needs_create    FOR TESTING.
    METHODS when_edit_then_needs_change    FOR TESTING.
    METHODS when_not_asked_then_untouched  FOR TESTING.

ENDCLASS.


CLASS ltc_authorizations IMPLEMENTATION.

  METHOD setup.
    authority = CAST zif_form_trans_authority( cl_abap_testdouble=>create( 'zif_form_trans_authority' ) ).
    lcl_form_trans_factory=>inject_authority( authority ).
    CREATE OBJECT cut FOR TESTING.
  ENDMETHOD.

  METHOD teardown.
    lcl_form_trans_factory=>inject_authority( VALUE #( ) ).
  ENDMETHOD.

  METHOD given_only.
    cl_abap_testdouble=>configure_call( authority )->returning( abap_true ).
    authority->is_allowed( activity ).
  ENDMETHOD.

  METHOD assert_global_message.
    DATA found TYPE abap_boolean.

    LOOP AT reported-translation INTO DATA(entry).
      IF     entry-%global = if_abap_behv=>mk-on
         AND entry-%msg IS BOUND
         AND entry-%msg->if_t100_message~t100key-msgno = expected.
        found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
        act = found
        msg = |Global message { expected } was not reported for the denied operation| ).
  ENDMETHOD.

  METHOD when_create_allowed_then_ok.
    " --- ARRANGE
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.
    given_only( zif_form_trans_authority=>activities-create ).

    " --- ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %create = if_abap_behv=>mk-on )
      CHANGING  result                   = result
                reported                 = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = if_abap_behv=>auth-allowed
        act = result-%create
        msg = `A user holding activity 01 must be allowed to create` ).
    cl_abap_unit_assert=>assert_initial(
        act = reported-translation
        msg = `An allowed operation must not report anything` ).
  ENDMETHOD.

  METHOD when_create_denied_then_msg008.
    " --- ARRANGE: nothing granted on the double
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.

    " --- ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %create = if_abap_behv=>mk-on )
      CHANGING  result                   = result
                reported                 = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = if_abap_behv=>auth-unauthorized
        act = result-%create
        msg = `Without activity 01 a create must be denied` ).
    assert_global_message( reported = reported
                           expected = zcl_form_trans_rules=>msg_create_unauthorized ).
  ENDMETHOD.

  METHOD when_update_denied_then_msg009.
    " --- ARRANGE
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.
    given_only( zif_form_trans_authority=>activities-create ).

    " --- ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %update = if_abap_behv=>mk-on )
      CHANGING  result                   = result
                reported                 = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = if_abap_behv=>auth-unauthorized
        act = result-%update
        msg = `Activity 01 alone must not allow an update` ).
    assert_global_message( reported = reported
                           expected = zcl_form_trans_rules=>msg_change_unauthorized ).
  ENDMETHOD.

  METHOD when_copy_then_needs_create.
    " --- ARRANGE
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.
    given_only( zif_form_trans_authority=>activities-create ).

    " --- ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %action-copytolanguage = if_abap_behv=>mk-on )
      CHANGING  result                   = result
                reported                 = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = if_abap_behv=>auth-allowed
        act = result-%action-copytolanguage
        msg = `copyToLanguage creates rows and must follow the create activity` ).
  ENDMETHOD.

  METHOD when_edit_then_needs_change.
    " --- ARRANGE
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.
    given_only( zif_form_trans_authority=>activities-change ).

    " --- ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( %action-edit = if_abap_behv=>mk-on )
      CHANGING  result                   = result
                reported                 = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = if_abap_behv=>auth-allowed
        act = result-%action-edit
        msg = `Edit opens an update and must follow the change activity` ).
  ENDMETHOD.

  METHOD when_not_asked_then_untouched.
    " --- ARRANGE: nothing granted, nothing requested
    DATA result   TYPE auth_result.
    DATA reported TYPE reported_early.

    " --- ACT
    cut->get_global_authorizations(
      EXPORTING requested_authorizations = VALUE #( )
      CHANGING  result                   = result
                reported                 = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = reported-translation
        msg = `Operations the framework did not ask about must not be evaluated` ).
  ENDMETHOD.

ENDCLASS.
