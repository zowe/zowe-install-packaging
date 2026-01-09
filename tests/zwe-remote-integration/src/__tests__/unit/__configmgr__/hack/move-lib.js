const fs = require('fs');


const tscOutDir = 'lib'; // reading from tsconfig requires JSONC
// Bad hack because tsc requires rootDir to include the 'bin' dir in the repo root. This places the unit test 
//  output in a deeply nested directory within the 'outDir'

const outputDir = fs.readdirSync(tscOutDir);
if (!outputDir.includes('tests')) {
  console.error(`Output dir ${tscOutDir} not found. Did the project compile?`)
  process.exit(1);
}

fs.renameSync(
  `${tscOutDir}/tests/zwe-remote-integration/src/__tests__/unit/__configmgr__/tests`, 
  `${tscOutDir}/tests_bk`
)
fs.rmSync(`${tscOutDir}/tests`, {recursive: true, force: true})
fs.renameSync(`${tscOutDir}/tests_bk`, `${tscOutDir}/tests`);
