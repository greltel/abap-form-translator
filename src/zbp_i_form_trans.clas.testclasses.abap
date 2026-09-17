*"* use this source file for your ABAP unit test classes

"! <p class="shorttext" lang="EN">CDS and draft table doubles for the handler tests</p>
"! Every test class that drives the handler needs the same two doubles; this
"! helper owns their lifecycle so the test classes only state their data.
"! <br>
"! READ ENTITIES is served through the CDS entity, not through the table, so
"! a plain table double stays invisible to the managed runtime. Doubling the
"! entity with its base dependencies also doubles ZABAP_FORM_TRANS, which keeps
"! the managed reads and the direct SELECT of validateUniqueKey on the same
"! data. The draft table is declared in the BDEF, not in the CDS entity, so it
"! needs its own double.
CLASS lth_translation_doubles DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    TYPES translations TYPE STANDARD TABLE OF zabap_form_trans WITH EMPTY KEY.

    "! Creates both doubles once; further calls are no-ops.
    CLASS-METHODS create.
    "! Destroys both doubles; the next create builds them again.
    CLASS-METHODS destroy.
    "! Empties both doubles - call it in every setup.
    CLASS-METHODS clear.

    "! Inserts rows as active, persisted translations.
    "!
    "! @parameter rows | Rows to insert into the double of ZABAP_FORM_TRANS.
    CLASS-METHODS given_active
      IMPORTING rows TYPE translations.

    "! Builds one row; every parameter defaults to a valid value so a test only
    "! names what it wants to be different.
    "!
    "! @parameter formname  | Form key.
    "! @parameter fieldname | Field key.
    "! @parameter langu     | Language of the text.
    "! @parameter descr     | Text; defaults to a non-empty value.
    "! @parameter length    | Length limit; 0 means no limit.
    "! @parameter result    | Row ready for given_active.
    CLASS-METHODS row
      IMPORTING formname      TYPE zabap_form_trans_name   DEFAULT 'ZTEST'
                fieldname     TYPE zabap_form_trans_field  DEFAULT 'TITLE'
                langu         TYPE zabap_form_trans_langu  DEFAULT 'E'
                descr         TYPE zabap_form_trans_descr  DEFAULT 'Invoice'
                !length       TYPE zabap_form_trans_maxlen DEFAULT 0
      RETURNING VALUE(result) TYPE zabap_form_trans.

  PRIVATE SECTION.
    CLASS-DATA cds_environment   TYPE REF TO if_cds_test_environment.
    CLASS-DATA draft_environment TYPE REF TO if_osql_test_environment.
ENDCLASS.


CLASS lth_translation_doubles IMPLEMENTATION.
  METHOD create.
    IF cds_environment IS BOUND.
      RETURN.
    ENDIF.

    cds_environment = cl_cds_test_environment=>create_for_multiple_cds(
                          i_for_entities = VALUE #( ( i_for_entity               = 'ZI_FORM_TRANS'
                                                      i_select_base_dependencies = abap_true ) ) ).

    draft_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZABAP_FORM_DRFT' ) ) ).
  ENDMETHOD.

  METHOD destroy.
    IF cds_environment IS NOT BOUND.
      RETURN.
    ENDIF.

    cds_environment->destroy( ).
    draft_environment->destroy( ).
    CLEAR cds_environment.
    CLEAR draft_environment.
  ENDMETHOD.

  METHOD clear.
    cds_environment->clear_doubles( ).
    draft_environment->clear_doubles( ).
  ENDMETHOD.

  METHOD given_active.
    cds_environment->insert_test_data( rows ).
  ENDMETHOD.

  METHOD row.
    result = VALUE #( form      = formname
                      fieldname = fieldname
                      langu     = langu
                      descr     = descr
                      length    = length ).
  ENDMETHOD.
ENDCLASS.

"! <p class="shorttext" lang="EN">Save sequence smoke test</p>
"! Two EML driven tests that prove the wiring: a valid row passes the whole
"! save sequence, and a rejection raised by a validation reaches the caller
"! of COMMIT ENTITIES. Every rule and every handler method is covered by the
"! direct tests below; nothing else is repeated here.
CLASS ltc_form_trans DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES failed_late   TYPE RESPONSE FOR FAILED   LATE zi_form_trans.
    TYPES reported_late TYPE RESPONSE FOR REPORTED LATE zi_form_trans.

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
    "! @parameter failed      | Instances rejected by the save sequence.
    "! @parameter reported    | Messages raised by the save sequence.
    METHODS create_and_save
      IMPORTING formname     TYPE zabap_form_trans_name   DEFAULT 'ZTEST'
                fieldname    TYPE zabap_form_trans_field  DEFAULT 'TITLE'
                languagekey  TYPE zabap_form_trans_langu  DEFAULT 'E'
                !description TYPE zabap_form_trans_descr  DEFAULT 'Invoice'
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

    METHODS given_valid_row_then_saved  FOR TESTING.
    METHODS given_no_text_then_rejected FOR TESTING.

