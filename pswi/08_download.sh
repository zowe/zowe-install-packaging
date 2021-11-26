#!/bin/sh

echo ""
echo ""
echo "Script for download ZOWE PSWI artifact to build server"
echo "PSWI name              :" $PSWI

script_dir=$(cd "$(dirname "${0}"))";pwd)
pax_dir=$(cd "${script_dir}/../.pax";pwd)

cd "${pax_dir}"
echo "Downloading ${SWI_NAME}-${VERSION}.pax.Z ..."
sshpass -p${ZOSMF_PASS} sftp -o BatchMode=no -o StrictHostKeyChecking=no -o PubkeyAuthentication=no -b - -P 22 ${ZOSMF_USER}@${HOST} << EOF
cd ${OUTPUT_MOUNT}
ge ${SWI_NAME}-${VERSION}.pax.Z
EOF

if [ ! -f "${SWI_NAME}-${VERSION}.pax.Z" ]; then
  exit 1
fi

mv "${SWI_NAME}-${VERSION}.pax.Z" zowe-pswi.pax.Z
