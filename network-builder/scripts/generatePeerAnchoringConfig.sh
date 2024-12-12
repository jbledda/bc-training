#!/bin/bash
# Edda Luxembourg S.A.
#
#
source scripts/utils.sh

if [[ -z "${CORE_CHANNEL_NAME}" ]]; then
  errorln "CORE_CHANNEL_NAME env variable not defined";
  exit;
fi

if [[ -z "${CORE_ARTIFACTS}" ]]; then
  errorln "CORE_ARTIFACTS env variable not defined"
  exit;
fi

set -e

FILE_CHANNEL_BLOCK=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-config_block.pb 
FILE_CHANNEL_BLOCK_DECODED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-config_block.json
FILE_CHANNEL_CONFIG=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config.json
FILE_CHANNEL_CONFIG_UPDATED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config-modified.json
FILE_CHANNEL_CONFIG_BLOCK_ORIGINAL=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block.pb
FILE_CHANNEL_CONFIG_BLOCK_UPDATED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-updated.pb
FILE_CHANNEL_CONFIG_BLOCK_COMPUTED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-computed.pb
FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_DECODED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-computed.json
FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_ENVELOP=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-computed-envelop.json
FILE_CHANNEL_CONFIG_TX=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-anchors.tx

infoln "Retrieve channel config"
peer channel fetch config ${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-config_block.pb -o CORE_ORDERER_ADDRESS --ordererTLSHostnameOverride ${CORE_ORDERER_DOMAIN} -c ${CORE_CHANNEL_NAME} --tls --cafile "$CORE_ORDERER_CA"
infoln "Decode channel configuration"
configtxlator proto_decode --input ${FILE_CHANNEL_BLOCK} --type common.Block --output ${FILE_CHANNEL_BLOCK_DECODED} 
jq .data.data[0].payload.data.config ${FILE_CHANNEL_BLOCK_DECODED} > ${FILE_CHANNEL_CONFIG}
infoln "Modify configuration to anchor Peer"
jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'$CORE_PEER_DOMAIN'","port": '$CORE_PEER_PORT'}]},"version": "0"}}' ${FILE_CHANNEL_CONFIG} > ${FILE_CHANNEL_CONFIG_UPDATED}
infoln "Compute new transaction to commit Peer as new Anchor into the channel configuration"
configtxlator proto_encode --input "${FILE_CHANNEL_CONFIG}" --type common.Config --output ${FILE_CHANNEL_CONFIG_BLOCK_ORIGINAL}
configtxlator proto_encode --input "${FILE_CHANNEL_CONFIG_UPDATED}" --type common.Config --output ${FILE_CHANNEL_CONFIG_BLOCK_UPDATED}
configtxlator compute_update --channel_id "${CORE_CHANNEL_NAME}" --original ${FILE_CHANNEL_CONFIG_BLOCK_ORIGINAL} --updated ${FILE_CHANNEL_CONFIG_BLOCK_UPDATED} --output ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED}
configtxlator proto_decode --input ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED} --type common.ConfigUpdate --output ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_DECODED}
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CORE_CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_DECODED})'}}}' | jq . > ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_ENVELOP}
configtxlator proto_encode --input ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_ENVELOP} --type common.Envelope --output "${FILE_CHANNEL_CONFIG_TX}"