// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ICrossDomainMessenger} from "src/interfaces/ICrossDomainMessenger.sol";

contract MockCrossDomainMessenger is ICrossDomainMessenger {
  address srcAddress;

  constructor(address srcAddress_) {
    srcAddress = srcAddress_;
  }

  function xDomainMessageSender() external view returns (address) {
    return srcAddress;
  }

  function sendMessage(address target_, bytes calldata message_, uint32 /* gasLimit */ ) external {
    (bool success_, bytes memory result_) = target_.call(message_);
    // Bubble up reverts.
    // Taken from https://yos.io/2022/07/16/bubbling-up-errors-in-solidity/
    if (!success_) {
      // If call reverts
      // If there is return data, the call reverted without a reason or a custom error.
      if (result_.length == 0) revert();
      assembly {
        // We use Yul's revert() to bubble up errors from the target contract.
        revert(add(32, result_), mload(result_))
      }
    }
  }

  function setSender(address sender_) external {
    srcAddress = sender_;
  }
}
