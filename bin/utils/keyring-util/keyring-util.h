#ifndef _keyring_util
#define _keyring_util

#define MAX_FUNCTION_LEN 16
#define MAX_USERID_LEN 8
#define MAX_KEYRING_LEN 236
#define MAX_LABEL_LEN 32

#define NEWRING_CODE 0x07
#define DELCERT_CODE 0x09
#define DELRING_CODE 0x0A
#define REFRESH_CODE 0x0B
#define HELP_CODE  0x00
#define NOTSUPPORTED_CODE 0x00


typedef struct _Command_line_params {
    char function[MAX_FUNCTION_LEN];
    char userid[MAX_USERID_LEN + 1];
    char keyring[MAX_KEYRING_LEN + 1];
    char label[MAX_LABEL_LEN + 1];

} Command_line_parms;

typedef struct _R_datalib_parm_list_64 {
	int num_parms;
    double workarea[128];  // double word aligned, 1024 bytes long workarea
    int saf_rc_ALET, return_code;
    int racf_rc_ALET, RACF_return_code;
    int racf_rsn_ALET, RACF_reason_code;
    char function_code;
    int  attributes;
    char RACF_userid_len; // DO NOT change position of this field
    char RACF_userid[MAX_USERID_LEN];  // DO NOT change position of this field
    char ring_name_len;   // DO NOT change position of this field
    char ring_name[MAX_KEYRING_LEN];  // DO NOT change position of this field
    int  parm_list_version;
    void *parmlist;
} R_datalib_parm_list_64;

typedef void (*function_action)(R_datalib_parm_list_64*, void*, Command_line_parms*);

typedef struct _R_datalib_function {
	char name[MAX_FUNCTION_LEN];
    char code;
    int default_attributes;
    int parm_list_version;
    void *parmlist;
    function_action action;
} R_datalib_function;

typedef _Packed struct _R_datalib_data_remove {
    int label_len;
    int reserve_1;
    char *label_addr;
    char CERT_userid_len;  // DO NOT change position of this field
    char CERT_userid[MAX_USERID_LEN];   // DO NOT change position of this field
    char reserved_2[3];
} R_datalib_data_remove;

void invoke_R_datalib(R_datalib_parm_list_64*);
void set_up_R_datalib_parameters(R_datalib_parm_list_64* , R_datalib_function* , char* ,char* );
void simple_action(R_datalib_parm_list_64*, void*, Command_line_parms*);
void delcert_action(R_datalib_parm_list_64*, void*, Command_line_parms*);
void print_help(R_datalib_parm_list_64*, void*, Command_line_parms*);
void process_cmdline_parms(Command_line_parms*, int , char**);
void validate_and_set_parm(char*, char*, int);
void check_return_code(R_datalib_parm_list_64*);

#endif
