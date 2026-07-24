CLASS lhc_translation DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS message_class TYPE symsgid VALUE 'ZABAP_FORM_TRANS_MSG'.

    " Default maximum length applied when the user leaves MaxLength empty on
    " create. It matches the storage width of the Description field, so it acts
    " as "translate up to the full stored text".
    CONSTANTS default_max_length TYPE i VALUE 50.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR translation RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR translation RESULT result ##NEEDED.

    METHODS setdefaultmaxlength FOR DETERMINE ON MODIFY
      IMPORTING keys FOR translation~setdefaultmaxlength.

    METHODS validatemaxlength FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatemaxlength.

    METHODS validatedescription FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatedescription.

    METHODS validateuniquekey FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validateuniquekey.

    METHODS copytolanguage FOR MODIFY
      IMPORTING keys FOR ACTION translation~copytolanguage RESULT result.

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

  METHOD setdefaultmaxlength.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( maxlength ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    DATA update TYPE TABLE FOR UPDATE zi_form_trans.

    " Give newly created rows a meaningful, non-zero MaxLength instead of a
    " bare 0. Only fill it when the user left it empty.
    update = VALUE #( FOR translation IN translations
                      WHERE ( maxlength IS INITIAL )
                      ( %tky              = translation-%tky
                        maxlength         = default_max_length
                        %control-maxlength = if_abap_behv=>mk-on ) ).

    IF update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zi_form_trans IN LOCAL MODE
           ENTITY translation
           UPDATE FIELDS ( maxlength ) WITH update
           REPORTED DATA(reported_update).

    reported-translation = VALUE #( BASE reported-translation
                                    ( LINES OF reported_update-translation ) ).
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

  METHOD copytolanguage.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    DATA active_keys TYPE TABLE FOR READ IMPORT zi_form_trans.
    DATA draft_keys  TYPE TABLE FOR READ IMPORT zi_form_trans.

    LOOP AT translations INTO DATA(source).
      " Empty target languages are reported later (message 004); building an
      " empty key here is harmless because the existence reads simply find nothing.
      DATA(requested_language) = keys[ %tky = source-%tky ]-%param-TargetLanguage.
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
         RESULT DATA(existing_active).

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         ALL FIELDS WITH draft_keys
         RESULT DATA(existing_draft).

    DATA(existing) = existing_active.
    APPEND LINES OF existing_draft TO existing.

    DATA new_entries TYPE TABLE FOR CREATE zi_form_trans.
    DATA(cid_index) = 0.

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

      cid_index += 1.

      APPEND VALUE #( %cid        = |CTL{ cid_index }|
                      formname    = translation-formname
                      fieldname   = translation-fieldname
                      languagekey = target_language
                      description = translation-description
                      maxlength   = translation-maxlength
                      %is_draft   = if_abap_behv=>mk-on )
             TO new_entries.
    ENDLOOP.

    MODIFY ENTITIES OF zi_form_trans IN LOCAL MODE
           ENTITY translation
           CREATE FIELDS ( formname fieldname languagekey description maxlength )
           WITH new_entries
           MAPPED DATA(mapped_create)
           FAILED DATA(failed_create)
           REPORTED DATA(reported_create).

    mapped-translation   = mapped_create-translation.
    failed-translation   = VALUE #( BASE failed-translation
                                    ( LINES OF failed_create-translation ) ).
    reported-translation = VALUE #( BASE reported-translation
                                    ( LINES OF reported_create-translation ) ).

    " Return the newly created drafts so the UI can navigate to them.
    result = VALUE #( FOR created IN mapped_create-translation
                      ( %tky = created-%tky ) ).
  ENDMETHOD.

ENDCLASS.
