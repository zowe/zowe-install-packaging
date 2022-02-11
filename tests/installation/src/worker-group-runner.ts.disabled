/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

import type {Config} from '@jest/types';
import Worker from 'jest-worker';
import TestRunner from 'jest-runner' ;
import type {SerializableError} from '@jest/test-result';
import * as fs from 'fs';
import exit = require('exit');
import throat from 'throat';
import type TResult from 'throat';
import { parse as parseDocBlock } from 'jest-docblock';
import type {SerializableResolver, worker} from '../node_modules/jest-runner/build/testWorker';
import type {
  OnTestFailure as JestOnTestFailure,
  OnTestStart as JestOnTestStart,
  OnTestSuccess as JestOnTestSuccess,
  Test as JestTest,
  TestRunnerContext as JestTestRunnerContext,
  TestRunnerOptions as JestTestRunnerOptions,
  TestWatcher as JestTestWatcher,
  WatcherState,
} from '../node_modules/jest-runner/build/types';

const DEFAULT_WORKER_ENVVAR = 'TEST_SERVER';
const DEFAULT_WORKER_NAME = '__default__';

const TEST_WORKER_PATH = require.resolve('../node_modules/jest-runner/build/testWorker');

interface WorkerInterface extends Worker {
  worker: typeof worker;
}

class CancelRun extends Error {
  constructor(message?: string) {
    super(message);
    this.name = 'CancelRun';
  }
}

type TestWorkerConfig = {
  workerName: string;
  workerIndex: number;
};


class WorkerGroupRunner extends TestRunner {
  private _uniqueWorkerNames: string[];
  // these properties are defined as private, but we need here
  private _globalConfigWGR: Config.GlobalConfig;
  private _contextWGR: JestTestRunnerContext;

  constructor(
    globalConfig: Config.GlobalConfig,
    context?: JestTestRunnerContext,
  ) {
    super(globalConfig, context);

    this._globalConfigWGR = globalConfig;
    this._contextWGR = context || {};
  }

  _findWorkers(tests: Array<JestTest>): Map<string, TestWorkerConfig> {
    const workersMap: Map<string, TestWorkerConfig> = new Map();
    this._uniqueWorkerNames = [];
    const defaultWorker: string = process.env[DEFAULT_WORKER_ENVVAR] || DEFAULT_WORKER_NAME;

    for (const test of tests) {
      const twc: TestWorkerConfig = {} as TestWorkerConfig;

      const parsedDoc = parseDocBlock( fs.readFileSync( test.path, 'utf8' ) );
      const desiredWorker = (parsedDoc.worker && parsedDoc.worker.toString()) || defaultWorker;
      twc.workerName = desiredWorker;
      
      const exitWorkerName: number = this._uniqueWorkerNames.indexOf(desiredWorker);
      if (exitWorkerName > -1) {
        twc.workerIndex = exitWorkerName;
      } else {
        this._uniqueWorkerNames.push(desiredWorker);
        twc.workerIndex = this._uniqueWorkerNames.length - 1;
      }

      workersMap.set(test.path, twc);
    }

    return workersMap;
  }

  async runTests(
    tests: Array<JestTest>,
    watcher: JestTestWatcher,
    onStart: JestOnTestStart,
    onResult: JestOnTestSuccess,
    onFailure: JestOnTestFailure,
    options: JestTestRunnerOptions,
  ): Promise<void> {
    // always try to run in parallel
    options.serial = false;

    // NOTE: below code are mainly copied from jest-runner _createParallelTestRun
    // The purpose of the changes are initialize number of workers based on
    // @worker annotation defined in test suite.
    // Test cases with same @worker will run sequentially in SAME worker instead
    // of running parallel in random workers.

    const workersMap: Map<string, TestWorkerConfig> = this._findWorkers(tests);
    // console.log('workersMap:', workersMap);

    const resolvers: Map<string, SerializableResolver> = new Map();
    for (const test of tests) {
      if (!resolvers.has(test.context.config.name)) {
        resolvers.set(test.context.config.name, {
          config: test.context.config,
          serializableModuleMap: test.context.moduleMap.toJSON(),
        });
      }
    }

    const worker = new Worker(TEST_WORKER_PATH, {
      exposedMethods: ['worker'],
      forkOptions: {stdio: 'pipe'},
      maxRetries: 3,
      numWorkers: this._uniqueWorkerNames.length,
      setupArgs: [
        {
          serializableResolvers: Array.from(resolvers.values()),
        },
      ],
      computeWorkerKey: (method: string, ...args: Array<any>): string|null => {
        // console.log('???computeWorkerKey???', method, args[0].path);
        const testConfig = args[0];
        if (testConfig && testConfig.path && workersMap.has(testConfig.path)) {
          // console.log('!!!computeWorkerKey!!!', workersMap.get(testConfig.path).workerIndex);
          return String(workersMap.get(testConfig.path).workerIndex + 1);
        }
      },
    }) as WorkerInterface;

    if (worker.getStdout()) worker.getStdout().pipe(process.stdout);
    if (worker.getStderr()) worker.getStderr().pipe(process.stderr);

    // define mutex for each worker thread
    const mutexes: any[] = []; 
    this._uniqueWorkerNames.forEach(() => {
      // inside each worker, we run tests in sequence
      mutexes.push(throat(1));
    });

    // Send test suites to workers continuously instead of all at once to track
    // the start time of individual tests.
    const runTestInWorker = (test: JestTest) => {
      if (!workersMap.has(test.path)) {
        throw new Error('Unknown test: ' + test.path);
      }
      const testWorkerConfig: TestWorkerConfig = workersMap.get(test.path);
      const testWorkerIndex: number = testWorkerConfig.workerIndex;
      return mutexes[testWorkerIndex](async () => {
        if (watcher.isInterrupted()) {
          return Promise.reject();
        }

        await onStart(test);

        return worker.worker({
          config: test.context.config,
          context: {
            ...this._contextWGR,
            changedFiles:
              this._contextWGR.changedFiles &&
              Array.from(this._contextWGR.changedFiles),
          },
          globalConfig: this._globalConfigWGR,
          path: test.path,
        });
      });
    };

    const onError = async (err: SerializableError, test: JestTest) => {
      await onFailure(test, err);
      if (err.type === 'ProcessTerminatedError') {
        console.error(
          'A worker process has quit unexpectedly! ' +
            'Most likely this is an initialization error.',
        );
        exit(1);
      }
    };

    const onInterrupt = new Promise((_, reject) => {
      watcher.on('change', (state: WatcherState) => {
        if (state.interrupted) {
          reject(new CancelRun());
        }
      });
    });

    const runAllTests = Promise.all(
      tests.map(test =>
        runTestInWorker(test)
          .then((testResult: any) => onResult(test, testResult))
          .catch((error: any) => onError(error, test)),
      ),
    );

    const cleanup = async () => {
      const {forceExited} = await worker.end();
      if (forceExited) {
        console.log(
          'A worker process has failed to exit gracefully and has been force exited. ' +
            'This is likely caused by tests leaking due to improper teardown. ' +
            'Try running with --runInBand --detectOpenHandles to find leaks.',
        );
      }
    };
    return Promise.race([runAllTests, onInterrupt]).then(cleanup, cleanup);

    // return super.runTests(
    //   tests,
    //   watcher,
    //   onStart,
    //   onResult,
    //   onFailure,
    //   options
    // );
  }
}

export = WorkerGroupRunner;
