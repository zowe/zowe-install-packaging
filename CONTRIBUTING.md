# Contribution Guidelines
This document is a living summary of conventions and best practices for development within the zowe-install-packaging repository.

  - [SIGN ALL OF YOUR GIT COMMITS](#sign-all-of-your-git-commits)
  - [Understanding the Repository](#understanding-packages-and-plug-ins)
  - [Pull Requests](#pull-requests)
  - [General Guidelines](#general-guidelines)
  - [Changelog Update Guidelines](#changelog-update-guidelines)
  - [Code Guidelines](#code-guidelines)
  - [Versioning Guidelines](#versioning-guidelines)
  - [Build Process Guidelines](#build-process-guidelines)
  - [Documentation Guidelines](#documentation-guidelines)
  - [More Information](#more-information)

## SIGN ALL OF YOUR GIT COMMITS

Whenever you make a commit, it is required to be signed. If you do not, you will have to re-write the git history to get all commits signed before they can be merged, which can be quite a pain.

Use the "-s" or "--signoff" flags to sign a commit.

Example calls:
* `git commit -s -m "Adding a test file to new_branch"`
* `git commit --signoff -m "Adding a test file to new_branch"`

Why? Sign-off is a line at the end of the commit message which certifies who is the author of the commit. Its main purpose is to improve tracking of who did what, especially with patches.

Example commit in git history:

```
Add tests for the payment processor.

Signed-off-by: Humpty Dumpty <humpty.dumpty@example.com>
```

What to do if you forget to sign off on a commit?

To sign old commits: `git rebase --exec 'git commit --amend --no-edit --signoff' -i <commit-hash>`

where commit hash is one before your first commit in history

If you forget to signoff on a commit, you'll likely receive the following message:

"Commit message must be signed off with your user name and email.
To sign off your commit, add the -s flag to the git commit command."

## Understanding the Repository

The zowe-install-packaging repository contains multiple sub-projects written in different languages with different goals. To better understand the repository structure and intent behind each sub-project, visit the [repository overview](./docs/README.md).

## Pull Requests

Consider the following when you interact with pull requests:

- Pull request reviewers should be assigned to a member of the Zowe Systems Squad or a member of your Zowe component squad. See [points of contact](./README.md#point-of-contacts).
- Pull requests should remain open for at least 24 hours, or until close of business next business day (accounting for weekends and holidays).
- Anyone can comment on a pull request to request delay on merging or to get questions answered.
- Any exception to the above should be mentioned in the pull request, either in the pull description or as a comment.

## General Guidelines

The following list describes general conventions for contributing to zowe-install-packaging:

- Communicate frequently (before pull request) with cross-team member representatives (in informal & small meetings) for new design features.
- Before implementing new functionality, evaluate if existing packages or functions available already achieve intended functionality.
- Provide adequate logging to diagnose problems that happen at external customer sites.

## Changelog Update Guidelines

Add an entry to changelog.md for any PR that introduces a feature, enhancement, or fix that affects end users. Changes to certain files, such as Github Workflows, do not require a changelog update. The changelogs are compiled into Zowe Docs [Release Notes](https://docs.zowe.org/stable/getting-started/summaryofchanges.html) periodically.

**Each changelog entry must:**
- Describe the change and how it impacts end users.
- Include a relevant Issue # or Pull Request #.

The following is an example of the markdown that you should insert into the changelog above the last-released version:

```
## Recent Changes

- Document your changes here. [Issue# or PR#](link-to-issue-or-pr)
- Document another change here. [Issue# or PR#](link-to-issue-or-pr)
```

**Tips:**
- Start the sentence with a verb in past tense. For example "Added...", "Fixed...", "Improved...", "Enhanced...".
- Write from a user's perspective. Document why the change matters to the end user (what this feature allows them to do now). For example, "Added the validate-only mode of Zowe. This lets you check whether all the component validation checks of the Zowe installation pass without starting any of the components.".
- Use second person "you" instead of "users".

## Code Guidelines

Indent code with 2 spaces. This is also documented via `.editorconfig`, which can be used to automatically format the code if you use an [EditorConfig](https://editorconfig.org/) extension for your editor of choice.

As there are multiple languages in this repository, coding guidelines can only be stated in generalities for the entire repository. Above all, aim to make code readable and obvious rather than clever or succinct. Optimize for the maintainer of the future who is less familiar with your area of expertise.

## Versioning Guidelines

For information about adhering to our versioning scheme, see [our versioning strategy](./docs/dead_link-versioning.md).

## Build Process Guidelines

Use build tasks to enforce rules where possible.

## Documentation Guidelines

- For **all user-facing contributions** (i.e. HOLDDATA or `zwe` command-line changes), we recommend that you provide the following:

   - A Release Notes entry in [Zowe Docs site](https://github.com/zowe/docs-site) to announce your change to end users.
   - Documentation for how to use your feature, command, etc... Open an issue in [docs-site repository](https://github.com/zowe/docs-site) if you need assistance.

In addition to external documentation, please thoroughly comment your code for future developers.

## More Information
| For more information about ... | See: |
| ------------------------------ | ----- |
| Branch Strategy | [Documentation](./docs/README.md#branch-strategy) |
| Repository Overview | [Documentation](./docs/README.md) |