ENDCLASS.


CLASS ltc_form_trans IMPLEMENTATION.

  METHOD class_setup.
    lth_translation_doubles=>create( ).
  ENDMETHOD.

  METHOD class_teardown.
    lth_translation_doubles=>destroy( ).
  ENDMETHOD.

  METHOD setup.
    lth_translation_doubles=>clear( ).

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
           CREATE FIELDS ( formname fieldname languagekey description )
           WITH VALUE #( ( %cid        = 'CID1'
                           formname    = formname
                           fieldname   = fieldname
                           languagekey = languagekey
                           description = description ) ).

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


"! <p class="shorttext" lang="EN">Tests for the ON SAVE validations</p>
"! Calls each validation directly on the handler with active rows in the CDS
"! double, so every rule is asserted with its message and without a save
"! sequence. The rules themselves are covered by {@link zcl_form_trans_rules};
"! these tests prove the wiring: read, rule, failed and reported.
CLASS ltc_validations DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES failed_late   TYPE RESPONSE FOR FAILED   LATE zi_form_trans.
    TYPES reported_late TYPE RESPONSE FOR REPORTED LATE zi_form_trans.

    DATA cut TYPE REF TO lhc_translation.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    "! Asserts that a message with the given number and severity was reported.
    "!
    "! @parameter reported | Reported response returned by the validation.
    "! @parameter expected | Message number that has to be present.
    "! @parameter severity | Expected severity of that message.
    METHODS assert_message
      IMPORTING !reported TYPE reported_late
                expected  TYPE symsgno
                severity  TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error.

    METHODS given_valid_row_then_clean   FOR TESTING.
    METHODS given_no_text_then_msg002    FOR TESTING.
    METHODS given_len_20000_then_msg001  FOR TESTING.
    METHODS given_long_text_then_warn006 FOR TESTING.
    METHODS given_lower_form_then_msg007 FOR TESTING.
    METHODS given_stored_key_then_msg003 FOR TESTING.

ENDCLASS.


