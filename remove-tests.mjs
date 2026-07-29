import fs from 'fs';
import path from 'path';

// Off-stack build preparation.
//
// The transpiler cannot run the tests that rely on CL_OSQL_TEST_ENVIRONMENT,
// so a throw-away copy of /src is created under /build and the affected test
// class is stripped there. The repository itself is never modified.

const SOURCE_DIR = 'src';
const BUILD_DIR = path.join('build', 'src');

const EXCLUDED = [
  {
    file: 'zcl_form_translation.clas.testclasses.abap',
    classes: ['ltc_get_translations'],
  },
];

function stripClass(code, name) {
  // Also swallows the ABAP Doc block in front of the class, so no orphan
  // comment is left behind.
  const block = String.raw`(?:^[ \t]*"!.*\r?\n)*^[ \t]*CLASS\s+${name}\s+(?:DEFINITION|IMPLEMENTATION)[\s\S]*?^[ \t]*ENDCLASS\.\r?\n`;
  const regex = new RegExp(block, 'gim');

  const removed = (code.match(regex) || []).length;
  if (removed !== 2) {
    throw new Error(
      `Expected to remove DEFINITION and IMPLEMENTATION of ${name}, removed ${removed} block(s). ` +
        `Has the class been renamed?`
    );
  }
  return code.replace(regex, '');
}

fs.rmSync('build', { recursive: true, force: true });
fs.cpSync(SOURCE_DIR, BUILD_DIR, { recursive: true });

for (const { file, classes } of EXCLUDED) {
  const target = path.join(BUILD_DIR, file);
  let code = fs.readFileSync(target, 'utf8');
  for (const name of classes) {
    code = stripClass(code, name);
  }
  fs.writeFileSync(target, code, 'utf8');
  console.log(`Stripped ${classes.join(', ')} from build copy of ${file}`);
}
