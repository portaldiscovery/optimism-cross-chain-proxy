# Cross Chain Proxy

## Overview
This repo contains cross chain proxy contracts, which are used to hold assets and execute transactions on behalf of addresses from other chains.
An example of this is OptimismL1Proxy, which allows an L1 address to have a proxy in Optimism, allowing it to hold assets on Optimism and execute arbitrary transactions on Optimism.

## Testing
```
forge test
```
will run all the tests in the repo.

## Deployment

To deploy the OptimismL1Proxy on Optimism, use
```
forge script scripts/DeployOptimismL1Proxy.sol \
--sig "run(address)" <desired L1 owner address> \ 
--rpc-url <your optimism provider URL>
```
to simulate the deployment transaction, and then
```
forge script scripts/DeployOptimismL1Proxy.sol \
--sig "run(address)" <desired L1 owner address> \ 
--rpc-url <your optimism provider URL> \
--private-key <your private key> \
--broadcast 
```
to deploy the contract.

