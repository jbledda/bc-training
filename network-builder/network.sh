#!/bin/bash
#
# Edda Luxembourg S.A.
#
#
#

# This script brings up a Hyperledger Fabric network for testing smart contracts
# and applications. The test network consists of two organizations with one
# peer each, and a single node Raft ordering service. Users can also use this
# script to create a channel deploy a chaincode on the channel
#
# prepending $PWD/../bin to PATH to ensure we are picking up the correct binaries
# this may be commented out to resolve installed version of tools if desired
#
# However using PWD in the path has the side effect that location that
# this script is run from is critical. To ease this, get the directory
# this script is actually in and infer location from there. (putting first)

ROOTDIR=$(cd "$(dirname "$0")" && pwd)
export PATH=${ROOTDIR}/../bin:${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

# push to the required directory & set a trap to go back if needed
pushd ${ROOTDIR} > /dev/null
trap "popd > /dev/null" EXIT

. scripts/utils.sh

: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose > /dev/null 2>&1; then
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
    : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

# Obtain CONTAINER_IDS and remove them
# This function is called when you bring a network down
function clearContainers() {
  infoln "Removing remaining containers"
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter label=service=hyperledger-fabric) 2>/dev/null || true
  ${CONTAINER_CLI} rm -f $(${CONTAINER_CLI} ps -aq --filter name='dev-peer*') 2>/dev/null || true
  ${CONTAINER_CLI} kill "$(${CONTAINER_CLI} ps -q --filter name=ccaas)" 2>/dev/null || true
}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# This function is called when you bring the network down
function removeUnwantedImages() {
  infoln "Removing generated chaincode docker images"
  ${CONTAINER_CLI} image rm -f $(${CONTAINER_CLI} images -aq --filter reference='dev-peer*') 2>/dev/null || true
}

# Versions of fabric known not to work with the test network
NONWORKING_VERSIONS="^1\.0\. ^1\.1\. ^1\.2\. ^1\.3\. ^1\.4\."

# Do some basic sanity checking to make sure that the appropriate versions of fabric
# binaries/images are available. In the future, additional checking for the presence
# of go or other items could be added.
function checkPrereqs() {
  ## Check if your have cloned the peer binaries and configuration files.
  peer version > /dev/null 2>&1

  if [[ $? -ne 0 || ! -d "../config" ]]; then
    errorln "Peer binary and configuration files not found.."
    errorln
    errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
    errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
    exit 1
  fi
  # use the fabric tools container to see if the samples and binaries match your
  # docker images
  LOCAL_VERSION=$(peer version | sed -ne 's/^ Version: //p')
  DOCKER_IMAGE_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-tools:latest peer version | sed -ne 's/^ Version: //p')

  infoln "LOCAL_VERSION=$LOCAL_VERSION"
  infoln "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
    warnln "Local fabric binaries and docker images are out of  sync. This may cause problems."
  fi

  for UNSUPPORTED_VERSION in $NONWORKING_VERSIONS; do
    infoln "$LOCAL_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      fatalln "Local Fabric binary version of $LOCAL_VERSION does not match the versions supported by the test network."
    fi

    infoln "$DOCKER_IMAGE_VERSION" | grep -q $UNSUPPORTED_VERSION
    if [ $? -eq 0 ]; then
      fatalln "Fabric Docker image version of $DOCKER_IMAGE_VERSION does not match the versions supported by the test network."
    fi
  done

  ## Check for fabric-ca

    fabric-ca-client version > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
      errorln "fabric-ca-client binary not found.."
      errorln
      errorln "Follow the instructions in the Fabric docs to install the Fabric Binaries:"
      errorln "https://hyperledger-fabric.readthedocs.io/en/latest/install.html"
      exit 1
    fi
    CA_LOCAL_VERSION=$(fabric-ca-client version | sed -ne 's/ Version: //p')
    CA_DOCKER_IMAGE_VERSION=$(${CONTAINER_CLI} run --rm hyperledger/fabric-ca:latest fabric-ca-client version | sed -ne 's/ Version: //p' | head -1)
    infoln "CA_LOCAL_VERSION=$CA_LOCAL_VERSION"
    infoln "CA_DOCKER_IMAGE_VERSION=$CA_DOCKER_IMAGE_VERSION"

    if [ "$CA_LOCAL_VERSION" != "$CA_DOCKER_IMAGE_VERSION" ]; then
      warnln "Local fabric-ca binaries and docker images are out of sync. This may cause problems."
    fi
  
}

