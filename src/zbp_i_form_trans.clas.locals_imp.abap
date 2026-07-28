CLASS lhc_translation DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS message_class TYPE symsgid VALUE 'ZABAP_FORM_TRANS_MSG'.

    " Counter for the content IDs of instances created inside copyToLanguage.
    " It is CLASS-DATA on purpose: %cid must be unique across the whole
    " transactional buffer, not just within a single handler invocation.
    CLASS-DATA cid_counter TYPE i.

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

    METHODS copytolanguage FOR MODIFY
      IMPORTING keys FOR ACTION translation~copytolanguage RESULT result.

    "! Reads the translations that already occupy the requested target keys,
    "! both in the active and in the draft persistence.
    METHODS read_existing_targets
      IMPORTING sources       TYPE TABLE FOR READ RESULT zi_form_trans
                action_keys   TYPE TABLE FOR ACTION IMPORT zi_form_trans~copytolanguage
      RETURNING VALUE(result) TYPE TABLE FOR READ RESULT zi_form_trans.

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

      " MaxLength = 0 is a valid value and means "no length limit"
      " (see ZCL_FORM_TRANSLATION, which only truncates when length > 0).
      IF translation-maxlength < 0.

        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky               = translation-%tky
                        %element-maxlength = if_abap_behv=>mk-on
                        %msg               = new_message( id       = message_class
                                                          number   = '001'
                                                          severity = if_abap_behv_message=>severity-error ) )
               TO reported-translation.

        CONTINUE.
      ENDIF.

      " Non-blocking warning: at print time the description is truncated to
      " MaxLength, so warn the maintainer that text will be cut off.
      IF     translation-maxlength           > 0
         AND strlen( translation-description ) > translation-maxlength.

        APPEND VALUE #( %tky                 = translation-%tky
                        %element-description = if_abap_behv=>mk-on
                        %element-maxlength   = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = message_class
                                                            number   = '006'
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
      IF translation-description IS INITIAL.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        " Fix #4: translatable message from the message class.
        APPEND VALUE #( %tky                 = translation-%tky
                        %element-description = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = message_class
                                                            number   = '002'
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

      " A newly created row must not clash with an already active translation
      " for the same Form / Field / Language. Report a friendly duplicate
      " message instead of letting the framework raise a generic save error.
      SELECT SINGLE @abap_true FROM zabap_form_trans
        WHERE form      = @translation-formname
          AND fieldname = @translation-fieldname
          AND langu     = @translation-languagekey
        INTO @DATA(exists).

      IF exists = abap_true.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = message_class
                                            number   = '003'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = translation-languagekey ) )
               TO reported-translation.
      ENDIF.

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

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         ALL FIELDS WITH active_keys
         RESULT result.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         ALL FIELDS WITH draft_keys
         RESULT DATA(existing_draft).

    APPEND LINES OF existing_draft TO result.

  ENDMETHOD.

  METHOD copytolanguage.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    DATA(existing) = read_existing_targets( sources     = translations
                                            action_keys = keys ).

    DATA new_entries TYPE TABLE FOR CREATE zi_form_trans.

    LOOP AT translations INTO DATA(translation).
      DATA(target_language) = keys[ %tky = translation-%tky ]-%param-TargetLanguage.

      IF target_language IS INITIAL.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = message_class
                                            number   = '004'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-translation.
        CONTINUE.
      ENDIF.

      IF target_language = translation-languagekey.
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message( id       = message_class
                                            number   = '005'
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
                                            number   = '003'
                                            severity = if_abap_behv_message=>severity-error
                                            v1       = target_language ) )
               TO reported-translation.
        CONTINUE.
      ENDIF.

      cid_counter += 1.

      APPEND VALUE #( %cid        = |CTL{ cid_counter }|
                      formname    = translation-formname
                      fieldname   = translation-fieldname
                      languagekey = target_language
                      description = translation-description
                      maxlength   = translation-maxlength
                      %is_draft   = if_abap_behv=>mk-on )
             TO new_entries.

      " The key of the new instance is fully determined by the data above (no
      " numbering), so the action result can be built here: %tky identifies the
      " source instance the action was called on, %param carries the new draft.
      APPEND VALUE #( %tky   = translation-%tky
                      %param = VALUE #( %is_draft        = if_abap_behv=>mk-on
                                        %key-FormName    = translation-formname
                                        %key-FieldName   = translation-fieldname
                                        %key-LanguageKey = target_language
                                        formname         = translation-formname
                                        fieldname        = translation-fieldname
                                        languagekey      = target_language
                                        description      = translation-description
                                        maxlength        = translation-maxlength ) )
             TO result.
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
