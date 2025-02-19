// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFV2PlusWrapperConsumerExample} from "../src/Consumer.sol";
import {BaseTest} from "../test/BaseTest.t.sol";

import {VRFV2PlusWrapper} from "@chainlink/contracts/vrf/dev/VRFV2PlusWrapper.sol";
import {ExposedVRFCoordinatorV2_5} from "@chainlink/contracts/vrf/dev/testhelpers/ExposedVRFCoordinatorV2_5.sol";
import {Test, Vm, console} from "forge-std/Test.sol";

contract VRFV2PlusWrapperTest is BaseTest {
  address internal constant LINK_WHALE = 0xD883a6A1C22fC4AbFE938a5aDF9B2Cc31b1BF18B;
  ExposedVRFCoordinatorV2_5 private s_testCoordinator;
  uint256 private s_wrapperSubscriptionId;

  function setUp() public override {
    BaseTest.setUp();
    // Fund our users.
    vm.roll(1);
    vm.deal(LINK_WHALE, 10_000 ether);
    vm.stopPrank();
    vm.startPrank(LINK_WHALE);
    // Deploy coordinator.
    s_testCoordinator = new ExposedVRFCoordinatorV2_5(address(0));
    s_wrapperSubscriptionId = s_testCoordinator.createSubscription();
  }

  function testNative() public {}
}
