import json
import subprocess
import requests
import os
import glob


class Deploy_test:

  def __init__(self, url, user, password, system, hlq, jobst1, jobst2, volume, tzone, dzone, new_mountpoint, pswi_path,
               work_mount, swi_name):

    izudurl = "{0}/zosmf/restfiles/fs{1}/IZUD00DF.json".format(url, pswi_path)
    self.headers = {'X-CSRF-ZOSMF-HEADER': ''}
    resp = requests.get(izudurl, headers=self.headers, auth=(user, password), verify=False)

    izud = json.loads(resp.text)
    # Set variables
    self.url = url
    self.user = user
    self.password = password
    self.system = system
    self.hlq = hlq.upper()
    self.jobst1 = jobst1 + "\n"
    self.jobst2 = jobst2 + "\n"
    self.volume = volume.upper()
    self.pswi_path = pswi_path
    self.tzone = tzone.upper()
    self.dzone = dzone.upper()
    self.new_mountp = new_mountpoint

    self.definition = izud["izud.pswi.descriptor"]
    self.datasets = self.definition["datasets"]
    self.work_mount = work_mount
    self.swi_name = swi_name
    self.version = int(self.definition["version"])
    for dataset in self.datasets:
      if dataset["zonedddefs"] is not None:
        for zonedddef in dataset["zonedddefs"]:
          for dddef in zonedddef["dddefs"]:
            if dddef["path"] is not None:
              self.no_dddef = dddef["dddef"]
              self.old_mountp = dataset["mountpoint"]
              self.tracks = int(dataset["tracks"])
              self.secondary = int(dataset["secondary"])
              self.new_zfs = self.new_name(dataset["dsname"])
              self.zfs_archid = dataset["archid"]

    for zone in self.definition["zones"]:
      if zone["type"] == "TARGET":
        self.target = zone["name"]
      elif zone["type"] == "DLIB":
        self.dlib = zone["name"]

    self.job1 = """//GIMUNZIP EXEC PGM=GIMUNZIP,PARM='HASH=NO'
//SYSUT3   DD UNIT=SYSALLDA,SPACE=(CYL,(1,1))
//SYSUT4   DD UNIT=SYSALLDA,SPACE=(CYL,(1,1))
//SMPWKDIR DD PATH='{0}/'
//SMPOUT   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SMPDIR   DD PATHDISP=KEEP,
//             PATH='{1}'
//SYSIN    DD *
<GIMUNZIP>
<TEMPDS volume="{2}"> </TEMPDS> 
""".format(self.work_mount, self.pswi_path, self.volume)
    self.job1_end = """</GIMUNZIP>
/*        
        """
    self.job2 = """//RENAME1  EXEC PGM=IDCAMS,REGION=0M
//SYSPRINT DD   SYSOUT=*
//SYSIN    DD   *
"""
    self.job3 = """//UPDZONES EXEC PGM=GIMSMP,REGION=0M,
// PARM='CSI={0}'
//SMPLOG   DD SYSOUT=*
//SMPLOGA  DD SYSOUT=*
//SMPOUT   DD SYSOUT=*
//SMPRPT   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SMPPTS   DD UNIT=SYSALLDA,SPACE=(TRK,(1,1,5))
//SMPCNTL  DD *
""".format(self.new_name(self.definition["globalzone"]))
    self.job3_global = """  SET BOUNDARY(GLOBAL).
    UCLIN.
      REP GLOBALZONE
        ZONEINDEX(
        ({0},{2},TARGET)
        ({1},{2},DLIB)
                  ).
""".format(self.tzone, self.dzone, self.new_name(self.definition["globalzone"]))

    self.job3_target = """  SET BOUNDARY({0}).
    UCLIN.
      REP TZONE({0}) RELATED({1}).
""".format(self.tzone, self.dzone)

    self.job3_path = ""
    if self.version >= 9:
      self.job3_path = """      REP DDDEF({0}) PATH(
 '{1}'
     ).
""".format(self.no_dddef, self.new_mountp + "/")
    else:
      self.job3_path = """   ZONEEDIT DDDEF.
      CHANGE PATH(
 '{0}'*,
 '{1}'*).
   ENDZONEEDIT.
""".format(self.old_mountp, self.new_mountp)
    self.job3_endzone = "    ENDUCL.\n"
    self.job3_distribution = """  SET BOUNDARY({0}).
    UCLIN.
      REP DZONE({0}) RELATED({1}).
""".format(self.dzone, self.tzone)
    
    self.zfs_job = """//ALLOCDS  EXEC PGM=IDCAMS,COND=(0,LT)
//SYSPRINT DD SYSOUT=*
//SYSIN    DD *
 DEFINE CLUSTER( +
          NAME({0}) +
          CYLINDERS({1},{2}) +
          VOLUME({3}) +
          ZFS +
          SHAREOPTIONS(2))
/*
//MOUNT1    EXEC PGM=BPXBATCH,COND=(0,LT)
//STDOUT   DD SYSOUT=*
//STDERR   DD SYSOUT=*
//STDPARM  DD *
SH ;
dsn='{0}';
mpdir={4}/$dsn;
if [ -e "$mpdir" ]; then;
 rm -r $mpdir;
fi;
if [ ! -e "$mpdir" ]; then;
 echo "Work directory $mpdir will be created.";
 umask 077 ;
 mkdir -p -m 700 "$mpdir";
 rc=$?;
 if [ $rc -ne 0 ]; then;
   echo "** mkdir command failure: rc=$rc";
   exit $rc;
 fi;
fi;
echo "Format the file system $dsn.";
zfsadm format -aggregate $dsn;
rc=$?;
if [ $rc -ne 0 ]; then;
 echo "** zfsadm format command failure: rc=$rc";
 exit $rc;
fi;
echo "Mount $dsn on $mpdir.";
/usr/sbin/mount -t ZFS -s nosecurity -f $dsn $mpdir;
if [ $rc -ne 0 ]; then;
 echo "** mount command failure: rc=$rc";
 exit $rc;
fi;
mkdir -p {4}/workdir;
/*
//UNZIP    EXEC PGM=GIMUNZIP,PARM='HASH=NO',COND=(0,LT)
//SYSUT3   DD UNIT=SYSALLDA,SPACE=(CYL,(1,1))
//SYSUT4   DD UNIT=SYSALLDA,SPACE=(CYL,(1,1))
//SMPWKDIR DD PATH='{4}/workdir'
//SMPOUT   DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SMPDIR   DD PATHDISP=KEEP,
//             PATH='{5}'
//SYSIN DD *
<GIMUNZIP>
<ARCHDEF archid="{6}"
        newname="{7}"
        preserveid="YES" replace="YES"/>
</GIMUNZIP>
/*
    """.format(self.new_zfs + ".#", int(self.tracks / 15), int(self.secondary / 15), self.volume, self.work_mount,
               self.pswi_path, self.zfs_archid, self.work_mount + "/" + self.new_zfs + ".#")

  def create_zfs(self):
    new_zfs = {"cylsPri": int(self.tracks / 15), "cylsSec": int(self.secondary / 15), "volumes": [self.volume]}
    new_zfs_url = "{0}/zosmf/restfiles/mfs/zfs/{1}".format(self.url, self.new_zfs + ".%23")
    new_zfs_resp = requests.post(new_zfs_url, headers=self.headers, auth=(user, password), data=json.dumps(new_zfs),
                                 verify=False)
    if new_zfs_resp.status_code != 201:
      print("Status code: {0}".format(new_zfs_resp.status_code))
      raise requests.exceptions.RequestException(new_zfs_resp.text)

  def create_directory(self, dir_name):
    dir_name = self.work_mount + "/" + self.new_zfs + ".%23"
    dir_parms = {"type": "directory", "mode": "rwxr-xrwx"}
    dir_url = "{0}/zosmf/restfiles/fs{1}".format(self.url, dir_name)
    dir_resp = requests.post(dir_url, headers=self.headers, auth=(user, password), data=json.dumps(dir_parms),
                             verify=False)

    if dir_resp.status_code != 201:
      print("Status code: {0}".format(dir_resp.status_code))
      raise requests.exceptions.RequestException(dir_resp.text)

  def mount(self, dir=None, zfs=None, action="mount"):
    if dir is None and zfs is None:
      dir = self.work_mount + "/" + self.new_zfs + ".#"
      zfs = self.new_zfs + ".%23"
      action = "unmount"
    elif dir is None or zfs is None:
      raise TypeError("Wrong arguments")

    mount_parms = {"action": action, "mount-point": dir, "fs-type": "zFS", "mode": "rdwr"}
    mount_url = "{0}/zosmf/restfiles/mfs/{1}".format(self.url, zfs)
    mount_resp = requests.put(mount_url, headers=self.headers, auth=(user, password), data=json.dumps(mount_parms),
                              verify=False)

    if mount_resp.status_code != 204:
      print("Status code: {0}".format(mount_resp.status_code))
      raise requests.exceptions.RequestException(mount_resp.text)

  def archdef(self, dataset):
    if dataset["dsname"].endswith(".CSI"):
      new_name = self.new_name(dataset["dsname"])
    elif dataset["dsname"].endswith(".ZFS") and self.version >= 9:
      return ""
    else:
      new_name = self.new_name(dataset["dsname"]) + ".#"
    return """<ARCHDEF archid="{0}"
         newname="{1}"
         volume="{2}"
         catalog="YES"/>
""".format(dataset["archid"], new_name, self.volume)

  def new_name(self, dsname):
    return self.hlq + dsname[dsname.rfind("."):]

  def listcat(self, dataset):
    final_name = self.new_name(dataset)
    new_name = final_name + ".#"
    lstcat = """  LISTCAT -
    ENTRY({0})
  IF LASTCC = 0 THEN DO
     ALTER -
       {0} -
       NEWNAME({1})|zfs|
  END
  IF LASTCC = 0 THEN SET MAXCC = 0
  ELSE CANCEL 
""".format(new_name, final_name)
    if dataset.endswith(".ZFS"):
      self.zfs = final_name
      zfs = """
     ALTER -
       {0}.* -
       NEWNAME({1}.*)""".format(new_name, final_name)
      return lstcat.replace("|zfs|", zfs)
    else:
      return lstcat.replace("|zfs|", "")

  def zone_template(self, dataset, zone):
    dddef_templ = ""
    if dataset["zonedddefs"] is not None:
      for zoneddef in dataset["zonedddefs"]:
        if zoneddef["zone"] == zone:
          for dddef in zoneddef["dddefs"]:
            if dddef["dddef"] == self.no_dddef:
              continue
            dddef_templ = dddef_templ + """      REP DDDEF({0})
          DATASET({1})
          VOLUME() UNIT().
""".format(dddef["dddef"], self.new_name(dataset["dsname"]))
    return dddef_templ

  def first_job(self):
    jcl = self.jobst1 + self.jobst2 + self.job1
    for dataset in self.datasets:
      jcl = jcl + self.archdef(dataset)
    return jcl + self.job1_end

  def zfsInstall_job(self):
    return self.jobst1 + self.jobst2 + self.zfs_job

  def second_job(self):
    jcl = self.jobst1 + self.jobst2 + self.job2
    for dataset in self.datasets:
      if dataset["dsname"].endswith(".CSI"):
        continue
      jcl = jcl + self.listcat(dataset["dsname"])
    return jcl + "//*"

  def third_job(self):
    jcl = self.jobst1 + self.jobst2 + self.job3 + self.job3_global
    for dataset in self.datasets:
      jcl = jcl + self.zone_template(dataset, "GLOBAL")
    jcl = jcl + self.job3_endzone + self.job3_target
    for dataset in self.datasets:
      jcl = jcl + self.zone_template(dataset, self.target)
    if self.version >= 9:
      jcl = jcl + self.job3_path + self.job3_endzone + self.job3_distribution
    else:
      jcl = jcl + self.job3_endzone + self.job3_path + self.job3_distribution
    for dataset in self.datasets:
      jcl = jcl + self.zone_template(dataset, self.dlib)
    return jcl + self.job3_endzone + "/*"

  def create_swi(self):
    self.mount(self.new_mountp, self.zfs, "mount")

    parms = {
      "name": self.swi_name,
      "system": self.system,
      "description": "Zowe Deploy test",
      "globalzone": self.new_name(self.definition["globalzone"]),
      "targetzones": [self.target],
      "workflows": [
        {"name": "ZOWE Mount Workflow",
         "description": "This workflow performs mount action of ZOWE zFS.",
         "location": {"dsname": self.hlq + ".WORKFLOW(ZWEWRF02)"}},
        {"name": "ZOWE Configuration of Zowe 3.0",
         "description": "This workflow configures Zowe v3.0.",
         "location": {"dsname": self.hlq + ".WORKFLOW(ZWECONF)"}},
         {"name": "ZOWE APIML optimized Configuration",
         "description": "This simplified workflow configures APIML for Zowe 3.0.",
         "location": {"dsname": self.hlq + ".WORKFLOW(ZWEAMLCF)"}},
        {"name": "ZOWE Creation of CSR request workflow",
         "description": "This workflow creates a certificate sign request.",
         "location": {"dsname": self.hlq + ".WORKFLOW(ZWECRECR)"}},
        {"name": "ZOWE Sign a CSR request",
         "description": "This workflow signs the certificate sign request by a local CA.",
         "location": {"dsname": self.hlq + ".WORKFLOW(ZWESIGNC)"}},
        {"name": "ZOWE Load Authentication Certificate into ESM",
         "description": "This workflow loads a signed client authentication certificate to the ESM.",
         "location": {"dsname": self.hlq + ".WORKFLOW(ZWELOADC)"}},
        {"name": "ZOWE Define key ring and certificates",
         "description": "This workflow defines key ring and certificates for Zowe.",
         "location": {"dsname": self.hlq + ".WORKFLOW(ZWEKRING)"}}
      ]
    }
    swi_url = "{0}/zosmf/swmgmt/swi".format(self.url)
    swi_resp = requests.post(swi_url, headers=self.headers, auth=(user, password), data=json.dumps(parms), verify=False)
    if swi_resp.status_code != 200:
      raise requests.exceptions.RequestException(swi_resp.text)

    prod_url = "{0}/zosmf/swmgmt/swi/{1}/{2}/products".format(self.url, self.system, self.swi_name)
    prod_resp = requests.put(prod_url, headers=self.headers, auth=(user, password), verify=False)
    if prod_resp.status_code != 202:
      raise requests.exceptions.RequestException(prod_resp.text)
    status = ""
    while status != "complete":
      starus_url = prod_resp.json()["statusurl"]
      status_resp = requests.get(starus_url, headers=self.headers, auth=(user, password), verify=False)
      if status_resp.status_code != 200:
        raise requests.exceptions.RequestException(status_resp.text)
      status = status_resp.json()["status"]


