# ABAP Form Translator
# ✅ Status: Release (2.0.0)
> **Open Source Contribution:** This project is community-driven and **Open Source**! 🚀
> If you spot a bug or have an idea for an enhancement, open an **Issue** or submit a **Pull Request** — see [CONTRIBUTING.md](CONTRIBUTING.md).

[![ABAP Cloud](https://img.shields.io/badge/ABAP-for%20Cloud%20Development-green)](https://abaplint.app/stats/greltel/abap-form-translator/object_classifications)
[![ABAP Version](https://img.shields.io/badge/ABAP-7.58%2B-blue)](https://abaplint.app/stats/greltel/abap-form-translator/statement_compatibility)
[![Code Statistics](https://img.shields.io/badge/CodeStatistics-abaplint-blue)](https://abaplint.app/stats/greltel/abap-form-translator)
[![License](https://img.shields.io/badge/License-MIT-green)](https://github.com/greltel/abap-form-translator/blob/main/LICENSE)
[![Tests](https://github.com/greltel/abap-form-translator/actions/workflows/test_main.yml/badge.svg)](https://github.com/greltel/abap-form-translator/actions/workflows/test_main.yml)
![Version](https://img.shields.io/endpoint?url=https://shield.abappm.com/github/greltel/abap-form-translator/src/zcl_form_translation.clas.abap/version)

A lightweight, dynamic **runtime translation tool** for SAP forms, written in
ABAP for Cloud Development. It decouples text management from form development:
functional consultants maintain labels in a Fiori Elements app, and the print
program picks them up at runtime — no SE63, no transport for a changed label.

# Table of contents
1. [Key benefits](#key-benefits)
2. [What's new in 2.0.0](#whats-new-in-200)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Usage](#usage)
6. [The maintenance app](#the-maintenance-app)
7. [Architecture](#architecture)
8. [Design decisions](#design-decisions)
9. [Tests](#tests)
10. [License](#license)
11. [Contributors](#contributors)

## Key benefits

* **No more SE63:** forget the standard translation workflow for forms.
* **Zero hardcoding:** keep the form logic clean — no `IF sy-langu = 'D'. text = 'Kunde'. ENDIF`.
* **Hot-swap texts:** change a label in production without a transport request.
  The table is buffered, so a change becomes visible on other application servers
  after the buffer synchronisation interval (typically ~60 s). Inside a long-running
  session (mass print, batch job) call `ZCL_FORM_TRANSLATION=>clear_buffer( )` to
  pick it up immediately.
* **Generic:** works with **any** flat ABAP structure or form interface, matched by
  component name through RTTI.
* **Performance:** table buffering plus a per-session translation buffer — zero
  impact on print times.
* **Fiori Elements app** built with the ABAP RESTful Application Programming
  Model (RAP), draft-enabled, with a **Copy Language** action that duplicates a
  translation into another language straight from the list.
* **Authorization:** read and maintenance access is governed by one authorization
  object, `ZFORMTRA`, checked in CDS access control and in the behavior implementation.
* **Tested:** 66 ABAP Unit tests, 42 of which also run outside SAP on every push.

![2026-03-07 23-40-52](https://github.com/user-attachments/assets/becf5ae2-4df8-4431-baca-0b66c9ba50a2)

## What's new in 2.0.0

2.0.0 is the first release built as **ABAP for Cloud Development**, with
authorization checks and a hardened behavior implementation. It is a breaking
release for installations: see [CHANGELOG.md](CHANGELOG.md) for the details and
the upgrade notes.

## Requirements

* SAP S/4HANA 2023 (ABAP 7.58) or later — on premise or private cloud.
* A package with ABAP language version **ABAP for Cloud Development**. All objects
  carry that language version; the repository sets it for abapGit as well.
* [abapGit](https://abapgit.org) for the installation.

The runtime class can be called from **any** ABAP code — classic print programs and
Smart Forms / Adobe Forms drivers included. Only the objects of this package need
the cloud language version, not their callers.

> Older systems or standard packages: the code itself is compatible with Standard
> ABAP. Set the abapGit repository option *ABAP Language Version* to *Undefined*
> before pulling, and expect no support for releases before 7.58 — the logon
> language is read through `xco_cp=>sy->language( )`, which is not available on
> every 7.57 system.

## Installation

1. Create a package (for example `ZABAP_FORM_TRANSLATION`) with ABAP language
   version *ABAP for Cloud Development*.
2. In abapGit, create an online repository for
   `https://github.com/greltel/abap-form-translator` on that package and pull.
   Activate the objects if abapGit did not do it for you.
3. **Roles:** add authorization object `ZFORMTRA` to a role. Activity `03`
   displays translations in the app, `01`/`02`/`06` create, change and delete
   them. The Copy Language action needs `01`. The service binding
   `ZUI_FORM_TRANS_BIN` ships with SU22 default values, so PFCG proposes the
   object when the binding is added to a role.
4. **Fiori app:** publish the OData V4 service binding `ZUI_FORM_TRANS_BIN` and
   either use the ADT preview or generate a List Report with SAP Fiori tools from
   the published service and deploy it to your launchpad. The repository ships the
   service, not a UI5 project.

Print-time reads of the table are **not** guarded by the access control on
purpose: the user who prints a form needs no maintenance role. Only the app is
checked.

## Usage

### In your Adobe / Smart Forms driver program

1. Define a structure for your labels in the form's global definitions or in the
   driver program.
2. Populate it with defaults (optional).
3. Call the translator **before** the form function module.

```abap
TYPES: BEGIN OF form_labels,
         title        TYPE string,
         footer_note  TYPE string,
         customer_lbl TYPE string,
       END OF form_labels.

DATA(labels) = VALUE form_labels( title = 'Invoice' ).

DATA(translator) = CAST zif_form_translation( NEW zcl_form_translation( ) ).

" Texts in the logon language of the user, English filling the gaps.
translator->translate_form( EXPORTING formname      = 'ZINVOICE_FORM'
                            CHANGING  form_elements = labels ).

" labels now carries the texts maintained in the app - pass it to the form.
```

Pass `langu` to translate into a specific language, for example the language of
the business partner the document is addressed to.

### API reference

`translate_form` maps the rows of `ZABAP_FORM_TRANS` onto the components of your
structure by field name (via RTTI).

| Parameter | Direction | Type | Default | Meaning |
|---|---|---|---|---|
| `formname` | importing | `zabap_form_trans_name` | – | Key in `ZABAP_FORM_TRANS`. An empty value returns without changes. Matched case-insensitively. |
| `langu` | importing | `zabap_form_trans_langu` | logon language | Target language. When empty, the logon language of the user is used; when that cannot be resolved, the default language `E`. |
| `enable_fallback` | importing | `abap_boolean` | `abap_true` | When on, fields without a text in the target language fall back to the default language `E`. |
| `form_elements` | changing | `any` | – | Flat structure whose components are filled with the translated texts. Components that cannot hold text keep their value. |

`clear_buffer` (static) invalidates the in-memory translation buffer.

The constructor accepts an optional `zif_form_trans_user_context` — the source
of the logon language. You will only ever pass it in a unit test.

> Only **flat** structures are supported. Nested structures and internal tables
> are not translated. A translation with an empty text leaves the component untouched.

### Database table `ZABAP_FORM_TRANS`

| Field | Type | Key | Description |
|---|---|---|---|
| `FORM` | `ZABAP_FORM_TRANS_NAME` (CHAR 30) | ✔ | Form key passed as `formname`. |
| `FIELDNAME` | `ZABAP_FORM_TRANS_FIELD` (CHAR 30) | ✔ | Component name in your structure. |
| `LANGU` | `ZABAP_FORM_TRANS_LANGU` (LANG) | ✔ | Language of the text. |
| `DESCR` | `ZABAP_FORM_TRANS_DESCR` (CHAR 50) | | Translated text. |
| `LENGTH` | `ZABAP_FORM_TRANS_MAXLEN` (INT2, 0–9999) | | Max length; a longer text is truncated at print time. `0` means no limit. |

Form and field names are stored in upper case; the app rejects anything else,
because HANA compares case-sensitively and the text could never be found at print time.

## The maintenance app

The list report on `ZC_FORM_TRANS` is draft-enabled: create, edit and delete rows,
search by form, field or language, and use the value helps for form and field names.

### Copying a translation into another language

Select one or more rows, press **Copy Language** and pick the target language.
Each selected row is duplicated into that language as a draft, keeping its
description and max length. Rejected with a message:

* the target language is empty, or is the language of the row itself
* a translation already exists under the target key, active or draft
* two selected rows of the same form and field aim at the same target language —
  there is no way to tell which text should win, so the whole selection is
  rejected rather than letting the first row silently decide

### Validations

| Rule | Trigger | Message |
|---|---|---|
| Description must not be empty | create, update, Prepare | 002 |
| Max length between 0 and 9999 | create, update, Prepare | 001 |
| Text longer than max length | create, update, Prepare | 006 (warning, does not block) |
| Key must not exist yet | create | 003 |
| Form and field name upper case | create | 007 |

### Authorization

| Operation | `ZFORMTRA` activity |
|---|---|
| Display (list, value helps) | 03 |
| Create, Copy Language | 01 |
| Edit / Update | 02 |
| Delete | 06 |

Denied operations report messages 008 (create) and 009 (change / delete).

## Architecture

Three layers, each testable on its own:

| Layer | Objects | Role |
|---|---|---|
| Print time | `ZIF_FORM_TRANSLATION`, `ZCL_FORM_TRANSLATION`, `ZIF_FORM_TRANS_USER_CONTEXT`, `ZCL_FORM_TRANS_USER_CONTEXT` | Reads the table, resolves the language, maps texts onto the caller structure. The user context adapter is the only platform dependency. |
| Rules | `ZCL_FORM_TRANS_RULES` | Pure functions: validation and copy rules, free of RAP and persistence. |
| Maintenance | `ZI_FORM_TRANS` (root, draft), `ZC_FORM_TRANS` (projection), `ZBP_I_FORM_TRANS`, `ZDD_COPY_LANG_POPUP`, value helps, `ZIF_FORM_TRANS_AUTHORITY`, `ZCL_FORM_TRANS_AUTHORITY`, DCLs, `ZFORMTRA`, `ZUI_FORM_TRANS_O4`, `ZUI_FORM_TRANS_BIN` | RAP business object, authorization, OData V4 service. |

Inside the behavior pool, `lcl_form_trans_factory` resolves the authority check;
tests inject a double through it. Handler methods are called directly by the test
classes (friends of the handler), EML is reserved for two smoke tests.

## Design decisions

* **`ZCL_FORM_TRANSLATION` is not FINAL and reads the database in a protected
  method.** An injected reader interface would cost two more objects for one
  SELECT; tests substitute the read by subclassing. The logon language, in
  contrast, is injected, because without that seam the "no language given" path
  could not be tested.
* **`ZCL_FORM_TRANS_RULES` is a static class.** The rules are pure functions with
  no collaborators; there is nothing to double, so nothing to inject.
* **Authorization is global, not per instance.** `ZFORMTRA` carries only
  `ACTVT`; a per-form authorization would add a field and an instance check —
  easy to add later, not needed now.
* **The logon language comes from XCO** (`xco_cp=>sy->language( )`), the one
  place in the package that reads the session, behind `ZIF_FORM_TRANS_USER_CONTEXT`.
* **The table has delivery class C.** Translations are transportable customizing
  by default; production maintenance through the app is still possible.
* **Object names are frozen.** Renaming shipped tables and views would force a
  data migration on every installation; new objects follow the naming of the
  existing ones.

## Tests

66 ABAP Unit tests run in ADT:

| Class | Tests | Covers |
|---|---|---|
| `ZCL_FORM_TRANSLATION` | 17 | RTTI mapping, truncation, language resolution, fallback, buffer |
| `ZCL_FORM_TRANS_RULES` | 25 | every validation and copy rule, including ambiguity |
| `ZCL_FORM_TRANS_USER_CONTEXT` | 1 | forwards the logon language |
| `ZBP_I_FORM_TRANS` | 23 | global authorization, validations, feature control, Copy Language, save sequence |

### Running the tests off-stack

The classes without RAP dependency also run outside the ABAP system, transpiled
to JavaScript with [abaplint](https://abaplint.org), so every push is verified
without an SAP system:

    npm ci
    npm run check

`check` runs abaplint (Clean ABAP rules plus a syntax check against the released
ABAP Cloud API) and 42 transpiled tests of `ZCL_FORM_TRANSLATION`,
`ZCL_FORM_TRANS_RULES` and `ZCL_FORM_TRANS_USER_CONTEXT`, backed by an in-memory
SQLite database so SELECT and `CL_OSQL_TEST_ENVIRONMENT` behave as in the system.
One test is skipped off-stack (`abap_transpile.json`, `skip`): the user context
test needs the XCO language API, which the open-abap stubs declare but do not
implement. The behavior pool tests need the RAP runtime and run in ADT only.

## License

This project is licensed under the [MIT License](https://github.com/greltel/abap-form-translator/blob/main/LICENSE).

## Contributors

Created by [George Drakos](https://www.linkedin.com/in/george-drakos/).
