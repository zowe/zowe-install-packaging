#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#ifdef _LP64
    #pragma linkage(IRRSDL64, OS)
#else
    #error "31-bit not supported yet."
#endif

#include "keyring-util.h"

int debug = 0;

int main(int argc, char **argv)
{
    int i;

    if (getenv("KEYRING_UTIL_DEBUG") != NULL && ! strcmp(getenv("KEYRING_UTIL_DEBUG"), "YES")) {
        debug = 1;
    }
    Command_line_parms parms;
    memset(&parms, 0, sizeof(Command_line_parms));

    R_datalib_data_remove rem_parm;
    memset(&rem_parm, 0x00, sizeof(R_datalib_data_remove));

    R_datalib_parm_list_64 p;

    process_cmdline_parms(&parms, argc, argv);

    R_datalib_function function_table[] = {
        {"NEWRING", NEWRING_CODE, 0x00000000, 0, NULL, simple_action},
        {"DELCERT", DELCERT_CODE, 0x00000000, 0, &rem_parm, delcert_action},
        {"DELRING", DELRING_CODE, 0x00000000, 0, NULL, simple_action},
        {"REFRESH", REFRESH_CODE, 0x00000000, 0, NULL, simple_action},
        {"HELP",    HELP_CODE,    0x00000000, 0, NULL, print_help},
        {"NOTSUPPORTED", NOTSUPPORTED_CODE, 0x00000000, 0, NULL, print_help}
    };

    R_datalib_function function;
    for (i = 0; i < sizeof(function_table)/sizeof(R_datalib_function); i++) {
        if (strncasecmp(function_table[i].name, parms.function, sizeof(parms.function)) == 0) {
            function = function_table[i];
            break;
        }
        function = function_table[sizeof(function_table)/sizeof(R_datalib_function) - 1];
    }
    if (debug) {
        printf("Selected function is %s with code of %.2X\n", function.name, function.code);
    }
    function.action(&p, &function, &parms);

    return 0;
}

void simple_action(R_datalib_parm_list_64* rdatalib_parms, void * function, Command_line_parms* parms) {
    R_datalib_function *func = function;
    if (debug) {
        printf("%s action\n", func->name);
    }
    set_up_R_datalib_parameters(rdatalib_parms, function, parms->userid, parms->keyring);
    invoke_R_datalib(rdatalib_parms);
    check_return_code(rdatalib_parms);
}

void delcert_action(R_datalib_parm_list_64* rdatalib_parms, void * function, Command_line_parms* parms) {
    R_datalib_function *func = function;
    R_datalib_data_remove *rem_parm = func->parmlist;

    if (debug) {
        printf("%s action\n", func->name);
    }
    rem_parm->label_len = strlen(parms->label);
    rem_parm->label_addr = parms->label;
    rem_parm->CERT_userid_len = 0x00;

    set_up_R_datalib_parameters(rdatalib_parms, func, parms->userid, parms->keyring);
    invoke_R_datalib(rdatalib_parms);
    check_return_code(rdatalib_parms);
    // refresh DIGTCERT class if required
    if (rdatalib_parms->return_code == 4 && rdatalib_parms->RACF_return_code == 4 && rdatalib_parms->RACF_reason_code == 12) {
        printf("DIGTCERT class has to refreshed.\n");
        func->code = REFRESH_CODE;
        set_up_R_datalib_parameters(rdatalib_parms, func, "", "");
        invoke_R_datalib(rdatalib_parms);
        check_return_code(rdatalib_parms);
        printf("DIGTCERT class refreshed.\n");
    }
}

void validate_and_set_parm(char * parm, char * cmd_parm, int maxlen) {
    if (strlen(cmd_parm) <= maxlen) {
        strcpy(parm, cmd_parm);
    } else {
        printf("ERROR: %s parm too long and will not be set.\n", cmd_parm);
    }
}

void check_return_code(R_datalib_parm_list_64* p) {
    if (p->return_code != 0 || p->RACF_return_code != 0 || p->RACF_reason_code != 0) {
        printf("Function code: %.2X, SAF rc: %d, RACF rc: %d, RACF rsn: %d\n",
            p->function_code, p->return_code, p->RACF_return_code, p->RACF_reason_code);
    }
}

void process_cmdline_parms(Command_line_parms* parms, int argc, char** argv) {
    int i;
    for (i = 1; i < argc; i++) {
        if (debug) {
            printf("%d. parameter: %s\n", i, argv[i]);
        }
        switch(i) {
            case 1:
                validate_and_set_parm(parms->function, argv[i], MAX_FUNCTION_LEN);
                break;
            case 2:
                validate_and_set_parm(parms->userid, argv[i], MAX_USERID_LEN);
                break;
            case 3:
                validate_and_set_parm(parms->keyring, argv[i], MAX_KEYRING_LEN);
                break;
            case 4:
                validate_and_set_parm(parms->label, argv[i], MAX_LABEL_LEN);
                break;
            default:
                printf("WARNING: %i. parameter - %s - is currently not supported and will be ignored.\n", i, argv[i]);
        }
    }
}

void invoke_R_datalib(R_datalib_parm_list_64 * p) {

    IRRSDL64(
                &p->num_parms,
                &p->workarea,
                &p->saf_rc_ALET, &p->return_code,
                &p->racf_rc_ALET, &p->RACF_return_code,
                &p->racf_rsn_ALET, &p->RACF_reason_code,
                &p->function_code,
                &p->attributes,
                &p->RACF_userid_len,
                &p->ring_name_len,
                &p->parm_list_version,
                p->parmlist
            );
}

void set_up_R_datalib_parameters(R_datalib_parm_list_64 * p, R_datalib_function * function, char * userid, char * keyring) {
    memset(p, 0, sizeof(R_datalib_parm_list_64));
    p->num_parms = 14;
    p->saf_rc_ALET = 0;
    p->racf_rc_ALET = 0;
    p->racf_rsn_ALET = 0;
    p->function_code = function->code;
    p->attributes = function->default_attributes;
    memset(&p->RACF_userid_len, strlen(userid), 1);
    memcpy(p->RACF_userid, userid, strlen(userid));
    memset(&p->ring_name_len, strlen(keyring), 1);
    memcpy(p->ring_name, keyring, strlen(keyring));
    p->parm_list_version = function->parm_list_version;
    p->parmlist = function->parmlist;
}

void print_help(R_datalib_parm_list_64* rdatalib_parms, void * function, Command_line_parms* parms) {
    printf("----------------------------------------------------\n");
    printf("Usage: keyring-util function userid keyring label\n");
    printf("----------------------------------------------------\n");
    printf("function:\n");
    printf("NEWRING - creates a new keyring.\n");
    printf("DELRING - deletes a keyring\n");
    printf("DELCERT - disconnects a certificate (label) from a keyring or deletes a certificate from RACF database\n");
    printf("REFRESH - refreshes DIGTCERT class\n");
    printf("HELP    - prints this help\n");
}
