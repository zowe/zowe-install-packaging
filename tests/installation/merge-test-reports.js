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

const { INSTALL_TEST_REPORTS_DIR } = require('./src/constants');
const { calculateHash } = require('./src/utils');

const rootJunitFile = path.resolve(INSTALL_TEST_REPORTS_DIR, 'junit.xml');
if (!fs.existsSync(rootJunitFile)) {
  process.stderr.write(`Error: no test result found\n`);
  process.exit(1);
}
const htmlReportIndex = path.resolve(INSTALL_TEST_REPORTS_DIR, 'index.html');

const readXml = async (file) => {
  var xml = fs.readFileSync(file, {
    encoding: 'utf8'
  });
  return await parseString(xml, {trim: true});
};

(async () => {
  // ---------------------------------------------------------
  process.stdout.write(`Read ${rootJunitFile}\n`);
  let rootJunit = await readXml(rootJunitFile);
  // console.dir(rootJunit, {depth: null, colors: true})

  // ---------------------------------------------------------
  let htmlReport = [
    '<!DOCTYPE html>',
    '<html>',
    '<body>',
    `<h1>${rootJunit.testsuites.$.name} HTML Report</h1>`,
    `<p>Total ${rootJunit.testsuites.$.tests} tests (`,
    `${rootJunit.testsuites.$.errors ? rootJunit.testsuites.$.errors : 0} errors`,
    `, ${rootJunit.testsuites.$.failures ? rootJunit.testsuites.$.failures : 0} failures`,
    `, ${rootJunit.testsuites.$.skipped ? rootJunit.testsuites.$.skipped : 0} skipped`,
    `) in ${rootJunit.testsuites.$.time} seconds.</p>`,
    '<ul>',
  ];

  // ---------------------------------------------------------
  process.stdout.write('Merge:\n');
  let testcasesMerged = 0;
  for (let ts of rootJunit.testsuites.testsuite) {
    const testHash = calculateHash(ts.$.name);

    const verifyTestResultFile = path.resolve(INSTALL_TEST_REPORTS_DIR, testHash, 'junit.xml');
    if (fs.existsSync(verifyTestResultFile)) {
      process.stdout.write(`- ${ts.$.name} (${testHash})\n`);
      const verifyJunit = await readXml(verifyTestResultFile);
      for (let vts of verifyJunit.testsuites.testsuite) {
        for (let vtc of vts.testcase) {
          vtc.$.name = `${ts.$.name} - sanity test - ${vts.$.name}  - ${vtc.$.name}`;
          ts.testcase.push(vtc);
          testcasesMerged++;
        }
      }
      // delete after merged
      fs.unlinkSync(verifyTestResultFile);
    }

    const verifyTestHtmlReport = path.resolve(INSTALL_TEST_REPORTS_DIR, testHash, 'index.html');
    htmlReport.push('<ul>');
    if (fs.existsSync(verifyTestHtmlReport)) {
      htmlReport.push(`<a href="${testHash}/index.html">${ts.$.name}</a>`);
    } else {
      htmlReport.push(ts.$.name);
    }
    htmlReport.push(`: ${ts.$.tests} tests (`);
    htmlReport.push(`${ts.$.errors ? ts.$.errors : 0} errors`);
    htmlReport.push(`, ${ts.$.failures ? ts.$.failures : 0} failures`);
    htmlReport.push(`, ${ts.$.skipped ? ts.$.skipped : 0} skipped`);
    htmlReport.push(`) in ${ts.$.time} seconds.</ul>`);
  }

  // ---------------------------------------------------------
  if (testcasesMerged > 0) {
    process.stdout.write(`Write back to ${rootJunitFile}\n`);
    const updatedXml = builder.buildObject(rootJunit);
    fs.writeFileSync(rootJunitFile, updatedXml);
  } else {
    process.stdout.write(`No update required.\n`);
  }

  // ---------------------------------------------------------
  htmlReport = [
    ...htmlReport,
    '</ul>',
    '</body>',
    '</html>',
  ];
  process.stdout.write(`Update ${htmlReportIndex}\n`);
  fs.writeFileSync(htmlReportIndex, htmlReport.join('\n'));

  // ---------------------------------------------------------
  process.stdout.write('DONE\n');
})();
