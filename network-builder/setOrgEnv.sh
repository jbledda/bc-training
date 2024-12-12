#!/bin/bash
# Edda Luxembourg S.A.
#
#


. scripts/utils.sh

if [[ $# -lt 2 ]] ; then
  errorln "Missing organization name and/or organization domaine name"  
  infoln "Used command ./setOrgEnv.sh ORG_NAME ORG_DOMAIN_NAME"
  exit 0
fi

# Global configuration
export PATH=${PWD}/../fabric-samples/bin:$PATH
export FABRIC_CFG_PATH=$PWD/../fabric-samples/config/
export ORG_NAME=${1}
export ORG_DOMAIN_NAME=${2}
export FABRIC_CA_CLIENT_HOME=$PWD/organizations/peerOrganizations/${2}/
export FABRIC_CA_TLS_CERT_FILES=$PWD/organizations/fabric-ca/${1}/ca-cert.pem

# CA
export CORE_CA_NAME=ca-${1}
export CORE_CA_PORT=7054
export CORE_CA_TLS=$PWD/organizations/fabric-ca/${1}/ca-cert.pem
export CORE_CA_URL=ca.${2}

# Peer configuration environment
export CORE_PEER_TLS_ENABLED=true
export PEER0_CA=${PWD}/organizations/peerOrganizations/${2}/tlsca/tlsca.${2}-cert.pem
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/${2}/users/Admin@${2}/msp
export CORE_PEER_DOMAIN=peer0.${2}
export CORE_PEER_PORT=7051
export CORE_PEER_ADDRESS=${CORE_PEER_DOMAIN}:${CORE_PEER_PORT}
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/${2}/tlsca/tlsca.${2}-cert.pem
export CORE_PEER_TLS_FILE=${PWD}/organizations/peerOrganizations/${2}/peers/$CORE_PEER_DOMAIN/tls/ca.crt
export CORE_PEER_LOCALMSPID=${1}MSP

# Orderer configuration
export CORE_ORDERER_CA=${PWD}/organizations/ordererOrganizations/${2}/tlsca/tlsca.${2}-cert.pem
export CORE_ORDERER_MSP_TLS=${PWD}/organizations/ordererOrganizations/${2}/msp/tlscacerts/tlsca.${2}-cert.pem
export CORE_ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/${2}/orderers/orderer.${2}/tls/server.crt
export CORE_ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/${2}/orderers/orderer.${2}/tls/server.key
export CORE_ORDERER_DOMAIN=orderer.${2}
export CORE_ORDERER_PORT=7050
export CORE_ORDERER_PORT_ADMINISTRATION=7053
export CORE_ORDERER_ADDRESS=${CORE_ORDERER_DOMAIN}:${CORE_ORDERER_PORT}