*"* use this source file for your ABAP unit test classes
"! <p class="shorttext" lang="EN">Tests for the platform user context</p>
"! The adapter only forwards to the platform, so the single test pins the
"! forwarding down: the language it returns is the one of the session that
"! runs the test.
"! <br>
"! Skipped in the off-stack run (see the skip list in abap_transpile.json):
"! open-abap-xco declares the XCO language API but does not populate its value.
CLASS ltc_user_context DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS when_asked_then_logon_langu FOR TESTING.
ENDCLASS.


CLASS ltc_user_context IMPLEMENTATION.
  METHOD when_asked_then_logon_langu.
    " --- ARRANGE
    DATA(cut) = CAST zif_form_trans_user_context( NEW zcl_form_trans_user_context( ) ).

    " --- ACT
    DATA(language) = cut->language( ).

    " --- ASSERT
    cl_abap_unit_assert=>assert_equals(
        exp = sy-langu
        act = language
        msg = `The adapter must hand back the logon language of the running session` ).
  ENDMETHOD.
ENDCLASS.
