/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as yaml from 'yaml';
import { THIS_TEST_BASE_YAML } from './TestConfig';
import * as fs from 'fs-extra';
import ZoweYamlType from '../types/ZoweYamlType';

export class ZoweYaml {
  /* public updateField(field: string, value: string) {
    // this.zoweYaml[field] = value;
  }*/

  /**
   * This functions reads the template zowe.yaml created in {@link ../globalSetup.ts}
   * and coerces it to a JSON Object.
   *
   * @returns ZoweYaml JSON Object
   */
  static basicZoweYaml(): ZoweYamlType {
    const fileContents = fs.readFileSync(THIS_TEST_BASE_YAML, 'utf8');
    const zoweYaml = yaml.parse(fileContents);
    return zoweYaml as ZoweYamlType;
  }
}
