"! <p class="shorttext" lang="EN">Pure validation rules</p>
"! Free of any RAP, draft or persistence dependency, so that every rule can be
"! unit tested directly - no test doubles, no transactional buffer and no
"! release specific behaviour.
"! <br>
"! The truncation rule deliberately mirrors {@link zcl_form_translation}, which
"! cuts the description to MaxLength at print time.
CLASS lcl_rules DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.

    "! T100 message class carrying all texts of this application.
    CONSTANTS message_class         TYPE symsgid VALUE 'ZABAP_FORM_TRANS_MSG'.

    "! Maximum length must be between 0 and 9999.
    CONSTANTS msg_maxlength_invalid TYPE symsgno VALUE '001'.
    "! Please enter a description.
    CONSTANTS msg_description_empty TYPE symsgno VALUE '002'.
    "! A translation for language &amp;1 already exists.
    CONSTANTS msg_duplicate_key     TYPE symsgno VALUE '003'.
    "! Please specify a target language.
    CONSTANTS msg_language_missing  TYPE symsgno VALUE '004'.
    "! Cannot copy a translation to its own language &amp;1.
    CONSTANTS msg_same_language     TYPE symsgno VALUE '005'.
    "! Description is longer than the maximum length &amp;1 and will be truncated.
    CONSTANTS msg_text_truncated    TYPE symsgno VALUE '006'.
    "! Form and field names must be entered in upper case.
    CONSTANTS msg_key_not_upper     TYPE symsgno VALUE '007'.

    "! Upper bound of domain {@link DOMA:ZABAP_FORM_MAXLENGTH}. Its fixed values
    "! are only enforced on the UI, so the range has to be checked again here
    "! for requests arriving through OData or the EML API.
    CONSTANTS max_length_limit      TYPE i       VALUE 9999.

    TYPES:
      "! Identifies exactly one translation row.
      BEGIN OF translation_key,
        "! Form key, as passed to {@link zcl_form_translation}.
        formname    TYPE zabap_form_trans_name,
        "! Component name inside the caller structure.
        fieldname   TYPE zabap_form_trans_field,
        "! Language of the text.
        languagekey TYPE zabap_form_trans_langu,
      END OF translation_key.

    "! Set of translation keys that are already taken. Non-unique on purpose:
    "! the caller fills it from two separate reads, so duplicates can occur and
    "! are harmless for the lookup.
    TYPES translation_keys TYPE SORTED TABLE OF translation_key
                           WITH NON-UNIQUE KEY formname fieldname languagekey.

    "! Checks MaxLength against the range of its domain.
    "! A value of 0 means <em>no length limit</em> and stays legal.
    "!
    "! @parameter maxlength | Value to check.
    "! @parameter result    | abap_true when the value is inside the range.
    CLASS-METHODS is_maxlength_valid
      IMPORTING maxlength     TYPE zabap_form_trans_maxlen
      RETURNING VALUE(result) TYPE abap_boolean.

    "! Tells whether the description would be cut off at print time.
    "! A MaxLength of 0 switches the limit off, so nothing is ever truncated.
    "!
    "! @parameter description | Text that will be printed.
    "! @parameter maxlength   | Configured limit, 0 for no limit.
    "! @parameter result      | abap_true when the text exceeds the limit.
    CLASS-METHODS is_text_truncated
      IMPORTING !description  TYPE zabap_form_trans_descr
                maxlength     TYPE zabap_form_trans_maxlen
      RETURNING VALUE(result) TYPE abap_boolean.

    "! Tells whether the technical keys are stored in upper case.
    "! HANA compares case sensitively and OData does not apply the DDIC lower
    "! case flag, so a key stored in lower case can never be found by
    "! {@link zcl_form_translation} at print time. LanguageKey is excluded on
    "! purpose: SAP language keys are case significant and may legitimately be
    "! lower case.
    "!
    "! @parameter formname  | Form key to check.
    "! @parameter fieldname | Field key to check.
    "! @parameter result    | abap_true when both keys are upper case.
    CLASS-METHODS is_key_upper_case
      IMPORTING formname      TYPE zabap_form_trans_name
                fieldname     TYPE zabap_form_trans_field
      RETURNING VALUE(result) TYPE abap_boolean.

    "! Decides whether one copy request is acceptable.
    "! The rejection reasons are evaluated in a fixed order: missing target
    "! language, copy onto the source language itself, and finally a target key
    "! that is already taken.
    "!
    "! @parameter source_language | Language of the row being copied.
    "! @parameter target_language | Language requested in the popup.
    "! @parameter formname        | Form key of the row being copied.
    "! @parameter fieldname       | Field key of the row being copied.
    "! @parameter occupied        | Target keys that are already taken, both
    "!                             persisted and queued within the same batch.
    "! @parameter result          | Message number describing the rejection,
    "!                             initial when the request is acceptable.
    CLASS-METHODS check_copy_request
      IMPORTING source_language TYPE zabap_form_trans_langu
                target_language TYPE zabap_form_trans_langu
                formname        TYPE zabap_form_trans_name
                fieldname       TYPE zabap_form_trans_field
                occupied        TYPE translation_keys
      RETURNING VALUE(result)   TYPE symsgno.

