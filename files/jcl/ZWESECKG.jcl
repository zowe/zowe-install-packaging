//ZWESECKG JOB
//PROCLIB  JCLLIB ORDER=CBC.SCCNPRC
//BUILD#GO EXEC EDCCBG,
//             CPARM='SEARCH(/usr/include),DLL'
//COMPILE.SYSIN DD *
 /*-------------------------------------------------------------------*
* Invokes CSFPGSK (Generate secret key)
*--------------------------------------------------------------------*/
#include <stdio.h>
#include <csfbext.h>
#include <csnpdefs.h>
 /*-------------------------------------------------------------------*
* Utility for printing hex strings *
*--------------------------------------------------------------------*/
void printHex(unsigned char *, unsigned int);

 /*********************************************************************
* Modify values according to your requirements                        *
**********************************************************************/
 /* Modify PKCS#11 token name. Its name can be up to 32 bytes long.
  The whole 'handle' string literal should be 44 bytes long.
  More info on handle format:
  https://www.ibm.com/docs/en/zos/2.4.0?topic=services-handles#handl */

#define HANDLE "IDTTKN.JWT.SECRET                       T   "

 /* Modify ATTRIBUTES_NUMBER accordingly if you add more attributes to
   template structure.                                               */

#define ATTRIBUTES_NUMBER 4

CK_OBJECT_CLASS class = CKO_SECRET_KEY;
CK_KEY_TYPE keyType = CKK_GENERIC_SECRET;
CK_ULONG length = 32;
CK_BBOOL trueVal = TRUE;

 /* Modify attributes here if required */
CK_ATTRIBUTE template[ATTRIBUTES_NUMBER] = {
    {CKA_CLASS, &class, sizeof(class)},
    {CKA_KEY_TYPE, &keyType, sizeof(keyType)},
    {CKA_TOKEN, &trueVal, sizeof(trueVal)},
    {CKA_VALUE_LEN, &length, sizeof(length)}
};

 /*********************************************************************
* Main Function
**********************************************************************/
int main(void) {
 /*-------------------------------------------------------------------*
* Constant inputs to ICSF services *
*--------------------------------------------------------------------*/
  static unsigned char handle[45] = HANDLE;
  static int exitDataLength = 0;
  static unsigned char exitData[4] = {0};
  static int ruleArrayCount = 1;
  static unsigned char ruleArray[8] = "KEY     ";
  static int attributeListLength = 2 + ATTRIBUTES_NUMBER * 6;
  static unsigned char attributeList[32752] = {0};
  static int parmsListLength = 0;
  static unsigned char parmsList[4] = {0};
 /*-------------------------------------------------------------------*
* Variable inputs/outputs for ICSF services *
*--------------------------------------------------------------------*/

  int returnCode = 0;
  int reasonCode = 0;
 /*-------------------------------------------------------------------*
* Populate attribute list *
*--------------------------------------------------------------------*/
  char *ptr;
  CK_ATTRIBUTE attr;
  unsigned short len;
  unsigned short *count;
  int i;

  ptr = (void *) attributeList;
  count = (unsigned short *) ptr;
  *count = ATTRIBUTES_NUMBER;
  ptr += 2;

  for (i = 0; i < ATTRIBUTES_NUMBER; i++) {
    attr = template[i];

    len = (unsigned short) attr.ulValueLen;

    memcpy(ptr, (void *)(&attr.type), 4);
    memcpy(ptr + 4, (void *) &len, 2);
    memcpy(ptr + 6, (void *) (attr.pValue), len);

    attributeListLength += len;
    ptr += 6 + len;
  }

 /*-------------------------------------------------------------------*
* Call key generate *
*--------------------------------------------------------------------*/
  if ((returnCode = CSFPGSK(&returnCode,
                            &reasonCode,
                            &exitDataLength,
                            exitData,
                            handle,
                            &ruleArrayCount,
                            ruleArray,
                            &attributeListLength,
                            attributeList,
                            &parmsListLength,
                            parmsList)) != 0)
  {
    printf("\nKey Generate failed:\n");
    printf(" Return Code = %04d\n", returnCode);
    printf(" Reason Code = %04d\n", reasonCode);
  }
  printf("\nAttribute struct:\n");
  printHex(attributeList, attributeListLength);
  printf("\nHandle:\n");
  printf("\n%s\n", handle);

  return returnCode;
}

 /*-------------------------------------------------------------------*
* Prints a string as hex characters *
*--------------------------------------------------------------------*/
void printHex(unsigned char *text, unsigned int len)
{
  unsigned int i;
  for (i = 0; i < len; ++i)
    if (((i & 7) == 7) || (i == (len - 1)))
      printf(" %02x\n", text[i]);
    else
      printf(" %02x", text[i]);
  printf("\n");
} /* end printHex */
/*
//BIND.SYSIN DD *
 INCLUDE '/usr/lib/CSFDLL31.x'
/*
//