CLASS ltc_validations IMPLEMENTATION.

  METHOD class_setup.
    lth_translation_doubles=>create( ).
  ENDMETHOD.

  METHOD class_teardown.
    lth_translation_doubles=>destroy( ).
  ENDMETHOD.

  METHOD setup.
    lth_translation_doubles=>clear( ).
    CREATE OBJECT cut FOR TESTING.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD assert_message.
    DATA found TYPE abap_boolean.

    LOOP AT reported-translation INTO DATA(entry).
      " State area clearing entries carry no message object.
      IF     entry-%msg IS BOUND
         AND entry-%msg->if_t100_message~t100key-msgno = expected
         AND entry-%msg->m_severity = severity.
        found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
        act = found
        msg = |Message { expected } was not reported with the expected severity| ).
  ENDMETHOD.

  METHOD given_valid_row_then_clean.
    " --- ARRANGE
    DATA failed   TYPE failed_late.
    DATA reported TYPE reported_late.
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( ) ) ) ).

    " --- ACT
    cut->validatedescription( EXPORTING keys     = VALUE #( ( formname    = 'ZTEST'
                                                             fieldname   = 'TITLE'
                                                             languagekey = 'E' ) )
                              CHANGING  failed   = failed
                                        reported = reported ).
    cut->validatemaxlength( EXPORTING keys     = VALUE #( ( formname = 'ZTEST' fieldname = 'TITLE' languagekey = 'E' ) )
                            CHANGING  failed   = failed
                                      reported = reported ).
    cut->validatekeycase( EXPORTING keys     = VALUE #( ( formname = 'ZTEST' fieldname = 'TITLE' languagekey = 'E' ) )
                          CHANGING  failed   = failed
                                    reported = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = failed-translation
        msg = `A row that satisfies every rule must not be rejected by any validation` ).
  ENDMETHOD.

  METHOD given_no_text_then_msg002.
    " --- ARRANGE
    DATA failed   TYPE failed_late.
    DATA reported TYPE reported_late.
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( descr = VALUE #( ) ) ) ) ).

    " --- ACT
    cut->validatedescription( EXPORTING keys     = VALUE #( ( formname    = 'ZTEST'
                                                             fieldname   = 'TITLE'
                                                             languagekey = 'E' ) )
                              CHANGING  failed   = failed
                                        reported = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `A row without a description must be rejected` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_description_empty ).
  ENDMETHOD.

  METHOD given_len_20000_then_msg001.
    " --- ARRANGE
    DATA failed   TYPE failed_late.
    DATA reported TYPE reported_late.
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( length = 20000 ) ) ) ).

    " --- ACT
    cut->validatemaxlength( EXPORTING keys     = VALUE #( ( formname = 'ZTEST' fieldname = 'TITLE' languagekey = 'E' ) )
                            CHANGING  failed   = failed
                                      reported = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `A MaxLength above the domain range must be rejected` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD given_long_text_then_warn006.
    " --- ARRANGE
    DATA failed   TYPE failed_late.
    DATA reported TYPE reported_late.
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( length = 3 ) ) ) ).

    " --- ACT
    cut->validatemaxlength( EXPORTING keys     = VALUE #( ( formname = 'ZTEST' fieldname = 'TITLE' languagekey = 'E' ) )
                            CHANGING  failed   = failed
                                      reported = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = failed-translation
        msg = `Truncation is a warning and must not reject the row` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_text_truncated
                    severity = if_abap_behv_message=>severity-warning ).
  ENDMETHOD.

  METHOD given_lower_form_then_msg007.
    " --- ARRANGE
    DATA failed   TYPE failed_late.
    DATA reported TYPE reported_late.
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( formname = 'ztest' ) ) ) ).

    " --- ACT
    cut->validatekeycase( EXPORTING keys     = VALUE #( ( formname = 'ztest' fieldname = 'TITLE' languagekey = 'E' ) )
                          CHANGING  failed   = failed
                                    reported = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `A lower case form name must be rejected` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_key_not_upper ).
  ENDMETHOD.

  METHOD given_stored_key_then_msg003.
    " The double serves both the instance under validation and the persisted
    " table, so a row that exists there is exactly the "key already stored"
    " situation the validation guards against.

    " --- ARRANGE
    DATA failed   TYPE failed_late.
    DATA reported TYPE reported_late.
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( ) ) ) ).

    " --- ACT
    cut->validateuniquekey( EXPORTING keys     = VALUE #( ( formname = 'ZTEST' fieldname = 'TITLE' languagekey = 'E' ) )
                            CHANGING  failed   = failed
                                      reported = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `A key that is already persisted must be rejected` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_duplicate_key ).
  ENDMETHOD.

ENDCLASS.

"! <p class="shorttext" lang="EN">Tests for the instance features</p>
"! copyToLanguage is only offered for rows that carry a description.
CLASS ltc_features DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES feature_result TYPE TABLE FOR INSTANCE FEATURES RESULT zi_form_trans\\translation.
    TYPES failed_early   TYPE RESPONSE FOR FAILED   EARLY zi_form_trans.
    TYPES reported_early TYPE RESPONSE FOR REPORTED EARLY zi_form_trans.

    DATA cut TYPE REF TO lhc_translation.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    "! Asks the handler about copyToLanguage for the default row.
    "!
    "! @parameter result | Feature control returned by the handler.
    METHODS features_of_default_row
      RETURNING VALUE(result) TYPE feature_result.

    METHODS given_text_then_copy_enabled  FOR TESTING.
    METHODS given_no_text_then_disabled   FOR TESTING.
    METHODS when_not_requested_then_empty FOR TESTING.

ENDCLASS.


CLASS ltc_features IMPLEMENTATION.

  METHOD class_setup.
    lth_translation_doubles=>create( ).
  ENDMETHOD.

  METHOD class_teardown.
    lth_translation_doubles=>destroy( ).
  ENDMETHOD.

  METHOD setup.
    lth_translation_doubles=>clear( ).
    CREATE OBJECT cut FOR TESTING.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD features_of_default_row.
    DATA failed   TYPE failed_early.
    DATA reported TYPE reported_early.

    cut->get_instance_features(
      EXPORTING keys               = VALUE #( ( formname = 'ZTEST' fieldname = 'TITLE' languagekey = 'E' ) )
                requested_features = VALUE #( %action-copytolanguage = if_abap_behv=>mk-on )
      CHANGING  result             = result
                failed             = failed
                reported           = reported ).
  ENDMETHOD.

  METHOD given_text_then_copy_enabled.
    " --- ARRANGE
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( ) ) ) ).

    " --- ACT
    DATA(features) = features_of_default_row( ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = if_abap_behv=>fc-o-enabled
        act = features[ 1 ]-%action-copytolanguage
        msg = `A row with a description must offer copyToLanguage` ).
  ENDMETHOD.

  METHOD given_no_text_then_disabled.
    " --- ARRANGE
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( descr = VALUE #( ) ) ) ) ).

    " --- ACT
    DATA(features) = features_of_default_row( ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = if_abap_behv=>fc-o-disabled
        act = features[ 1 ]-%action-copytolanguage
        msg = `A row without a description has nothing to copy and must not offer the action` ).
  ENDMETHOD.

  METHOD when_not_requested_then_empty.
    " --- ARRANGE
    DATA result   TYPE feature_result.
    DATA failed   TYPE failed_early.
    DATA reported TYPE reported_early.
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( ) ) ) ).

    " --- ACT
    cut->get_instance_features(
      EXPORTING keys               = VALUE #( ( formname = 'ZTEST' fieldname = 'TITLE' languagekey = 'E' ) )
                requested_features = VALUE #( )
      CHANGING  result             = result
                failed             = failed
                reported           = reported ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = result
        msg = `When the framework does not ask about copyToLanguage nothing must be read or returned` ).
  ENDMETHOD.

