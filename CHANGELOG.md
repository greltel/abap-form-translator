# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Data model / DDIC
- Added domain `ZABAP_FORM_MAXLENGTH` (INT2, range 0–9999) and data element
  `ZABAP_FORM_TRANS_MAXLEN`; the `LENGTH`/`MAXLENGTH` columns now use it instead of
  raw `INT2`, enforcing a non-negative range declaratively.
- Fixed the draft table `ZABAP_FORM_DRFT`: removed the incorrect `LANGDEP` flag and
  set `UEBERSETZ = N` (draft tables must be neither language-dependent nor
  translation-relevant).
- Added `@Semantics.language: true` to `LanguageKey` so the framework treats it as
  the row's language column (ISO conversion, language filtering, text association).
- Normalised data-element labels: consistent casing ("Field Name"), a proper
  `Description` heading, and corrected screen/heading lengths.

### RAP behavior
- Added instance feature control: `copyToLanguage` is disabled for rows without a
  description (nothing to copy).
- Added determination `setDefaultMaxLength`: newly created rows get a meaningful
  MaxLength (50) instead of a bare 0 when the user leaves it empty.
- `copyToLanguage` is now a factory action with a `result`, so the UI can navigate
  to the created drafts; the created instances also get unique `%cid`s.

### Fixed
- **Runtime buffer now caches empty results** (negative caching), so repeated
  `translate_form` calls for forms without translations no longer re-run the
  `SELECT` on every call.
- **Language resolution fallback**: when the user language cannot be resolved,
  `get_translations` now falls back to the default language (`E`) instead of
  silently returning no translations.
- **`copyToLanguage` duplicate protection**: duplicates produced within the same
  batch (two source rows copied to the same target language) are now detected and
  reported instead of causing a primary-key collision on save.
- **Duplicate-on-create**: creating a translation whose Form/Field/Language key
  already exists now reports a friendly message (`validateUniqueKey`) instead of a
  generic framework error.

### Added
- **Copy-to-same-language guard** in `copyToLanguage` with a dedicated message.
- **Description-length warning**: a non-blocking warning is raised when a
  description is longer than its configured `MaxLength` (it will be truncated at
  print time).
- Additional ABAP Unit tests covering multiple fields, untouched fields, initial
  form name, empty description, unknown field, and truncation edge cases.
- Message texts (001–004) rewritten to be end-user friendly; new messages 005 and
  006 added.

### Documentation
- Completed the README usage example, fixed the table-of-contents anchors, and
  documented the `ZABAP_FORM_TRANS` schema, the `enable_fallback` parameter, and
  the `clear_buffer` method.
- Added `CONTRIBUTING.md`.
- Corrected the `SAP_BASIS` minimum release in `.abapgit.xml` to `754`.

## [1.2.0]
- Baseline release: runtime translation class `ZCL_FORM_TRANSLATION` with table
  buffering and fallback, plus a draft-enabled RAP / Fiori Elements maintenance
  application for form translations.
