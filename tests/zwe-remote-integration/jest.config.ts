/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import type { Config } from 'jest';

const config: Config = {
  // runner: "./dist/worker-group-runner.js",
  globalSetup: '<rootDir>/src/globalSetup.ts',
  globalTeardown: '<rootDir>/src/globalTeardown.ts',
  setupFilesAfterEnv: ['<rootDir>/src/jest-config.ts'],
  preset: 'ts-jest',
  modulePathIgnorePatterns: ['<rootDir>/.build'],
  testRegex: '__tests__.*\\.*?\\.(spec|test)\\.ts$',
  testEnvironmentOptions: {
    ZOWE_IMPERATIVE_LOG_LEVEL: 'OFF',
    ZOWE_APP_LOG_LEVEL: 'OFF',
  },
  // maxWorkers: 1,
  reporters: [
    'default',
    [
      'jest-junit',
      {
        suiteName: 'Zowe System Integration Test',
        outputDirectory: './reports',
        classNameTemplate: '{filepath}',
        titleTemplate: '{classname} - {title}',
      },
    ],
  ],
  testTimeout: 150000,
  transform: {
    '^.+\\.(t|j)sx?$': ['ts-jest', { isolatedModules: true }],
  },
  fakeTimers: {},
  verbose: false,
  silent: false,
};

export default config;
