/* REXX */
parse arg options
/* I added 'parse' in the line above, to avoid uppercasing the parameter */
trace 'o'
parse var options command
parse var command opercmd

opercmd = strip(opercmd,'L')
if opercmd == '' then do
    say 'Invalid command.  Must not be blank'
    exit 12
end
ISFCONS = 'mycons'
cmd.1 = opercmd
cmd.0 = 1
rc=isfcalls('ON')
/* Use SDSF Interface to issue console command */
/* add VERBOSE in the (WAIT) for additional diagnostics. */
Address SDSF ISFSLASH "("cmd.") (WAIT)"

if rc<>0 then do
     say 'Bad return from isfslash.  rc is ' rc
     Exit rc
end
/*  Say "isfmsg is:" isfmsg  */
/*  say 'isfulog size ' isfulog.0 */
do ix=1 to isfulog.0
    say isfulog.ix
end
do ix=1 to isfmsg2.0
    say isfmsg2.ix
end

rc=isfcalls('OFF')
Exit 0