# Create Organization crypto material using CA
function createOrgs() {
  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  if [ -d "organizations/fabric-ca/${ORG}" ]; then
    rm -Rf organizations/fabric-ca/${ORG}
  fi

  mkdir "organizations/fabric-ca/${ORG}"

  # Generate Fabric CA configuration file
  infoln "Generating CA Configuration files for ${ORG}: organizations/fabric-ca/${ORG}/fabric-ca-server-config.yaml"
  ./organizations/ca-config-generate.sh ${ORG} ${ORG_DOMAIN}

  # Create crypto material using Fabric CA
  
  infoln "Generating certificates using Fabric CA"
  ${CONTAINER_CLI_COMPOSE} -f compose/$COMPOSE_FILE_CA -f compose/$CONTAINER_CLI/${CONTAINER_CLI}-$COMPOSE_FILE_CA up -d 2>&1

  . organizations/fabric-ca/registerEnroll.sh

  while :
    do
      if [ ! -f "organizations/fabric-ca/${ORG}/tls-cert.pem" ]; then
        sleep 1
      else
        break
      fi
  done

  infoln "Creating ${ORG} Identities"

  createOrgIdentities


  infoln "Generating CCP files for ${ORG}"
  ./organizations/ccp-generate.sh ${ORG} ${ORG_DOMAIN}
}

function generateDockerTemplate() {
  if [ -d "compose" ]; then
    rm -Rf compose
  fi

  cp -r ./compose-template ./compose

  if [ "$DEPLOY_CA" == "yes" ]; then
    infoln "Generating ${CONTAINER_CLI} configuration files for ${ORG} Fabric CA"
    ./compose/docker-config-generate.sh ${ORG} ${ORG_DOMAIN} "./compose/${COMPOSE_FILE_CA}"
    ./compose/docker-config-generate.sh ${ORG} ${ORG_DOMAIN} "./compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_CA}"
  fi

  if [ "$DEPLOY_PEER" == "yes" ]; then
    infoln "Generating ${CONTAINER_CLI} configuration files for ${ORG} Fabric Peer"
    ./compose/docker-config-generate.sh ${ORG} ${ORG_DOMAIN} "./compose/${COMPOSE_FILE_PEER}"
    ./compose/docker-config-generate.sh ${ORG} ${ORG_DOMAIN} "./compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_PEER}"
    ./compose/docker-config-generate.sh ${ORG} ${ORG_DOMAIN} "./compose/${COMPOSE_FILE_COUCH}"
    ./compose/docker-config-generate.sh ${ORG} ${ORG_DOMAIN} "./compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
  fi

  if [ "$DEPLOY_ORDERER" == "yes" ]; then
    infoln "Generating ${CONTAINER_CLI} configuration files for ${ORG} Fabric Orderer"
    ./compose/docker-config-generate.sh ${ORG} ${ORG_DOMAIN} "./compose/${COMPOSE_FILE_ORDERER}"
  fi
}

# Bring up the peer and orderer nodes using docker compose.
function networkUp() {

  checkPrereqs

  generateDockerTemplate

  # generate artifacts if they don't exist
  if [ "$DEPLOY_CA" == "yes" ]; then
    createOrgs
  fi

  if [ "$DEPLOY_PEER" == "yes" ]; then
    COMPOSE_PEER_FILES="-f compose/${COMPOSE_FILE_PEER} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_PEER}"
    COMPOSE_PEER_FILES="${COMPOSE_PEER_FILES} -f compose/${COMPOSE_FILE_COUCH} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
  else
    COMPOSE_PEER_FILES=""
  fi
  
  if [ "$DEPLOY_ORDERER" == "yes" ]; then
    COMPOSE_ORDERER_FILES="-f compose/${COMPOSE_FILE_ORDERER}"
  else
    COMPOSE_ORDERER_FILES=""
  fi

  COMPOSE_FILES="${COMPOSE_PEER_FILES} ${COMPOSE_ORDERER_FILES}"
  if [ "$DEPLOY_ORDERER" == "yes" ] || [ "$DEPLOY_PEER" == "yes" ]; then
	DOCKER_SOCK="${DOCKER_SOCK}" ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} up -d 2>&1
  fi
  $CONTAINER_CLI ps -a
  if [ $? -ne 0 ]; then
    fatalln "Unable to start network"
  fi
}


