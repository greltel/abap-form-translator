"! <p class="shorttext synchronized" lang="EN">Logon language of the current user</p>
"! System-context adapter: the only contract through which the package learns
"! the language of the current user. Production wires
"! {@link zcl_form_trans_user_context}; tests inject a double that returns a
"! fixed language, so that language resolution can be asserted without a
"! logon session.
INTERFACE zif_form_trans_user_context
  PUBLIC.

  "! <p class="shorttext synchronized" lang="EN">Returns the logon language</p>
  "! Initial when the platform cannot determine the language of the current
  "! user - the caller decides which language to fall back to.
  "!
  "! @parameter result | Logon language in the SAP one-character format, or initial.
  METHODS language
    RETURNING VALUE(result) TYPE zabap_form_trans_langu.

ENDINTERFACE.
