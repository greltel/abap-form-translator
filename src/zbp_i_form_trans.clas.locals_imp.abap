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
    IF keys IS NOT INITIAL.
    ENDIF.
    IF requested_authorizations IS NOT INITIAL.
    ENDIF.
    CLEAR result.
  ENDMETHOD.

  METHOD validatemaxlength.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( maxlength ) WITH CORRESPONDING #( keys )
         RESULT DATA(lt_translations).

    LOOP AT lt_translations INTO DATA(ls_trans).

      IF ls_trans-maxlength < 0.

        APPEND VALUE #( %tky = ls_trans-%tky ) TO failed-translation.

        APPEND VALUE #( %tky = ls_trans-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Max Length cannot be negative.' ) )
               TO reported-translation.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validatedescription.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( description ) WITH CORRESPONDING #( keys )
         RESULT DATA(lt_translations).

    LOOP AT lt_translations INTO DATA(ls_trans).
      " Αν το πεδίο περιγραφής είναι τελείως κενό
      IF ls_trans-description IS INITIAL.
        APPEND VALUE #( %tky = ls_trans-%tky ) TO failed-translation.
        APPEND VALUE #( %tky                 = ls_trans-%tky
                        %element-description = if_abap_behv=>mk-on " Κάνει highlight το πεδίο με κόκκινο
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
         RESULT DATA(lt_translations).

    DATA lt_create TYPE TABLE FOR CREATE zi_form_trans.

    LOOP AT lt_translations INTO DATA(ls_trans).
      DATA(lv_new_langu) = keys[ %tky = ls_trans-%tky ]-%param-TargetLanguage.

      IF lv_new_langu IS NOT INITIAL.
        APPEND VALUE #( %cid        = keys[ %tky = ls_trans-%tky ]-%cid
                        formname    = ls_trans-formname
                        fieldname   = ls_trans-fieldname
                        languagekey = lv_new_langu
                        description = ls_trans-description
                        maxlength   = ls_trans-maxlength
                        %is_draft   = if_abap_behv=>mk-on )
               TO lt_create.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF zi_form_trans IN LOCAL MODE
           ENTITY translation
           CREATE FIELDS ( formname fieldname languagekey description maxlength )
           WITH lt_create
           MAPPED DATA(lt_mapped_create)
           FAILED failed
           REPORTED reported.

    mapped-translation = lt_mapped_create-translation.
  ENDMETHOD.

ENDCLASS.
