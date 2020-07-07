//Z0PTFUCL JOB 
//*                                                            
//* update active CSI                                          
//*                                                            
//UCLIN    EXEC PGM=GIMSMP,REGION=0M,COND=(4,LT)               
//SMPLOG   DD SYSOUT=*                                         
//SMPCSI   DD DISP=OLD,DSN=#globalcsi
//SMPCNTL  DD *,SYMBOLS=JCLONLY                                
   SET BOUNDARY(GLOBAL) .                                      
   UCLIN .                                                     
   REP DDDEF(SYSUT1)   CYL SPACE(400,10) UNIT(SYSALLDA)        
   VOLUME(#volser) .                                           
   ENDUCL                                                      
   .                                                           
   SET BOUNDARY(#tzone) .                                       
   UCLIN .                                                     
   REP DDDEF(SMPWRK6)  CYL SPACE(400,10) DIR(50) UNIT(SYSALLDA)        
   VOLUME(#volser) .    
   REP DDDEF(SYSUT1)   CYL SPACE(400,10) UNIT(SYSALLDA)        
   VOLUME(#volser) .                                          
   ENDUCL                                                      
   .                                                           
   SET BOUNDARY(#dzone) .                                       
   UCLIN .                                                     
   REP DDDEF(SMPWRK6)  CYL SPACE(400,10) DIR(50) UNIT(SYSALLDA)        
   VOLUME(#volser) .                                           
   ENDUCL                                                      
   .                                                           
//*                                                            
