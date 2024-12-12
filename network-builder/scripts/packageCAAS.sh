#!/bin/bash
# Edda Luxembourg S.A.
#
#

source scripts/utils.sh
CC_NAME=${1}
CC_SRC_PATH=${2}
CC_SRC_LANGUAGE=${3}
CC_VERSION=${4:-"1.0"}
CCAAS_DOCKER_RUN=${5:-"true"}
CC_SEQUENCE=${6:-"1"}
CC_INIT_FCN=${7:-"NA"}
CC_END_POLICY=${8:-"NA"}
CC_COLL_CONFIG=${9:-"NA"}
DELAY=${10:-"3"}
MAX_RETRY=${11:-"5"}
VERBOSE=${12:-"false"}

CCAAS_SERVER_PORT=9999

: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose >/dev/null 2>&1; then
  : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
  : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi

#infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

. scripts/ccUtils.sh

buildDockerImages() {
  # if set don't build - useful when you want to debug yourself
  if [ "$CCAAS_DOCKER_RUN" = "true" ]; then
    # build the docker container
    infoln "Building Chaincode-as-a-Service docker image '${CC_NAME}' '${CC_SRC_PATH}'"
    infoln "This may take several minutes..."
    set -x
    ${CONTAINER_CLI} build -f $CC_SRC_PATH/Dockerfile -t ${CC_NAME}_ccaas_image:latest --build-arg CC_SERVER_PORT=$CCAAS_SERVER_PORT $CC_SRC_PATH >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    cat log.txt
    verifyResult $res "Docker build of chaincode-as-a-service container failed"
    successln "Docker image '${CC_NAME}_ccaas_image:latest' built succesfully"
  else
    infoln "Not building docker image; this the command we would have run"
    infoln "   ${CONTAINER_CLI} build -f $CC_SRC_PATH/Dockerfile -t ${CC_NAME}_ccaas_image:latest --build-arg CC_SERVER_PORT=$CCAAS_SERVER_PORT $CC_SRC_PATH"
  fi
}

packageChaincode() {

  address="${CC_NAME}-ccaas.${ORG_DOMAIN_NAME}:${CCAAS_SERVER_PORT}"
  prefix=$(basename "$0")
  tempdir=$(mktemp -d -t "$prefix.XXXXXXXX") || error_exit "Error creating temporary directory"
  label=${CC_NAME}_${CC_VERSION}
  mkdir -p "$tempdir/src"

  cat >"$tempdir/src/connection.json" <<CONN_EOF
{
  "address": "${address}",
  "dial_timeout": "10s",
  "tls_required": false
}
CONN_EOF

  mkdir -p "$tempdir/pkg"

  cat <<METADATA-EOF >"$tempdir/pkg/metadata.json"
{
    "type": "ccaas",
    "label": "$label"
}
METADATA-EOF

  tar -C "$tempdir/src" -czf "$tempdir/pkg/code.tar.gz" .
  tar -C "$tempdir/pkg" -czf "$CC_NAME.tar.gz" metadata.json code.tar.gz
  rm -Rf "$tempdir"

  #PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_NAME}.tar.gz)

  successln "Chaincode is packaged  ${address}"
}

printChaincodeConfig() {
  if [ "$CC_END_POLICY" = "NA" ]; then
    CC_END_POLICY=""
  else
    CC_END_POLICY="--signature-policy $CC_END_POLICY"
  fi

  if [ "$CC_COLL_CONFIG" = "NA" ]; then
    CC_COLL_CONFIG=""
  else
    CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
  fi

  println "Used Configuration"
  println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
  println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
  println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
  println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
  println "- CC_END_POLICY: ${C_GREEN}${CC_END_POLICY}${C_RESET}"
  println "- CC_COLL_CONFIG: ${C_GREEN}${CC_COLL_CONFIG}${C_RESET}"
  println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"
  println "- CCAAS_DOCKER_RUN: ${C_GREEN}${CCAAS_DOCKER_RUN}${C_RESET}"
  println "- DELAY: ${C_GREEN}${DELAY}${C_RESET}"
  println "- MAX_RETRY: ${C_GREEN}${MAX_RETRY}${C_RESET}"
  println "- VERBOSE: ${C_GREEN}${VERBOSE}${C_RESET}"  #User has not provided a name
}
  
  printChaincodeConfig
  if [ -z "$CC_NAME" ] || [ "$CC_NAME" = "NA" ]; then
    fatalln "No chaincode name was provided. Valid call example: ./network.sh ccas package -org eddaindustries -orgdomain "edda-industries.lu" -ccn basic -ccl node -ccv 1.0 -ccp ../chaincode -c asset-tracking "
  # User has not provided a path
  elif [ -z "$CC_SRC_PATH" ] || [ "$CC_SRC_PATH" = "NA" ]; then
    fatalln "No chaincode path was provided. Valid call example: ./network.sh ccas package -org eddaindustries -orgdomain "edda-industries.lu" -ccn basic -ccl node -ccv 1.0 -ccp ../chaincode -c asset-tracking "
  ## Make sure that the path to the chaincode exists
  elif [ ! -d "$CC_SRC_PATH" ]; then
    fatalln "Path to chaincode does not exist ($CC_SRC_PATH). Please provide different path."
  fi
  buildDockerImages
  packageChaincode

exit