/* REXX */

/*************************************/
/* Usage: list_jobs.rexx "<jobname>" */
/*                                   */
/* Exmple output: id,name,owner,rc   */
/*                                   */
/* STC03574,ZWESISTC,ZWESIUSR,       */
/* STC03575,ZWE1SV,ZWESVUSR,         */
/* JOB03454,ZWE0GUNZ,ZOWEAD3,CC 0000 */
/* JOB03455,ZWE1SMPE,ZOWEAD3,CC 0000 */
/*************************************/

arg jobname

rc=isfcalls('ON')

/* Any owner */
ISFOWNER='*'
/* Filter by job name */
jobname = strip(jobname,'L')
if (jobname <> '') then
  do
    ISFPREFIX=jobname
  end

/* Call SDSF ST */
Address SDSF "ISFEXEC ST (ALTERNATE DELAYED)"
if rc<>0 then
  exit 20

/***********************/
/* Display all job IDs */
/***********************/
do ix=1 to JNAME.0
    Say JOBID.ix','JNAME.ix','OWNERID.ix','RETCODE.ix
end

rc=isfcalls('OFF')
exit 0
