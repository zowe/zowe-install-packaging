The keyring-util's source code can be found in the 
https://github.com/zowe/keyring-utilities

The binary will be placed here by artifactory during build process.

# keyring-util

The keyring-util program leverages
[R_datalib callable service](https://www.ibm.com/support/knowledgecenter/SSLTBW_2.4.0/com.ibm.zos.v2r4.ichd100/datalib.htm)
to perform various operations on digital certificates and RACF key rings.

## Build
Execute the `build.sh` script

## Syntax
```bash
keyring-util function userid keyring label
```
**Parametres:**
 1. `function` see [Functions](##Functions) section below
 2. `userid` - an owner of the `keyring` and `label` certificate
 3. `keyring` - a name of the keyring
 4. `label` - a label of the certificate
 5. `extra-parm-1` - specific to a used function
 6. `extra-parm-2` - specific to a used function

## Functions

  * `NEWRING` - creates a keyring
       * Example: `keyring-util NEWRING USER01 RING02`

  * `DELRING` - deletes a keyring
       * Example: `keyring-util DELRING USER01 RING02`

  * `DELCERT` - remove a certificate from a keyring or deletes a certificate from RACF database

    **Current Limitation:** The `DELCERT` function can only manipulate a certificate that is owned by the `userid`, i.e. it can't
     work with certificates owned by the CERTAUTH, SITE or different userid.

       The following example removes `CERT03` certificate owned by the `USER01` from the `RING02` keyring owned by the `USER01` userid
       * Example: `keyring-util DELCERT USER01 RING02 CERT03`

       The following example removes `CERT03` certificate owned by the `USER01` from the RACF database. The command fails if the certificate
       is still connected to some keyring.
       * Example: `keyring-util DELCERT USER01 '*' CERT03`
       
  * `EXPORT` - exports a certificate in PEM format. The file is created in a `pwd` directory with a name of `<cert_alias>.pem`
       * Example: `keyring-util EXPORT USER01 RING02 CERT03`
         
         Creates a file CERT03.pem.
         
  * `IMPORT` - imports a certificate from the PKCS12 format. 
       
       **Warning:** The scenario where a private key is also imported currently works only with RACF.
  
       * Example: `keyring-util IMPORT USER01 RING02 CERT03 /path/to/file.p12 pkcs12_password`
         
  * `REFRESH` - refreshes DIGTCERT class
       * Example: `keyring-util REFRESH`

For any return and reason codes, check [R_datalib return and reason codes](https://www.ibm.com/support/knowledgecenter/SSLTBW_2.4.0/com.ibm.zos.v2r4.ichd100/ich2d100238.htm)

## Further development
There is room for improvement:
  * command line argument processing and syntax (perhaps using the argp library from [ambitus project](https://github.com/ambitus/glibc/tree/zos/2.28/master/argp))
  * an extension of functionality of the current R_datalib functions
  * adding support for other [R_datalib functions](https://www.ibm.com/support/knowledgecenter/SSLTBW_2.4.0/com.ibm.zos.v2r4.ichd100/ich2d100226.htm)

Work with the following resource if you want to add support for other R_datalib functions [Data areas for R_datalib callable service](https://www.ibm.com/support/knowledgecenter/SSLTBW_2.4.0/com.ibm.zos.v2r4.ichc400/comx.htm)


