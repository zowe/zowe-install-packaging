// This script checks that the manifest sourceDependencies are reachable.

const core = require('@actions/core');
const fs = require('fs-extra');
const { Octokit } = require('@octokit/rest')

const results = {
  success: 'found_matching_tag',
  warn: 'found_matching_branch',
  fail: 'no_matching_tag_or_branch'
}


function isRcOrMaster(branchName) {
  return /v[0-9]\.x\-[rc|master]/i.test(branchName);
}

async function main() {

  if (process.env['BASE_REF'] == null) {
    core.setFailed('This script requires the BASE_REF env to bet set.');
    return;
  }

  if (process.env['GITHUB_TOKEN'] == null) {
    core.setFailed('This script requires the GITHUB_TOKEN env to be set.');
    return;
  }

  const baseRef = process.env['BASE_REF'].trim();

  const github = new Octokit({
    auth: process.env['GITHUB_TOKEN']
  });

  // expect script to be run from repo root
  const sourceDeps = fs.readJSONSync('./manifest.json.template').sourceDependencies;

  /**
   * Source dep structure is below:
   * 
   * [
   *   {
   *    "componentGroup": "Performance Timing Utility",
   *    "entries": [{
   *      "repository": "perf-timing",
   *      "tag": "master",
   *      "destinations": ["Zowe CLI Package"]
   *    }]
   *  },
   *  { ...same structure as prior...}
   * ]
   */

  const analyzedRepos = [];

  for (const dep of sourceDeps) {
    for (const entry of dep.entries) {
      const repo = entry.repository;
      const tag = entry.tag;

      const tags = await github.rest.repos.listTags({
        owner: 'zowe',
        repo: repo,
      }).then((resp) => {
        if (resp.status < 400) {
          return resp.data;
        }
        return [];
      })
      const knownTag = tags.find((item) => item.name === tag);
      if (knownTag != null && knownTag.name.trim().length > 0) {
        analyzedRepos.push({repository: repo, tag: tag, result: results.success});
        continue;
      }

      // if we didn't find tag, look at branches
      const branches = await github.rest.repos.listBranches({
        owner: 'zowe',
        repo: repo
      }).then((resp) => {
        if (resp.status < 400) {
          return resp.data;
        }
        return [];
      })

      const knownBranch = branches.find((item) => item.name === tag);
      if (knownBranch != null && knownBranch.name.trim().length > 0) {
        analyzedRepos.push({repository: repo, tag: tag, result: results.warn});
        continue;
      }

      // if we didn't find tag or branch
      analyzedRepos.push({repository: repo, tag: tag, result: results.fail});
    }
  }

  const failRepos = analyzedRepos.filter((item) => item.result === results.fail);
  if (failRepos != null && failRepos.length > 0) {
    core.warning('The following repositories do not have a matching tag or branch: ' + JSON.stringify(failRepos, null, {indent: 4}))
    core.setFailed('There are manifest sourceDependencies without a matching tag or branch. Review the output and update the manifest.')
    return;
  }

  const warnRepos = analyzedRepos.filter((item) => item.name === results.warn) ;
  if (warnRepos != null && warnRepos.length > 0) { 
    core.warning('The following repositories have a branch instead of tag: ' + JSON.stringify(warnRepos, null, {indent: 4}))
    if (isRcOrMaster(baseRef)) {
      core.setFailed('Merges to RC and master require tags instead of branches for sourceDependencies.');
      return;
    }
  }
}
main()
