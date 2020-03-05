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
const { spawn } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const ncp = util.promisify(require('ncp').ncp);
const mkdirp = require('mkdirp');
const path = require('path');
const debug = require('debug')('test:utils');

const { ANSIBLE_ROOT_DIR, SANITY_TEST_REPORTS_DIR, INSTALL_TEST_REPORTS_DIR } = require('./constants');

const checkMadatoryEnvironmentVariabls = (vars) => {
  for (let v of vars) {
    expect(process.env).toHaveProperty(v);
  }
};

const calculateHash = (obj) => {
  return crypto.createHash('md5').update(util.format('%j', obj)).digest('hex');
};

const copySanityTestReport = async (reportId) => {
  if (fs.existsSync(path.resolve(SANITY_TEST_REPORTS_DIR, 'junit.xml'))) {
    const targetReportDir = path.resolve(INSTALL_TEST_REPORTS_DIR, `${reportId}`);
    mkdirp.sync(targetReportDir);
    await ncp(SANITY_TEST_REPORTS_DIR, targetReportDir);
  }
};

const importDefaultExtraVars = (extraVars) => {
  const defaultMapping = {
    'ansible_ssh_host': 'SSH_HOST',
    'ansible_port': 'SSH_PORT',
    'ansible_user': 'SSH_USER',
    'ansible_password': 'SSH_PASSWD',
  };

  Object.keys(defaultMapping).forEach((item) => {
    if (process.env[defaultMapping[item]]) {
      extraVars[item] = process.env[defaultMapping[item]];
    }
  });
};

/**
 * Run Ansible playbook
 *
 * @param  {String}    testcase 
 * @param  {String}    playbook
 * @param  {String}    serverId
 * @param  {Object}    extraVars
 * @param  {String}    verbose
 */
const runAnsiblePlaybook = (testcase, playbook, serverId, extraVars = {}, verbose = '-v') => {
  return new Promise((resolve, reject) => {
    let result = {
      reportId: calculateHash(testcase),
      code: null,
      stdout: '',
      stderr: '',
    };
    // import default vars
    if (!extraVars) {
      extraVars = {};
    }
    importDefaultExtraVars(extraVars);
    let params = [
      '-l', serverId,
      playbook,
      verbose,
      `--extra-vars`,
      util.format('%j', extraVars),
    ];
    let opts = {
      cwd: ANSIBLE_ROOT_DIR,
    };

    const pb = spawn('ansible-playbook', params, opts);

    pb.stdout.on('data', (data) => {
      const d = data.toString('utf8');
      result.stdout += d;
      debug(d);
    });
    
    pb.stderr.on('data', (data) => {
      const d = data.toString('utf8');
      result.stderr += d;
      debug('Error: ' + d);
    });

    pb.on('error', (err) => {
      debug('Error: ' + err);
      result.error = err;

      reject(result);
    });
    
    pb.on('close', (code) => {
      result.code = 0;
      debug(`Playbook ${playbook} exits with code ${code}`);

      if (code === 0) {
        resolve(result);
      } else {
        reject(result);
      }
    });
  });
};

// export constants and methods
module.exports = {
  checkMadatoryEnvironmentVariabls,
  calculateHash,
  copySanityTestReport,
  runAnsiblePlaybook,
};
