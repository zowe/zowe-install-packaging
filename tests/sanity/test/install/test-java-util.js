/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const sshHelper = require('./ssh-helper');

describe('verify java-utils', function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  let start_path, start_java_home;
  before('get required parameters', async function() {
    start_path = await sshHelper.executeCommandWithNoError('echo $PATH');
    start_java_home = await sshHelper.executeCommandWithNoError('echo $JAVA_HOME');
  });

  const ensure_java_is_on_path = 'ensure_java_is_on_path';
  describe(`verify ${ensure_java_is_on_path}`, function() {

    it('test java added to path if required', async function() {
      const java_home = '/junk_path1/java';
      await test_java_added_to_path(java_home, true);
    });

    it('test java added to path if bin missing', async function() {
      const path_pre_addition = '/junk_path2/java';
      const java_home = '/junk_path2/java';
      await test_java_added_to_path(java_home, true, path_pre_addition);
    });

    it('test java not added to path if already there', async function() {
      const path_pre_addition = '/junk_path3/java/bin';
      const java_home = '/junk_path3/java';
      await test_java_added_to_path(java_home, false, path_pre_addition);
    });

    async function test_java_added_to_path(java_home, expected_addition, path_pre_addition = '') {
      let command = path_pre_addition === '' ? '' : `export PATH=$PATH:${path_pre_addition} && `;
      command += `export JAVA_HOME=${java_home} && ${ensure_java_is_on_path}`;
      const expected_out = expected_addition ? 'Appending JAVA_HOME/bin to the PATH...' : '';
      await test_java_utils_function_has_expected_rc_stdout_stderr(command, 0, expected_out, '');
    }
  });

  const validate_java_home = 'validate_java_home';
  describe(`verify ${validate_java_home}`, function() {

    it('test empty java home throws error', async function() {
      const java_home = '';
      await test_validate_java_home(java_home, 1, '', 'JAVA_HOME is empty');
    });

    it('test junk java home throws error', async function() {
      const java_home = '/junk/';
      await test_validate_java_home(java_home, 1, '', `JAVA_HOME: ${java_home}/bin does not point to a valid install of Java`);
    });

    describe('java -version error caught with dummy java', async function() {
      const rc = 13;
      const error = 'This is not a real java version';
      let temp_dir, java_home;
      before('create dummy java', async function() {
        temp_dir = '~/delete_1234';
        java_home = `${temp_dir}/java`;
        await sshHelper.executeCommandWithNoError(`mkdir -p ${java_home}/bin && echo "echo ${error} 1>&2\nexit ${rc}" > ${java_home}/bin/java && chmod u+x ${java_home}/bin/java`);
      });
  
      after('dispose dummy java', async function() {
        await sshHelper.executeCommandWithNoError(`rm -rf ${temp_dir}`);
      });
  
      it('test java home with incorrect bin/java throws error', async function() {
        const expected_err = `Java version check failed with return code: ${rc}, error: ${error}`;
        await test_validate_java_home(java_home, 1, expected_err, expected_err);
      });
    });

    async function test_validate_java_home(java_home, expected_rc, expected_stdout, expected_stderr) {
      const command = `export JAVA_HOME=${java_home} && ${validate_java_home}`;
      await test_java_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr);
    }
  });

  const check_java_version = 'check_java_version';
  describe(`verify ${check_java_version}`, function() {

    it('test 6.0 fails', async function() {
      const java_version_string = 'java version "1.6.0"';
      await test_java_version(java_version_string, '1.6.0', false);
    });

    it('test 7.0 fails', async function() {
      const java_version_string = 'java version "1.7.0"';
      await test_java_version(java_version_string, '1.7.0', false);
    });

    it('test Java 8.0 passes', async function() {
      const java_version_string = 'java version "1.8.0_231"';
      await test_java_version(java_version_string, '1.8.0_231', true);
    });
  
    async function test_java_version(version_output, expected_version, expected_valid) {
      const command = `${check_java_version} "${version_output}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_out = expected_valid ? `Java version ${expected_version} is supported` : '';
      const expected_err = expected_valid ? '' : `Java Version ${expected_version} is less than the minimum level required of Java 8 (1.8.0)`;
      await test_java_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_out, expected_err);
    }
  });

  async function test_java_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    const java_utils_path = process.env.ZOWE_ROOT_DIR + '/bin/utils/java-utils.sh';
    command = `export ZOWE_ROOT_DIR=${process.env.ZOWE_ROOT_DIR} && . ${java_utils_path} && ${command}`;
    // Whilst printErrorMessage outputs to STDERR and STDOUT we need to expect the err in both
    if (expected_stderr != '') {
      expected_stdout = expected_stderr;
    }
    await sshHelper.testCommand(command, expected_rc, expected_stdout, expected_stderr);
  }

  after('restore env', async function() {
    await sshHelper.executeCommandWithNoError(`export PATH=${start_path}`);
    await sshHelper.executeCommandWithNoError(`export JAVA_HOME=${start_java_home}`);
  });

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
