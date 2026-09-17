"! <p class="shorttext" lang="EN">Composition root of the behavior pool</p>
"! Handler classes have no constructor of their own, so their collaborators
"! are resolved here. The inject_* hooks let a test swap a collaborator for a
"! double; passing an unbound reference restores the production default.
CLASS lcl_form_trans_factory DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    "! Authority check the handler asks before granting an operation.
    CLASS-METHODS authority
      RETURNING VALUE(result) TYPE REF TO zif_form_trans_authority.

    "! Test hook: replaces the production authority check until reset.
    "!
    "! @parameter authority | Double to hand out, or unbound to restore the default.
    CLASS-METHODS inject_authority
      IMPORTING authority TYPE REF TO zif_form_trans_authority.

  PRIVATE SECTION.
    CLASS-DATA authority_override TYPE REF TO zif_form_trans_authority.
ENDCLASS.


CLASS lcl_form_trans_factory IMPLEMENTATION.
  METHOD authority.
    result = COND #( WHEN authority_override IS BOUND
                     THEN authority_override
                     ELSE NEW zcl_form_trans_authority( ) ).
  ENDMETHOD.

  METHOD inject_authority.
    authority_override = authority.
  ENDMETHOD.
ENDCLASS.


" Forward declarations so the handler can name its test classes as friends.
CLASS ltc_authorizations DEFINITION DEFERRED FOR TESTING.
CLASS ltc_validations DEFINITION DEFERRED FOR TESTING.
CLASS ltc_features DEFINITION DEFERRED FOR TESTING.
CLASS ltc_copy_action DEFINITION DEFERRED FOR TESTING.

