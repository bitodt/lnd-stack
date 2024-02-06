#!/bin/bash

# The script is pausing at multiple points of its execution by 
# SMALLSTEP (just a pause for you to read the progress)
# BIGSTEP (when a sync is needed and we need to wait more. You might need to increase this, depending on your node's compute power)
SMALLSTEP=1 # Recommended minimum: 1
BIGSTEP=7 # Recommended minimum: 7

if [[ -n "$RELEASE_NAME" ]]; then
    echo Release name provided is $RELEASE_NAME...
else
    # will try to get the release name
    echo Guessing the release name...
    RELEASE_NAME=$(helm ls | grep lnd-stack | awk '{print $1}')
    echo Release name guessed is $RELEASE_NAME...
fi

NAMESPACE=${NAMESPACE:-default}

# Helm naming helpers
ALICEAPPNAME=$RELEASE_NAME-lnd-stack-alice
BOBAPPNAME=$RELEASE_NAME-lnd-stack-bob
BTCDAPPNAME=$RELEASE_NAME-lnd-stack-btcd

# Get Alice address
ALICEPOD=$(kubectl -n $NAMESPACE get pods -l app="$ALICEAPPNAME" -o jsonpath='{.items[0].metadata.name}')
ALICEADDR=$(kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet newaddress np2wkh | jq -r '.address')
ALICEADDR64=$(echo $ALICEADDR | base64)
# Add Alice's address as the mining address in btcd
echo Adding Alice receiving address to btcd...
sleep $SMALLSTEP
kubectl -n $NAMESPACE patch secret $BTCDAPPNAME-secret --type='json' -p="[{\"op\": \"replace\", \"path\": \"/data/miningaddress\", \"value\": \"$ALICEADDR64\"}]"
# Restart btcd pod to get new mining address
echo Restarting btcd...
sleep $SMALLSTEP
kubectl -n $NAMESPACE scale --replicas=0 deployment.apps/$BTCDAPPNAME
sleep $BIGSTEP
kubectl -n $NAMESPACE scale --replicas=1 deployment.apps/$BTCDAPPNAME
echo Restart successful...
sleep $BIGSTEP
BTCDPOD=$(kubectl -n $NAMESPACE get pods -l app=$BTCDAPPNAME -o jsonpath='{.items[0].metadata.name}')
# Activate SegWit
echo Generating blocks to activate SegWit...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $BTCDPOD -- /start-btcctl.sh generate 401
kubectl -n $NAMESPACE exec $BTCDPOD -- /start-btcctl.sh getblockchaininfo | grep -A 1 segwit
sleep $BIGSTEP

# Check Alice balance
echo Alice wallet balance...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet walletbalance

# Get Bob pubkey
BOBPOD=$(kubectl -n $NAMESPACE get pods -l app="$BOBAPPNAME" -o jsonpath='{.items[0].metadata.name}')
BOBPUBKEY=$(kubectl -n $NAMESPACE exec $BOBPOD -- lncli --network=simnet getinfo | jq -r '.identity_pubkey')
BOBIP=$BOBAPPNAME-svc

# Connect Alice to Bob node
echo Connecting Alice to Bob...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet connect $BOBPUBKEY@$BOBIP
# List Alice peers
echo Listing Alice peers...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet listpeers
# List Bob peers
echo Listing Bob peers...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $BOBPOD -- lncli --network=simnet listpeers

# Open channel from Alice to Bob
sleep $SMALLSTEP
echo Opening channel from Alice to Bob...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet openchannel --node_key=$BOBPUBKEY --local_amt=1000000
sleep $BIGSTEP
# Create blocks to validate the transaction
echo Generating blocks to validate channel open...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $BTCDPOD -- /start-btcctl.sh generate 7
sleep $BIGSTEP

# List Alice channels
echo Listing Alice channels...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet listchannels

# Bob creates an invoice
echo Bob creates an invoice...
sleep $SMALLSTEP
PAYREQ=$(kubectl -n $NAMESPACE exec $BOBPOD -- lncli --network=simnet addinvoice --amt=10000 | jq -r '.payment_request')

# Alice pays the invoice. --force added to skip confirmation
echo Alice pays the invoice...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet sendpayment --force --pay_req=$PAYREQ

# Check channel balances
echo Alice channel balance...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet channelbalance
echo Bob channel balance...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $BOBPOD -- lncli --network=simnet channelbalance

# Get channel information
echo Getting Alice channel information...
sleep $SMALLSTEP
ALICECHANPOINT=$(kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet listchannels | jq -r '.channels[0].channel_point')
CHANFUNDINGTXID=$(echo $ALICECHANPOINT | awk -F ':' '{print $1}')
CHANOUTPUTINDEX=$(echo $ALICECHANPOINT | awk -F ':' '{print $2}')

# Close the channel
echo Closing the channel...
sleep $SMALLSTEP
# Run the channel close in the background; sometimes it doesn't return even though the channel was closed. Need to debug
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet closechannel --funding_txid=$CHANFUNDINGTXID --output_index=$CHANOUTPUTINDEX &
sleep $BIGSTEP

# Create blocks to validate the transaction
echo Generating blocks to validate channel close...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $BTCDPOD -- /start-btcctl.sh generate 7
sleep $BIGSTEP

# Check Alice balance
echo Alice on-chain balance...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $ALICEPOD -- lncli --network=simnet walletbalance

# Check Bob balance
echo Bob on-chain balance...
sleep $SMALLSTEP
kubectl -n $NAMESPACE exec $BOBPOD -- lncli --network=simnet walletbalance
