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
  // FIXME: disable the customized runner to handle running test in parallel.
  //        The complexity is not just running multiple tests in different sub-
  //        processes, but also how can we separate the test reports and merge
  //        them later.
  // runner: "./dist/worker-group-runner.js",
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
