


const core = require('@actions/core');

if (process.env['HOLDDATA_FILES'] == null || 
    process.env['HOLDDATA_FILES'].trim().length == 0) {
  core.setFailed('This script requires the HOLDDATA_FILES env to be set.');
  return;
}

core.info(`Checking HOLDDATA: ${process.env.HOLDDATA_FILES}`);

const errors = [];
for (const holdDataFile of process.env.HOLDDATA_FILES.trim().split(' ')) {

  const fs = require('fs');

  core.info(`Testing ${holdDataFile}`);
  const lines = fs.readFileSync(holdDataFile, 'utf-8').split('\n');

  const openParens = [];

  for (let i = 0; i < lines.length; i++) {

    const rawLine = lines[i];
    const line = lines[i].trim();

    if (rawLine.length > 64) {
      errors.push({file: holdDataFile, error: `Line ${i+1} is too long. It has ${line.length} characters, but should have no more than 64.` });
    }

    if (line.startsWith('*')) {
      continue;
    }
    if (line.includes('/*') || line.includes('*/')) {
      errors.push({file: holdDataFile, error: `HOLDDATA has the invalid comment sequence on line ${i+1}. Either '/*' or '*/'`});
    }
    if (line.includes('~')) { 
      errors.push({file: holdDataFile, error: `HOLDDATA has the invalid character '~' on line ${i+1}. This character is reserved by automation for use in sed and should not be used.`});
    }
    for (let j = 0; j < line.length; j++) {
      if (line.charAt(j) === '(') {
        openParens.push(j);
      }
      if (line.charAt(j) === ')') {
        if (openParens.pop() == null) {
          errors.push({file: holdDataFile, error: `HOLDDATA has a ')' without a matching '(' on line ${i+1}.`});
        }
      }
    }
  }

  if (openParens.length > 0) {
    errors.push({file: holdDataFile, error: `HOLDDATA has a '(' without a matching ')'.`});
  }
}

if (errors.length > 0) {
  core.error(JSON.stringify(errors));
  core.setFailed(`HOLDDATA has errors. See above.`);
} else {
  core.info(`HOLDDATA has no errors.`);
}
