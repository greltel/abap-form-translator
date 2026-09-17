# Contributing

Thanks for taking the time. Issues and pull requests are welcome — a short
description of the problem or the idea is enough to start.

## Development loop

1. Fork and clone. Create a package with ABAP language version *ABAP for Cloud
   Development* in an SAP S/4HANA 2023 (or later) system and pull your fork with
   abapGit onto a branch.
2. Develop in ADT. Every global class ships its ABAP Unit tests in the test
   include; run them with `Ctrl+Shift+F10` before you push.
3. Push from abapGit to your branch, then run the off-stack gate locally:

       npm ci
       npm run check

   `check` is what the GitHub workflow runs: abaplint with a syntax check against
   the released ABAP Cloud API, plus the transpiled unit tests. Both have to be
   green before a pull request is reviewed.
4. Open a pull request against `main`. Describe what changed and why; link the
   issue if there is one.

## What the gate enforces

- **Clean ABAP** as configured in `abaplint.json`: no Hungarian prefixes, inline
  declarations, `xsdbool`, table expressions instead of `READ TABLE`, no `SELECT`
  in loops, `ORDER BY` on every `SELECT`, ABAP Doc on every public element.
- **Released APIs only.** The syntax check runs against the abapedia snapshot of
  the released ABAP Cloud API; anything outside it fails the lint.
- **Line endings** are LF; `.gitattributes` and `.editorconfig` take care of it.
  Run `git add --renormalize .` once after cloning if your editor converted files.

Two abaplint grammar gaps are worked around in the configuration and are not a
reason to change the code: `CLASS … DEFINITION DEFERRED FOR TESTING` and
`CREATE OBJECT … FOR TESTING` are not parsed, so `parser_error` excludes the two
behavior pool includes and `errorNamespace` treats unresolved `LTC_`/`LTD_`/`LTH_`
names as known.

## Tests

- Rules and runtime classes: plain ABAP Unit, no test doubles beyond an Open SQL
  test environment; these also run off-stack.
- Behavior pool: handler methods are called directly through test classes that
  are friends of the handler. `lth_translation_doubles` owns the CDS and draft
  table doubles, `lcl_form_trans_factory=>inject_authority` replaces the
  authority check. EML is used for two smoke tests only. These tests need the RAP
  runtime and run in ADT.
- Name tests `given_<state>_then_<outcome>` or `when_<action>_then_<outcome>`,
  30 characters at most, with an Arrange / Act / Assert layout and a message
  that explains what the assertion protects.
- A test that is skipped off-stack goes into the `skip` list of
  `abap_transpile.json` with the reason documented in its ABAP Doc.

## Conventions

- Object names of the shipped objects are frozen; renaming a table or a view
  forces a data migration on every installation. New objects follow the naming
  of the existing ones (`ZCL_FORM_TRANS_*`, `ZIF_FORM_TRANS_*`, `ZI_`/`ZC_` views).
- Business rules live in `ZCL_FORM_TRANS_RULES`, free of RAP and persistence.
  The behavior implementation is an adapter: read, call the rule, report.
- Platform access (logon language, authority check) sits behind an interface
  with a production implementation and a test double.
- Messages come from message class `ZABAP_FORM_TRANS_MSG`; the numbers are
  constants in `ZCL_FORM_TRANS_RULES`.
- The version lives in `ZCL_FORM_TRANSLATION=>VERSION`, `package.json` and
  `CHANGELOG.md`; bump all three in a release.

## Releasing

1. Update `CHANGELOG.md`, `ZCL_FORM_TRANSLATION=>VERSION` and `package.json`.
2. Push, wait for the workflow to pass.
3. Tag `vX.Y.Z` (lower-case `v`) and publish a GitHub release with the changelog
   section as its notes.
