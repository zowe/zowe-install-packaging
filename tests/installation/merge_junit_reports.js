/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const util = require('util');
const fs = require('fs');
const path = require('path');
const xml2js = require('xml2js');
const parseString = util.promisify(xml2js.parseString);
const builder = new xml2js.Builder();
const rimraf = util.promisify(require('rimraf'));

const { INSTALL_TEST_REPORTS_DIR } = require('./src/constants');
const { calculateHash } = require('./src/utils');

const rootJunitFile = path.resolve(INSTALL_TEST_REPORTS_DIR, 'junit.xml');
if (!fs.existsSync(rootJunitFile)) {
  process.stderr.write(`Error: no test result found`);
  process.exit(1);
}

const readXml = async (file) => {
  var xml = fs.readFileSync(file, {
    encoding: 'utf8'
  });
  return await parseString(xml, {trim: true});
};

(async () => {
  // ---------------------------------------------------------
  process.stdout.write(`Read ${rootJunitFile}`);
  let rootJunit = await readXml(rootJunitFile);

  // ---------------------------------------------------------
  process.stdout.write('Merge:');
  let testcasesMerged = 0;
  for (let ts of rootJunit.testsuites.testsuite) {
    const testHash = calculateHash(ts.$.name);
    const verifyTestResultFile = path.resolve(INSTALL_TEST_REPORTS_DIR, testHash, 'junit.xml');
    if (fs.existsSync(verifyTestResultFile)) {
      process.stdout.write(`- ${ts.$.name} (${testHash})`);
      const verifyJunit = await readXml(verifyTestResultFile);
      for (let vts of verifyJunit.testsuites.testsuite) {
        for (let vtc of vts.testcase) {
          vtc.$.name = `${ts.$.name} - sanity test - ${vts.$.name}  - ${vtc.$.name}`;
          ts.testcase.push(vtc);
          testcasesMerged++;
        }
      }
      // delete after merged
      rimraf(path.resolve(INSTALL_TEST_REPORTS_DIR, testHash), {
        glob: false
      });
    }
  }

  // ---------------------------------------------------------
  if (testcasesMerged > 0) {
    process.stdout.write(`Write back to ${rootJunitFile}`);
    const updatedXml = builder.buildObject(rootJunit);
    fs.writeFileSync(rootJunitFile, updatedXml);
  } else {
    process.stdout.write(`No update required.`);
  }

  // ---------------------------------------------------------
  process.stdout.write('DONE');
})();
