"! <p class="shorttext synchronized" lang="EN">Runtime translation of form labels</p>
"! Contract for translating the components of a flat structure at print time.
"! <br>
"! Consumers should type their references against this interface rather than
"! against {@link zcl_form_translation}, so that driver programs can be unit
"! tested with a test double instead of the real database read.
"! <br>
"! Buffer invalidation is deliberately not part of this contract: it is a
"! process wide cache operation rather than a translation, and stays available
"! as the static method CLEAR_BUFFER of {@link zcl_form_translation}.
INTERFACE zif_form_translation
  PUBLIC.

  "! <p class="shorttext synchronized" lang="EN">Translates fields of a structure</p>
  "! Maps the rows of ZABAP_FORM_TRANS onto the components of the given
  "! structure by field name, using RTTI. Only flat structures are supported;
  "! nested structures and internal tables are left untouched.
  "!
  "! @parameter formname        | Key in ZABAP_FORM_TRANS. An empty value returns without changes.
  "! @parameter langu           | Target language. The logon language is used when empty.
  "! @parameter enable_fallback | Fall back to the default language for fields without a text.
  "! @parameter form_elements   | Flat structure whose components receive the translated texts.
  METHODS translate_form
    IMPORTING formname        TYPE zabap_form_trans_name
              langu           TYPE zabap_form_trans_langu OPTIONAL
              enable_fallback TYPE abap_boolean           DEFAULT abap_true
    CHANGING  form_elements   TYPE any.

ENDINTERFACE.
