// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IOptimismL1ProxyEvents {
  // Event indicating that the L1 ownership was transferred.
  event L1OwnershipTransferred(address indexed previousL1Owner, address indexed newL1Owner);
  // Event indicating that the L1 ownership has started to transfer.
  event L1OwnershipTransferStarted(address indexed previousL1Owner, address indexed pendingL1Owner);
  // Event indicating that ETH has been received.
  event Received(address indexed from, uint256 amount);
  // Event indicating that the function call was successful.
  event FunctionCallSuccess(address indexed to, bytes result, bytes payload);
  // Event indicating that the function call failed.
  event FunctionCallFailed(address indexed to, bytes reason, bytes payload);
  // Event indicating native currency has been transfered.
  event TransferSuccess(address indexed to, uint256 amount);
  // Event indicating native currency transfer has failed.
  event TransferFailed(address indexed to, uint256 amountTransfered, uint256 contractBalance);
}