ENDCLASS.


"! <p class="shorttext" lang="EN">Tests for the copyToLanguage action</p>
"! Calls the action directly with active rows in the CDS double. The action
"! creates the copies as drafts in the transactional buffer, which the tests
"! read back in local mode; ROLLBACK ENTITIES discards them.
CLASS ltc_copy_action DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES mapped_early   TYPE RESPONSE FOR MAPPED   EARLY zi_form_trans.
    TYPES failed_early   TYPE RESPONSE FOR FAILED   EARLY zi_form_trans.
    TYPES reported_early TYPE RESPONSE FOR REPORTED EARLY zi_form_trans.

    DATA cut TYPE REF TO lhc_translation.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    "! Builds one action key for the field TITLE of ZTEST.
    "!
    "! @parameter cid             | Content id of the request.
    "! @parameter source_language | Language of the row to copy.
    "! @parameter target_language | Language to copy it to.
    "! @parameter result          | Action key ready for copytolanguage.
    METHODS copy_key
      IMPORTING cid             TYPE abp_behv_cid
                source_language TYPE zabap_form_trans_langu DEFAULT 'E'
                target_language TYPE zabap_form_trans_langu
      RETURNING VALUE(result)   TYPE lhc_translation=>copy_action_keys.

    "! Runs the action and hands back its responses.
    "!
    "! @parameter keys     | Action keys to process.
    "! @parameter mapped   | Content ids mapped to the created drafts.
    "! @parameter failed   | Rejected keys.
    "! @parameter reported | Messages raised.
    METHODS copy
      IMPORTING keys      TYPE lhc_translation=>copy_action_keys
      EXPORTING !mapped   TYPE mapped_early
                !failed   TYPE failed_early
                !reported TYPE reported_early.

    "! Asserts that a message with the given number was reported.
    "!
    "! @parameter reported | Reported response returned by the action.
    "! @parameter expected | Message number that has to be present.
    METHODS assert_message
      IMPORTING !reported TYPE reported_early
                expected  TYPE symsgno.

    METHODS given_target_free_then_copied  FOR TESTING.
    METHODS given_same_lang_then_msg005    FOR TESTING.
    METHODS given_no_target_then_msg004    FOR TESTING.
    METHODS given_target_taken_then_msg003 FOR TESTING.
    METHODS given_two_sources_then_msg010  FOR TESTING.
    METHODS given_unknown_key_then_failed  FOR TESTING.

ENDCLASS.