if __name__ == "__main__":
  url = os.environ['ZOSMF_URL'] + ":" + os.environ['ZOSMF_PORT']  # Url and port of the z/OSMF server
  # # auth
  user = os.environ['ZOSMF_USER']  # z/OSMF user
  password = os.environ['ZOSMF_PASS']  # Password for z/OSMF
  system = os.environ['ZOSMF_SYSTEM']  # z/OSMF nickname for the system where the PSWI will be deployed
  hlq = os.environ['TEST_HLQ']  # HLQ for new datasets
  mount = os.environ['TEST_MOUNT']  # New mount point for ZFS #newmount
  jobst1 = os.environ['JOBST1']  # Job statement
  jobst2 = os.environ['JOBST2']  # Sysaff
  volume = os.environ['VOLUME']  # Volum where to store datasets
  work_path = os.environ['WORK_MOUNT']  # SMP work directory 
  tzone = os.environ['TZONE']  # Target zone
  dzone = os.environ['DZONE']  # Dlib
  pswi_path = os.environ['EXPORT']  # Path to unzipped PSWI
  swi_name = os.environ['DEPLOY_NAME']  # Name of the software instance to be created

  deploy = Deploy_test(url, user, password, system, hlq, jobst1, jobst2, volume, tzone, dzone, mount, pswi_path,
                       work_path, swi_name)

  unzip_job = deploy.first_job()
  install_zfs = deploy.zfsInstall_job()
  rename_datasets = deploy.second_job()
  update_csi = deploy.third_job()

  try:
    submit_jcl = glob.glob('./*/submit_jcl.sh')[0]
  except IndexError:
    raise FileNotFoundError(
      "\"submit_jcl.sh\" for submitting JCLs wasn't found. Make sure that it is in a subfolder of {0}".format(
        os.getcwd()))

  unzip_rc = subprocess.call(["sh", submit_jcl, unzip_job])
  if unzip_rc != 0:
    raise OSError("The unzip datasets job failed.")
  install_rc = subprocess.call(["sh", submit_jcl, install_zfs])
  if install_rc != 0:
    raise OSError("The install zFS datasets job failed.")
  deploy.mount()  # unmount
  rename_rc = subprocess.call(["sh", submit_jcl, rename_datasets])
  if rename_rc != 0:
    raise OSError("The rename datasets job failed.")
  update_rc = subprocess.call(["sh", submit_jcl, update_csi])
  if update_rc != 0:
    raise OSError("The update CSI job failed.")

  deploy.create_swi()
  print("Portable software instance deployed successfully!")

# todo: function for removing just the HLQ which all the old datasets have same -> needed only for internal usage
