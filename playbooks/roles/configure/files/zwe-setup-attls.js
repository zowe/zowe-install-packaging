// using node because sed does not handle multi-line string replacement well
//  We set ##---start_zowe_dynamic--- and ##---end_zowe_dynamic to track ATTLS rules implemented by automation.

// Expected call pattern:
//   node zwe-setup-attls.js <attls-enabled> <attls-rules> <attls-member>

// This takes the rules supplied by <attls-rules> and inserts them into the dynamic block of the <attls-member>. 
//   If <attls-enabled> is false, then <attls-rules> are ignored and the dynamic block is blanked.
const args = process.argv;
const fs = require('fs');
const cp = require('child_process');
const path = require('path');
if (args.length !== 5) {
  throw new Error('Missing command line argument(s). Usage: node zwe-setup-attls.js <attls-enabled> <attls-rules> <attls-member>');
}
const attlsEnabled = args[2].toLowerCase();
const attlsIncomingRulesFile = args[3];
let attlsPolicyMember = args[4];
if (attlsEnabled !== 'true' && attlsEnabled !== 'false') {
  throw new Error('The first argument, attls-enabled, must be either \'true\' or \'false\'');
}
if (attlsEnabled == 'true' && (attlsIncomingRulesFile.trim().length > 0 && !fs.existsSync(attlsIncomingRulesFile))) {
  throw new Error(`Couldn't find the AT-TLS new rules file: ${attlsRulesFile}`);
}
if (attlsPolicyMember.includes('//')) {
  throw new Error('Please remove forward slashes from the policy member. Use a format like <HLQ.PFX.LVL(MEM)>.')
}

attlsPolicyMember = attlsPolicyMember.replaceAll(/"'/gi,'');
attlsPolicyMember = `"//'${attlsPolicyMember}'"`;

const tmpdir = fs.mkdtempSync('attls-auto', {encoding: 'cp1047'});
let attlsContent;
try {
  attlsContent = cp.execSync(`cat ${attlsPolicyMember}`).toString();
} catch(error) {
  throw new Error(`Couldn't find AT-TLS policy member: `+ attlsPolicyMember);
}

// clean content out and leave the start block
let modifiedContent = attlsContent.replace(/(##---start_zowe_dynamic---).*##---end_zowe_dynamic---/gms, '$1')

if (attlsEnabled == 'true') {
  const rules = fs.readFileSync(attlsIncomingRulesFile, 'cp1047')
  modifiedContent+=rules;
}

// end dynamic block
modifiedContent+="\n##---end_zowe_dynamic---\n";
const tmpFile = `${tmpdir}${path.sep}attls.final`;
fs.writeFileSync(tmpFile, modifiedContent, {encoding: 'cp1047'});
try {

  // make sure policy member is in writable form - "//'<member-name>'"
  cp.execSync(`cp ${tmpFile} ${attlsPolicyMember}`);
} catch (error) {
  console.log(error);
} finally {
  fs.rmdirSync(tmpdir, { force: true, recursive: true });
}