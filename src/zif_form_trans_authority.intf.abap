"! <p class="shorttext synchronized" lang="EN">Authority check for form translations</p>
"! Boundary between the behavior implementation and the authorization concept
"! of the system. Production wires {@link zcl_form_trans_authority}, which
"! checks authorization object ZFORMTRA; tests inject a double, so that the
"! mapping of operations to activities can be asserted without roles.
INTERFACE zif_form_trans_authority
  PUBLIC.

  "! Activity value of field ACTVT.
  TYPES activity TYPE c LENGTH 2.

  "! Activities of authorization object ZFORMTRA.
  CONSTANTS:
    BEGIN OF activities,
      create  TYPE activity VALUE '01',
      change  TYPE activity VALUE '02',
      display TYPE activity VALUE '03',
      delete  TYPE activity VALUE '06',
    END OF activities.

  "! <p class="shorttext synchronized" lang="EN">Tells whether the user may perform an activity</p>
  "!
  "! @parameter activity | Activity to check, one of {@link zif_form_trans_authority.DATA:activities}.
  "! @parameter result   | abap_true when the current user holds the activity.
  METHODS is_allowed
    IMPORTING activity      TYPE activity
    RETURNING VALUE(result) TYPE abap_boolean.

ENDINTERFACE.