"! <p class="shorttext" lang="EN">Behavior implementation for ZI_FORM_TRANS</p>
"! Handles the global authorization, the ON SAVE validations, the instance
"! features and the copyToLanguage factory action of {@link zi_form_trans}.
"! <br>
"! Every validation reports into its own state area, so the framework replaces
"! the messages of a previous run instead of piling them up in the message
"! popover on every Prepare. The rules themselves live in {@link zcl_form_trans_rules}
"! and carry no RAP dependency.
CLASS lhc_translation DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltc_authorizations ltc_validations ltc_features ltc_copy_action.
  PRIVATE SECTION.

    "! State area of validateMaxLength.
    CONSTANTS area_maxlength   TYPE string VALUE 'MAXLENGTH'.
    "! State area of validateDescription.
    CONSTANTS area_description TYPE string VALUE 'DESCRIPTION'.
    "! State area of validateUniqueKey.
    CONSTANTS area_unique_key  TYPE string VALUE 'UNIQUE_KEY'.
    "! State area of validateKeyCase.
    CONSTANTS area_key_case    TYPE string VALUE 'KEY_CASE'.

    "! Failed response of the interaction phase.
    TYPES failed_early   TYPE RESPONSE FOR FAILED EARLY zi_form_trans.
    "! Reported response of the interaction phase.
    TYPES reported_early TYPE RESPONSE FOR REPORTED EARLY zi_form_trans.
    "! Mapped response of the interaction phase.
    TYPES mapped_early   TYPE RESPONSE FOR MAPPED EARLY zi_form_trans.
    "! Draft rows handed to the managed CREATE.
    TYPES new_entries    TYPE TABLE FOR CREATE zi_form_trans.

    "! Grants or denies the operations the framework asks about, based on
    "! authorization object ZFORMTRA. copyToLanguage creates rows and follows
    "! the create activity; Edit is the draft entry point of an update and
    "! follows the change activity.
    "!
    "! @parameter requested_authorizations | Operations the framework asks about.
    "! @parameter result                   | Verdict per requested operation.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR translation RESULT result.

    "! Turns one requested operation into a verdict and, when denied, reports
    "! the global message that names the missing activity.
    "!
    "! @parameter requested | Whether the framework asked about this operation.
    "! @parameter activity  | Activity of ZFORMTRA the operation needs.
    "! @parameter denial    | Message to report when the activity is missing.
    "! @parameter verdict   | Verdict field of the result to fill.
    "! @parameter reported  | Reported response the denial message goes into.
    METHODS authorize
      IMPORTING requested TYPE if_abap_behv=>t_xflag
                activity  TYPE zif_form_trans_authority=>activity
                denial    TYPE symsgno
      CHANGING  verdict   TYPE if_abap_behv=>t_xflag
                !reported TYPE reported_early.

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

    "! Reads which of the given keys already exist in the persisted table - the
    "! duplicate check of validateUniqueKey must not see the transactional buffer.
    "!
    "! @parameter sources | Instances about to be created.
    "! @parameter result  | Keys among them that are already persisted.
    METHODS read_persisted_keys
      IMPORTING sources       TYPE translation_result
      RETURNING VALUE(result) TYPE zcl_form_trans_rules=>translation_keys.

    "! Pairs one selected row with the target language requested for it.
    "!
    "! @parameter source      | Row that is about to be copied.
    "! @parameter action_keys | Action keys carrying the target language.
    "! @parameter result      | The copy request for that row.
    METHODS copy_request_of
      IMPORTING source        TYPE LINE OF translation_result
                action_keys   TYPE copy_action_keys
      RETURNING VALUE(result) TYPE zcl_form_trans_rules=>copy_request.

    "! Pairs every selected row with the target language requested for it, so
    "! that the ambiguity rule can look at the whole batch before the first row
    "! is processed.
    "!
    "! @parameter sources     | Rows that are about to be copied.
    "! @parameter action_keys | Action keys carrying the target language.
    "! @parameter result      | One request per selected row.
    METHODS build_copy_requests
      IMPORTING sources       TYPE translation_result
                action_keys   TYPE copy_action_keys
      RETURNING VALUE(result) TYPE zcl_form_trans_rules=>copy_requests.

    "! Runs every selected row through the copy rules: acceptable rows are
    "! queued as new draft entries, the others are reported with their reason.
    "!
    "! @parameter sources     | Rows that are about to be copied.
    "! @parameter action_keys | Action keys carrying the target language.
    "! @parameter entries     | Draft rows accepted so far.
    "! @parameter failed      | Rejected keys.
    "! @parameter reported    | Rejection messages.
    METHODS queue_copies
      IMPORTING sources     TYPE translation_result
                action_keys TYPE copy_action_keys
      CHANGING  entries     TYPE new_entries
                !failed     TYPE failed_early
                !reported   TYPE reported_early.

    "! Marks one request as failed and reports why, naming the target
    "! language and the field in the message.
    "!
    "! @parameter translation | Row whose copy was rejected.
    "! @parameter request     | The rejected copy request.
    "! @parameter rejection   | Message number returned by the rules.
    "! @parameter failed      | Rejected keys.
    "! @parameter reported    | Rejection messages.
    METHODS report_rejection
      IMPORTING translation TYPE LINE OF translation_result
                !request    TYPE zcl_form_trans_rules=>copy_request
                rejection   TYPE symsgno
      CHANGING  !failed     TYPE failed_early
                !reported   TYPE reported_early.

    "! Creates the queued rows as drafts and merges the responses of the
    "! managed CREATE into the responses of the action.
    "!
    "! @parameter entries  | Draft rows to create.
    "! @parameter mapped   | Content ids mapped to the created drafts.
    "! @parameter failed   | Rows the managed CREATE rejected.
    "! @parameter reported | Messages of the managed CREATE.
    METHODS create_drafts
      IMPORTING entries   TYPE new_entries
      CHANGING  !mapped   TYPE mapped_early
                !failed   TYPE failed_early
                !reported TYPE reported_early.

    "! Formats a language key the way the rest of the app shows it.
    "! ZABAP_FORM_TRANS_LANGU carries the ISOLA conversion exit, which the T100
    "! message system does not apply: a message variable reads "G" where every
    "! list and popup of the app reads "EL".
    "!
    "! @parameter language | Internal SAP language key.
    "! @parameter result   | ISO 639 code, falling back to the internal key when
    "!                       it cannot be resolved - a readable message matters
    "!                       less than a message that appears at all.
    METHODS language_code
      IMPORTING language      TYPE zabap_form_trans_langu
      RETURNING VALUE(result) TYPE symsgv.

ENDCLASS.


