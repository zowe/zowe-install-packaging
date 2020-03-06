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
const debug = require('debug')('zowe-install-test:utils');

const {
  ANSIBLE_ROOT_DIR,
  SANITY_TEST_REPORTS_DIR,
  INSTALL_TEST_REPORTS_DIR,
} = require('./constants');

/**
 * Check if there are any mandatory environment variable is missing.
 * 
 * @param {Array} vars     list of env variable names
 */
const checkMandatoryEnvironmentVariables = (vars) => {
  for (let v of vars) {
    expect(process.env).toHaveProperty(v);
  }
};

/**
 * Generate MD5 hash of a variable
 *
 * @param {Any} obj        any object
 */
const calculateHash = (obj) => {
  return crypto.createHash('md5').update(util.format('%j', obj)).digest('hex');
};

/**
 * Copy sanity test report to install test report folder for future publish.
 *
 * @param {String} reportHash      report hash
 */
const copySanityTestReport = async (reportHash) => {
  if (fs.existsSync(path.resolve(SANITY_TEST_REPORTS_DIR, 'junit.xml'))) {
    const targetReportDir = path.resolve(INSTALL_TEST_REPORTS_DIR, `${reportHash}`);
    mkdirp.sync(targetReportDir);
    await ncp(SANITY_TEST_REPORTS_DIR, targetReportDir);
  }
};

/**
 * Import extra vars for Ansible playbook from environment variables.
 * 
 * @param {Object} extraVars      Object
 */
const importDefaultExtraVars = (extraVars) => {
  const defaultMapping = {
    'ansible_ssh_host': 'SSH_HOST',
    'ansible_port': 'SSH_PORT',
    'ansible_user': 'SSH_USER',
    'ansible_password': 'SSH_PASSWD',
    'zowe_build_local': 'ZOWE_BUILD_LOCAL',
    'zos_node_home': 'ZOS_NODE_HOME',
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
      reportHash: calculateHash(testcase),
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
      process.env.ANSIBLE_VERBOSE || verbose,
      `--extra-vars`,
      util.format('%j', extraVars),
    ];
    let opts = {
      cwd: ANSIBLE_ROOT_DIR,
    };

    debug(`Playbook ${playbook} started with parameter: ${util.format('%j', params)}`);
    process.stdout.write(`>>>>>>>>>>>>>>>>>>>>> playbook ${playbook} started >>>>>>>>>>>>>>>>>>>>>`);
    const pb = spawn('ansible-playbook', params, opts);

    pb.stdout.on('data', (data) => {
      const d = data.toString('utf8');
      result.stdout += d;
      process.stdout.write(d);
      // debug(d);
    });
    
    pb.stderr.on('data', (data) => {
      const d = data.toString('utf8');
      result.stderr += d;
      process.stderr.write(d);
      // debug('Error: ' + d);
    });

    pb.on('error', (err) => {
      // debug('Error: ' + err);
      process.stderr.write('Error: ' + err);
      result.error = err;

      process.stdout.write(`<<<<<<<<<<<<<<<<<<<<<<<<< playbook ${playbook} exit with error <<<<<<<<<<<<<<<<<<<<<<<<<`);
      reject(result);
    });
    
    pb.on('close', (code) => {
      result.code = 0;
      debug(`Playbook ${playbook} exits with code ${code}`);
      process.stdout.write(`<<<<<<<<<<<<<<<<<<<<<<<<< playbook ${playbook} exit with code ${code} <<<<<<<<<<<<<<<<<<<<<<<<<`);

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
  checkMandatoryEnvironmentVariables,
  calculateHash,
  copySanityTestReport,
  runAnsiblePlaybook,
};
