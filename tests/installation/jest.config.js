/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

module.exports = {
  runner: "./dist/worker-group-runner.js",
  reporters: [
    "default",
    [
      "jest-junit",
      {
        suiteName: "Zowe Install Test",
        outputDirectory: "./reports",
        classNameTemplate: "{filepath}",
        titleTemplate: "{classname} - {title}",
      }
    ]
  ]
};
