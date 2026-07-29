"! <p class="shorttext synchronized">Pure validation rules</p>
"! Free of any RAP, draft or persistence dependency, so that every rule can be
"! unit tested directly - no test doubles, no transactional buffer and no
"! release specific behaviour.
"! <br>
"! The truncation rule deliberately mirrors {@link zcl_form_translation}, which
"! cuts the description to MaxLength at print time.
CLASS zcl_form_trans_rules DEFINITION
  PUBLIC
  ABSTRACT
  FINAL.
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


CLASS zcl_form_trans_rules IMPLEMENTATION.
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

