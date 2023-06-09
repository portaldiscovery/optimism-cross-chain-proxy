// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {OptimismL1Proxy} from "src/OptimismL1Proxy.sol";
import {ICrossDomainMessenger} from "src/interfaces/ICrossDomainMessenger.sol";

contract DeployOptimismL1Proxy is Script {

  function run(address owner_) public {
    address cdmAddr_ = address(0);

    // Mainnet
    if (block.chainid == 1)
      cdmAddr_ = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1;

    // Goerli
    if (block.chainid == 5)
      cdmAddr_ = 0x5086d1eEF304eb5284A0f6720f79403b4e9bE294;

    // L2 (same address on every network)
    if (block.chainid == 10 || block.chainid == 420)
      cdmAddr_ = 0x4200000000000000000000000000000000000007;

    console2.log("Deploying OptimismL1Proxy.");
    console2.log("Cross Domain Messenger: ", cdmAddr_);
    console2.log("L1 Owner Address: ", owner_);

    vm.broadcast();
    OptimismL1Proxy proxy_ = new OptimismL1Proxy(owner_, ICrossDomainMessenger(cdmAddr_));

    console2.log("Deployed new OptimismL1Proxy at: ", address(proxy_));
  }
}