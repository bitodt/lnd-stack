# btcd & lnd stack

<img src="btcln.png">

# CAUTION
This setup should only be used for development purposes, and by default on simnet. Do not use on mainchain with real sats.

## Installation (requires an active kubernetes cluster and helm)
The stack uses images generated with these [Dockerfiles](https://github.com/orfeas0/lnd-stack-dockerfiles).

To install the stack, you need a kubernetes cluster, and the command-line tools _kubectl_ and _helm_. For a quick local setup, please check out [minikube](https://minikube.sigs.k8s.io/docs/).

To install the stack, just run in a shell (change release name to your liking):
```shell
export RELEASE_NAME=lndstack
helm upgrade $RELEASE_NAME --install .
```
## Verify everything is running smoothly

```
kubectl get pods
```
You should see 2 completed jobs:
- alice-lndinit
- bob-lndinit

and 4 running pods:
- alice-deployment
- bob-deployment
- btcd
- debugger

The 2 **lndinit** *jobs* create the lnd wallets required by the lnd deployments.

**Alice** and **Bob** *deployments* are lnd nodes (on simnet), each using a separate wallet and connecting to the same btcd.

The **btcd** *deployment* is a btcd node on simnet.

The **debugger** *deployment* is a debian pod with all volumes and secrets mounted, for debugging purposes. You can enter its shell with
```
kubectl exec -it debugger_pod_name -- bash
```
and check out mounted volumes as seen in the debugger.yaml *volumeMounts* section.

## Demo

After making sure everything is up and running, run the demo script.

The demo script creates a payment channel from Alice to Bob, sends a payment and then closes the channel.

```
cd scripts
export RELEASE_NAME=lndstack # same as used for installation
./run_demo.sh
```
It can be run multiple times (**not in parallel**), and each time it will create a new default wallet (for minted coins), and a new channel.

# Uninstall
Remove your installation with
```
helm uninstall $RELEASE_NAME
```
and delete the wallets with
```
kubectl delete secret $RELEASE_NAME-lnd-stack-alice-wallet-secret
kubectl delete secret $RELEASE_NAME-lnd-stack-bob-wallet-secret
```

# TODO
- Better security should be considered if we move this to production
- More configurability of the chart
- More scripts (and functions) for easier operations (i.e. quickly open a new channel, create and pay invoices); maybe split run_demo.sh into smaller parts.