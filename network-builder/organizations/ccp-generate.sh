#!/bin/bash

function one_line_pem {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
    local PP=$(one_line_pem $5)
    local CP=$(one_line_pem $6)
    sed -e "s/\${ORG_NAME}/$1/" \
        -e "s/\${ORG_DOMAIN_NAME}/$2/" \
		-e "s/\${P0PORT}/$3/" \
        -e "s/\${CAPORT}/$4/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template.json
}

function yaml_ccp {
    local PP=$(one_line_pem $5)
    local CP=$(one_line_pem $6)
    sed -e "s/\${ORG_NAME}/$1/" \
        -e "s/\${ORG_DOMAIN_NAME}/$2/" \
		-e "s/\${P0PORT}/$3/" \
        -e "s/\${CAPORT}/$4/" \
        -e "s#\${PEERPEM}#$PP#" \
        -e "s#\${CAPEM}#$CP#" \
        organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

ORG_NAME=$1
ORG_DOMAIN_NAME=$2
P0PORT=7051
CAPORT=7054
PEERPEM=organizations/peerOrganizations/${ORG_DOMAIN_NAME}/tlsca/tlsca.${ORG_DOMAIN_NAME}-cert.pem
CAPEM=organizations/peerOrganizations/${ORG_DOMAIN_NAME}/ca/ca.${ORG_DOMAIN_NAME}-cert.pem

echo "$(json_ccp $ORG_NAME $ORG_DOMAIN_NAME $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/${ORG_DOMAIN_NAME}/connection-${ORG_NAME}.json
echo "$(yaml_ccp $ORG_NAME $ORG_DOMAIN_NAME $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/${ORG_DOMAIN_NAME}/connection-${ORG_NAME}.yaml

