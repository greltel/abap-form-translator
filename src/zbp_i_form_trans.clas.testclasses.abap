*"* use this source file for your ABAP unit test classes

CLASS ltc_form_trans DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES failed_late    TYPE RESPONSE FOR FAILED LATE zi_form_trans.
    TYPES reported_late  TYPE RESPONSE FOR REPORTED LATE zi_form_trans.
    TYPES reported_early TYPE RESPONSE FOR REPORTED EARLY zi_form_trans.

    CONSTANTS msg_maxlength_invalid TYPE symsgno VALUE '001'.
    CONSTANTS msg_description_empty TYPE symsgno VALUE '002'.
    CONSTANTS msg_duplicate_key     TYPE symsgno VALUE '003'.
    CONSTANTS msg_language_missing  TYPE symsgno VALUE '004'.
    CONSTANTS msg_same_language     TYPE symsgno VALUE '005'.
    CONSTANTS msg_text_truncated    TYPE symsgno VALUE '006'.
    CONSTANTS msg_key_not_upper     TYPE symsgno VALUE '007'.

    CLASS-DATA cds_environment   TYPE REF TO if_cds_test_environment.
    CLASS-DATA draft_environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    "! Puts one active row into the persistence double.
    "!
    "! @parameter formname |
    "! @parameter fieldname |
    "! @parameter languagekey |
    METHODS given_active_row
      IMPORTING formname    TYPE zabap_form_trans_name  DEFAULT 'ZTEST'
                fieldname   TYPE zabap_form_trans_field DEFAULT 'TITLE'
                languagekey TYPE zabap_form_trans_langu DEFAULT 'E'.

    "! Runs a CREATE through the full save sequence so the ON SAVE
    "! validations are executed, and hands back their outcome.
    "!
    "! @parameter formname |
    "! @parameter fieldname |
    "! @parameter languagekey |
    "! @parameter description |
    "! @parameter maxlength |
    "! @parameter failed |
    "! @parameter reported |
    METHODS create_and_save
      IMPORTING formname     TYPE zabap_form_trans_name   DEFAULT 'ZTEST'
                fieldname    TYPE zabap_form_trans_field  DEFAULT 'TITLE'
                languagekey  TYPE zabap_form_trans_langu  DEFAULT 'E'
                !description TYPE zabap_form_trans_descr  DEFAULT 'Invoice'
                maxlength    TYPE zabap_form_trans_maxlen DEFAULT 0
      EXPORTING !failed      TYPE failed_late
                !reported    TYPE reported_late.

    "! Executes copyToLanguage on an existing active instance.
    "! @parameter target |
    "! @parameter result |
    METHODS copy_to
      IMPORTING !target       TYPE zabap_form_trans_langu
      RETURNING VALUE(result) TYPE reported_early.

    METHODS assert_save_message
      IMPORTING !reported TYPE reported_late
                expected  TYPE symsgno.

    METHODS assert_action_message
      IMPORTING !reported TYPE reported_early
                expected  TYPE symsgno.

    METHODS test_valid_row_is_saved    FOR TESTING.
    METHODS test_empty_description     FOR TESTING.
    METHODS test_maxlength_above_limit FOR TESTING.
    METHODS test_maxlength_negative    FOR TESTING.
    METHODS test_truncation_is_warning FOR TESTING.
    METHODS test_lower_case_key        FOR TESTING.
    METHODS test_duplicate_key         FOR TESTING.
    METHODS test_copy_to_same_language FOR TESTING.
    METHODS test_copy_without_language FOR TESTING.

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

    " Doubled separately: the draft table is declared in the BDEF, not in the
    " CDS entity, so it is not covered by the base dependencies above.
    " read_existing_targets reads it even on paths that never reach a CREATE.
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

  METHOD given_active_row.
    " Seeded through the BO instead of through the test double: this way the
    " row lands in whatever persistence the managed runtime actually writes to,
    " so both READ ENTITIES and the direct SELECT in validateUniqueKey see it.
    MODIFY ENTITIES OF zi_form_trans
           ENTITY translation
           CREATE FIELDS ( formname fieldname languagekey description maxlength )
           WITH VALUE #( ( %cid        = 'SEED1'
                           formname    = formname
                           fieldname   = fieldname
                           languagekey = languagekey
                           description = 'Existing text'
                           maxlength   = 0 ) )
           FAILED DATA(seed_failed).

    COMMIT ENTITIES RESPONSE OF zi_form_trans
           FAILED DATA(seed_commit_failed).

    " Fail loudly here rather than letting the actual test assert something
    " misleading further down.
    cl_abap_unit_assert=>assert_initial(
      act = seed_commit_failed-translation
      msg = |Could not seed { formname }/{ fieldname }/{ languagekey }| ).
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

  METHOD copy_to.
    " copyToLanguage is a FACTORY action and therefore instance-generating:
    " the EML contract requires a %cid, otherwise the kernel raises
    " BEHAVIOR_CONTRACT_VIOLATION (CC/C:MISSING_CID).
    MODIFY ENTITIES OF zi_form_trans
           ENTITY translation
           EXECUTE copyToLanguage
           FROM VALUE #( ( %cid                  = 'COPY1'
                           %tky-formname         = 'ZTEST'
                           %tky-fieldname        = 'TITLE'
                           %tky-languagekey      = 'E'
                           %tky-%is_draft        = if_abap_behv=>mk-off
                           %param-TargetLanguage = target ) )
           REPORTED DATA(action_reported).

    result = action_reported.
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

  METHOD assert_action_message.
    DATA found TYPE abap_boolean.

    LOOP AT reported-translation INTO DATA(entry).
      IF entry-%msg IS BOUND AND entry-%msg->if_t100_message~t100key-msgno = expected.
        found = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    cl_abap_unit_assert=>assert_true( act = found
                                      msg = |Expected message { expected } was not reported by the action| ).
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
                         expected = msg_description_empty ).
  ENDMETHOD.

  METHOD test_maxlength_above_limit.
    " The domain range is only enforced on the UI, so the server has to reject
    " values above 9999 that arrive through OData or an API call.
    create_and_save( EXPORTING maxlength = 20000
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD test_maxlength_negative.
    create_and_save( EXPORTING maxlength = -1
                     IMPORTING failed    = DATA(failed)
                               reported  = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = msg_maxlength_invalid ).
  ENDMETHOD.

  METHOD test_truncation_is_warning.
    " A description longer than MaxLength is legal - it is only truncated at
    " print time - so the row must still be saved.
    create_and_save( EXPORTING description = 'A description that is clearly too long'
                               maxlength   = 5
                     IMPORTING failed      = DATA(failed)
                               reported    = DATA(reported) ).

    cl_abap_unit_assert=>assert_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = msg_text_truncated ).
  ENDMETHOD.

  METHOD test_lower_case_key.
    create_and_save( EXPORTING formname = 'ztest'
                     IMPORTING failed   = DATA(failed)
                               reported = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = msg_key_not_upper ).
  ENDMETHOD.

  METHOD test_duplicate_key.
    given_active_row( ).

    create_and_save( IMPORTING failed   = DATA(failed)
                               reported = DATA(reported) ).

    cl_abap_unit_assert=>assert_not_initial( failed-translation ).
    assert_save_message( reported = reported
                         expected = msg_duplicate_key ).
  ENDMETHOD.

  METHOD test_copy_to_same_language.
    given_active_row( ).

    assert_action_message( reported = copy_to( 'E' )
                           expected = msg_same_language ).
  ENDMETHOD.

  METHOD test_copy_without_language.
    given_active_row( ).

    assert_action_message( reported = copy_to( VALUE #( ) )
                           expected = msg_language_missing ).
  ENDMETHOD.
ENDCLASS.
