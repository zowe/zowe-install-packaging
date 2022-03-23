# Verify Zowe Security Configuration using the z/OSMF Security Configuration Assistant (SCA)

The `zowe_base_server.json` and `zowe_base_user.json` are the security descriptors files that can
be used to verify Zowe security setup using z/OSMF SCA tool. To make use of the files, refer to the
`IBM z/OS Management Facility Configuration Guide` book, the `Creating security descriptor files for
the Security Configuration Assistant task` section, the `Working with a security descriptor file`
subsection, or the [link](https://www.ibm.com/docs/en/zos/2.5.0?topic=zmfcg-creating-security-descriptor-files-security-configuration-assistant-task).

## Troubleshooting

Your z/OSMF doesn't have to have all the privileges to test a specific security class. If such an issue
occurs then the z/OSMF has to be permitted to check for the specific security class.

**Example**:

While validating access to a resource for PTKTDATA security class, you get the 'Unknown' validation
result with the message:
`The z/OSMF server ID IZUSVR cannot access the requested SAF resource BBG.SECCLASS.PTKTDATA in class SERVER.`

To resolve the issue, you have to execute the following security commands (for RACF):
```
RDEFINE SERVER BBG.SECCLASS.PTKTDATA UACC(NONE)
PERMIT BBG.SECCLASS.PTKTDATA CLASS(SERVER) ACCESS(READ) ID(IZUSVR)
SETROPTS RACLIST(SERVER) REFRESH
```



