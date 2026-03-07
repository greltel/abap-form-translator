CLASS lhc_Translation DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
        IMPORTING keys REQUEST requested_authorizations FOR Translation RESULT result.

    METHODS validateMaxLength FOR VALIDATE ON SAVE
      IMPORTING keys FOR Translation~validateMaxLength.

    METHODS validateDescription FOR VALIDATE ON SAVE
      IMPORTING keys FOR Translation~validateDescription.

ENDCLASS.


CLASS lhc_Translation IMPLEMENTATION.
  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD validateMaxLength.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY Translation
         FIELDS ( MaxLength ) WITH CORRESPONDING #( keys )
         RESULT DATA(lt_translations).

    LOOP AT lt_translations INTO DATA(ls_trans).

      IF ls_trans-MaxLength < 0.

        APPEND VALUE #( %tky = ls_trans-%tky ) TO failed-translation.

        APPEND VALUE #( %tky = ls_trans-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Max Length cannot be negative.' ) )
               TO reported-translation.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validateDescription.

    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY Translation
         FIELDS ( Description ) WITH CORRESPONDING #( keys )
         RESULT DATA(lt_translations).

    LOOP AT lt_translations INTO DATA(ls_trans).
      " Αν το πεδίο περιγραφής είναι τελείως κενό
      IF ls_trans-Description IS INITIAL.
        APPEND VALUE #( %tky = ls_trans-%tky ) TO failed-translation.
        APPEND VALUE #( %tky                 = ls_trans-%tky
                        %element-Description = if_abap_behv=>mk-on " Κάνει highlight το πεδίο με κόκκινο
                        %msg                 = new_message_with_text(
                                                   severity = if_abap_behv_message=>severity-error
                                                   text     = 'Translation description cannot be empty.' ) )
               TO reported-translation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