# Tear down running network
function networkDown() {
  local temp_compose=$COMPOSE_FILE_PEER
  COMPOSE_PEER_FILES="-f compose/${COMPOSE_FILE_PEER} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_PEER}"
  COMPOSE_ORDERER_FILES="-f compose/${COMPOSE_FILE_ORDERER}"
  COMPOSE_COUCH_FILES="-f compose/${COMPOSE_FILE_COUCH} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_COUCH}"
  COMPOSE_CA_FILES="-f compose/${COMPOSE_FILE_CA} -f compose/${CONTAINER_CLI}/${CONTAINER_CLI}-${COMPOSE_FILE_CA}"
  COMPOSE_FILES="${COMPOSE_PEER_FILES} ${COMPOSE_ORDERER_FILES} ${COMPOSE_COUCH_FILES} ${COMPOSE_CA_FILES}"

  if [ "${CONTAINER_CLI}" == "docker" ]; then
    DOCKER_SOCK=$DOCKER_SOCK ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes --remove-orphans
  elif [ "${CONTAINER_CLI}" == "podman" ]; then
    ${CONTAINER_CLI_COMPOSE} ${COMPOSE_FILES} down --volumes
  else
    fatalln "Container CLI  ${CONTAINER_CLI} not supported"
  fi

  COMPOSE_FILE_BASE=$temp_compose

  # Don't remove the generated artifacts -- note, the ledgers are always removed
  if [ "$MODE" != "restart" ]; then
    # Bring down the network, deleting the volumes
    ${CONTAINER_CLI} volume rm docker_orderer.${ORG_DOMAIN} docker_peer.${ORG_DOMAIN}
    #Cleanup the chaincode containers
    clearContainers
    #Cleanup images
    removeUnwantedImages
    # remove orderer block and other channel configuration transactions and certs
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations'
    ## remove fabric ca artifacts
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/${ORG}/msp organizations/fabric-ca/${ORG}/tls-cert.pem organizations/fabric-ca/${ORG}/ca-cert.pem organizations/fabric-ca/${ORG}/IssuerPublicKey organizations/fabric-ca/${ORG}/IssuerRevocationPublicKey organizations/fabric-ca/${ORG}/fabric-ca-server.db'
    # remove channel and script artifacts
    ${CONTAINER_CLI} run --rm -v "$(pwd):/data" busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz'
  fi
}

. ./network.config

# use this as the default docker-compose yaml definition
COMPOSE_FILE_PEER=compose-peer.yaml
COMPOSE_FILE_ORDERER=compose-orderer.yaml
# docker-compose.yaml file if you are using couchdb
COMPOSE_FILE_COUCH=compose-couch.yaml
# certificate authorities compose file
COMPOSE_FILE_CA=compose-ca.yaml
#

# Get docker sock path from environment variable
SOCK="${DOCKER_HOST:-/var/run/docker.sock}"
DOCKER_SOCK="${SOCK##unix://}"
DEPLOY_CA="yes"
DEPLOY_ORDERER="yes"
DEPLOY_PEER="yes"
ORG="myorg"
ORG_DOMAIN="myorg.example.com"

# Parse commandline args

