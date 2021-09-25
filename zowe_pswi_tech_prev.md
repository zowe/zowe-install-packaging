# z/OSMF Portable Software Instance For Zowe z/OS Components - Technology Preview

The Zowe z/OSMF Portable Instance - Technology Preview (Zowe PSWI) is the new way of Zowe z/OS components distribution.

## Version

The Zowe PSWI was build on top of SMP/E data sets of Zowe version 1.24. 

## Additional Resources

If you would like to read more about Zowe Portable Software Instance, plese read this [blog post](medium).

## Prerequisities

To be able to use the Zowe PSWI, you need to fulfill a few prerequisites: 
- The current version of the Zowe PSWI was built for the z/OSMF 2.3 and higher. The z/OSMF 2.2 and lower is not supported.
- The user ID you are using for the Zowe PSWI deployment must have READ access to the System Authorization Facility (SAF) resource that protects the Zowe data sets that are produced during the creation of the Zowe PSWI. That is, your user ID requires READ access to data set names that begin with ZOWEPSI. Please note, that the prefix is subject to change as the current Zowe PSWI is a technology preview.

## Installation

As the Zowe PSWI is a technology preview, the official Zowe documentation is still in progress. You can reffer to IBM's [documentation](https://www.ibm.com/docs/en/zos/2.4.0?topic=zosmf-portable-software-instances-page) covering Portable Software Instances related tasks. Later, there should be available a blog covering the Zowe PSWI installation process.

## Known Issues and Troubleshooting

- It is not a real issue, but it is worth to mention it. You need to make sure, that in the sysplex environment you have defined a SYSAFF variable in the job header with proper value. Otherwise, deployment jobs might be submitted on the wrong system.
- If you have never used workflows in the z/OSMF, you should configure your job statement for workflows engine. For more details please refer to the IBM's [documentation](https://www.ibm.com/docs/en/zos/2.4.0?topic=task-customizing-job-statement-workflows-your-system).