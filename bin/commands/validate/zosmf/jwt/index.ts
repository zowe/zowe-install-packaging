/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html

  SPDX-License-Identifier: EPL-2.0

  Copyright Contributors to the Zowe Project.
*/

import * as std from 'cm_std';
import * as common from '../../../../libs/common';
import * as config from '../../../../libs/config';
import * as java from '../../../../libs/java';
import * as shell from '../../../../libs/shell';

const COMMAND_NAME = 'zwe-validate-zosmf-jwt';

export function execute(quitOnError?: boolean): number {
  common.requireZoweYaml();
  const ZOWE_CONFIG = config.getZoweConfig();

  // Verify that zosmf.host and zosmf.port are configured.
  const zosmfHost = ZOWE_CONFIG.zOSMF?.host;
  const zosmfPort = ZOWE_CONFIG.zOSMF?.port;
  if (!zosmfHost || !zosmfPort) {
    const msg = `ZWEL0359E: z/OSMF host (zosmf.host) or port (zosmf.port) is not configured in the Zowe YAML.` +
      ` Cannot validate z/OSMF JWT support without a z/OSMF destination.`;
    if (quitOnError) {
      common.printErrorAndExit(msg, undefined, 359);
    } else {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, msg);
    }
    return 359;
  }

  // Verify that at least one of the required APIML servers is enabled.
  const discoveryEnabled = ZOWE_CONFIG.components?.discovery?.enabled === true;
  const apimlEnabled = ZOWE_CONFIG.components?.apiml?.enabled === true;
  if (!discoveryEnabled && !apimlEnabled) {
    const msg = `ZWEL0360E: Neither components.discovery.enabled nor components.apiml.enabled is set to true.` +
      ` The required APIML servers are not enabled for z/OSMF access.`;
    if (quitOnError) {
      common.printErrorAndExit(msg, undefined, 360);
    } else {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, msg);
    }
    return 360;
  }

  // Check whether the gateway is configured to use z/OSMF as the authentication provider.
  const authProvider = ZOWE_CONFIG.components?.gateway?.apiml?.security?.auth?.provider;
  if (!authProvider || authProvider.toLowerCase() !== 'zosmf') {
    common.printFormattedInfo(
      common.MSG_KEY,
      COMMAND_NAME,
      `Zowe is not configured to use z/OSMF as the authentication provider` +
        ` (components.gateway.apiml.security.auth.provider=${authProvider || '<not set>'}).` +
        ` No z/OSMF JWT check is required.`
    );
    return 0;
  }

  // Determine the jwtAutoconfiguration value to understand what mode we are in.
  const jwtAutoconfigRaw = ZOWE_CONFIG.components?.gateway?.apiml?.security?.auth?.zosmf?.jwtAutoconfiguration || '';
  const jwtAutoconfig = jwtAutoconfigRaw.toLowerCase();

  // Ensure java is available before invoking the jar.
  java.requireJava();
  const javaHome = std.getenv('JAVA_HOME');
  const javaExec = `${javaHome}/bin/java`;

  const runtimeDir = std.getenv('ZWE_zowe_runtimeDirectory');
  const jarPath = `${runtimeDir}/bin/utils/zosmf-jwt-check.jar`;

  // Collect truststore parameters from the Zowe YAML.
  const verifyCertificates = ZOWE_CONFIG.zowe?.verifyCertificates || 'STRICT';
  const truststoreType = ZOWE_CONFIG.zowe?.certificate?.truststore?.type || '';
  const truststoreFile = ZOWE_CONFIG.zowe?.certificate?.truststore?.file || '';
  const truststorePassword = ZOWE_CONFIG.zowe?.certificate?.truststore?.password || '';

  common.printFormattedInfo(
    common.MSG_KEY,
    COMMAND_NAME,
    `Running z/OSMF JWT check for ${zosmfHost}:${zosmfPort} (jwtAutoconfiguration=${jwtAutoconfigRaw || '<not set>'})`
  );

  const result = shell.execOutErrSync(
    javaExec,
    '-Djava.protocol.handler.pkgs=com.ibm.crypto.provider',
    '-jar', jarPath,
    '--zosmf-host', zosmfHost,
    '--zosmf-port', String(zosmfPort),
    '--verify-certificates', verifyCertificates,
    '--truststore-type', truststoreType,
    '--truststore-file', truststoreFile,
    '--truststore-password', truststorePassword
  );

  if (result.rc !== 0) {
    if (jwtAutoconfig === 'ltpa') {
      // LTPA mode does not require z/OSMF JWT support - treat as a warning only.
      common.printFormattedWarn(
        common.MSG_KEY,
        COMMAND_NAME,
        `ZWEL0361W: z/OSMF JWT check failed (rc=${result.rc}) but jwtAutoconfiguration is 'ltpa',` +
          ` so JWT support is not required for this Zowe configuration.` +
          ` z/OSMF JWT support may not be available.`
      );
      if (result.out) {
        common.printDebug(result.out);
      }
      if (result.err) {
        common.printDebug(result.err);
      }
      return 0;
    }

    // JWT mode requires z/OSMF JWT support - this is an error.
    const jarOutput = [result.out, result.err].filter(Boolean).join('\n');
    const errorMsg =
      `ZWEL0362E: z/OSMF JWT check failed (rc=${result.rc}).` +
      ` Zowe requires z/OSMF JWT support (jwtAutoconfiguration is '${jwtAutoconfigRaw}') but it is not working.\n` +
      `\nJar output:\n${jarOutput}\n` +
      `\nZowe YAML parameters that led to this result:` +
      `\n  zosmf.host=${zosmfHost}` +
      `\n  zosmf.port=${zosmfPort}` +
      `\n  zowe.verifyCertificates=${verifyCertificates}` +
      `\n  zowe.certificate.truststore.type=${truststoreType}` +
      `\n  zowe.certificate.truststore.file=${truststoreFile}` +
      `\n  zowe.certificate.truststore.password=<redacted>` +
      `\n  components.gateway.apiml.security.auth.provider=${authProvider}` +
      `\n  components.gateway.apiml.security.auth.zosmf.jwtAutoconfiguration=${jwtAutoconfigRaw || '<not set>'}` +
      `\n\nTo resolve this issue:` +
      `\n  Verify that z/OSMF has been configured for JWT support by reviewing:` +
      `\n    https://www.ibm.com/docs/en/zos/3.2.0?topic=configurations-enabling-json-web-token-support` +
      `\n  Also check the z/OSMF joblog for further diagnostic information.` +
      `\n\nIf you do not wish to use z/OSMF JWT support, you can instead change:` +
      `\n  components.gateway.apiml.security.auth.zosmf.jwtAutoconfiguration to 'ltpa'` +
      `\n\nIf you believe this validate command is incorrect, you can set it to a warning or disable it:` +
      `\n  zowe.launchScript.startupChecks.zosmfjwt: warn    (report as warning, continue startup)` +
      `\n  zowe.launchScript.startupChecks.zosmfjwt: disabled (skip this check entirely)`;

    if (quitOnError) {
      common.printErrorAndExit(errorMsg, undefined, 362);
    } else {
      common.printFormattedError(common.MSG_KEY, COMMAND_NAME, errorMsg);
    }
    return result.rc;
  }

  common.printFormattedInfo(
    common.MSG_KEY,
    COMMAND_NAME,
    `z/OSMF JWT check passed. z/OSMF at ${zosmfHost}:${zosmfPort} supports JWT.`
  );
  return 0;
}
