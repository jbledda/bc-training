Welcome to the NSPA Blockchain Workshop!

# Install Fabric

```shell
./install-fabric.sh
```

# PRACTICE I - Run a test network

```shell
cd fabric-samples/test-network
```

```shell
# Start a test network with two Organization (Org1 and Org2) both using a Certifcate Authority and CouchDB as State Database.
./network.sh up -ca -s couchdb
```

```shell
# Create a channel named mychannel and endorse each organization inside
./network.sh createChannel -c mychannel
```

```shell
# Deploy a sample chaincode (asset-transfer-basic)
# -c: Channel name
# -ccn: chaincode name once deployed on Channel
# -ccp: Path to the chaincode sources
# -ccl: Chaincode programming language (Javascript, Typescript, Java, Go)
./network.sh deployCC -c mychannel -ccn basic -ccp ../asset-transfer-basic/chaincode-javascript/ -ccl javascript
```

```shell
# Set environment variable for Fabric Administration Tools
export PATH=${PWD}/../bin:${PWD}:$PATH
export FABRIC_CFG_PATH=$PWD/../config/
```

```shell
# Set environment variables to authenticate as Org1 Admin
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
```

```shell
# Query Peer to obtain list of joined Channel
peer channel list
```

```shell
# Query Peer to obtain list of installed chaincode on Channel mychannel
peer lifecycle chaincode querycommitted -C mychannel
```

```shell
# Detroy everything!
./network.sh down
```

# PRACTICE II - Building a Channel 

What to do:
1. Create your Organization and export it configuration.
1. Perform network configuration (host file).
1. Obtain Orderer and Peers TLS certificates from participants organizations.
1. Define Channel configuration into the configtx.yaml file.
1. Generate the Channel Genesis Block
1. Share Channel Genesis Block with participants
1. Initiate the Ordering Service by joining the channel with Orderer
1. Anchor Peers to Ordering Services

## Create your organization

```shell
# CONFIG: duplicate bin/ and config/ from fabric-samples into the root directory
cp -r fabric-samples/bin .
cp -r fabric-samples/config .
```

```shell
# Create your own Organization (peer, orderer, couchdb, CA + administrator accounts)
./network.sh up -org <yourOrgName> -orgdomain <yourorg.domain.com>
```

```shell
# Load all environment variables to administrate your Organization.
. ./setOrgEnv.sh <org-name> <org-domain>
```

```shell
# Export config for Genesis Block Creation into export folder
./network.sh export -org <yourOrgName> -orgdomain <yourorg.domain.com>
```

```shell
cd network-builder
```


## Create Channel Genesis Block
The Genesis Block is used to initialize a Channel. It is computed by one participant of the Channel and used by other participants to join it.

As an Administrator of one participant organization, executes the following actions:
```shell
. ./setOrgEnv.sh <org-name> <org-domain>
export CORE_CHANNEL_NAME=mychannel
export CORE_ARTIFACTS=./channel-artifacts
```

```shell
configtxgen -profile ChannelUsingRaft -outputBlock ${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}.block -channelID $CORE_CHANNEL_NAME -configPath ./configtx/
```

## Join channel
Once the Genesis Block that define the configuration of Channel is created, it can be used by all participants to join the Channel. This action is performed at the Orderer and Peer level.
- Orderer joining the Channel are integrated into the Ordering Service (based on the rules defined in the Genesis Block).
- Peer joining the Channel are initializing the ledger. They are also required to contact their respective Orderers to be registered as Anchor for the Channel.


### Orderer - Join Ordering Service of the Channel
Execute this command as administrator of the organisation on every orderer nodes that compose the Ordering service.

```shell
osnadmin channel join --channelID ${CORE_CHANNEL_NAME} --config-block ${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}.block -o ${CORE_ORDERER_DOMAIN}:${CORE_ORDERER_PORT_ADMINISTRATION} --ca-file "$CORE_ORDERER_CA" --client-cert "$CORE_ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$CORE_ORDERER_ADMIN_TLS_PRIVATE_KEY"
```

In case of success, the Orderer shall respond with a 201 statut

```json
{
        "name": "mychannel",
        "url": "/participation/v1/channels/asset-tracking",
        "consensusRelation": "consenter",
        "status": "active",
        "height": 1
}
```


### Peer - Join Channel
Execute this command as administrator of the organisation on every peer nodes that shall part of the Channel.
```shell
peer channel join -b ${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}.block
```

In case of sucess, the peer will respond with a positif answer:
```shell
[channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
[channelCmd] executeJoin -> Successfully submitted proposal to join channel
```

