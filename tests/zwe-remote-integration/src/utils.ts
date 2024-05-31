/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */

import * as util from 'util';
import * as crypto from 'crypto';
import * as path from 'path';
import * as semver from 'semver';

export function findDirWalkingUpOrThrow(dirName: string) {
  let tries = 10; // max walk-back of 10 directories
  let currPath = path.resolve(__dirname);
  while (tries > 0) {
    if (path.basename(currPath) === dirName) {
      return currPath;
    }
    currPath = path.resolve(currPath, '..');
    tries--;
  }
  throw new Error(`could not find path ${dirName}`);
}

/**
 * Sleep for certain time
 * @param {Integer} ms
 */
export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

/**
 * Generate MD5 hash of a variable
 *
 * @param {Any} obj        any object
 */
export function calculateHash(obj: unknown): string {
  return crypto.createHash('md5').update(util.format('%j', obj)).digest('hex');
}

export function processManifestVersion(version: string, repository: string = undefined): DownloadSpec {
  /* Lifted from zowe-actions */
  const REPOSITORY_SNAPSHOT = 'libs-snapshot-local';
  const REPOSITORY_RELEASE = 'libs-release-local';
  let repoOut = repository;
  let versionOut = '';
  const m1 = version.match(/^~([0-9]+)\.([0-9]+)\.([0-9]+)(-.+)?$/);
  const m2 = version.match(/^\^([0-9]+)\.([0-9]+)\.([0-9]+)(-.+)?$/);
  if (m1) {
    if (repoOut == null) {
      repoOut = m1[4] ? REPOSITORY_SNAPSHOT : REPOSITORY_RELEASE;
    }
    versionOut = `${m1[1]}.${m1[2]}.*${m1[4] ? m1[4] : ''}`;
  } else if (m2) {
    if (repoOut == null) {
      repoOut = m2[4] ? REPOSITORY_SNAPSHOT : REPOSITORY_RELEASE;
    }
    versionOut = `${m2[1]}.*${m2[4] ? m2[4] : ''}`;
  } else {
    // parse semantic version, this may throw exception if version is invalid
    if (semver.prerelease(version)) {
      repoOut = `${repository ? repository : REPOSITORY_SNAPSHOT}`;
      versionOut = `${semver.major(version)}.${semver.minor(version)}.${semver.patch(version)}-${semver.prerelease(version)}/`;
    } else {
      // this is formal release
      repoOut = `${repository ? repository : REPOSITORY_RELEASE}`;
      versionOut = `${version}`;
    }
  }
  return {
    repository: repoOut,
    versionPattern: versionOut,
  };
}

export type DownloadSpec = {
  repository: string;
  versionPattern: string;
};