## Parse mode
if [[ $# -lt 1 ]] ; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

## if no parameters are passed, show the help for cc
if [ "$MODE" == "cc" ] && [[ $# -lt 1 ]]; then
  printHelp $MODE
  exit 0
fi

function packageCAAS() {

  infoln "Packaging chaincode-as-a-service"

  scripts/packageCAAS.sh $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION true

  if [ $? -ne 0 ]; then
    fatalln "Packaging the chaincode-as-a-service failed"
  fi

}

function exportConfiguration() {
  if [ -d "export" ]; then
    rm -Rf export 
  fi
  
  mkdir -p export/peerOrganizations/${ORG_DOMAIN}/msp
  mkdir -p export/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer.${ORG_DOMAIN}/tls

  cp -r ./organizations/peerOrganizations/${ORG_DOMAIN}/msp ./export/peerOrganizations/${ORG_DOMAIN}/msp
  cp ./organizations/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer.${ORG_DOMAIN}/tls/server.crt ./export/ordererOrganizations/${ORG_DOMAIN}/orderers/orderer.${ORG_DOMAIN}/tls
  
  infoln "Orderer TLS and MSP definition are exported in ./export"
}

function deployCAAS() {
  . ./setOrgEnv.sh $ORG_NAME $ORG_DOMAIN_NAME

  infoln "Deploying chaincode-as-a-service"
  PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz)
  scripts/deployCAAS.sh $CC_NAME $CC_SRC_PATH $PACKAGE_ID $CHANNEL_NAME $CC_SRC_LANGUAGE $CC_VERSION true 

  if [ $? -ne 0 ]; then
    fatalln "Deploying the chaincode-as-a-service failed"
  fi

}

## Call the script to list installed and committed chaincode on a peer
function listChaincode() {
  . setOrgEnv.sh $ORG_NAME $ORG_DOMAIN_NAME
  . scripts/ccUtils.sh

  println
  queryInstalledOnPeer
  println
  listAllCommitted
}

## Call the script to invoke 
function invokeChaincode() {
  . setOrgEnv.sh $ORG_NAME $ORG_DOMAIN_NAME
  . scripts/ccUtils.sh

  chaincodeInvoke $ORG_NAME $CHANNEL_NAME $CC_NAME $CC_INVOKE_CONSTRUCTOR

}

## Call the script to query chaincode 
function queryChaincode() {
  . setOrgEnv.sh $ORG_NAME $ORG_DOMAIN_NAME
  . scripts/ccUtils.sh

  chaincodeQuery $ORG_NAME $CHANNEL_NAME $CC_NAME $CC_QUERY_CONSTRUCTOR
}

if [[ $# -ge 1 ]] ; then
  key="$1"
  # check for the ccas subcommand
if [[ "$MODE" == "ccas" ]]; then
    if [ "$1" != "-h" ]; then
      export SUBCOMMAND=$key
      shift
    fi
  fi
fi

# parse flags
while [[ $# -ge 1 ]] ; do
  key="$1"
  case $key in
  -h )
    printHelp $MODE
    exit 0
    ;;
  -orderer )
    DEPLOY_ORDERER="yes"
    DEPLOY_PEER="no"
    DEPLOY_CA="no"
    shift
    ;;
  -peer )
    DEPLOY_ORDERER="no"
    DEPLOY_PEER="yes"
    DEPLOY_CA="no"
    shift
    ;;
  -ca )
    DEPLOY_ORDERER="no"
    DEPLOY_PEER="no"
    DEPLOY_CA="yes"
    shift
    ;;
  -r )
    MAX_RETRY="$2"
    shift
    ;;
  -d )
    CLI_DELAY="$2"
    shift
    ;;
  -verbose )
    VERBOSE=true
    ;;
  -org )
    ORG="$2"
    shift
    ;;
  -orgdomain )
    ORG_DOMAIN="$2"
    shift
    ;;
  -i )
    IMAGETAG="$2"
    shift
    ;;
  -cai )
    CA_IMAGETAG="$2"
    shift
    ;;
  -ccic )
    CC_INVOKE_CONSTRUCTOR="$2"
    shift
    ;;
  -ccqc )
    CC_QUERY_CONSTRUCTOR="$2"
    shift
    ;;
      -ccl )
    CC_SRC_LANGUAGE="$2"
    shift
    ;;
      -c )
    CHANNEL_NAME="$2"
    shift
    ;;
  -ccn )
    CC_NAME="$2"
    shift
    ;;
  -ccv )
    CC_VERSION="$2"
    shift
    ;;
  -ccs )
    CC_SEQUENCE="$2"
    shift
    ;;
  -ccp )
    CC_SRC_PATH="$2"
    shift
    ;;
  -ccep )
    CC_END_POLICY="$2"
    shift
    ;;
  -cccg )
    CC_COLL_CONFIG="$2"
    shift
    ;;
  -cci )
    CC_INIT_FCN="$2"
    shift
    ;;
  -ccaasdocker )
    CCAAS_DOCKER_RUN="$2"
    shift
    ;;
  * )
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

# Determine mode of operation and printing out what we asked for
if [ "$MODE" == "prereq" ]; then
  infoln "Installing binaries and fabric images. Fabric Version: ${IMAGETAG}  Fabric CA Version: ${CA_IMAGETAG}"
  installPrereqs
elif [ "$MODE" == "up" ]; then
  infoln "Starting nodes with CLI timeout of '${MAX_RETRY}' tries and CLI delay of '${CLI_DELAY}' seconds"
  infoln "Organization Name: '${ORG}'"
  infoln "Organization Domain Name: '${ORG_DOMAIN}'"
  infoln "Orderer deployment: '${DEPLOY_ORDERER}'"
  infoln "Peer deployment: '${DEPLOY_PEER}'"
  infoln "Fabric CA deployment: '${DEPLOY_CA}'"
  networkUp
  infoln "Use command :"
  infoln "$ . ./setOrgEnv.sh ${ORG} ${ORG_DOMAIN}"
  infoln "To load environment variable and access nodes with Fabric CLI"
  #exportConfiguration
elif [ "$MODE" == "down" ]; then
  infoln "Stopping network"
  networkDown
elif [ "$MODE" == "export" ]; then
  infoln "Exporting Configuration"
  exportConfiguration
elif [ "$MODE" == "ccas" ] && [ "$SUBCOMMAND" == "package" ]; then
  packageCAAS
elif [ "$MODE" == "ccas" ] && [ "$SUBCOMMAND" == "deploy" ]; then
  deployCAAS
else
  printHelp
  exit 1
fi
