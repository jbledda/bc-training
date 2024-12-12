# Blockchain Explorer

## Pre-requisite
- A Fabric Network shall be up and running

## Copy organisation credentials folder
```bash
cp -r ../fabric-samples/test-network/organizations/ .
```

## Edit test-network.json onfiguration file
Replace the admin's certificate path with the correct one. The path ./organisations/ is mapped from the local folder into /tmp/crypto/ in the container. Only the certificate name has to be updated to the correct value. It can be obtained with the following command :

```bash
ls ./organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore
```

String to update in connection-profile/test-network.json:

```json
"adminPrivateKey": {
    "path": "/tmp/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/93018f3ccf073657fd121f15ecc39d25ee0fceba9e3af5de1030a59d0d9f1b67_sk"
    }
```

## Build container
Run the following to start up explore and explorer-db services after starting your fabric network:

```shell
    docker-compose up -d
```

## Clean up

To stop services without removing persistent data, run the following:

```shell
    docker-compose down
```

In the docker-compose.yaml, two named volumes are allocated for persistent data (for Postgres data and user wallet). If you would like to clear these named volumes up, run the following:

```shell
    docker-compose down -v
```

## URL
- http://localhost:8080
- **Login**: exploreradmin
- **Password**: exploreradminpw