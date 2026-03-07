# ABAP Form Translator
# ✅ Status: Release (v1.0.0)
> **Open Source Contribution:** This project is community-driven and **Open Source**! 🚀  
> If you spot a bug or have an idea for a cool enhancement, your contributions are more than welcome. Feel free to open an **Issue** or submit a **Pull Request**.

![ABAP Cloud](https://img.shields.io/badge/ABAP-Cloud%20Ready-green)
![ABAP Version](https://img.shields.io/badge/ABAP-7.57%2B-blue)
[![Code Statistics](https://img.shields.io/badge/CodeStatistics-abaplint-blue)](https://abaplint.app/stats/greltel/abap-form-translator)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/endpoint?url=https://shield.abappm.com/github/greltel/abap-form-translator/src/zcl_form_translation.clas.abap/c_version)

A lightweight, dynamic **runtime translation tool** for SAP forms.
It decouples text management from form development, allowing functional consultants or users to maintain labels via a simple database table (`SM30`,`Business Configuration`), bypassing the complex standard SE63 workflow.

# Table of contents
1. [License](#License)
2. [Contributors-Developers](#Contributors-Developers)
3. [Key Benefits](#Key-Benefits)
4. [Design Goals-Features](#Design-Goals-Features)
5. [Usage](#Usage)

## License
This project is licensed under the [MIT License](https://github.com/greltel/abap-form-translator/blob/main/LICENSE).

## Contributors-Developers
The repository was created by [George Drakos](https://www.linkedin.com/in/george-drakos/).

## Key Benefits

* **No more SE63:** Forget about the painful standard translation process for forms.
* **Zero Hardcoding:** Keep your form logic clean. No more `IF sy-langu = 'D'. text = 'Kunde'. ENDIF`.
* **Hot-Swap Texts:** Change a label description in Production without a Transport Request.
* **Generic:** Works with **any** ABAP structure or Form interface using RTTI.
* **Performance:** Optimized with table buffering to ensure zero impact on print times.
* **Unit Tested:** Includes built-in ABAP Unit tests.

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
DATA: BEGIN OF gs_labels,
        title        TYPE string,
        footer_note  TYPE string,
        customer_lbl TYPE string,
      END OF gs_labels.

" 1.Initialize (Optional defaults)
gs_labels-title = 'Invoice'.

" 2.Translate dynamically based on Language and DB Configuration
NEW zcl_form_translation( )->translate_form(
  EXPORTING
    iv_formname      = 'ZINVOICE_FORM'   " Key in ZABAP_FORM_TRANS
    iv_langu         = p_langu           " e.g., NAST-SPRAS
  CHANGING
    cs_form_elements = gs_labels ).         " The structure to be translated

" 3. The gs_labels structure now contains the translated texts from ZDB_FORM_TRANS
"    Pass this structure to your Smartform / Adobe Form interface.
