/*
  This program and the accompanying materials are made available
  under the terms of the Eclipse Public License v2.0 which
  accompanies this distribution, and is available at
  https://www.eclipse.org/legal/epl-v20.html
 
  SPDX-License-Identifier: EPL-2.0
 
  Copyright Contributors to the Zowe Project.
*/

import * as std from 'std';
import * as common from '../../../../../libs/common';
import * as fs from '../../../../../libs/fs';
import * as java from '../../../../../libs/java';
import * as shell from '../../../../../libs/shell';
import * as config from '../../../../../libs/config';
import * as certificatelib from '../../../../../libs/certificate';

export function execute(properties: {keystoreDir: string, alias: string, password: string, commonName: string, orgUnit: string, org: string, locality: string, state: string, Country: string, validity: number}, allowOverwrite: boolean) {
  common.printLevel1Message(`Creating certificate authority "${properties.alias}"`);

  // validation
  java.requireJava();

  // check existence
  const keystore=`${properties.keystoreDir}/${properties.alias}/${properties.alias}.keystore.p12`;
  if (fs.fileExists(keystore)) {
    if (allowOverwrite) {
      // warning
      common.printMessage(`Warning ZWEL0300W: Keystore "${keystore}" already exists. This keystore will be overwritten during configuration.`);
      fs.rmrf(`${properties.keystoreDir}/${properties.alias}`);
    } else {
      // error
      common.printErrorAndExit(`Error ZWEL0158E: Keystore "${keystore}" already exists.`, undefined, 158);
    }
  }

  // create CA
  const rc = certificatelib.pkcs12CreateCertificateAuthority.execute(properties);
  if (rc != 0) {
    common.printErrorAndExit(`Error ZWEL0168E: Failed to create certificate authority "${alias}".`, undefined, 168);
  }

  common.printLevel2Message(`Certificate authority ${alias} is created successfully.`);
}
