import fs from 'fs';

const filePath = 'src/zcl_form_translation.clas.testclasses.abap';

try {
  let code = fs.readFileSync(filePath, 'utf8');

  // Αφαίρεση του DEFINITION
  const defRegex = /CLASS\s+ltc_get_translations\s+DEFINITION[\s\S]*?ENDCLASS\./gi;
  code = code.replace(defRegex, '');

  // Αφαίρεση του IMPLEMENTATION
  const impRegex = /CLASS\s+ltc_get_translations\s+IMPLEMENTATION[\s\S]*?ENDCLASS\./gi;
  code = code.replace(impRegex, '');

  fs.writeFileSync(filePath, code, 'utf8');
  console.log('Class ltc_get_translations removed for GitHub Actions.');
} catch (err) {
  console.error('Error', err);
  process.exit(1);
}
