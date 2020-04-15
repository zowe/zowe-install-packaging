# Extended Test Cases

Extended scenarios are organized by directories. This is caused by a bug of jest
https://github.com/facebook/jest/issues/7434.

We want each installation test scenarios to be **"test suite"** level, not **"test cases"** level. After we define the scenario as test suite, we can attach the sanity test case results under it.