### Peer - Anchoring and Configuration update 
Execute this step as administrator of the organization on every peer nodes that shall part of the Channel.
All steps described in this section can be automatically performed using the `./scripts/generatePeerAnchoringConfig.sh`
#### Retrive configuration from Channel
Fetch the most recent configuration block for the channel
```shell
peer channel fetch config ${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-config_block.pb -o $CORE_ORDERER_ADDRESS --ordererTLSHostnameOverride ${CORE_ORDERER_DOMAIN} -c ${CORE_CHANNEL_NAME} --tls --cafile "$CORE_ORDERER_CA"
```
#### Decoding config block to JSON and isolating config into config file
```shell
export FILE_CHANNEL_BLOCK=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-config_block.pb 
export FILE_CHANNEL_BLOCK_DECODED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-config_block.json
export FILE_CHANNEL_CONFIG=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config.json

configtxlator proto_decode --input ${FILE_CHANNEL_BLOCK} --type common.Block --output ${FILE_CHANNEL_BLOCK_DECODED} 
jq .data.data[0].payload.data.config ${FILE_CHANNEL_BLOCK_DECODED} > ${FILE_CHANNEL_CONFIG}
```
#### Modify the configuration to append the anchor peer
```shell
export FILE_CHANNEL_CONFIG_UPDATED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config-modified.json

jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'$CORE_PEER_DOMAIN'","port": '$CORE_PEER_PORT'}]},"version": "0"}}' ${FILE_CHANNEL_CONFIG} > ${FILE_CHANNEL_CONFIG_UPDATED}
```
#### Compute new transaction proposal block with the updated configuration including the anchoring of the peer

```shell
export FILE_CHANNEL_CONFIG_BLOCK_ORIGINAL=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block.pb
export FILE_CHANNEL_CONFIG_BLOCK_UPDATED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-updated.pb
export FILE_CHANNEL_CONFIG_BLOCK_COMPUTED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-computed.pb
export FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_DECODED=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-computed.json
export FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_ENVELOP=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-config_block-computed-envelop.json
export FILE_CHANNEL_CONFIG_TX=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-anchors.tx

configtxlator proto_encode --input "${FILE_CHANNEL_CONFIG}" --type common.Config --output ${FILE_CHANNEL_CONFIG_BLOCK_ORIGINAL}
configtxlator proto_encode --input "${FILE_CHANNEL_CONFIG_UPDATED}" --type common.Config --output ${FILE_CHANNEL_CONFIG_BLOCK_UPDATED}
configtxlator compute_update --channel_id "${CORE_CHANNEL_NAME}" --original ${FILE_CHANNEL_CONFIG_BLOCK_ORIGINAL} --updated ${FILE_CHANNEL_CONFIG_BLOCK_UPDATED} --output ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED}
configtxlator proto_decode --input ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED} --type common.ConfigUpdate --output ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_DECODED}
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CORE_CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_DECODED})'}}}' | jq . > ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_ENVELOP}
configtxlator proto_encode --input ${FILE_CHANNEL_CONFIG_BLOCK_COMPUTED_ENVELOP} --type common.Envelope --output "${FILE_CHANNEL_CONFIG_TX}"
```
### Register Anchor to the Orderer(s)
Now all Peers have to commit their Anchor configuration to their respective Orderer(s).
```shell
export FILE_CHANNEL_CONFIG_TX=${CORE_ARTIFACTS}/${CORE_CHANNEL_NAME}-${CORE_PEER_LOCALMSPID}-anchors.tx
peer channel update -o ${CORE_ORDERER_DOMAIN}:${CORE_ORDERER_PORT} --ordererTLSHostnameOverride ${CORE_ORDERER_DOMAIN} -c $CORE_CHANNEL_NAME -f ${FILE_CHANNEL_CONFIG_TX} --tls --cafile "$CORE_ORDERER_CA"
```
In case of success, the following information are displayed:
```bash
[channelCmd] InitCmdFactory -> Endorser and orderer connections initialized
[channelCmd] update -> Successfully submitted channel update
```

# PRACTICE III - Deploy a chaincode 

## Package and Deploy CCAAS for each organizations

```bash
./network.sh ccas package -org nato -orgdomain "bc.nato.int" -ccn asset-tracking -ccl node -ccv 1.0 -ccp ../chaincode -c nato-asset-tracking
./network.sh ccas deploy -org nato -orgdomain "bc.nato.int" -ccn asset-tracking -ccl node -ccv 1.0 -ccp ../chaincode -c nato-asset-tracking
```

# Approve package
## Set environment variable with chaincode package ID

```bash
# CAUTION : CHAINCODE ID IS DIFFERENT PER ORGANIZATION!!!
export NEW_CC_PACKAGE_ID=asset-tracking_1.0:76c11efc36639c8ad8c3d9ffe81d752257f02b2b989751647a838a3644a99613
```
## Approve chaincode definition per organization
```bash
peer lifecycle chaincode approveformyorg -o ${CORE_ORDERER_DOMAIN}:${CORE_ORDERER_PORT} --ordererTLSHostnameOverride ${CORE_ORDERER_DOMAIN} --sequence 1 --channelID asset-tracking --name asset-tracking --version 1.0 --package-id ${NEW_CC_PACKAGE_ID} --tls --cafile "$CORE_ORDERER_CA"
```  

## Check Commit readyness 
Control that both organization have approved the chaincode definition
```bash
peer lifecycle chaincode checkcommitreadiness --channelID asset-tracking --name asset-tracking --version 1.0 --sequence 1 --output json
```

```bash
{
        "approvals": {
                "Org1MSP": true,
                "Org2MSP": true
        }
}
```

## Commit chaincode definition
```bash
peer lifecycle chaincode commit -o ${CORE_ORDERER_ADDRESS} --ordererTLSHostnameOverride ${CORE_ORDERER_DOMAIN} --tls --cafile "$CORE_ORDERER_CA" --channelID asset-tracking --name asset-tracking --version 1.0 --sequence 1 --peerAddresses ${CORE_PEER_ADDRESS} --tlsRootCertFiles ${CORE_PEER_TLS_FILE} 
```