ENDCLASS.


CLASS lcl_rules IMPLEMENTATION.
  METHOD is_maxlength_valid.
    result = xsdbool(     maxlength >= 0
                      AND maxlength <= max_length_limit ).
  ENDMETHOD.

  METHOD is_text_truncated.
    result = xsdbool(     maxlength             > 0
                      AND strlen( description ) > maxlength ).
  ENDMETHOD.

  METHOD is_key_upper_case.
    result = xsdbool(     formname  = to_upper( formname )
                      AND fieldname = to_upper( fieldname ) ).
  ENDMETHOD.

  METHOD check_copy_request.
    IF target_language IS INITIAL.
      result = msg_language_missing.
      RETURN.
    ENDIF.

    IF target_language = source_language.
      result = msg_same_language.
      RETURN.
    ENDIF.

    " Covers rows that are already persisted (active or draft) as well as rows
    " queued earlier in the same batch - both end up in "occupied".
    IF line_exists( occupied[ formname    = formname
                              fieldname   = fieldname
                              languagekey = target_language ] ).
      result = msg_duplicate_key.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


"! <p class="shorttext" lang="EN">Behavior implementation for ZI_FORM_TRANS</p>
"! Handles the ON SAVE validations, the instance features and the
"! copyToLanguage factory action of {@link zi_form_trans}.
"! <br>
"! Every validation reports into its own state area, so the framework replaces
"! the messages of a previous run instead of piling them up in the message
"! popover on every Prepare. The rules themselves live in {@link .lcl_rules}
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
      IF lcl_rules=>is_maxlength_valid( translation-maxlength ) = abap_false.

        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky               = translation-%tky
                        %state_area        = area_maxlength
                        %element-maxlength = if_abap_behv=>mk-on
                        %msg               = new_message( id       = lcl_rules=>message_class
                                                          number   = lcl_rules=>msg_maxlength_invalid
                                                          severity = if_abap_behv_message=>severity-error ) )
               TO reported-translation.

        CONTINUE.
      ENDIF.

      " Non-blocking warning: at print time the description is truncated to
      " MaxLength, so warn the maintainer that text will be cut off.
      IF lcl_rules=>is_text_truncated( description = translation-description
                                       maxlength   = translation-maxlength ) = abap_true.

        APPEND VALUE #( %tky                 = translation-%tky
                        %state_area          = area_maxlength
                        %element-description = if_abap_behv=>mk-on
                        %element-maxlength   = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = lcl_rules=>message_class
                                                            number   = lcl_rules=>msg_text_truncated
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
                        %msg                 = new_message( id       = lcl_rules=>message_class
                                                            number   = lcl_rules=>msg_description_empty
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

      " Only reached for the create trigger, so an active row with the same key
      " is always a real duplicate and never the instance being edited.
      SELECT SINGLE @abap_true FROM zabap_form_trans
        WHERE form      = @translation-formname
          AND fieldname = @translation-fieldname
          AND langu     = @translation-languagekey
        INTO @DATA(exists).

      IF exists = abap_true.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky        = translation-%tky
                        %state_area = area_unique_key
                        %msg        = new_message( id       = lcl_rules=>message_class
                                                   number   = lcl_rules=>msg_duplicate_key
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
      IF lcl_rules=>is_key_upper_case( formname  = translation-formname
                                       fieldname = translation-fieldname ) = abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

      APPEND VALUE #( %tky               = translation-%tky
                      %state_area        = area_key_case
                      %element-formname  = if_abap_behv=>mk-on
                      %element-fieldname = if_abap_behv=>mk-on
                      %msg               = new_message( id       = lcl_rules=>message_class
                                                        number   = lcl_rules=>msg_key_not_upper
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
    DATA(occupied) = VALUE lcl_rules=>translation_keys( FOR row IN existing
                                                        ( formname    = row-formname
                                                          fieldname   = row-fieldname
                                                          languagekey = row-languagekey ) ).

    DATA new_entries TYPE TABLE FOR CREATE zi_form_trans.

    LOOP AT translations INTO DATA(translation).
      DATA(action_key)      = keys[ Key id %tky = translation-%tky ].
      DATA(target_language) = action_key-%param-TargetLanguage.

      DATA(rejection) = lcl_rules=>check_copy_request( source_language = translation-languagekey
                                                       target_language = target_language
                                                       formname        = translation-formname
                                                       fieldname       = translation-fieldname
                                                       occupied        = occupied ).

      IF rejection IS NOT INITIAL.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = lcl_rules=>message_class
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
