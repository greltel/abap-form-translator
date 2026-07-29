CLASS lhc_translation DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS message_class         TYPE symsgid VALUE 'ZABAP_FORM_TRANS_MSG'.

    CONSTANTS msg_maxlength_invalid TYPE symsgno VALUE '001'.
    CONSTANTS msg_description_empty TYPE symsgno VALUE '002'.
    CONSTANTS msg_duplicate_key     TYPE symsgno VALUE '003'.
    CONSTANTS msg_language_missing  TYPE symsgno VALUE '004'.
    CONSTANTS msg_same_language     TYPE symsgno VALUE '005'.
    CONSTANTS msg_text_truncated    TYPE symsgno VALUE '006'.
    CONSTANTS msg_key_not_upper     TYPE symsgno VALUE '007'.

    " State areas let the framework replace the messages of a previous validation
    " run instead of piling them up in the message popover on every Prepare.
    CONSTANTS area_maxlength        TYPE string  VALUE 'MAXLENGTH'.
    CONSTANTS area_description      TYPE string  VALUE 'DESCRIPTION'.
    CONSTANTS area_unique_key       TYPE string  VALUE 'UNIQUE_KEY'.
    CONSTANTS area_key_case         TYPE string  VALUE 'KEY_CASE'.

    " Upper bound of domain ZABAP_FORM_MAXLENGTH. Fixed values are only enforced
    " on the UI, so the same range has to be checked again on the server side.
    CONSTANTS max_length_limit      TYPE i       VALUE 9999.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR translation RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR translation RESULT result.

    METHODS validatemaxlength FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatemaxlength.

    METHODS validatedescription FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatedescription.

    METHODS validateuniquekey FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validateuniquekey.

    METHODS validatekeycase FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatekeycase.

    METHODS copytolanguage FOR MODIFY
      IMPORTING keys FOR ACTION translation~copytolanguage.

    TYPES translation_result TYPE TABLE FOR READ RESULT zi_form_trans.
    TYPES copy_action_keys   TYPE TABLE FOR ACTION IMPORT zi_form_trans~copytolanguage.

    "! Reads the translations that already occupy the requested target keys,
    "! both in the active and in the draft persistence.
    "! @parameter sources |
    "! @parameter action_keys |
    "! @parameter result |
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
      IF    translation-maxlength < 0
         OR translation-maxlength > max_length_limit.

        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky               = translation-%tky
                        %state_area        = area_maxlength
                        %element-maxlength = if_abap_behv=>mk-on
                        %msg               = new_message( id       = message_class
                                                          number   = msg_maxlength_invalid
                                                          severity = if_abap_behv_message=>severity-error ) )
               TO reported-translation.

        CONTINUE.
      ENDIF.

      " Non-blocking warning: at print time the description is truncated to
      " MaxLength, so warn the maintainer that text will be cut off.
      IF     translation-maxlength             > 0
         AND strlen( translation-description ) > translation-maxlength.

        APPEND VALUE #( %tky                 = translation-%tky
                        %state_area          = area_maxlength
                        %element-description = if_abap_behv=>mk-on
                        %element-maxlength   = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = message_class
                                                            number   = msg_text_truncated
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
                        %msg                 = new_message( id       = message_class
                                                            number   = msg_description_empty
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
                        %msg        = new_message( id       = message_class
                                                   number   = msg_duplicate_key
                                                   severity = if_abap_behv_message=>severity-error
                                                   v1       = translation-LanguageKey ) )
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
      IF     translation-formname  = to_upper( translation-formname )
         AND translation-fieldname = to_upper( translation-fieldname ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

      APPEND VALUE #( %tky               = translation-%tky
                      %state_area        = area_key_case
                      %element-formname  = if_abap_behv=>mk-on
                      %element-fieldname = if_abap_behv=>mk-on
                      %msg               = new_message( id       = message_class
                                                        number   = msg_key_not_upper
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
      DATA(requested_language) = action_keys[ %tky = source-%tky ]-%param-TargetLanguage.
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

    DATA new_entries TYPE TABLE FOR CREATE zi_form_trans.

    LOOP AT translations INTO DATA(translation).
      DATA(action_key)      = keys[ %tky = translation-%tky ].
      DATA(target_language) = action_key-%param-TargetLanguage.

      IF target_language IS INITIAL.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = message_class
                                            number   = msg_language_missing
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-translation.
        CONTINUE.
      ENDIF.

      IF target_language = translation-languagekey.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = message_class
                                            number   = msg_same_language
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = target_language ) )
               TO reported-translation.
        CONTINUE.
      ENDIF.

      " Reject duplicates against already persisted rows (active or draft) as
      " well as rows already queued in this same batch - two source rows sharing
      " Form/Field copied to the same target language would otherwise collide on
      " the primary key in the CREATE below.
      IF    line_exists( existing[ formname    = translation-formname
                                   fieldname   = translation-fieldname
                                   languagekey = target_language ] )
         OR line_exists( new_entries[ formname    = translation-formname
                                      fieldname   = translation-fieldname
                                      languagekey = target_language ] ).
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = message_class
                                            number   = msg_duplicate_key
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = target_language ) )
               TO reported-translation.
        CONTINUE.
      ENDIF.

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
