/* REXX */

/* Usage: showlog.rexx "jobid=JOB12345 owner=* jobname=*" */
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

    /*****************************************/
    /* Issue the ? (JDS) action against the  */
    /* row to list the data sets in the job. */
    /******************************************/
    Address SDSF "ISFACT ST TOKEN('"TOKEN.ix"') PARM(NP ?)" ,
        "( prefix jds_"
    if rc<>0 then
      exit 20

    /**********************************************/
    /* Find the JESMSGLG data set and read it     */
    /* using ISFBROWSE.  Use isflinelim to limit  */
    /* the number of REXX variables returned.     */
    /**********************************************/
    isflinelim=500
    do jx=1 to jds_DDNAME.0

      Say '-------------------------------' jds_STEPN.jx':'jds_DDNAME.jx '-------------------------------'
      Say ''

      /*****************************************************/
      /* Read the records from the data set.               */
      /*****************************************************/
      total_lines = 0
      do until isfnextlinetoken=''

        Address SDSF "ISFBROWSE ST TOKEN('"jds_TOKEN.jx"')"

        do kx=1 to isfline.0
          Say isfline.kx
        end

        total_lines = total_lines + isfline.0
          /*****************************/
          /* Set start for next browse */
          /*****************************/
        isfstartlinetoken = isfnextlinetoken

      end

      Say ''

    end
end

Say '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<'
Say ''

rc=isfcalls('OFF')
exit 0