CLASS ltc_copy_action IMPLEMENTATION.

  METHOD class_setup.
    lth_translation_doubles=>create( ).
  ENDMETHOD.

  METHOD class_teardown.
    lth_translation_doubles=>destroy( ).
  ENDMETHOD.

  METHOD setup.
    lth_translation_doubles=>clear( ).
    CREATE OBJECT cut FOR TESTING.
  ENDMETHOD.

  METHOD teardown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  METHOD copy_key.
    result = VALUE #( ( %cid                  = cid
                        formname              = 'ZTEST'
                        fieldname             = 'TITLE'
                        languagekey           = source_language
                        %param-targetlanguage = target_language ) ).
  ENDMETHOD.

  METHOD copy.
    CLEAR mapped.
    CLEAR failed.
    CLEAR reported.

    cut->copytolanguage( EXPORTING keys     = keys
                         CHANGING  mapped   = mapped
                                   failed   = failed
                                   reported = reported ).
  ENDMETHOD.

  METHOD assert_message.
    DATA found TYPE abap_boolean.

    LOOP AT reported-translation INTO DATA(entry).
      IF entry-%msg IS BOUND AND entry-%msg->if_t100_message~t100key-msgno = expected.
        found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true(
        act = found
        msg = |Message { expected } was not reported by copyToLanguage| ).
  ENDMETHOD.

  METHOD given_target_free_then_copied.
    " --- ARRANGE
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( length = 7 ) ) ) ).

    " --- ACT
    copy( EXPORTING keys     = copy_key( cid = 'C1' target_language = 'D' )
          IMPORTING mapped   = DATA(mapped)
                    failed   = DATA(failed) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_initial(
        act = failed-translation
        msg = `A free target language must not be rejected` ).
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( mapped-translation )
        msg = `Exactly one draft must be mapped to the content id` ).

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( description maxlength )
         WITH VALUE #( ( %is_draft   = if_abap_behv=>mk-on
                         formname    = 'ZTEST'
                         fieldname   = 'TITLE'
                         languagekey = 'D' ) )
         RESULT DATA(copies).

    cl_abap_unit_assert=>assert_equals(
        exp = 'Invoice'
        act = copies[ 1 ]-description
        msg = `The draft must carry the description of the source row` ).
    cl_abap_unit_assert=>assert_equals(
        exp = 7
        act = copies[ 1 ]-maxlength
        msg = `The draft must carry the length limit of the source row` ).
  ENDMETHOD.

  METHOD given_same_lang_then_msg005.
    " --- ARRANGE
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( ) ) ) ).

    " --- ACT
    copy( EXPORTING keys     = copy_key( cid = 'C1' target_language = 'E' )
          IMPORTING mapped   = DATA(mapped)
                    failed   = DATA(failed)
                    reported = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `Copying a row onto its own language must be rejected` ).
    cl_abap_unit_assert=>assert_initial(
        act = mapped-translation
        msg = `A rejected request must not create a draft` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_same_language ).
  ENDMETHOD.

  METHOD given_no_target_then_msg004.
    " --- ARRANGE
    lth_translation_doubles=>given_active( VALUE #( ( lth_translation_doubles=>row( ) ) ) ).

    " --- ACT
    copy( EXPORTING keys     = copy_key( cid = 'C1' target_language = VALUE #( ) )
          IMPORTING failed   = DATA(failed)
                    reported = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `An empty target language must be rejected` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_language_missing ).
  ENDMETHOD.

  METHOD given_target_taken_then_msg003.
    " --- ARRANGE
    lth_translation_doubles=>given_active(
        VALUE #( ( lth_translation_doubles=>row( ) )
                 ( lth_translation_doubles=>row( langu = 'D' descr = 'Rechnung' ) ) ) ).

    " --- ACT
    copy( EXPORTING keys     = copy_key( cid = 'C1' target_language = 'D' )
          IMPORTING failed   = DATA(failed)
                    reported = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `A target language that already has a row must be rejected` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_duplicate_key ).
  ENDMETHOD.

  METHOD given_two_sources_then_msg010.
    " --- ARRANGE
    lth_translation_doubles=>given_active(
        VALUE #( ( lth_translation_doubles=>row( ) )
                 ( lth_translation_doubles=>row( langu = 'D' descr = 'Rechnung' ) ) ) ).

    DATA(keys) = copy_key( cid = 'C1' target_language = 'F' ).
    INSERT LINES OF copy_key( cid = 'C2' source_language = 'D' target_language = 'F' ) INTO TABLE keys.

    " --- ACT
    copy( EXPORTING keys     = keys
          IMPORTING mapped   = DATA(mapped)
                    failed   = DATA(failed)
                    reported = DATA(reported) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 2
        act = lines( failed-translation )
        msg = `Two sources competing for one target must both be rejected` ).
    cl_abap_unit_assert=>assert_initial(
        act = mapped-translation
        msg = `Neither competing source may silently win` ).
    assert_message( reported = reported
                    expected = zcl_form_trans_rules=>msg_ambiguous_source ).
  ENDMETHOD.

  METHOD given_unknown_key_then_failed.
    " --- ARRANGE: nothing in the double

    " --- ACT
    copy( EXPORTING keys     = copy_key( cid = 'C1' target_language = 'D' )
          IMPORTING mapped   = DATA(mapped)
                    failed   = DATA(failed) ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = 1
        act = lines( failed-translation )
        msg = `A key that cannot be read must be reported as failed, not silently skipped` ).
    cl_abap_unit_assert=>assert_initial(
        act = mapped-translation
        msg = `Nothing may be created for a key that could not be read` ).
  ENDMETHOD.

ENDCLASS.
