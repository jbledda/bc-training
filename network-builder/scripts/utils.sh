#!/bin/bash

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

# Print the usage message
function printHelp() {
  USAGE="$1"
  if [ "$USAGE" == "prereq" ]; then
    println "Usage: "
    println "  network.sh <Mode> [Flags]"
    println "    Modes:"
    println "      \033[0;32mprereq\033[0m - Install Fabric binaries and docker images"
    println
    println "    Flags:"
    println "    Used with \033[0;32mnetwork.sh prereq\033[0m:"
    println "    -i     FabricVersion (default: '2.5.4')"
    println "    -cai   Fabric CA Version (default: '1.5.7')"
    println  
  elif [ "$USAGE" == "up" ]; then
    println "Usage: "
    println "  network.sh \033[0;32mup\033[0m [Flags]"
    println
    println "    Flags:"
    println "    -org - Organization name. (i.e. org1)"
    println "    -orgdomain - Organization Domain name. (i.e. example.com)"
    println "    -ca - Deploy Fabric CA and identities for Peer, Orderer and Administrator/User"
    println "    -peer - Deploy Fabric Peer nodes configurated with identities provided by CA and CouchDB as State database"
    println "    -orderer - Deploy Fabric Orderer nodes configurated with identities provided by CA"
    println "    -r <max retry> - CLI times out after certain number of attempts (defaults to 5)"
    println "    -d <delay> - CLI delays for a certain number of seconds (defaults to 3)"
    println "    -verbose - Verbose mode"
    println
    println "    -h - Print this message"
    println
    println " Examples:"
    println "   network.sh up -org myorg -orgdomain myorg.com"
    elif [ "$USAGE" == "ccas" ]; then
    println "Usage: "
    println "  network.sh \033[0;32mup\033[0m [Flags]"
    println
    println "    Functions:"
    println "    package - Package chaincode as-a-service"
    println "    deploy - Deploy chaincode as-a-service"
    println
    println "    Flags:"
    println "    -org - Organization name. (i.e. org1)"
    println "    -orgdomain - Organization Domain name. (i.e. example.com)"
    println "    -c <channel name> - Name of channel to deploy chaincode to"
    println "    -ccn <name> - Chaincode name."
    println "    -ccl <language> - Programming language of chaincode to deploy: go, java, javascript, typescript"
    println "    -ccv <version>  - Chaincode version. 1.0 (default), v2, version3.x, etc"
    println "    -ccs <sequence>  - Chaincode definition sequence.  Must be auto (default) or an integer, 1 , 2, 3, etc"
    println "    -ccp <path>  - File path to the chaincode."
    println "    -ccep <policy>  - (Optional) Chaincode endorsement policy using signature policy syntax. The default policy requires an endorsement from Org1 and Org2"
    println "    -cccg <collection-config>  - (Optional) File path to private data collections configuration file"
    println "    -cci <fcn name>  - (Optional) Name of chaincode initialization function. When a function is provided, the execution of init will be requested and the function will be invoked."
    println
    println "    -h - Print this message"
    println
    println " Examples:"
    println "   network.sh ccas package -org myorg -orgdomain myorg.com -ccn basic -ccp ../asset-transfer-basic/chaincode-go "
  else
    println "Usage: "
    println "  network.sh <Mode> [Flags]"
    println "    Modes:"
    println "      \033[0;32mprereq\033[0m - Install Fabric binaries and docker images"
    println "      \033[0;32mup\033[0m - Bring up Fabric orderer and peer nodes. No channel is created"
    println "      \033[0;32mdown\033[0m - Bring down the network"
    println "      \033[0;32mccas\033[0m - Package or Deploy Chaincode-as-a-Service"
    println
    println "    Flags:"
    println "    Used with \033[0;32mnetwork.sh prereq\033[0m"
    println "    -i     FabricVersion (default: 'lastest')"
    println "    -cai   Fabric CA Version (default: 'lastest')"
    println
    println "    Used with \033[0;32mnetwork.sh up\033[0m:"
    println "    -org - Organization name. (i.e. org1)"
    println "    -orgdomain - Organization Domain name. (i.e. example.com)"
    println "    -ca - Deploy Fabric CA and identities for Peer, Orderer and Administrator/User"
    println "    -peer - Deploy Fabric Peer nodes configurated with identities provided by CA and CouchDB as State database"
    println "    -orderer - Deploy Fabric Orderer nodes configurated with identities provided by CA"
    println "    -r <max retry> - CLI times out after certain number of attempts (defaults to 5)"
    println "    -d <delay> - CLI delays for a certain number of seconds (defaults to 3)"
    println "    -verbose - Verbose mode"
    println
    println "    Used with \033[0;32mnetwork.sh ccas package:deploy\033[0m:"
    println "    -org - Organization name. (i.e. org1)"
    println "    -orgdomain - Organization Domain name. (i.e. example.com)"
    println "    -c <channel name> - Name of channel to deploy chaincode to"
    println "    -ccn <name> - Chaincode name."
    println "    -ccl <language> - Programming language of chaincode to deploy: go, java, javascript, typescript"
    println "    -ccv <version>  - Chaincode version. 1.0 (default), v2, version3.x, etc"
    println "    -ccs <sequence>  - Chaincode definition sequence.  Must be auto (default) or an integer, 1 , 2, 3, etc"
    println "    -ccp <path>  - File path to the chaincode."
    println "    -ccep <policy>  - (Optional) Chaincode endorsement policy using signature policy syntax. The default policy requires an endorsement from Org1 and Org2"
    println "    -cccg <collection-config>  - (Optional) File path to private data collections configuration file"
    println "    -cci <fcn name>  - (Optional) Name of chaincode initialization function. When a function is provided, the execution of init will be requested and the function will be invoked."
    println "    -h - Print this message"
    println
    println " Possible Mode and flag combinations"
    println "   \033[0;32mup\033[0m -org org1 -orgdomain example.com"
    println "   \033[0;32mdown\033[0m"
    println "   \033[0;32mccas package\033[0m -org myorg -orgdomain myorg.com -ccn basic -ccp ../asset-transfer-basic/chaincode-go"
    println "   \033[0;32mccas deploy\033[0m -org myorg -orgdomain myorg.com -ccn basic -ccp ../asset-transfer-basic/chaincode-go"
    println
    println
    println " NOTE: Default settings can be changed in network.config"
  fi
}

function installPrereqs() {

  infoln "installing prereqs"

  FILE=../install-fabric.sh     
  if [ ! -f $FILE ]; then
    curl -sSLO https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh && chmod +x install-fabric.sh
    cp install-fabric.sh ..
  fi
  
  IMAGE_PARAMETER=""
  if [ "$IMAGETAG" != "default" ]; then
    IMAGE_PARAMETER="-f ${IMAGETAG}"
  fi 

  CA_IMAGE_PARAMETER=""
  if [ "$CA_IMAGETAG" != "default" ]; then
    CA_IMAGE_PARAMETER="-c ${CA_IMAGETAG}"
  fi 

  cd ..
  ./install-fabric.sh ${IMAGE_PARAMETER} ${CA_IMAGE_PARAMETER} docker binary samples
  docker pull couchdb
}

# println echos string
function println() {
  echo -e "$1"
}

# errorln echos i red color
function errorln() {
  println "${C_RED}${1}${C_RESET}"
}

# successln echos in green color
function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

# infoln echos in blue color
function infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}

# warnln echos in yellow color
function warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

# fatalln echos in red color and exits with fail status
function fatalln() {
  errorln "$1"
  exit 1
}

export -f errorln
export -f successln
export -f infoln
export -f warnln
