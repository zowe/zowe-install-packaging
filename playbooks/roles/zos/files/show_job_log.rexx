/* REXX */

/* Usage: show_job_log.rexx "jobid=JOB12345 owner=* jobname=*" */
arg options
parse var options param
upper param
parse var param 'JOBID=' jobid ' OWNER=' owner ' JOBNAME=' jobname

Say '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
Say 'List jobs (Job ID: 'jobid', Owner: 'owner', Job Name: 'jobname')'
Say ''

rc=isfcalls('ON')

/* Update ST parameter based on parameters */
jobid = strip(jobid,'L')
if (jobid <> '') then
  do
    ISFFILTER='JobID EQ ' jobid
  end
owner = strip(owner,'L')
if (owner <> '') then
  do
    ISFOWNER=owner
  end
jobname = strip(jobname,'L')
if (jobname <> '') then
  do
    ISFPREFIX=jobname
  end

/* Call SDSF ST */
Address SDSF "ISFEXEC ST (ALTERNATE DELAYED)"
if rc<>0 then
  exit 20

/*********************/
/* Loop for all jobs */
/*********************/
do ix=1 to JNAME.0
    Say '============================================================================'
    Say 'Job ID      :' JOBID.ix
    Say 'Job Name    :' JNAME.ix
    Say 'Job Type    :' JTYPE.ix
    Say 'Job Class   :' JCLASS.ix
    Say 'Owner       :' OWNERID.ix
    Say 'Return Code :' RETCODE.ix
    Say ''

    /* On z/OS v2.5, this line sometimes failed to establish TSO session */
    /*   Address SDSF "ISFACT ST TOKEN('"TOKEN.ix"') PARM(NP ?)" */
    /* Possible error message is: */
    /* IRX0250E System abend code 0C4, reason code 00000017.   */
    /* IRX0255E Abend in host command ISFACT or address environment routine SDSF.     */
    /*     54 *-*  Address SDSF "ISFACT ST TOKEN('"TOKEN.ix"') PARM(NP ?)" ,        "( prefix jds_" */
    /*        +++ RC(-196) +++ */
    /* rc= -196 */
    /* Temporary fix is removing call of ISFACT */
    Address SDSF "ISFBROWSE ST TOKEN('"TOKEN.ix"')"
    do kx=1 to isfline.0
      Say isfline.kx
    end

    Say ''
end

Say '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'
Say ''

rc=isfcalls('OFF')
exit 0
