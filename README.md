# ABAP Form Translator
# ✅ Status: Release (1.3.0)
> **Open Source Contribution:** This project is community-driven and **Open Source**! 🚀  
> If you spot a bug or have an idea for a cool enhancement, your contributions are more than welcome. Feel free to open an **Issue** or submit a **Pull Request**.

[![ABAP Cloud](https://img.shields.io/badge/ABAP-Cloud%20Ready-green)](https://abaplint.app/stats/greltel/abap-form-translator/object_classifications)
[![ABAP Version](https://img.shields.io/badge/ABAP-7.57%2B-blue )](https://abaplint.app/stats/greltel/abap-form-translator/statement_compatibility)
[![Code Statistics](https://img.shields.io/badge/CodeStatistics-abaplint-blue)](https://abaplint.app/stats/greltel/abap-form-translator)
[![License](https://img.shields.io/badge/License-MIT-green)](https://github.com/greltel/abap-form-translator/blob/main/LICENSE)
![Version](https://img.shields.io/endpoint?url=https://shield.abappm.com/github/greltel/abap-form-translator/src/zcl_form_translation.clas.abap/version)

A lightweight, dynamic **runtime translation tool** for SAP forms.
It decouples text management from form development, allowing functional consultants or users to maintain labels via a simple database table (`RAP Application`), bypassing the complex standard SE63 workflow.

# Table of contents
1. [License](#license)
2. [Contributors-Developers](#contributors-developers)
3. [Key Benefits](#key-benefits)
4. [Design Goals-Features](#design-goals-features)
5. [Usage](#usage)

## License
This project is licensed under the [MIT License](https://github.com/greltel/abap-form-translator/blob/main/LICENSE).

## Contributors-Developers
The repository was created by [George Drakos](https://www.linkedin.com/in/george-drakos/).

## Key Benefits

* **No more SE63:** Forget about the painful standard translation process for forms.
* **Zero Hardcoding:** Keep your form logic clean. No more `IF sy-langu = 'D'. text = 'Kunde'. ENDIF`.
* **Hot-Swap Texts:** Change a label description in Production without a Transport Request.
  Note: the table is buffered, so a change becomes visible to other application
  servers after the buffer synchronisation interval (typically ~60s). Inside a
  long-running session (mass print / batch job) call `ZCL_FORM_TRANSLATION=>clear_buffer( )`
  to pick up changes immediately.
* **Generic:** Works with **any** ABAP flat structure or Form interface using RTTI.
* **Performance:** Optimized with table buffering to ensure zero impact on print times.
* **Unit Tested:** Includes built-in ABAP Unit tests.
* **Fiori Elements App** built entirely with the ABAP RESTful Application Programming Model (RAP) for maintaining form translations

![2026-03-07 23-40-52](https://github.com/user-attachments/assets/becf5ae2-4df8-4431-baca-0b66c9ba50a2)

## Design Goals-Features

* Install via [ABAPGit](http://abapgit.org)
* ABAP Cloud/Clean Core compatibility.Passed SCI check variant S4HANA_READINESS_2023 and ABAP_CLOUD_READINESS
* Unit Tested

## Usage

### In your Adobe / Smartform Driver Program / Print Program

1.  Define a structure for your labels/texts in the form Global Definitions or the Driver Program.
2.  Populate it with default values (optional).
3.  Call the translator **before** calling the form Function Module(for smartforms).

```abap
DATA: BEGIN OF labels,
        title        TYPE string,
        footer_note  TYPE string,
        customer_lbl TYPE string,
      END OF labels.

" 1.Initialize (Optional defaults)
labels-title = 'Invoice'.

" 2.Translate dynamically based on Language and DB Configuration
DATA(translator) = CAST zif_form_translation( NEW zcl_form_translation( ) ).

translator->translate_form(
      EXPORTING formname      = 'ZINVOICE_FORM'   " Key in ZABAP_FORM_TRANS
                langu         = cl_abap_context_info=>get_user_language_abap_format( )
      CHANGING  form_elements = labels ).         " The structure to be translated

" 3. The labels structure now contains the translated texts from ZABAP_FORM_TRANS
"    Pass this structure to your Smartform / Adobe Form interface.
```

### API reference

`translate_form` maps the fields of `ZABAP_FORM_TRANS` onto the components of your
structure by field name (via RTTI). Signature:

| Parameter | Direction | Type | Default | Meaning |
|---|---|---|---|---|
| `formname` | importing | `zabap_form_trans_name` | – | Key in `ZABAP_FORM_TRANS`. An empty value returns without changes. |
| `langu` | importing | `zabap_form_trans_langu` | logon language | Target language. If empty, the current user language is used. |
| `enable_fallback` | importing | `abap_boolean` | `abap_true` | When on, fields that have no text in the target language fall back to the default language (`E`). |
| `form_elements` | changing | `any` | – | Flat structure whose components are filled with the translated texts. |

`clear_buffer` (static) invalidates the in-memory translation buffer. Call it after
maintaining translations inside a long-living session (mass print / batch / job
server) so hot-swapped texts take effect immediately.

> Note: only **flat** structures are supported. Nested structures and internal
> tables are not translated.

### Database table `ZABAP_FORM_TRANS`

Maintain the texts through the RAP/Fiori app (`ZUI_FORM_TRANS_BIN`) in this table:

| Field | Type | Key | Description |
|---|---|---|---|
| `FORM` | `ZABAP_FORM_TRANS_NAME` (CHAR 30) | ✔ | Form key passed as `formname`. |
| `FIELDNAME` | `ZABAP_FORM_TRANS_FIELD` (CHAR 30) | ✔ | Component name in your structure. |
| `LANGU` | `ZABAP_FORM_TRANS_LANGU` (LANG) | ✔ | Language of the text. |
| `DESCR` | `ZABAP_FORM_TRANS_DESCR` (CHAR 50) | | Translated text. |
| `LENGTH` | `ZABAP_FORM_TRANS_MAXLEN` (INT2, domain range 0–9999) | | Max length; text longer than this is truncated at print time. `0` means no length limit. |
