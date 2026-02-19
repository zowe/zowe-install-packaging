# SZWEEXEC/ZWEYAML

## Purpose

The `ZWEYAML` script is used to add or remove comments within YAML configurations. By default, the script utilizes two spaces for indentation, as this aligns with the standard format used in our examples.

## Installation

Copy this member to `SYSEXEC` DD.

## Customization

- Rename the member name as needed, as this is used in command line.
- Update the line command character: change `lineCommandChar = 'Y'` to your preferred character. You may use special characters such as `#` or `/`.

**Note:** Do not use ISPF [default line commands](https://www.ibm.com/docs/en/zos/2.5.0?topic=commands-line-command-summary).

## How to use

To process a single line, place `Y` on the desired line. For multiple lines, you can either use `Y` followed by the number of lines or use a pair of `YY` commands to mark the beginning and end of the block. Then type `ZWEYAML` into the line command. Following example shows the `YY` block to uncomment `zowe.setup.security` section:

```
VIEW       /zowe/example-zowe.yaml                         Command not recognized
Command ===> zweyaml                                             Scroll ===> HALF
000067
000068     # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
YY         # # Security related configurations. This setup is optional.
000070     # security:
000071     #   # security product name. Can be RACF, ACF2 or TSS
000072     #   product: RACF
000073     #   # security group name
000074     #   groups:
000075     #     admin: ZWEADMIN
000076     #     stc: ZWEADMIN
000077     #     sysProg: ZWEADMIN
000078     #   # security user name
000079     #   users:
000080     #     # Zowe runtime user name of main service
000081     #     zowe: ZWESVUSR
000082     #     # Zowe runtime user name of ZIS
000083     #     zis: ZWESIUSR
000084     #   # STC names
000085     #   stcs:
000086     #     # STC name of Zowe main service
000087     #     zowe: ZWESLSTC
000088     #     # STC name of Zowe ZIS
000089     #     zis: ZWESISTC
000090     #     # STC name of Zowe ZIS Auxiliary Server
YY         #     aux: ZWESASTC
```

**Note:** `Command not recognized` is correct behavior and it is caused by `Y` line command, which is unknown to ISPF.

Please note that after pressing the enter key, the configuration is processed and all comments are removed. Additionally, the entire block is shifted by two characters, which is necessary to ensure the configuration remains valid.

```
VIEW       /zowe/example-zowe.yaml                            Columns 00001 00125
Command ===>                                                     Scroll ===> HALF
000067
000068     # >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
000069     # Security related configurations. This setup is optional.
000070     security:
000071       # security product name. Can be RACF, ACF2 or TSS
000072       product: RACF
000073       # security group name
000074       groups:
000075         admin: ZWEADMIN
000076         stc: ZWEADMIN
000077         sysProg: ZWEADMIN
000078       # security user name
000079       users:
000080         # Zowe runtime user name of main service
000081         zowe: ZWESVUSR
000082         # Zowe runtime user name of ZIS
000083         zis: ZWESIUSR
000084       # STC names
000085       stcs:
000086         # STC name of Zowe main service
000087         zowe: ZWESLSTC
000088         # STC name of Zowe ZIS
000089         zis: ZWESISTC
000090         # STC name of Zowe ZIS Auxiliary Server
000091         aux: ZWESASTC
```

If all lines in a block are currently commented, the command will uncomment the entire block. In any other scenario the command will comment out the block.
