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

const install_iframe_script='zowe-install-iframe-plugin.sh';
const install_iframe_path = `${process.env.ZOWE_ROOT_DIR}/bin/utils/${install_iframe_script}`;
describe(`verify ${install_iframe_script}`, function() {
  before('prepare SSH connection', async function() {
    await sshHelper.prepareConnection();
  });

  describe('validate that input is processed correctly', function() {

    const id = 'org.zowe.plugin.example';
    const short_name = 'Example plugin';
    const directory = '/zowe/component/plugin';
    const url = 'https://zowe.org:443/about-us/';
    const tile_image = '/zowe_plugin/artifacts/tile_image.png';

    it('test legacy mode still works and defaults version to 1.0.0', async function() {
      const parameters = `"${id}" "${short_name}" "${url}" "${directory}" "${tile_image}"`;
      const expected = get_expected_output(id, short_name, url, directory, tile_image);
      await test_install_iframe_has_expected_rc_stdout_stderr(parameters, 4, expected);
    });

    it('test no parameters prints usage correctly', async function() {
      const parameters = '';
      const expected = missing_parameters_message(['i','s','u','d','t']);
      await test_install_iframe_has_expected_rc_stdout_stderr(parameters, 1, expected);
    });

    it('test missing id prints error and usage correctly', async function() {
      const parameters = `-s "${short_name}" -u "${url}" -d "${directory}" -t "${tile_image}"`;
      const expected = missing_parameters_message(['i']);
      await test_install_iframe_has_expected_rc_stdout_stderr(parameters, 1, expected);
    });

    const getopts_parameters = `-i "${id}" -s "${short_name}" -u "${url}" -d "${directory}" -t "${tile_image}"`;
    it('test getopts mode works and defaults version to 1.0.0', async function() {
      const expected = get_expected_output(id, short_name, url, directory, tile_image);
      await test_install_iframe_has_expected_rc_stdout_stderr(getopts_parameters, 4, expected);
    });

    it('test getopts mode works with specified version', async function() {
      const version = '3.1.4';
      const parameters_with_version = `${getopts_parameters} -v ${version}`;
      const expected = get_expected_output(id, short_name, url, directory, tile_image, version);
      await test_install_iframe_has_expected_rc_stdout_stderr(parameters_with_version, 4, expected);
    });

    function missing_parameters_message(missing_parms) {
      const missing_parameters = missing_parms.map(function (flag) {
        return `-${flag}`;
      }).join(' ');

      return `Some required parameters were not supplied: ${missing_parameters}
Usage: ${install_iframe_path} -i <plugin_id> -s <plugin_short_name> -u <url> -d <plugin_directory> -t <tile_image_path> [-v <plugin_version>]
  eg. ${install_iframe_path} -i "org.zowe.plugin.example" -s "Example plugin" -u "https://zowe.org:443/about-us/" -d "/zowe/component/plugin" -t "/zowe_plugin/artifacts/tile_image.png" -v "1.0.0"`;
    }

    function get_expected_output(id, short_name, url, directory, tile_image, version = '1.0.0') {
      return `i:${id} s:"${short_name}" u:${url} d:${directory} t:${tile_image} v:[${version}]`;
    }
  });
  
  async function test_install_iframe_has_expected_rc_stdout_stderr(parameters, expected_rc, expected_stdout) {
    await sshHelper.testCommand(`${install_iframe_path} -z ${parameters}`, expected_rc, expected_stdout, '',  true);
  }

  after('dispose SSH connection', function() {
    sshHelper.cleanUpConnection();
  });
});
