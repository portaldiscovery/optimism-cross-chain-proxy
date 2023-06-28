// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {OptimismL1Proxy} from "src/OptimismL1Proxy.sol";
import {MockCrossDomainMessenger} from "test/MockCrossDomainMessenger.sol";
import {Test} from "forge-std/Test.sol";
import {IOptimismL1ProxyEvents} from "src/interfaces/IOptimismL1ProxyEvents.sol";

interface ITestEvents {
  event SendSuccess();
}

contract SendTestContractWithArgs is Test, ITestEvents {
  uint256 aExpected;
  bytes bExpected;
  uint16[] cExpected;
  address dExpected;

  constructor(uint256 aExpected_, bytes memory bExpected_, uint16[] memory cExpected_, address dExpected_) {
    aExpected = aExpected_;
    bExpected = bExpected_;
    cExpected = cExpected_;
    dExpected = dExpected_;
  }

  function functionWithArgs(uint256 a_, bytes memory b_, uint16[] memory c_, address d_) external {
    bool aCorrect_ = aExpected == a_;
    bool bCorrect_ = bExpected.length == b_.length;
    for (uint256 i; i < b_.length; i++) {
      if (b_[i] != bExpected[i]) {
        bCorrect_ = false;
        break;
      }
    }
    bool cCorrect_ = cExpected.length == c_.length;
    for (uint256 i; i < c_.length; i++) {
      if (c_[i] != cExpected[i]) {
        cCorrect_ = false;
        break;
      }
    }
    bool dCorrect_ = dExpected == d_;

    if (aCorrect_ && bCorrect_ && cCorrect_ && dCorrect_) emit SendSuccess();
    else revert("incorrect inputs");
  }
}

contract SendTestContractNoArgs is Test, ITestEvents {
  function foo() external {
    emit SendSuccess();
  }
}

contract SentTestContractPayable is Test, ITestEvents {
  uint256 expectedWeiAmt;

  constructor(uint256 expectedWeiAmt_) {
    expectedWeiAmt = expectedWeiAmt_;
  }

  function functionPayable() external payable {
    if (expectedWeiAmt == msg.value) emit SendSuccess();
    else revert("failed");
  }
}

