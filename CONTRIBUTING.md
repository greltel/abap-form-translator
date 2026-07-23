# Contributing

Thanks for your interest in improving **ABAP Form Translator**! Contributions —
bug reports, feature ideas, and pull requests — are very welcome.

## Reporting issues

- Search the existing [issues](https://github.com/greltel/abap-form-translator/issues)
  first to avoid duplicates.
- For bugs, please include the ABAP release / stack, the form and structure you are
  translating, and the steps to reproduce.

## Development setup

- Import the repository into your ABAP Cloud / S/4HANA system with
  [abapGit](https://abapgit.org).
- The project targets **ABAP Cloud** and `SAP_BASIS 7.54+` and must stay Clean-Core
  compatible (no non-released APIs).

## Coding guidelines

- Follow the [Clean ABAP](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md)
  style guide.
- The repository is linted with [abaplint](https://abaplint.org); the configuration
  lives in `abaplint.json`. Please keep the code free of new abaplint findings.
- Keep the code buffer- and Clean-Core-friendly (host variables in Open SQL, no
  dynamic SQL, no hardcoded texts — use the message class).

## Tests

- Unit tests live in `zcl_form_translation.clas.testclasses.abap`. Please add or
  update tests for any behavior you change and make sure ABAP Unit is green before
  opening a pull request.

## Pull requests

- Keep pull requests focused and describe the motivation and the change.
- Update `CHANGELOG.md` under the **Unreleased** section.
- Bump the `version` constant in `zcl_form_translation.clas.abap` only for releases.
