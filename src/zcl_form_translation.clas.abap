"! <p class="shorttext synchronized" lang="en">Form Translation Class</p>
CLASS zcl_form_translation DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS c_version TYPE string VALUE '1.1.0' ##NEEDED.

    TYPES ty_fieldname_range TYPE RANGE OF zabap_form_trans-fieldname.

    "! <p class="shorttext synchronized">Translates fields of a structure based on DB configuration</p>
    "! @parameter iv_formname | <p class="shorttext synchronized">Smartform/Form Name (Key in DB)</p>
    "! @parameter iv_langu | <p class="shorttext synchronized">Target Language (Default: SY-LANGU)</p>
    "! @parameter cs_form_elements | <p class="shorttext synchronized">Structure containing fields to be translated</p>
    METHODS translate_form
      IMPORTING
        !iv_formname      TYPE zabap_form_trans_name
        !iv_langu         TYPE zabap_form_trans_langu DEFAULT syst-langu
      CHANGING
        !cs_form_elements TYPE any .
  PROTECTED SECTION.

    TYPES tt_zabap_form_transv TYPE STANDARD TABLE OF zabap_form_trans WITH EMPTY KEY.

    "! <p class="shorttext synchronized" lang="en"></p>
    "!
    "! @parameter iv_formname | <p class="shorttext synchronized" lang="en">Smart Forms: Form Name</p>
    "! @parameter iv_langu    | <p class="shorttext synchronized" lang="en">ABAP System Field: Language Key of Text Environment</p>
    METHODS get_translations
      IMPORTING
                !iv_formname           TYPE zabap_form_trans_name
                !iv_langu              TYPE zabap_form_trans_langu
                !iv_fieldnames         TYPE ty_fieldname_range
      RETURNING VALUE(re_translations) TYPE zcl_form_translation=>tt_zabap_form_transv.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_form_translation IMPLEMENTATION.


  METHOD translate_form.

    IF iv_formname IS INITIAL.
      RETURN.
    ENDIF.

    TRY.

        DATA(lt_translations) = me->get_translations( iv_fieldnames = VALUE ty_fieldname_range( FOR <fs> IN CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( cs_form_elements ) )->components
                                                                                              ( low    = <fs>-name
                                                                                                high   = <fs>-name
                                                                                                sign   = 'I'
                                                                                                option = 'EQ' )  )
                                                      iv_formname   = iv_formname
                                                      iv_langu      = iv_langu ).

      CATCH cx_sy_move_cast_error.
    ENDTRY.

    IF lt_translations IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_translations REFERENCE INTO DATA(lr_translation).

      ASSIGN COMPONENT lr_translation->*-fieldname OF STRUCTURE cs_form_elements TO FIELD-SYMBOL(<lv_field_value>).

      IF syst-subrc IS INITIAL AND <lv_field_value> IS ASSIGNED.

        TRY.

            DATA(lv_text) = lr_translation->*-descr.

            IF lr_translation->*-length IS NOT INITIAL AND strlen( lv_text ) GT lr_translation->*-length.
              lv_text = substring( val = lv_text
                                   off = 0
                                   len = lr_translation->*-length ).
            ENDIF.

            <lv_field_value> = lv_text.

          CATCH cx_root.
            CONTINUE.
        ENDTRY.

        CLEAR lv_text.
        UNASSIGN <lv_field_value>.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_translations.

    TRY.
        SELECT FROM zabap_form_trans
          FIELDS *
          WHERE fieldname IN @iv_fieldnames
            AND form  EQ @iv_formname
            AND langu EQ @( COND #( WHEN iv_langu IS NOT INITIAL THEN iv_langu
                                    ELSE cl_abap_context_info=>get_user_language_abap_format( ) ) )
           INTO TABLE @re_translations.
      CATCH cx_abap_context_info_error.
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