CLASS lhc_translation IMPLEMENTATION.
  METHOD get_global_authorizations.
    authorize( EXPORTING requested = requested_authorizations-%create
                         activity  = zif_form_trans_authority=>activities-create
                         denial    = zcl_form_trans_rules=>msg_create_unauthorized
               CHANGING  verdict   = result-%create
                         reported  = reported ).

    authorize( EXPORTING requested = requested_authorizations-%update
                         activity  = zif_form_trans_authority=>activities-change
                         denial    = zcl_form_trans_rules=>msg_change_unauthorized
               CHANGING  verdict   = result-%update
                         reported  = reported ).

    authorize( EXPORTING requested = requested_authorizations-%delete
                         activity  = zif_form_trans_authority=>activities-delete
                         denial    = zcl_form_trans_rules=>msg_change_unauthorized
               CHANGING  verdict   = result-%delete
                         reported  = reported ).

    authorize( EXPORTING requested = requested_authorizations-%action-edit
                         activity  = zif_form_trans_authority=>activities-change
                         denial    = zcl_form_trans_rules=>msg_change_unauthorized
               CHANGING  verdict   = result-%action-edit
                         reported  = reported ).

    authorize( EXPORTING requested = requested_authorizations-%action-copytolanguage
                         activity  = zif_form_trans_authority=>activities-create
                         denial    = zcl_form_trans_rules=>msg_create_unauthorized
               CHANGING  verdict   = result-%action-copytolanguage
                         reported  = reported ).
  ENDMETHOD.

  METHOD authorize.
    IF requested = if_abap_behv=>mk-off.
      RETURN.
    ENDIF.

    IF lcl_form_trans_factory=>authority( )->is_allowed( activity ) = abap_true.
      verdict = if_abap_behv=>auth-allowed.
      RETURN.
    ENDIF.

    verdict = if_abap_behv=>auth-unauthorized.

    INSERT VALUE #( %global = if_abap_behv=>mk-on
                    %msg    = new_message( id       = zcl_form_trans_rules=>message_class
                                           number   = denial
                                           severity = if_abap_behv_message=>severity-error ) )
           INTO TABLE reported-translation.
  ENDMETHOD.

  METHOD get_instance_features.
    IF requested_features-%action-copytolanguage = if_abap_behv=>mk-off.
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
                        %action-copytolanguage = COND #( WHEN translation-description IS NOT INITIAL
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
      INSERT VALUE #( %tky        = translation-%tky
                      %state_area = area_maxlength ) INTO TABLE reported-translation.

      " MaxLength = 0 is a valid value and means "no length limit"
      " (see ZCL_FORM_TRANSLATION, which only truncates when length > 0).
      IF zcl_form_trans_rules=>is_maxlength_valid( translation-maxlength ) = abap_false.

        INSERT VALUE #( %tky = translation-%tky ) INTO TABLE failed-translation.

        INSERT VALUE #( %tky               = translation-%tky
                        %state_area        = area_maxlength
                        %element-maxlength = if_abap_behv=>mk-on
                        %msg               = new_message( id       = zcl_form_trans_rules=>message_class
                                                          number   = zcl_form_trans_rules=>msg_maxlength_invalid
                                                          severity = if_abap_behv_message=>severity-error ) )
              INTO TABLE reported-translation.

        CONTINUE.
      ENDIF.

      " Non-blocking warning: at print time the description is truncated to
      " MaxLength, so warn the maintainer that text will be cut off.
      IF zcl_form_trans_rules=>is_text_truncated( description = translation-description
                                                  maxlength   = translation-maxlength ) = abap_true.

        INSERT VALUE #( %tky                 = translation-%tky
                        %state_area          = area_maxlength
                        %element-description = if_abap_behv=>mk-on
                        %element-maxlength   = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = zcl_form_trans_rules=>message_class
                                                            number   = zcl_form_trans_rules=>msg_text_truncated
                                                            severity = if_abap_behv_message=>severity-warning
                                                            v1       = |{ translation-maxlength }| ) )
              INTO TABLE reported-translation.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validatedescription.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( description ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    LOOP AT translations INTO DATA(translation).

      INSERT VALUE #( %tky        = translation-%tky
                      %state_area = area_description ) INTO TABLE reported-translation.

      IF translation-description IS INITIAL.
        INSERT VALUE #( %tky = translation-%tky ) INTO TABLE failed-translation.

        INSERT VALUE #( %tky                 = translation-%tky
                        %state_area          = area_description
                        %element-description = if_abap_behv=>mk-on
                        %msg                 = new_message( id       = zcl_form_trans_rules=>message_class
                                                            number   = zcl_form_trans_rules=>msg_description_empty
                                                            severity = if_abap_behv_message=>severity-error ) )
              INTO TABLE reported-translation.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateuniquekey.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( formname fieldname languagekey ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    DATA(persisted) = read_persisted_keys( translations ).

    LOOP AT translations INTO DATA(translation).

      INSERT VALUE #( %tky        = translation-%tky
                      %state_area = area_unique_key ) INTO TABLE reported-translation.

      " Only reached for the create trigger, so a hit is always a real duplicate
      " and never the instance being edited.
      IF NOT line_exists( persisted[ formname    = translation-formname
                                     fieldname   = translation-fieldname
                                     languagekey = translation-languagekey ] ).
        CONTINUE.
      ENDIF.

      INSERT VALUE #( %tky = translation-%tky ) INTO TABLE failed-translation.

      INSERT VALUE #( %tky        = translation-%tky
                      %state_area = area_unique_key
                      %msg        = new_message( id       = zcl_form_trans_rules=>message_class
                                                 number   = zcl_form_trans_rules=>msg_duplicate_key
                                                 severity = if_abap_behv_message=>severity-error
                                                 v1       = language_code( translation-languagekey ) ) )
             INTO TABLE reported-translation.

    ENDLOOP.
  ENDMETHOD.

  METHOD read_persisted_keys.
    " Deliberate exception to the "no SELECT in a handler" rule: READ ENTITIES
    " IN LOCAL MODE reads the transactional buffer, which during save already
    " contains the very instance being created - it would always report itself
    " as a duplicate. This check must see the persisted state only.
    IF sources IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM zabap_form_trans
      FIELDS form AS formname, fieldname, langu AS languagekey
      FOR ALL ENTRIES IN @sources
      WHERE form      = @sources-formname
        AND fieldname = @sources-fieldname
        AND langu     = @sources-languagekey
      INTO TABLE @result.
  ENDMETHOD.

  METHOD validatekeycase.
    READ ENTITIES OF zi_form_trans IN LOCAL MODE
         ENTITY translation
         FIELDS ( formname fieldname ) WITH CORRESPONDING #( keys )
         RESULT DATA(translations).

    LOOP AT translations INTO DATA(translation).

      INSERT VALUE #( %tky        = translation-%tky
                      %state_area = area_key_case ) INTO TABLE reported-translation.

      " HANA compares case sensitively and OData does not apply the DDIC
      " lower case flag, so a key stored in lower case can never be found by
      " ZCL_FORM_TRANSLATION at print time. LanguageKey is excluded on purpose:
      " SAP language keys are case significant and may legitimately be lower case.
      IF zcl_form_trans_rules=>is_key_upper_case( formname  = translation-formname
                                                  fieldname = translation-fieldname ) = abap_true.
        CONTINUE.
      ENDIF.

      INSERT VALUE #( %tky = translation-%tky ) INTO TABLE failed-translation.

      INSERT VALUE #( %tky               = translation-%tky
                      %state_area        = area_key_case
                      %element-formname  = if_abap_behv=>mk-on
                      %element-fieldname = if_abap_behv=>mk-on
                      %msg               = new_message( id       = zcl_form_trans_rules=>message_class
                                                        number   = zcl_form_trans_rules=>msg_key_not_upper
                                                        severity = if_abap_behv_message=>severity-error ) )
            INTO TABLE reported-translation.

    ENDLOOP.
  ENDMETHOD.

  METHOD read_existing_targets.
    DATA active_keys TYPE TABLE FOR READ IMPORT zi_form_trans.
    DATA draft_keys  TYPE TABLE FOR READ IMPORT zi_form_trans.

    LOOP AT sources INTO DATA(source).
      " Empty target languages are reported by the caller (message 004); building
      " an empty key here is harmless because the reads below simply find nothing.
      DATA(requested_language) = action_keys[ KEY id %tky = source-%tky ]-%param-targetlanguage.
      INSERT VALUE #( %key-formname    = source-formname
                      %key-fieldname   = source-fieldname
                      %key-languagekey = requested_language
                      %is_draft        = if_abap_behv=>mk-off ) INTO TABLE active_keys.
      INSERT VALUE #( %key-formname    = source-formname
                      %key-fieldname   = source-fieldname
                      %key-languagekey = requested_language
                      %is_draft        = if_abap_behv=>mk-on  ) INTO TABLE draft_keys.
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

    INSERT LINES OF existing_draft INTO TABLE result.
  ENDMETHOD.

  METHOD copy_request_of.
    result = VALUE #( formname        = source-formname
                      fieldname       = source-fieldname
                      source_language = source-languagekey
                      target_language = action_keys[ KEY id %tky = source-%tky ]-%param-targetlanguage ).
  ENDMETHOD.

  METHOD build_copy_requests.
    result = VALUE #( FOR source IN sources
                      ( copy_request_of( source      = source
                                         action_keys = action_keys ) ) ).
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

    INSERT LINES OF read_failed-translation INTO TABLE failed-translation.

    IF translations IS INITIAL.
      RETURN.
    ENDIF.

    DATA entries TYPE new_entries.

    queue_copies( EXPORTING sources     = translations
                            action_keys = keys
                  CHANGING  entries     = entries
                            failed      = failed
                            reported    = reported ).

    IF entries IS INITIAL.
      RETURN.
    ENDIF.

    create_drafts( EXPORTING entries  = entries
                   CHANGING  mapped   = mapped
                             failed   = failed
                             reported = reported ).
  ENDMETHOD.

  METHOD queue_copies.
    " The whole batch has to be known before the first row is processed: two
    " selected rows of the same field, in different languages, can request the
    " same target. Whichever the READ happened to return first would otherwise
    " win silently, and the other would be rejected as a duplicate of a row that
    " this very action had just created.
    DATA(ambiguous) = zcl_form_trans_rules=>find_ambiguous_targets(
                          build_copy_requests( sources     = sources
                                               action_keys = action_keys ) ).

    " Persisted targets, active and draft, as a plain key set. Rows queued
    " during this call are added to the same set, so a collision the ambiguity
    " rule did not foresee is still caught.
    DATA(occupied) = VALUE zcl_form_trans_rules=>translation_keys(
                         FOR row IN read_existing_targets( sources     = sources
                                                           action_keys = action_keys )
                         ( formname    = row-formname
                           fieldname   = row-fieldname
                           languagekey = row-languagekey ) ).

    LOOP AT sources INTO DATA(translation).
      DATA(request) = copy_request_of( source      = translation
                                       action_keys = action_keys ).

      DATA(rejection) = zcl_form_trans_rules=>check_copy_request( request   = request
                                                                  ambiguous = ambiguous
                                                                  occupied  = occupied ).
      IF rejection IS NOT INITIAL.
        report_rejection( EXPORTING translation = translation
                                    request     = request
                                    rejection   = rejection
                          CHANGING  failed      = failed
                                    reported    = reported ).
        CONTINUE.
      ENDIF.

      INSERT VALUE #( formname    = request-formname
                      fieldname   = request-fieldname
                      languagekey = request-target_language ) INTO TABLE occupied.

      INSERT VALUE #( %cid        = action_keys[ KEY id %tky = translation-%tky ]-%cid
                      formname    = request-formname
                      fieldname   = request-fieldname
                      languagekey = request-target_language
                      description = translation-description
                      maxlength   = translation-maxlength
                      %is_draft   = if_abap_behv=>mk-on ) INTO TABLE entries.
    ENDLOOP.
  ENDMETHOD.

  METHOD report_rejection.
    INSERT VALUE #( %tky = translation-%tky ) INTO TABLE failed-translation.

    INSERT VALUE #( %tky = translation-%tky
                    %msg = new_message( id       = zcl_form_trans_rules=>message_class
                                        number   = rejection
                                        severity = if_abap_behv_message=>severity-error
                                        v1       = language_code( request-target_language )
                                        v2       = request-fieldname ) )
           INTO TABLE reported-translation.
  ENDMETHOD.

  METHOD create_drafts.
    " MODIFY ENTITIES needs a modifiable operand behind WITH; an importing
    " parameter is read-only, so the rows are handed over through a local copy.
    DATA(rows) = entries.

    MODIFY ENTITIES OF zi_form_trans IN LOCAL MODE
           ENTITY translation
           CREATE FIELDS ( formname fieldname languagekey description maxlength )
           WITH rows
           MAPPED DATA(mapped_create)
           FAILED DATA(failed_create)
           REPORTED DATA(reported_create).

    INSERT LINES OF mapped_create-translation   INTO TABLE mapped-translation.
    INSERT LINES OF failed_create-translation   INTO TABLE failed-translation.
    INSERT LINES OF reported_create-translation INTO TABLE reported-translation.
  ENDMETHOD.

  METHOD language_code.
    TRY.
        result = xco_cp=>language( language )->as( xco_cp_language=>format->iso_639 ).
      CATCH cx_xco_runtime_exception.
        " An unknown language key can arrive through OData or EML; the message
        " then shows the raw key rather than dumping inside a validation.
        CLEAR result.
    ENDTRY.

    IF result IS INITIAL.
      result = language.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
