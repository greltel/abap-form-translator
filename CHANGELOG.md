# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- The user context test runs off-stack as well: open-abap-xco implements the
  XCO language API since its PR #47, so the `skip` list in `abap_transpile.json`
  is gone and all 43 transpilable tests execute on every push.

## [2.0.0] - 2026-09

First release built as **ABAP for Cloud Development**. Breaking for existing
installations — read the upgrade notes.

### Added
- Authorization object `ZFORMTRA` (activity only) with CDS access control on
  every view and a global authorization check in the behavior implementation.
  Denied operations report messages 008 and 009.
- `ZIF_FORM_TRANS_AUTHORITY` / `ZCL_FORM_TRANS_AUTHORITY`: the authority check
  behind an interface, injected into the handler through a local factory.
- `ZIF_FORM_TRANS_USER_CONTEXT` / `ZCL_FORM_TRANS_USER_CONTEXT`: the logon
  language behind an interface; `ZCL_FORM_TRANSLATION` takes it as an optional
  constructor parameter, so the "no language given" path is testable.
- Direct handler tests for the global authorization, every validation, the
  feature control and the Copy Language action (23 tests on the behavior pool).
- Off-stack gate hardened: abaplint syntax check against the released ABAP Cloud
  API (2305 snapshot), Clean ABAP rules, a CI guard for the `#CHANGE_SET`
  grouping of the Copy Language button, Dependabot.

### Changed
- All objects carry ABAP language version *ABAP for Cloud Development*; the
  abapGit repository sets `cloudDevelopment`.
- Minimum release is SAP S/4HANA 2023 (ABAP 7.58).
- Validation `validateUniqueKey` reads the persisted keys with one SELECT per
  request instead of one per instance.
- Copy Language messages show the ISO 639 code of the language (`EL`, `DE`)
  instead of the internal key.
- `ZCL_FORM_TRANS_RULES=>check_copy_request` takes a `copy_request` structure
  instead of six scalar parameters.
- The behavior implementation of the Copy Language action is split into
  `queue_copies`, `report_rejection` and `create_drafts`.
- Message texts in the tests use string literals in backticks; internal tables
  are filled with `INSERT … INTO TABLE` throughout.

### Removed
- Dead exception handling around the logon language and the XCO language
  formatting.
- Four EML-driven tests of the save sequence that the direct handler tests
  cover; two smoke tests remain.

### Upgrade notes
- Move the objects into a package with ABAP language version
  *ABAP for Cloud Development* (or set the abapGit option *ABAP Language
  Version* to *Undefined* to keep a standard package).
- Every user of the app needs `ZFORMTRA`: `03` to display, `01`/`02`/`06` to
  maintain. Without a role the list is empty and create is denied.
- Callers of `ZCL_FORM_TRANS_RULES=>check_copy_request` (unlikely outside this
  package) have to pass a `copy_request` structure.
- The protected type `ZCL_FORM_TRANSLATION=>translations` became a sorted
  table with a unique key on the field name.

## [1.3.0] and earlier

Standard ABAP releases; see the
[GitHub releases](https://github.com/greltel/abap-form-translator/releases).
