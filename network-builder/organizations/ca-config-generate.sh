#!/bin/bash

function yaml_ccp {
    sed -e "s/\${ORG_NAME}/$1/" \
        -e "s/\${ORG_DOMAIN_NAME}/$2/" \
        -e "s/\${CAPORT}/$3/" \
        organizations/fabric-ca-server-config-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

ORG_NAME=$1
ORG_DOMAIN_NAME=$2
CAPORT=7054

echo "$(yaml_ccp $ORG_NAME $ORG_DOMAIN_NAME $CAPORT)" > organizations/fabric-ca/${ORG_NAME}/fabric-ca-server-config.yaml