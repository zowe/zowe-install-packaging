// This script checks that the manifest sourceDependencies are reachable.

const core = require('@actions/core');
const fs = require('fs-extra');

const results = {
  success: 'found_matching_tag',
  warn: 'found_matching_branch',
  fail: 'no_matching_tag_or_branch'
}


function isRcOrMaster(branchName) {
  return /v[0-9]\.x\/(rc|master)/i.test(branchName);
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

  const github = require('@actions/github')
  const octokit = github.getOctokit(process.env['GITHUB_TOKEN']);

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
    
      const isCommit = await octokit.rest.repos.getCommit({
        owner: 'zowe',
        repo: repo,
        ref: tag
      }).then((resp) => {
        if (resp.status < 400) {
          return true;
        }
        return false;
      })

      // Pinning repos with a commit is ok
      if (isCommit) {
        analyzedRepos.push({repository: repo, tag: tag, result: results.success});
        continue;
      }

      // If not a commit, check repo tags
      const tags = await octokit.rest.repos.listTags({
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
      // 2 REST Requests, unset protected was operating as protected=false
      const protBranches = await octokit.rest.repos.listBranches({
        owner: 'zowe',
        repo: repo,
        protected: true
      }).then((resp) => {
        if (resp.status < 400) {
          return resp.data;
        }
        return [];
      })
      const unProtBranches = await octokit.rest.repos.listBranches({
        owner: 'zowe',
        repo: repo,
        protected: false
      }).then((resp) => {
        if (resp.status < 400) {
          return resp.data;
        }
        return [];
      })

      const branches = [...protBranches, ...unProtBranches];

      const knownBranch = branches.find((item) => item.name === tag);
      if (knownBranch != null && knownBranch.name.trim().length > 0) {
        analyzedRepos.push({repository: repo, tag: tag, result: results.warn});
        continue;
      }

      // if we didn't find commit, tag or branch
      analyzedRepos.push({repository: repo, tag: tag, result: results.fail});
    }
  }

  let didFail = false;

  const failRepos = analyzedRepos.filter((item) => item.result === results.fail);
  if (failRepos != null && failRepos.length > 0) {
    core.warning('There are manifest sourceDependencies without a matching tag or branch. Review the output and update the manifest.');
    core.warning('The following repositories do not have a matching commit hash, tag or branch: ' + JSON.stringify(failRepos, null, {indent: 4}))
    didFail = true;
  }

  const warnRepos = analyzedRepos.filter((item) => item.result === results.warn) ;
  if (warnRepos != null && warnRepos.length > 0) { 
    if (isRcOrMaster(baseRef)) {
      core.warning('Merges to RC and master require tags or commit hashes instead of branches for sourceDependencies.')
      didFail = true
    }
    core.warning('The following repositories have a branch instead of tag: ' + JSON.stringify(warnRepos, null, {indent: 4}))
  }

  if (didFail) {
    core.setFailed('The manifest validation was not successful. Review the warning output for more details.');
  }

}
main()
