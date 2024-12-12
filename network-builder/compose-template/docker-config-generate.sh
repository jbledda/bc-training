#!/bin/bash

function yaml_ccp {
    sed -e "s/\${ORG_NAME}/$1/" \
        -e "s/\${ORG_DOMAIN_NAME}/$2/" \
        -e "s/\${ORG_DOMAIN_NAME}/$2/" \
        $3 | sed -e $'s/\\\\n/\\\n          /g'
}

ORG_NAME=$1
ORG_DOMAIN_NAME=$2
DOCKER_TEMPLATE=$3
OUTPUT_FILE=$3

echo "$(yaml_ccp $ORG_NAME $ORG_DOMAIN_NAME $DOCKER_TEMPLATE)" > $OUTPUT_FILE