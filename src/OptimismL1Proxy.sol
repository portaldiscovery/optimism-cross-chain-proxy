// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ExcessivelySafeCall} from "ExcessivelySafeCall/ExcessivelySafeCall.sol";
import {IOptimismL1ProxyEvents} from "src/interfaces/IOptimismL1ProxyEvents.sol";
import {ICrossDomainMessenger} from "src/interfaces/ICrossDomainMessenger.sol";

/**
 * @notice
 * OptimismL1Proxy acts as a proxy for users/contracts to hold assets on the Optimism network
 * and execute arbitrary transactions using these assets on Optimism.
 *
 * Only the L1Owner (EOA or contract) address can perform write operations using this contract.
 *
 * Ownership is based off of how the the OZ Ownable2Step contract works,
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol
 * however there is no option to renounce ownership (transfer to the zero address).
 *
 */
contract OptimismL1Proxy is IOptimismL1ProxyEvents {
  using ExcessivelySafeCall for address;

  // Maximum bytes to copy from the function call return.
  uint16 constant MAX_COPY = 150;

  // Error indicating that the caller of the function is unauthorized.
  error UnauthorizedCaller();

  /* ---- Storage Variables ---- */

  /// @dev The cross domain messenger for this proxy.
  ICrossDomainMessenger public immutable messenger;

  /// @dev The L1 Address that owns this proxy.
  address public l1OwnerAddress;

  /// @dev The pendinding L1 Address that will own this proxy, if there is one.
  /// Returns address(0) if none exists.
  address public pendingL1OwnerAddress;

  /// @dev Initializes the contract, setting l1OwnerAddress_ as the initial owner.
  constructor(address l1OwnerAddress_, ICrossDomainMessenger messenger_) {
    _transferL1Ownership(l1OwnerAddress_);
    messenger = messenger_;
  }

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }

  /// @notice Authenticates the L1 sending address and executes the function call at the destination.
  ///
  /// @param dst_ The destination address to execute the function call against.
  /// @param msgValue_ The msg.value value. Note that the proxy must have ETH GTE to this value or the transaction will
  /// revert.
  /// @param payload_ The abi encoded payload for the function call.
  function executeFunction(address dst_, uint256 msgValue_, bytes calldata payload_) external onlyAuthenticatedCall {
    // The caller of the function is trusted but we still use excessivelySafeCall to ensure no
    // malicious reverts can happen.
    (bool success, bytes memory ret) = dst_.excessivelySafeCall(gasleft(), msgValue_, MAX_COPY, payload_);

    if (success) emit FunctionCallSuccess(dst_, ret, payload_);
    else emit FunctionCallFailed(dst_, ret, payload_);
  }

  /// @notice Authenticates the L1 sending address and executes the transfer to the destination.
  ///
  /// @param dst_ The destination address to transfer to.
  /// @param value_ The amount of ETH to transfer. Note that the proxy must have ETH GTE to this value or the
  /// transaction will revert.
  function executeTransferEth(address dst_, uint256 value_) external onlyAuthenticatedCall {
    (bool success,) = dst_.excessivelySafeCall(gasleft(), value_, MAX_COPY, "");

    if (success) emit TransferSuccess(dst_, value_);
    else emit TransferFailed(dst_, value_, address(this).balance);
  }

  /* ---- Access Control ---- */

  /// @dev Starts the transfer of the L1 Owner of the proxy to newL1Owner_.
  function transferL1Ownership(address newL1Owner_) external onlyAuthenticatedCall {
    pendingL1OwnerAddress = newL1Owner_;
    emit L1OwnershipTransferStarted(l1OwnerAddress, newL1Owner_);
  }

  /// @dev Called by the pending L1 Owner of the proxy to accept ownership. When a transfer is started,
  /// until this is called, the L1 Owner of this proxy is the previous owner.
  function acceptL1Ownership() external {
    address sender_ = messenger.xDomainMessageSender();
    if (msg.sender != address(messenger) || sender_ != pendingL1OwnerAddress) revert UnauthorizedCaller();
    _transferL1Ownership(sender_);
  }

  modifier onlyAuthenticatedCall() {
    _authenticateCall();
    _;
  }

  /// @dev Reverts with UnauthorizedCaller if called by any other messenger than the cross domain messenger,
  /// and if the `messenger.xDomainMessageSender()` is not the l1OwnerAddress.
  function _authenticateCall() internal view {
    if (msg.sender != address(messenger) || messenger.xDomainMessageSender() != l1OwnerAddress) {
      revert UnauthorizedCaller();
    }
  }

  function _transferL1Ownership(address newL1Owner_) internal {
    delete pendingL1OwnerAddress;
    address oldL1Owner_ = l1OwnerAddress;
    l1OwnerAddress = newL1Owner_;
    emit L1OwnershipTransferred(oldL1Owner_, newL1Owner_);
  }
}
