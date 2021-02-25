/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const sshHelper = require('../ssh-helper');


describe('verify file-utils', function() {
  let TMP_DIR;
  const TMP_EXT_DIR = 'sanity_test_files_utils';
  const dummy_component_name = 'sanity_test_dummy';
  let component_runtime_dir;

  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  before('set up temporary directory', async function() {
    let tmpOnServer = await sshHelper.executeCommandWithNoError('echo "${TMPDIR}"');
    tmpOnServer = tmpOnServer && tmpOnServer.trim();
    if (!tmpOnServer) {
      tmpOnServer = await sshHelper.executeCommandWithNoError('echo "${TMP}"');
    }
    tmpOnServer = tmpOnServer && tmpOnServer.trim();
    TMP_DIR = tmpOnServer || '/tmp';
    component_runtime_dir = `${TMP_DIR}/${TMP_EXT_DIR}/${dummy_component_name}`;
  });

  let home_dir;
  before('get required parameters', async function() {
    home_dir = await sshHelper.executeCommandWithNoError('echo $HOME');
  });

  describe('verify get_full_path', function() {

    let curr_dir;
    // let parent_dir;
    before('get required parameters', async function() {
      curr_dir = await sshHelper.executeCommandWithNoError('echo $PWD');
      // parent_dir = await sshHelper.executeCommandWithNoError('echo $(cd ../;pwd)');
    });

    it('test home directory is expanded', async function() {
      const input = '~/test';
      const expected = home_dir + '/test';
      await test_get_full_path(input, expected);
    });

    it('test full path is not modified', async function() {
      const input = `${process.env.ZOWE_INSTANCE_DIR}/test123`;
      const expected = input;
      await test_get_full_path(input, expected);
    });

    it('test relative path is evaluated', async function() {
      const test_dir = 'test_dir123124';
      const input = `../${test_dir}`;
      const expected = `${curr_dir}/../${test_dir}`;// TODO - it would be evaluate to `${parent_dir}/${test_dir}`;
      await test_get_full_path(input, expected);
    });

    async function test_get_full_path(input, expected_stdout) {
      const command = `get_full_path "${input}"`;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, 0, expected_stdout, '');
    }
  });

  describe('validate_file_not_in_directory', function() {

    it('test file in directory not valid', async function() {
      const file = `${home_dir}/test`;
      const directory = home_dir;
      await test_validate_file_not_in_directory(file, directory, false);
    });

    it('test file in home directory expanded not valid', async function() {
      const file = '~/test';
      const directory = home_dir;
      await test_validate_file_not_in_directory(file, directory, false);
    });

    it('test siblings without trailing slash is valid', async function() {
      const file = '/home/zowe/instance';
      const directory = '/home/zowe/root';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    it('test siblings with trailing slash is valid', async function() {
      const file = '/home/zowe/instance';
      const directory = '/home/zowe/root/';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    it('test siblings with both trailing slash is valid', async function() {
      const file = '/home/zowe/instance/';
      const directory = '/home/zowe/root/';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    //TODO zip #1325 - until we can evaluate ../ this will fail
    it.skip('test relative sibling is valid', async function() {
      const file = '/home/zowe/root/../test';
      const directory = '/home/zowe/root/';
      await test_validate_file_not_in_directory(file, directory, true);
    });

    async function test_validate_file_not_in_directory(file, directory, expected_valid) {
      const command = `validate_file_not_in_directory "${file}" "${directory}"`;
      const expected_rc = expected_valid ? 0 : 1;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, '', '');
    }
  });

  const validate_file_is_accessible = 'validate_file_is_accessible';
  describe(`verify ${validate_file_is_accessible}`, function() {

    function get_inaccessible_message(file) {
      return `File '${file}' doesn't exist, or is not accessible to ${process.env.SSH_USER.toUpperCase()}. If the file exists, check all the parent directories have traversal permission (execute)`;
    }

    it('test start script is accessible', async function() {
      const file = `${process.env.ZOWE_INSTANCE_DIR}/bin/zowe-start.sh`;
      await test_validate_file_is_accessible(file, true);
    });

    it('test junk file is not accessible', async function() {
      const directory = '/junk/rubbish/madeup';
      await test_validate_file_is_accessible(directory, false);
    });

    async function test_validate_file_is_accessible(file, expected_valid) {
      const command = `${validate_file_is_accessible} "${file}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : get_inaccessible_message(file);
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_err, expected_err);
    }
  });

  describe('validate_directory_is_accessible and writable', function() {

    let temp_dir = 'temp_' + Math.floor(Math.random() * 10e6);
    let inaccessible_dir = `${temp_dir}/inaccessible`;
    before('set up test directory', async function() {
      await sshHelper.executeCommandWithNoError(`mkdir -p ${inaccessible_dir} && chmod a-wx ${temp_dir}`);
    });

    after('clean up test directory', async function() {
      await sshHelper.executeCommandWithNoError(`chmod 770 ${temp_dir} && rm -rf ${temp_dir}`);
    });

    function get_inaccessible_message(directory) {
      return `Directory '${directory}' doesn't exist, or is not accessible to ${process.env.SSH_USER.toUpperCase()}. If the directory exists, check all the parent directories have traversal permission (execute)`;
    }

    it('test home directory is accessible', async function() {
      const directory = home_dir;
      await test_validate_directory_is_accessible(directory, true);
    });

    it('test junk directory is not accessible', async function() {
      const directory = '/junk/rubbish/madeup';
      await test_validate_directory_is_accessible(directory, false);
    });

    // zip-1377 Marist seems to have elevated privileges be able to access non-traversable directories, so this fails
    it.skip('test non-traversable directory is not accessible', async function() {
      await test_validate_directory_is_accessible(inaccessible_dir, false);
    });

    async function test_validate_directory_is_accessible(directory, expected_valid) {
      const command = `validate_directory_is_accessible "${directory}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : get_inaccessible_message(directory);
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_err, expected_err);
    }

    const validate_directories_are_accessible = 'validate_directories_are_accessible';
    describe(`verify ${validate_directories_are_accessible}`, function() {
  
      it('test single accessible directory works', async function() {
        const input = [home_dir];
        await test_validate_directories_are_accessible(input, []);
      });
  
      it('test one accessible and one inaccessible directories gives a single error', async function() {
        const directory_list = [home_dir, '/junk/rubbish/madeup'];
        await test_validate_directories_are_accessible(directory_list, ['/junk/rubbish/madeup']);
      });
  
      it('test two inaccessible directories gives two errors', async function() {
        const directory_list = ['/junk/rubbish/madeup', '/junk/rubbish/madeup2'];
        await test_validate_directories_are_accessible(directory_list, directory_list);
      });
  
      async function test_validate_directories_are_accessible(directories_list, invalid_directories) {
        const command = `${validate_directories_are_accessible} "${directories_list.join()}"`;
        const expected_rc = invalid_directories.length;
        const error_list = invalid_directories.map((directory, index) => {
          return `Error ${index}: ${get_inaccessible_message(directory)}`;
        });
        const expected_err = error_list.join('\n');
        await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_err, expected_err);
      }
    });

    it('test home directory is writable', async function() {
      const directory = home_dir;
      await test_validate_directory_is_writable(directory, true);
    });

    it('test junk directory shows as not accessible on writable check', async function() {
      const directory = '/junk/rubbish/madeup';
      const command = `validate_directory_is_writable "${directory}"`;
      const expected_rc = 1;
      const expected_err = get_inaccessible_message(directory);
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_err, expected_err);
    });

    // zip-1377 Marist's ACF2 and TS id seems to have elevated privileges be able to write non-writable directories, so this fails
    it.skip('test non-writable directory is not writable', async function() {
      await test_validate_directory_is_writable(temp_dir, false);
    });

    async function test_validate_directory_is_writable(directory, expected_valid) {
      const command = `validate_directory_is_writable "${directory}"`;
      const expected_rc = expected_valid ? 0 : 1;
      const expected_err = expected_valid ? '' : `Directory '${directory}' does not have write access`;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_err, expected_err);
    }
  });

  const count_children_in_directory = 'count_children_in_directory';
  describe(`verify ${count_children_in_directory}`, function() {

    let temp_dir = 'temp_' + Math.floor(Math.random() * 10e6);
    let dir_with_no_children = `${temp_dir}/no_children`;
    let dir_with_1_child =  `${temp_dir}/has_child`;
    let dir_with_3_children =  `${temp_dir}/has_children`;
    before('set up test directory', async function() {
      await sshHelper.executeCommandWithNoError(`mkdir -p "${dir_with_no_children}" && mkdir -p "${dir_with_1_child}" && touch "${dir_with_1_child}/child" && mkdir -p "${dir_with_3_children}" && touch "${dir_with_3_children}/child1" && touch "${dir_with_3_children}/child2" && touch "${dir_with_3_children}/child3"`);
    });

    after('clean up test directory', async function() {
      await sshHelper.executeCommandWithNoError(`chmod 770 ${temp_dir} && rm -rf ${temp_dir}`);
    });

    it('test directory which doesn\'t exist has 0 children', async function() {
      await test_count_children_in_directory('/junk/rubbish/madeup', 0);
    });

    it('test directory with no children has 0 children', async function() {
      await test_count_children_in_directory(dir_with_no_children, 0);
    });

    it('test directory with a child has 1 children', async function() {
      await test_count_children_in_directory(dir_with_1_child, 1);
    });

    it('test directory with 3 children has 3 children', async function() {
      await test_count_children_in_directory(dir_with_3_children, 3);
    });

    async function test_count_children_in_directory(directory, expected_children) {
      const command = `${count_children_in_directory} "${directory}"`;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_children, '', '');
    }

    after('clean up test directory', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${temp_dir}`);
    });
  });

  const read_yaml = 'read_yaml';
  describe(`verify ${read_yaml}`, function() {

    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir}`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir}`);
    });

    it('test read component name', async function() {
      const component = 'api-catalog';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/manifest.yaml`;
      const key = '.name';
      await test_read_yaml(file, key, component);
    });

    it('test read non-existing entry in component manifest', async function() {
      const component = 'api-catalog';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/manifest.yaml`;
      const key = '.unexistingProperty';
      await test_read_yaml(file, key, null);
    });

    it('test read component manifest with incorrect key', async function() {
      const component = 'api-catalog';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/manifest.yaml`;
      const key = '.apimlServices.dynamic.serviceId';
      await test_read_yaml(file, key, null);
    });

    it('test read component manifest with correct key', async function() {
      const component = 'api-catalog';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/manifest.yaml`;
      const key = '.apimlServices.dynamic[].serviceId';
      await test_read_yaml(file, key, 'apicatalog');
    });

    it('test read component yaml template', async function() {
      const component = 'jobs-api';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/apiml-static-registration.yaml.template`;
      const key = '.services[].serviceId';
      await test_read_yaml(file, key, 'jobs');
    });

    it('test invalid yaml file', async function() {
      const invalid_yaml = 'invalid.yaml';
      await sshHelper.executeCommandWithNoError(`cd ${component_runtime_dir} && touch ${invalid_yaml} && chmod u+w ${invalid_yaml}`);
      await sshHelper.executeCommandWithNoError(`echo 'invalid: "invalid_value' >> ${component_runtime_dir}/${invalid_yaml}`);
      const file = `${component_runtime_dir}/${invalid_yaml}`;
      const key = '.invalid';
      const err_msg = 'Error: error reading input file: Missing closing "quote';
      await test_read_yaml(file, key, '', false, err_msg);
    });

    async function test_read_yaml(file, key, expected_output, expected_valid=true, expected_err='') {
      const command = `${read_yaml} "${file}" "${key}"`;
      const expected_rc = expected_valid ? 0 : 1;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_output, expected_err);
    }
  });

  //add invalid files (invalid yaml and json)
  const read_json = 'read_json';
  describe(`verify ${read_json}`, function() {
    
    before('create test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir} && mkdir -p ${component_runtime_dir}`);
    });

    after('dispose test component', async function() {
      await sshHelper.executeCommandWithNoError(`rm -rf ${component_runtime_dir}`);
    });

    const file_name = 'pluginDefinition.json';

    it('test read component\'s pluginDefinition identifier', async function() {
      const component = 'explorer-jes';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/${file_name}`;
      const key = '.identifier';
      await test_read_json(file, key, 'org.zowe.explorer-jes');
    });

    it('test read non-existing entry in pluginDefinition', async function() {
      const component = 'explorer-jes';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/${file_name}`;
      const key = '.unexistingProperty';
      await test_read_json(file, key, null);
    });

    it('test read pluginDefinition with correct key', async function() {
      const component = 'explorer-jes';
      const file = `${process.env.ZOWE_ROOT_DIR}/components/${component}/${file_name}`;
      const key = '.webContent.framework';
      await test_read_json(file, key, 'iframe');
    });

    it('test invalid json file', async function() {
      const invalid_json = 'invalid.json';
      await sshHelper.executeCommandWithNoError(`cd ${component_runtime_dir} && touch ${invalid_json} && chmod u+w ${invalid_json}`);
      await sshHelper.executeCommandWithNoError(`echo '{invalid: "invalid"}' >> ${component_runtime_dir}/${invalid_json}`);
      const file = `${component_runtime_dir}/${invalid_json}`;
      const key = '.invalid';
      const err_msg = 'Error: Unexpected token';
      await test_read_json(file, key, '', false, err_msg);
    });

    async function test_read_json(file, key, expected_output, expected_valid=true, expected_err='') {
      const command = `${read_json} "${file}" "${key}"`;
      const expected_rc = expected_valid ? 0 : 1;
      await test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_output, expected_err);
    }
  });
  
  async function test_file_utils_function_has_expected_rc_stdout_stderr(command, expected_rc, expected_stdout, expected_stderr) {
    await sshHelper.testCommand(command, {
      envs: {
        'ZOWE_ROOT_DIR': process.env.ZOWE_ROOT_DIR,
      },
      sources: [
        //process.env.ZOWE_ROOT_DIR + '/bin/utils/file-utils.sh',
        process.env.ZOWE_ROOT_DIR + '/bin/internal/prepare-environment.sh -c ' + process.env.ZOWE_INSTANCE_DIR + ' -r ' + process.env.ZOWE_ROOT_DIR,
      ]
    }, {
      rc: expected_rc,
      // Whilst printErrorMessage outputs to STDERR and STDOUT we need to expect the err in both
      stdout: expected_stdout,
      stderr: expected_stderr,
    });
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
