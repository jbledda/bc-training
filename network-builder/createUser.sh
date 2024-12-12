#!/bin/bash
# Edda Luxembourg S.A.
#
#


. scripts/utils.sh

if [[ $# -lt 2 ]] ; then
  errorln "Missing parameters : username, password"  
  infoln "Used command ./createUser.sh USERNAME USERPWD"
  exit 0
fi

USER_NAME=${1}
USER_PWD=${2}

if [ ! -f ${FABRIC_CA_TLS_CERT_FILES} ]; then
    errorln "Could not retrieve CA TLS files, please verify environment variables" 
    exit 0
fi

infoln "Registering user:"
infoln "Username:${USER_NAME}"
infoln "Password:${USER_PWD}"

infoln "Organization:${ORG_DOMAIN_NAME}"

set -x
fabric-ca-client register --id.name ${USER_NAME} --id.secret ${USER_PWD} --id.type client --tls.certfiles "${FABRIC_CA_TLS_CERT_FILES}"
{ set +x; } 2>/dev/null

set -x
fabric-ca-client enroll -u https://${USER_NAME}:${USER_PWD}@${CORE_CA_URL}:${CORE_CA_PORT} --caname ${CORE_CA_NAME} -M "${PWD}/organizations/peerOrganizations/${ORG_DOMAIN_NAME}/users/${USER_NAME}@${ORG_DOMAIN_NAME}/msp" --tls.certfiles "${FABRIC_CA_TLS_CERT_FILES}"
{ set +x; } 2>/dev/null

cp "${PWD}/organizations/peerOrganizations/${ORG_DOMAIN_NAME}/msp/config.yaml" "${PWD}/organizations/peerOrganizations/${ORG_DOMAIN_NAME}/users/${USER_NAME}@${ORG_DOMAIN_NAME}/msp/config.yaml"

successln "User registered with success"
