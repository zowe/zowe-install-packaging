/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

import * as fs from 'fs';
import * as path from 'path';
import { parseStringPromise, Options as parseStringOptions, Builder } from 'xml2js';
const builder = new Builder();

import { INSTALL_TEST_REPORTS_DIR } from './constants';
import { calculateHash } from './utils';

const rootJunitFile: string = path.resolve(INSTALL_TEST_REPORTS_DIR, 'junit.xml');
if (!fs.existsSync(rootJunitFile)) {
  process.stderr.write(`Error: no test result found\n`);
  process.exit(1);
}
const htmlReportIndex: string = path.resolve(INSTALL_TEST_REPORTS_DIR, 'index.html');

async function readXml(file: string): Promise<any> {
  const xml = fs.readFileSync(file, {
    encoding: 'utf8'
  });
  const parseOpt: parseStringOptions = {trim: true};
  return await parseStringPromise(xml, parseOpt);
}

(async (): Promise<void> => {
  // ---------------------------------------------------------
  process.stdout.write(`Read ${rootJunitFile}\n`);
  const rootJunit = await readXml(rootJunitFile);
  // console.dir(rootJunit, {depth: null, colors: true})
  
  // init test count if missing
  rootJunit.testsuites.$.tests = '' + parseInt(rootJunit.testsuites.$.tests || 0, 10);
  rootJunit.testsuites.$.errors = '' + parseInt(rootJunit.testsuites.$.errors || 0, 10);
  rootJunit.testsuites.$.failures = '' + parseInt(rootJunit.testsuites.$.failures || 0, 10);
  rootJunit.testsuites.$.skipped = '' + parseInt(rootJunit.testsuites.$.skipped || 0, 10);
  rootJunit.testsuites.$.time = '' + parseFloat(rootJunit.testsuites.$.time || 0);

  // ---------------------------------------------------------
  let htmlReport: string[] = [
    '<!DOCTYPE html>',
    '<html>',
    '<body>',
    `<h1>${rootJunit.testsuites.$.name} HTML Report</h1>`,
    `<p>Total ${rootJunit.testsuites.$.tests} tests (`,
    `${rootJunit.testsuites.$.errors} errors`,
    `, ${rootJunit.testsuites.$.failures} failures`,
    `, ${rootJunit.testsuites.$.skipped} skipped`,
    `) in ${rootJunit.testsuites.$.time} seconds.</p>`,
    '<ul>',
  ];

  // ---------------------------------------------------------
  process.stdout.write('Merge:\n');
  let testcasesMerged = 0;
  for (const ts of rootJunit.testsuites.testsuite) {
    const testHash = calculateHash(ts.$.name);
    // init test count if missing
    ts.$.tests = '' + parseInt(ts.$.tests || 0, 10);
    ts.$.errors = '' + parseInt(ts.$.errors || 0, 10);
    ts.$.failures = '' + parseInt(ts.$.failures || 0, 10);
    ts.$.skipped = '' + parseInt(ts.$.skipped || 0, 10);
    ts.$.time = '' + parseFloat(ts.$.time || 0);

    const verifyTestResultFile: string = path.resolve(INSTALL_TEST_REPORTS_DIR, testHash, 'junit.xml');
    if (fs.existsSync(verifyTestResultFile)) {
      process.stdout.write(`- ${ts.$.name} (${testHash})\n`);
      const verifyJunit = await readXml(verifyTestResultFile);
      for (const vts of verifyJunit.testsuites.testsuite) {
        // add tests count
        ts.$.tests = '' + (parseInt(ts.$.tests, 10) + parseInt(vts.$.tests || 0, 10));
        ts.$.errors = '' + (parseInt(ts.$.errors, 10) + parseInt(vts.$.errors || 0, 10));
        ts.$.failures = '' + (parseInt(ts.$.failures, 10) + parseInt(vts.$.failures || 0, 10));
        ts.$.skipped = '' + (parseInt(ts.$.skipped, 10) + parseInt(vts.$.skipped || 0, 10));
        ts.$.time = '' + (parseFloat(ts.$.time) + parseFloat(vts.$.time || 0));
        rootJunit.testsuites.$.tests = '' + (parseInt(rootJunit.testsuites.$.tests, 10) + parseInt(vts.$.tests || 0, 10));
        rootJunit.testsuites.$.errors = '' + (parseInt(rootJunit.testsuites.$.errors, 10) + parseInt(vts.$.errors || 0, 10));
        rootJunit.testsuites.$.failures = '' + (parseInt(rootJunit.testsuites.$.failures, 10) + parseInt(vts.$.failures || 0, 10));
        rootJunit.testsuites.$.skipped = '' + (parseInt(rootJunit.testsuites.$.skipped, 10) + parseInt(vts.$.skipped || 0, 10));
        rootJunit.testsuites.$.time = '' + (parseFloat(rootJunit.testsuites.$.time) + parseFloat(vts.$.time || 0));

        // merge test cases
        for (const vtc of vts.testcase) {
          vtc.$.name = `${ts.$.name} - sanity test - ${vts.$.name}  - ${vtc.$.name}`;
          ts.testcase.push(vtc);
          testcasesMerged++;
        }
      }
      // delete after merged
      fs.unlinkSync(verifyTestResultFile);
    }

    const verifyTestHtmlReport: string = path.resolve(INSTALL_TEST_REPORTS_DIR, testHash, 'index.html');
    htmlReport.push('<ul>');
    if (fs.existsSync(verifyTestHtmlReport)) {
      htmlReport.push(`<a href="${testHash}/index.html">${ts.$.name}</a>`);
    } else {
      htmlReport.push(ts.$.name);
    }
    htmlReport.push(`: ${ts.$.tests} tests (`);
    htmlReport.push(`${ts.$.errors} errors`);
    htmlReport.push(`, ${ts.$.failures} failures`);
    htmlReport.push(`, ${ts.$.skipped} skipped`);
    htmlReport.push(`) in ${ts.$.time} seconds.</ul>`);
  }

  // ---------------------------------------------------------
  if (testcasesMerged > 0) {
    process.stdout.write(`Write back to ${rootJunitFile}\n`);
    const updatedXml: string = builder.buildObject(rootJunit);
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
