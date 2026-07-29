"! <p class="shorttext" lang="EN">Behavior implementation for ZI_FORM_TRANS</p>
"! Handles the ON SAVE validations, the instance features and the
"! copyToLanguage factory action of {@link zi_form_trans}.
"! <br>
"! Every validation reports into its own state area, so the framework replaces
"! the messages of a previous run instead of piling them up in the message
"! popover on every Prepare. The rules themselves live in {@link zcl_form_trans_rules}
"! and carry no RAP dependency.
CLASS lhc_translation DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "! State area of validateMaxLength.
    CONSTANTS area_maxlength   TYPE string VALUE 'MAXLENGTH'.
    "! State area of validateDescription.
    CONSTANTS area_description TYPE string VALUE 'DESCRIPTION'.
    "! State area of validateUniqueKey.
    CONSTANTS area_unique_key  TYPE string VALUE 'UNIQUE_KEY'.
    "! State area of validateKeyCase.
    CONSTANTS area_key_case    TYPE string VALUE 'KEY_CASE'.

    "! Grants the instance bound operations. Every caller that reaches the
    "! entity is currently allowed to change it; a real check follows once the
    "! authorization object is in place.
    "!
    "! @parameter keys                     | Instances under evaluation.
    "! @parameter requested_authorizations | Operations the framework asks about.
    "! @parameter result                   | Verdict per instance and operation.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR translation RESULT result.

    "! Enables copyToLanguage only for rows that already carry a description,
    "! so the button is not offered when it would copy nothing meaningful.
    "!
    "! @parameter keys               | Instances under evaluation.
    "! @parameter requested_features | Features the framework asks about.
    "! @parameter result             | Feature control per instance.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR translation RESULT result.

    "! Rejects a MaxLength outside the domain range and warns, without
    "! blocking, when the description would be truncated at print time.
    "!
    "! @parameter keys | Instances to validate.
    METHODS validatemaxlength FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatemaxlength.

    "! Rejects rows without a description, since a translation without text
    "! would silently leave the form label unchanged.
    "!
    "! @parameter keys | Instances to validate.
    METHODS validatedescription FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatedescription.

    "! Rejects a key that is already persisted. Assigned to the create trigger
    "! only, so a hit is always a real duplicate and never the row being edited.
    "!
    "! @parameter keys | Instances to validate.
    METHODS validateuniquekey FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validateuniquekey.

    "! Rejects technical keys that are not upper case, because such a row could
    "! never be found by {@link zcl_form_translation} at print time.
    "!
    "! @parameter keys | Instances to validate.
    METHODS validatekeycase FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatekeycase.

    "! Copies a translation into another language as a new draft row.
    "!
    "! @parameter keys | Action keys including the requested target language.
    METHODS copytolanguage FOR MODIFY
      IMPORTING keys FOR ACTION translation~copytolanguage.

    "! Result set of a READ on {@link zi_form_trans}.
    TYPES translation_result TYPE TABLE FOR READ RESULT zi_form_trans.

    "! Import parameter set of the copyToLanguage action.
    TYPES copy_action_keys   TYPE TABLE FOR ACTION IMPORT zi_form_trans~copytolanguage.

    "! Reads the translations that already occupy the requested target keys,
    "! in the active as well as in the draft persistence.
    "!
    "! @parameter sources     | Rows that are about to be copied.
    "! @parameter action_keys | Action keys carrying the target language.
    "! @parameter result      | Rows found under the requested target keys.
    METHODS read_existing_targets
      IMPORTING sources       TYPE translation_result
                action_keys   TYPE copy_action_keys
      RETURNING VALUE(result) TYPE translation_result.

ENDCLASS.


