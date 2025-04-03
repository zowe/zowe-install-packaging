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
import { REMOTE_SYSTEM_INFO, THIS_TEST_BASE_DEFAULTS_YAML, THIS_TEST_BASE_ZOWE_YAML } from './TestConfig';
import * as fs from 'fs-extra';
import ZoweYamlType from './ZoweYamlType';
import _ from 'lodash';
import path from 'path';
import Mustache from 'mustache';

export class ZoweConfig {
  /* public updateField(field: string, value: string) {
    // this.zoweYaml[field] = value;
  }*/

  /**
   * This functions reads the template zowe.yaml created in {@link ../globalSetup.ts}
   * and coerces it to a JSON Object.
   *
   * @returns ZoweYaml JSON Object
   */

  static getZoweYaml(): ZoweYamlType {
    const fileContents = fs.readFileSync(THIS_TEST_BASE_ZOWE_YAML, 'utf8');
    const zoweYaml = yaml.parse(fileContents);
    return zoweYaml as ZoweYamlType;
  }

  static getDefaultsYaml(): ZoweYamlType {
    const fileContents = fs.readFileSync(THIS_TEST_BASE_DEFAULTS_YAML, 'utf8');
    const defaultsYaml = yaml.parse(fileContents);
    return defaultsYaml as ZoweYamlType;
  }

  /**
   * Loads a YAML resource from the specified directory and optionally renders it.
   *
   * @param {string} resourceDir - The directory where the YAML resource is located.
   * @param {string} yamlFile - The name of the YAML file.
   * @param {boolean} [render=true] - Whether to render the YAML content. Defaults to true.
   * @return {ZoweYamlType} The parsed YAML content.
   */
  static loadZoweYaml(resourceDir: string, yamlFile: string, render: boolean = true): ZoweYamlType {
    let yamlContent = fs.readFileSync(path.join(resourceDir, yamlFile), 'utf8');
    if (render) {
      yamlContent = Mustache.render(yamlContent, REMOTE_SYSTEM_INFO, {}, ['{@', '@}']);
    }
    const zoweYaml = yaml.parse(yamlContent);
    return zoweYaml as ZoweYamlType;
  }

  static loadAndOverlay(base: ZoweYamlType, resourceDir: string, yamlName: string): ZoweYamlType {
    const overlayYaml = this.loadZoweYaml(resourceDir, yamlName);
    return this.overlayYaml(base, overlayYaml);
  }

  static overlayYaml(base: ZoweYamlType, overlay: unknown, moreOverlays?: unknown[]): ZoweYamlType {
    let combined = _.merge(base, overlay);
    if (moreOverlays && moreOverlays.length > 0) {
      combined = _.merge(combined, ...moreOverlays);
    }
    return combined;
  }
}
