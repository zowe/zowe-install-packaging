# Information for Zowe Developers and Zowe Extension Developers

## Start Zowe on your own user ID without using ZWESLSTC

This can be achieved with few changes on Zowe YAML configuration and zwe commands.

### Properly configure Zowe security permission requirement

It's recommended to update these Zowe YAML configurations to your own user ID and group ID. For example:

```yaml
zowe:
  setup:
    security:
      # security product name. Can be RACF, ACF2 or TSS
      product: RACF
      # security group name
      groups:
        # Zowe admin user group
        admin: OMVS
        # Zowe STC group
        stc: OMVS
        # Zowe SysProg group
        sysProg: OMVS
      # security user name
      users:
        # Zowe runtime user name of main service
        zowe: IBMUSER
        # Zowe runtime user name of ZIS
        zis: IBMUSER
```

With this change, `zwe init` command will be initialized to configure permissions for your own user ID. The `zowe.setup.security.users.zowe` setting can affect both `zwe init security` and `zwe init certificate` steps.

### Custom PROCLIB

Zowe YAML configuration has a section for you to define PROCLIB where Zowe STCs will be placed. If you are not using system PROCLIBs, you can put Zowe STCs into your custom PROCLIB.

```yaml
zowe:
  setup:
    dataset:
      # **COMMONLY_CUSTOMIZED**
      # PROCLIB where Zowe STCs will be copied over
      proclib: IBMUSER.PROCLIB
```

This PROCLIB must be created before you run `zwe init` command. This is an example TSO command to create a PROCLIB data set:

```
ALLOCATE NEW DA('IBMUSER.PROCLIB') DSNTYPE(LIBRARY) DSORG(PO) RECFM(F B) LRECL(80) UNIT(SYSALLDA) SPACE(15,15) TRACKS
```

**Please note**, if you use custom PROCLIB which is not in the list of system PROCLIBs concatenation (can be verified with `D PROCLIB` command), you will not be able to use `zwe start` commands. 

### Start Zowe

If `ZWESLSTC` is not placed into system PROCLIBs, you will not be able to start Zowe with `zwe start` command, or `S ZWESLSTC` JES command. That's because `zwe start` commands will try to start `ZWESLSTC` defined in system PROCLIB. You can issue `D PROCLIB` command to check what are the system PROCLIB concatenation sequence.

In this case, you need to issue `zwe internal start` command to start Zowe and the instance will run under your own user ID.