CLASS lhc_translation IMPLEMENTATION.
  METHOD get_instance_authorizations.
    result = VALUE #(
        FOR key IN keys
        ( %tky                   = key-%tky
          %update                = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on
                                           THEN if_abap_behv=>auth-allowed )
          %action-Edit           = COND #( WHEN requested_authorizations-%action-Edit = if_abap_behv=>mk-on
                                           THEN if_abap_behv=>auth-allowed )
          %action-copyToLanguage = COND #( WHEN requested_authorizations-%action-copyToLanguage = if_abap_behv=>mk-on
                                           THEN if_abap_behv=>auth-allowed )
          %delete                = COND #( WHEN requested_authorizations-%delete = if_abap_behv=>mk-on
                                           THEN if_abap_behv=>auth-allowed ) ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    IF requested_features-%action-copyToLanguage = if_abap_behv=>mk-off.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( description ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    " copyToLanguage only makes sense once there is a description to copy;
    " disable it for empty / brand-new rows so the button is not offered
    " when it would just fail or copy nothing meaningful.
    result = VALUE #( FOR translation IN translations
                      ( %tky                   = translation-%tky
                        %action-copyToLanguage = COND #( WHEN translation-description IS NOT INITIAL
                                                         THEN if_abap_behv=>fc-o-enabled
                                                         ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD validatemaxlength.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( maxlength description ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    LOOP AT translations INTO DATA(translation).

      " Drop the messages of the previous run for this instance.
      APPEND VALUE #( %tky        = translation-%tky
                      %state_area = area_maxlength ) TO reported-translation.

      " MaxLength = 0 is a valid value and means "no length limit"
      " (see ZCL_FORM_TRANSLATION, which only truncates when length > 0).
      IF zcl_form_trans_rules=>is_maxlength_valid( translation-maxlength ) = abap_false.

        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky               = translation-%tky
                        %state_area        = area_maxlength
                        %element-maxlength = if_abap_behv=>mk-on
                        %msg               = new_message( id       = zcl_form_trans_rules=>message_class
                                                          number   = zcl_form_trans_rules=>msg_maxlength_invalid
                                                          severity = if_abap_behv_message=>severity-error ) )
               TO reported-translation.

        CONTINUE.
      ENDIF.

      " Non-blocking warning: at print time the description is truncated to
      " MaxLength, so warn the maintainer that text will be cut off.
      IF zcl_form_trans_rules=>is_text_truncated( description = translation-description
                                       maxlength   = translation-maxlength ) = abap_true.

        APPEND VALUE #( %tky                 = translation-%tky
                        %state_area          = area_maxlength
                        %element-description = if_abap_behv=>mk-on
                        %element-maxlength   = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = zcl_form_trans_rules=>message_class
                                                            number   = zcl_form_trans_rules=>msg_text_truncated
                                                            severity = if_abap_behv_message=>severity-warning
                                                            v1       = |{ translation-maxlength }| ) )
               TO reported-translation.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validatedescription.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( description ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    LOOP AT translations INTO DATA(translation).

      APPEND VALUE #( %tky        = translation-%tky
                      %state_area = area_description ) TO reported-translation.

      IF translation-description IS INITIAL.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky                 = translation-%tky
                        %state_area          = area_description
                        %element-description = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = zcl_form_trans_rules=>message_class
                                                            number   = zcl_form_trans_rules=>msg_description_empty
                                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-translation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateuniquekey.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( formname fieldname languagekey ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    LOOP AT translations INTO DATA(translation).

      APPEND VALUE #( %tky        = translation-%tky
                      %state_area = area_unique_key ) TO reported-translation.

      " Deliberate exception to the "no SELECT in a handler" rule: READ ENTITIES
      " IN LOCAL MODE reads the transactional buffer, which during save already
      " contains the very instance being created - it would always report itself
      " as a duplicate. This check must see the persisted state only.
      " Only reached for the create trigger, so a hit is always a real duplicate
      " and never the instance being edited.
      SELECT SINGLE @abap_true FROM zabap_form_trans
        WHERE form      = @translation-formname
          AND fieldname = @translation-fieldname
          AND langu     = @translation-languagekey
        INTO @DATA(exists).

      IF exists = abap_true.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky        = translation-%tky
                        %state_area = area_unique_key
                        %msg        = new_message( id       = zcl_form_trans_rules=>message_class
                                                   number   = zcl_form_trans_rules=>msg_duplicate_key
                                                   severity = if_abap_behv_message=>severity-error
                                                   v1       = translation-languagekey ) )
               TO reported-translation.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validatekeycase.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( formname fieldname ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    LOOP AT translations INTO DATA(translation).

      APPEND VALUE #( %tky        = translation-%tky
                      %state_area = area_key_case ) TO reported-translation.

      " HANA compares case sensitively and OData does not apply the DDIC
      " lower case flag, so a key stored in lower case can never be found by
      " ZCL_FORM_TRANSLATION at print time. LanguageKey is excluded on purpose:
      " SAP language keys are case significant and may legitimately be lower case.
      IF zcl_form_trans_rules=>is_key_upper_case( formname  = translation-formname
                                       fieldname = translation-fieldname ) = abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

      APPEND VALUE #( %tky               = translation-%tky
                      %state_area        = area_key_case
                      %element-formname  = if_abap_behv=>mk-on
                      %element-fieldname = if_abap_behv=>mk-on
                      %msg               = new_message( id       = zcl_form_trans_rules=>message_class
                                                        number   = zcl_form_trans_rules=>msg_key_not_upper
                                                        severity = if_abap_behv_message=>severity-error ) )
             TO reported-translation.

    ENDLOOP.
  ENDMETHOD.

  METHOD read_existing_targets.
    DATA active_keys TYPE TABLE FOR READ IMPORT zi_form_trans.
    DATA draft_keys  TYPE TABLE FOR READ IMPORT zi_form_trans.

    LOOP AT sources INTO DATA(source).
      " Empty target languages are reported by the caller (message 004); building
      " an empty key here is harmless because the reads below simply find nothing.
      DATA(requested_language) = action_keys[ KEY id %tky = source-%tky ]-%param-TargetLanguage.
      APPEND VALUE #( %key-FormName    = source-formname
                      %key-FieldName   = source-fieldname
                      %key-LanguageKey = requested_language
                      %is_draft        = if_abap_behv=>mk-off ) TO active_keys.
      APPEND VALUE #( %key-FormName    = source-formname
                      %key-FieldName   = source-fieldname
                      %key-LanguageKey = requested_language
                      %is_draft        = if_abap_behv=>mk-on  ) TO draft_keys.
    ENDLOOP.

    " Only the key fields are needed by the duplicate check in copyToLanguage.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( formname fieldname languagekey ) WITH active_keys
         RESULT result.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( formname fieldname languagekey ) WITH draft_keys
         RESULT DATA(existing_draft).

    APPEND LINES OF existing_draft TO result.
  ENDMETHOD.

  METHOD copytolanguage.
    " Keys that cannot be read must be reported as failed, otherwise the action
    " silently reports success while having copied nothing.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( formname fieldname languagekey description maxlength )
         WITH CORRESPONDING #( keys )
         RESULT DATA(translations)
         FAILED DATA(read_failed).

    failed-translation = VALUE #( BASE failed-translation
                                  ( LINES OF read_failed-translation ) ).

    IF translations IS INITIAL.
      RETURN.
    ENDIF.

    DATA(existing) = read_existing_targets( sources     = translations
                                            action_keys = keys ).

    " Flatten the persisted targets into a plain key table; rows queued during
    " this call are added to the same table so the in-batch collision case is
    " handled by exactly the same rule.
    DATA(occupied) = VALUE zcl_form_trans_rules=>translation_keys( FOR row IN existing
                                                        ( formname    = row-formname
                                                          fieldname   = row-fieldname
                                                          languagekey = row-languagekey ) ).

    DATA new_entries TYPE TABLE FOR CREATE zi_form_trans.

    LOOP AT translations INTO DATA(translation).
      DATA(action_key)      = keys[ Key id %tky = translation-%tky ].
      DATA(target_language) = action_key-%param-TargetLanguage.

      DATA(rejection) = zcl_form_trans_rules=>check_copy_request( source_language = translation-languagekey
                                                       target_language = target_language
                                                       formname        = translation-formname
                                                       fieldname       = translation-fieldname
                                                       occupied        = occupied ).

      IF rejection IS NOT INITIAL.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = zcl_form_trans_rules=>message_class
                                            number   = rejection
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = target_language ) )
               TO reported-translation.
        CONTINUE.
      ENDIF.

      INSERT VALUE #( formname    = translation-formname
                      fieldname   = translation-fieldname
                      languagekey = target_language ) INTO TABLE occupied.

      APPEND VALUE #( %cid        = action_key-%cid
                      formname    = translation-formname
                      fieldname   = translation-fieldname
                      languagekey = target_language
                      description = translation-description
                      maxlength   = translation-maxlength
                      %is_draft   = if_abap_behv=>mk-on )
             TO new_entries.

    ENDLOOP.

    IF new_entries IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_form_trans IN LOCAL MODE
           ENTITY translation
           CREATE FIELDS ( formname fieldname languagekey description maxlength )
           WITH new_entries
           MAPPED DATA(mapped_create)
           FAILED DATA(failed_create)
           REPORTED DATA(reported_create).

    mapped-translation   = VALUE #( BASE mapped-translation
                                    ( LINES OF mapped_create-translation ) ).
    failed-translation   = VALUE #( BASE failed-translation
                                    ( LINES OF failed_create-translation ) ).
    reported-translation = VALUE #( BASE reported-translation
                                    ( LINES OF reported_create-translation ) ).
  ENDMETHOD.
ENDCLASS.