contract OptimismL1ProxyTest is Test, ITestEvents, IOptimismL1ProxyEvents {
  address constant L1_OWNER = address(0x1234);
  OptimismL1Proxy proxy;
  MockCrossDomainMessenger messenger;

  function setUp() public virtual {
    messenger = new MockCrossDomainMessenger(L1_OWNER);
    proxy = new OptimismL1Proxy(L1_OWNER, messenger);
  }

  function _encodeOwnershipTransferAndSend(address proxy_, address newL1Owner_) internal {
    messenger.sendMessage(
      address(proxy_), abi.encodeWithSelector(OptimismL1Proxy.transferL1Ownership.selector, newL1Owner_), 0
    );
  }

  function _encodeAcceptOwnershipAndSend(address proxy_) internal {
    messenger.sendMessage(address(proxy_), abi.encodeWithSelector(OptimismL1Proxy.acceptL1Ownership.selector), 0);
  }

  function _encodeFunctionCallAndSend(address dst_, uint256 msgValue_, bytes memory payload_) internal {
    messenger.sendMessage(
      address(proxy), abi.encodeWithSelector(OptimismL1Proxy.executeFunction.selector, dst_, msgValue_, payload_), 0
    );
  }

  function _encodeTransferAndSend(address dst_, uint256 msgValue_) internal {
    messenger.sendMessage(
      address(proxy), abi.encodeWithSelector(OptimismL1Proxy.executeTransferEth.selector, dst_, msgValue_), 0
    );
  }

  function testFuzz_ConstructorEmitsOwnershipTransferred(address l1Owner_) public {
    vm.expectEmit();
    emit L1OwnershipTransferred(address(0), l1Owner_);
    OptimismL1Proxy testProxy_ = new OptimismL1Proxy(l1Owner_, messenger);
    assertEq(testProxy_.pendingL1OwnerAddress(), address(0));
    assertEq(testProxy_.l1OwnerAddress(), l1Owner_);
  }

  function testFuzz_TransferL1OwnershipSuccess(address originalL1Owner_, address newL1Owner_) public {
    OptimismL1Proxy testProxy_ = new OptimismL1Proxy(originalL1Owner_, messenger);

    // Start ownership transfer.
    messenger.setSender(originalL1Owner_);
    vm.expectEmit();
    emit L1OwnershipTransferStarted(testProxy_.l1OwnerAddress(), newL1Owner_);
    _encodeOwnershipTransferAndSend(address(testProxy_), newL1Owner_);
    assertEq(testProxy_.pendingL1OwnerAddress(), newL1Owner_);
    assertEq(testProxy_.l1OwnerAddress(), originalL1Owner_);

    // Accept ownership transfer.
    messenger.setSender(newL1Owner_);
    vm.expectEmit();
    emit L1OwnershipTransferred(originalL1Owner_, newL1Owner_);
    _encodeAcceptOwnershipAndSend(address(testProxy_));
    assertEq(testProxy_.pendingL1OwnerAddress(), address(0));
    assertEq(testProxy_.l1OwnerAddress(), newL1Owner_);
  }

  function testFuzz_CallsWithInvalidMessengerReverts() public {
    MockCrossDomainMessenger newMessenger_ = new MockCrossDomainMessenger(L1_OWNER);

    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    newMessenger_.sendMessage(
      address(proxy), abi.encodeWithSelector(OptimismL1Proxy.executeFunction.selector, L1_OWNER, 100, bytes("")), 0
    );

    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    newMessenger_.sendMessage(
      address(proxy), abi.encodeWithSelector(OptimismL1Proxy.transferL1Ownership.selector, address(0xABCD)), 0
    );

    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    newMessenger_.sendMessage(address(proxy), abi.encodeWithSelector(OptimismL1Proxy.acceptL1Ownership.selector), 0);

    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    newMessenger_.sendMessage(
      address(proxy), abi.encodeWithSelector(OptimismL1Proxy.executeTransferEth.selector, L1_OWNER, 100), 0
    );
  }

  function test_CallsWithInvalidL1OwnerReverts(address l1Owner_) public {
    vm.assume(l1Owner_ != L1_OWNER);
    messenger.setSender(l1Owner_);

    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    _encodeFunctionCallAndSend(address(0xABCD), 1000, bytes(""));

    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    _encodeOwnershipTransferAndSend(address(proxy), address(0xABCD));

    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    _encodeTransferAndSend(address(0xABCD), 1000);
  }

  function test_InvalidPendingOwnerUnableToAcceptOwnership(address newL1Owner_, address caller_) public {
    vm.assume(caller_ != address(0) && newL1Owner_ != caller_);

    _encodeOwnershipTransferAndSend(address(proxy), newL1Owner_);

    messenger.setSender(caller_);
    vm.expectRevert(abi.encodeWithSignature("UnauthorizedCaller()"));
    _encodeAcceptOwnershipAndSend(address(proxy));
  }

  function test_CallFunctionWithArgs() public {
    uint256 expectedA_ = 1e18;
    bytes memory expectedB_ = bytes("hello this is a random string");
    uint16[] memory expectedC_ = new uint16[](5);
    expectedC_[0] = 0;
    expectedC_[1] = 35;
    expectedC_[2] = 500;
    expectedC_[3] = 10_000;
    expectedC_[4] = type(uint16).max;
    address expectedD_ = address(0xBEEF);

    SendTestContractWithArgs testCallee_ = new SendTestContractWithArgs(expectedA_, expectedB_, expectedC_,
  expectedD_);

    bytes memory functionCallEncoded_ = abi.encodeWithSelector(
      SendTestContractWithArgs.functionWithArgs.selector, expectedA_, expectedB_, expectedC_, expectedD_
    );

    vm.expectEmit(address(testCallee_));
    emit SendSuccess();
    vm.expectEmit(true, true, true, false);
    emit FunctionCallSuccess(address(testCallee_), bytes(""), bytes(""));

    _encodeFunctionCallAndSend(address(testCallee_), 0, functionCallEncoded_);
  }

  function test_CallFunctionWithArgsFailed() public {
    uint256 expectedA_ = 1e18;
    bytes memory expectedB_ = bytes("hello this is a random string");
    uint16[] memory expectedC_ = new uint16[](5);
    expectedC_[0] = 0;
    expectedC_[1] = 35;
    expectedC_[2] = 500;
    expectedC_[3] = 10_000;
    expectedC_[4] = type(uint16).max;
    address expectedD_ = address(0xBEEF);

    SendTestContractWithArgs testCallee_ = new SendTestContractWithArgs(expectedA_, expectedB_, expectedC_,
  expectedD_);

    bytes memory functionCallEncoded_ = abi.encodeWithSelector(
      SendTestContractWithArgs.functionWithArgs.selector, expectedA_, expectedB_, expectedC_, address(0xABCDE)
    );

    vm.expectEmit(true, true, true, false);
    emit FunctionCallFailed(address(testCallee_), bytes(""), bytes(""));

    _encodeFunctionCallAndSend(address(testCallee_), 0, functionCallEncoded_);
  }

  function test_CallFunctionWithNoArgs() public {
    SendTestContractNoArgs testCallee_ = new SendTestContractNoArgs();

    bytes memory functionCallEncoded_ = abi.encodeWithSelector(SendTestContractNoArgs.foo.selector);

    vm.expectEmit(address(testCallee_));
    emit SendSuccess();
    vm.expectEmit(true, true, true, false);
    emit FunctionCallSuccess(address(testCallee_), bytes(""), bytes(""));

    _encodeFunctionCallAndSend(address(testCallee_), 0, functionCallEncoded_);
  }

  function test_CallFunctionDoesNotExist() public {
    SendTestContractNoArgs testCallee_ = new SendTestContractNoArgs();

    bytes memory functionCallEncoded_ = abi.encodeWithSignature("someFunctionDoesNotExist()");

    vm.expectEmit(true, true, true, false);
    emit FunctionCallFailed(address(testCallee_), bytes(""), bytes(""));

    _encodeFunctionCallAndSend(address(testCallee_), 0, functionCallEncoded_);
  }

  function testFuzz_CallFunctionPayable(uint256 expectedAmt_) public {
    vm.deal(address(proxy), expectedAmt_);
    SentTestContractPayable testCallee_ = new SentTestContractPayable(expectedAmt_);

    bytes memory functionCallEncoded_ = abi.encodeWithSelector(SentTestContractPayable.functionPayable.selector);

    vm.expectEmit(address(testCallee_));
    emit SendSuccess();
    vm.expectEmit(true, true, true, false);
    emit FunctionCallSuccess(address(testCallee_), bytes(""), bytes(""));

    _encodeFunctionCallAndSend(address(testCallee_), expectedAmt_, functionCallEncoded_);
  }

  function testFuzz_CallFunctionPayableNotEnoughNativeCurrency(uint256 expectedAmt_, uint256 dealtAmt_) public {
    expectedAmt_ = bound(expectedAmt_, 1, type(uint256).max);
    dealtAmt_ = bound(dealtAmt_, 0, expectedAmt_ - 1);
    vm.deal(address(proxy), dealtAmt_);

    SentTestContractPayable testCallee_ = new SentTestContractPayable(expectedAmt_);

    bytes memory functionCallEncoded_ = abi.encodeWithSelector(SentTestContractPayable.functionPayable.selector);

    vm.expectEmit(true, true, true, false);
    emit FunctionCallFailed(address(testCallee_), bytes(""), bytes(""));

    _encodeFunctionCallAndSend(address(testCallee_), expectedAmt_, functionCallEncoded_);
  }

  function testFuzz_Transfer(uint256 expectedAmt_) public {
    address transferAddress_ = address(0xBDCAE);
    vm.deal(address(proxy), expectedAmt_);

    vm.expectEmit(true, true, true, true);
    emit TransferSuccess(address(transferAddress_), expectedAmt_);

    _encodeTransferAndSend(transferAddress_, expectedAmt_);
    assertEq(transferAddress_.balance, expectedAmt_);
  }

  function testFuzz_TransferNotEnoughNativeCurrency(uint256 transferedAmt_, uint256 dealtAmt_, address transferAddress_)
    public
  {
    transferedAmt_ = bound(transferedAmt_, 1, type(uint256).max);
    dealtAmt_ = bound(dealtAmt_, 0, transferedAmt_ - 1);

    vm.deal(address(proxy), dealtAmt_);

    vm.expectEmit(true, true, true, true);
    emit TransferFailed(address(transferAddress_), transferedAmt_, dealtAmt_);

    _encodeTransferAndSend(transferAddress_, transferedAmt_);
  }

  function test_ReceiveEmitsEvent() public {
    vm.expectEmit(true, true, true, true);
    emit Received(address(this), 1e18);

    vm.deal(address(this), 1e18);
    address(proxy).call{value: 1e18}("");
  }

  function test_updateMaxCopy() public {
    uint16 newMaxCopy_ = 200;
    OptimismL1Proxy proxy_ = new OptimismL1Proxy(address(this), messenger);

    // Start ownership transfer.
    messenger.setSender(address(this));
    vm.expectEmit();
    emit MaxCopyUpdated(proxy_.maxCopy(), newMaxCopy_);
    messenger.sendMessage(
      address(proxy_), abi.encodeWithSelector(OptimismL1Proxy.updateMaxCopy.selector, newMaxCopy_), 0
    );

    assertEq(proxy_.maxCopy(), newMaxCopy_);
  }
}
