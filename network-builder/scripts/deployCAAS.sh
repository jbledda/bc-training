#!/bin/bash
# Edda Luxembourg S.A.
#
#

source scripts/utils.sh

CC_NAME=${1}
CC_SRC_PATH=${2}
PACKAGE_ID=${3}
CHANNEL_NAME=${4:-"mychannel"}
CC_SRC_LANGUAGE=${5}
CC_VERSION=${6:-"1.0"}
CCAAS_DOCKER_RUN=${7:-"true"}
CC_SEQUENCE=${8:-"1"}
CC_INIT_FCN=${9:-"NA"}
CC_END_POLICY=${10:-"NA"}
CC_COLL_CONFIG=${11:-"NA"}
DELAY=${12:-"3"}
MAX_RETRY=${13:-"5"}
VERBOSE=${14:-"false"}

CCAAS_SERVER_PORT=9999

: ${CONTAINER_CLI:="docker"}
if command -v ${CONTAINER_CLI}-compose >/dev/null 2>&1; then
  : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI}-compose"}
else
  : ${CONTAINER_CLI_COMPOSE:="${CONTAINER_CLI} compose"}
fi
#infoln "Using ${CONTAINER_CLI} and ${CONTAINER_CLI_COMPOSE}"

. scripts/ccUtils.sh

startDockerContainer() {
  # start the docker container
  if [ "$CCAAS_DOCKER_RUN" = "true" ]; then
    infoln "Starting the Chaincode-as-a-Service docker container..."
    set -x
    ${CONTAINER_CLI} run -d --name ${CC_NAME}-ccaas.${ORG_DOMAIN_NAME} \
      --network network.${ORG_DOMAIN_NAME} \
      -e CHAINCODE_SERVER_ADDRESS=${CC_NAME}-ccaas.${ORG_DOMAIN_NAME}:${CCAAS_SERVER_PORT} \
      -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
      ${CC_NAME}_ccaas_image:latest
    res=$?
    { set +x; } 2>/dev/null
    cat log.txt
    verifyResult $res "Failed to start the container container '${CC_NAME}_ccaas_image:latest' "
    successln "Docker container started succesfully '${CC_NAME}_ccaas_image:latest'"
  else

    infoln "Not starting docker containers; these are the commands we would have run"
    infoln "    ${CONTAINER_CLI} run -d --name peer0-${CC_NAME}-ccaas.${ORG_DOMAIN_NAME}  \
                  --network network.${ORG_DOMAIN_NAME} \
                  -e CHAINCODE_SERVER_ADDRESS=peer0-${CC_NAME}-ccaas.${ORG_DOMAIN_NAME}:${CCAAS_SERVER_PORT} \
                  -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
                    ${CC_NAME}_ccaas_image:latest"
  fi
}

printDockerContainerCmd() {
    infoln "    ${CONTAINER_CLI} run -d --name peer0-${CC_NAME}-ccaas.${ORG_DOMAIN_NAME}  \
        --network network.${ORG_DOMAIN_NAME} \
        -e CHAINCODE_SERVER_ADDRESS=peer0-${CC_NAME}-ccaas.${ORG_DOMAIN_NAME}:${CCAAS_SERVER_PORT} \
        -e CHAINCODE_ID=$PACKAGE_ID -e CORE_CHAINCODE_ID_NAME=$PACKAGE_ID \
         ${CC_NAME}_ccaas_image:latest"
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
  println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
  println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
  println "- PACKAGE_ID: ${C_GREEN}${PACKAGE_ID}${C_RESET}"
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
    fatalln "No chaincode name was provided. Valid call example: ./network.sh ccas package -org myorg -orgdomain myorg.com -ccn basic -ccp ../asset-transfer-basic/chaincode-go  "

  # User has not provided a path
  elif [ -z "$CC_SRC_PATH" ] || [ "$CC_SRC_PATH" = "NA" ]; then
    fatalln "No chaincode path was provided. Valid call example: ./network.sh ccas package -org myorg -orgdomain myorg.com -ccn basic -ccp ../asset-transfer-basic/chaincode-go  "
  elif [ -z "$CHANNEL_NAME" ] || [ "$CHANNEL_NAME" = "NA" ]; then
    fatalln "No channel name provided. Valid call example: ./network.sh ccas package -org eddaindustries -orgdomain "edda-industries.lu" -ccn basic -ccp ../chaincode -c asset-tracking"
  elif [ -z "$PACKAGE_ID" ] || [ "$PACKAGE_ID" = "NA" ]; then
    fatalln "No package id provided"
  ## Make sure that the path to the chaincode exists
  elif [ ! -d "$CC_SRC_PATH" ]; then
    fatalln "Path to chaincode does not exist. Please provide different path."
  fi


## Install chaincode on peer0.org1 and peer0.org2
infoln "Installing chaincode on ${CORE_PEER_DOMAIN}"
installChaincode 
resolveSequence
## query whether the chaincode is installed
queryInstalled
startDockerContainer
printDockerContainerCmd
exit 0
