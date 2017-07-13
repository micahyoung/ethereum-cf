# Ethereum on PCF

Example of private ethereum cluster running on Cloud Foundry

## Pre-requisites

* Cloud Foundry CLI https://github.com/cloudfoundry/cli
* Account on Cloud Foundry environment with [Container-to-Container networking](https://docs.pivotal.io/pivotalcf/1-10/concepts/understand-cf-networking.html) enabled
  * Recommended: Pivotal Web Services (you may need to [request C2C networking](mailto:support@run.pivotal.io?subject=Access%20to%20Container%20Networking%20on%20PWS&body=Can%20I%20please%20get%20access%20to%20Container%20Networking%20stack%20on%20PWS%3F%20Thank%20you.)
  * Supported on [Pivotal Cloud Foundry 1.10](https://docs.pivotal.io/pivotalcf/1-10/pcf-release-notes/index.html) and higher

## Instructions

* Install the cf cli network policy plugin
```
cf install-plugin network-policy
```

* Log in to Cloud Foundry and target an org and space
```
cf login -a https://api.your-cf.com -u your-email@example.com -o your-org -s your-space
```

* Run `up.sh` and wait for it to finish

* Watch the miner logs until the DAG finished (usually when **epoch=1 percentage=99**). May take several minutes to complete
```
cf logs miners | grep DAG
...
<log stamp> Generating DAG in progress               epoch=1 percentage=97 elapsed=55.801s
<log stamp> Generating DAG in progress               epoch=1 percentage=98 elapsed=56.444s
<log stamp> Generating DAG in progress               epoch=1 percentage=99 elapsed=57.409s
...
```

* Run `tests.sh`. Read the prompts and compare it to the output to confirm the cluster is working


## Notes

* Verbosity is turned up on `geth` and `bootnodes` so the logs show lots of false positive errors
```
<log stamp>Dial error                               task="dyndial 8ba26367c9651a53 10.253.245.133:33445" err="dial tcp 10.253.245.133:33445: getsockopt: connection refused"
```

## References

* [Go-Ethereum README Operating a Private Network - GitHub](https://github.com/ethereum/go-ethereum#operating-a-private-network)
* [Setting up a local private testnet - Ethereum Homestead](http://ethdocs.org/en/latest/network/test-networks.html#setting-up-a-local-private-testnet)
* [Mining - Go-Ethereum Wiki](https://github.com/ethereum/go-ethereum/wiki/Mining)
* [Contracts and Transactions - Go-Ethereum Wiki](https://github.com/ethereum/go-ethereum/wiki/Contracts-and-Transactions)
