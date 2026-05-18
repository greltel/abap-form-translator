CLASS lhc_translation DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR translation RESULT result.

    METHODS validatemaxlength FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatemaxlength.

    METHODS validatedescription FOR VALIDATE ON SAVE
      IMPORTING keys FOR translation~validatedescription.

    METHODS copytolanguage FOR MODIFY
      IMPORTING keys FOR ACTION translation~copytolanguage.

ENDCLASS.


CLASS lhc_translation IMPLEMENTATION.
  METHOD get_instance_authorizations.
    " Allow all: every requested instance operation is granted.
    " Access is governed by Fiori catalog / service binding roles, not per-instance.
    result = VALUE #( FOR key IN keys
                      ( %tky        = key-%tky
                        %update      = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on
                                               THEN if_abap_behv=>auth-allowed )
                        %action-Edit = COND #( WHEN requested_authorizations-%action-Edit = if_abap_behv=>mk-on
                                               THEN if_abap_behv=>auth-allowed )
                        %delete      = COND #( WHEN requested_authorizations-%delete = if_abap_behv=>mk-on
                                               THEN if_abap_behv=>auth-allowed ) ) ).
  ENDMETHOD.

  METHOD validatemaxlength.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( maxlength ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    LOOP AT translations INTO DATA(translation).

      IF translation-maxlength < 0.

        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.

        APPEND VALUE #( %tky               = translation-%tky
                        %element-maxlength = if_abap_behv=>mk-on " flag the element so the UI highlights it
                        %msg               = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                                    text     = 'Max Length cannot be negative.' ) )
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
        APPEND VALUE #( %tky                 = translation-%tky
                        %element-description = if_abap_behv=>mk-on " flag the element so the UI highlights it
                        %msg                 = new_message_with_text(
                                                   severity = if_abap_behv_message=>severity-error
                                                   text     = 'Translation description cannot be empty.' ) )
               TO reported-translation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD copytolanguage.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    " Collect the prospective target keys so duplicates are detected before CREATE
    DATA target_keys TYPE TABLE FOR READ IMPORT zi_form_trans.

    LOOP AT translations INTO DATA(source).
      DATA(requested_language) = keys[ %tky = source-%tky ]-%param-TargetLanguage.
      IF requested_language IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %key-FormName    = source-formname
                      %key-FieldName   = source-fieldname
                      %key-LanguageKey = requested_language ) TO target_keys.
    ENDLOOP.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         ALL FIELDS WITH target_keys
         RESULT DATA(existing).

    DATA new_entries TYPE TABLE FOR CREATE zi_form_trans.

    LOOP AT translations INTO DATA(translation).
      DATA(target_language) = keys[ %tky = translation-%tky ]-%param-TargetLanguage.

IF target_language IS INITIAL.
  APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
  APPEND VALUE #( %tky = translation-%tky
                  %msg = new_message_with_text(
                                                text     = |Translation language cannot be Initial.|
                                                severity = if_abap_behv_message=>severity-error ) )
         TO reported-translation.
  CONTINUE.
ENDIF.

      IF line_exists( existing[ formname    = translation-formname
                                fieldname   = translation-fieldname
                                languagekey = target_language ] ).
        APPEND VALUE #( %tky = translation-%tky ) TO failed-translation.
        APPEND VALUE #( %tky = translation-%tky
                        %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = |Translation already exists for language { target_language }.| ) )
               TO reported-translation.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %cid        = keys[ %tky = translation-%tky ]-%cid
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
  ENDMETHOD.

ENDCLASS.
