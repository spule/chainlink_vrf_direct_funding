// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DirectFundingConsumer, SlotMachine} from "../src/Consumer.sol";
import {BaseTest} from "../test/BaseTest.t.sol";
import {VRFV2PlusWrapper} from "@chainlink/contracts/vrf/dev/VRFV2PlusWrapper.sol";
import {ExposedVRFCoordinatorV2_5} from "@chainlink/contracts/vrf/dev/testhelpers/ExposedVRFCoordinatorV2_5.sol";
import {Test, Vm, console} from "forge-std/Test.sol";

contract VRFV2PlusWrapperTest is BaseTest {
  uint256 internal constant kwei = 1e15;
  address internal constant LINK_WHALE = 0xD883a6A1C22fC4AbFE938a5aDF9B2Cc31b1BF18B;
  bytes32 private constant vrfKeyHash = hex"9f2353bde94264dbc3d554a94cceba2d7d2b4fdce4304d3e09a1fea9fbeb1528";
  uint32 private wrapperGasOverhead = 100_000;
  uint32 private coordinatorGasOverheadNative = 200_000;
  uint32 private coordinatorGasOverheadLink = 220_000;
  //
  ExposedVRFCoordinatorV2_5 private s_testCoordinator;
  uint256 private s_wrapperSubscriptionId;
  VRFV2PlusWrapper private s_wrapper;
  DirectFundingConsumer private s_consumer;
  SlotMachine private slotMachine;
  //

  function setUp() public override {
    BaseTest.setUp();
    // Fund our users
    vm.roll(1);
    vm.deal(LINK_WHALE, 10_000 ether);
    vm.stopPrank();
    vm.startPrank(LINK_WHALE);
    // Deploy coordinator
    s_testCoordinator = new ExposedVRFCoordinatorV2_5(address(0));
    s_testCoordinator.setConfig(
      0, // minRequestConfirmations
      2_500_000, // maxGasLimit
      1, // stalenessSeconds
      50_000, // gasAfterPaymentCalculation
      50000000000000000, // fallbackWeiPerUnitLink
      0, // fulfillmentFlatFeeNativePPM
      0, // fulfillmentFlatFeeLinkDiscountPPM
      0, // nativePremiumPercentage
      0 // linkPremiumPercentage
    );
    s_wrapperSubscriptionId = s_testCoordinator.createSubscription();
    // Deploy wrapper
    s_wrapper = new VRFV2PlusWrapper(
      address(0), // no need for link feed
      address(0), // no need for native feed
      address(s_testCoordinator),
      s_wrapperSubscriptionId
    );
    // Configure wrapper
    s_wrapper.setConfig(
      wrapperGasOverhead, // wrapper gas overhead
      coordinatorGasOverheadNative, // coordinator gas overhead native
      coordinatorGasOverheadLink, // coordinator gas overhead link
      0, // coordinator gas overhead per word
      0, // native premium percentage,
      0, // link premium percentage
      vrfKeyHash, // keyHash
      10, // max number of words,
      1, // stalenessSeconds
      50000000000000000, // fallbackWeiPerUnitLink
      0, // fulfillmentFlatFeeNativePPM
      0 // fulfillmentFlatFeeLinkDiscountPPM
    );
    s_wrapper.enable();
    s_testCoordinator.addConsumer(uint256(s_wrapperSubscriptionId), address(s_wrapper));
    // Add and deploy consumer
    s_consumer = new DirectFundingConsumer(address(s_wrapper));
    slotMachine = new SlotMachine(address(s_wrapper),250_000,3,3,4,0.02 ether,0.015 ether);
  }

  function testNativeConsumer() public {
    // Fund subscription.
    s_testCoordinator.fundSubscriptionWithNative{value: 10 ether}(s_wrapperSubscriptionId);
    vm.deal(address(s_consumer), 10 ether);
    uint32 callbackGasLimit = 250_000;
    // Expected cost
    uint256 expectedPaid = s_wrapper.calculateRequestPriceNative(callbackGasLimit, 3);
    // Request randomness from wrapper.
    uint256 requestId = s_consumer.makeRequestNative(callbackGasLimit, 0, 3);
    // Verify if
    (uint256 paid, bool fulfilled,) = s_consumer.s_requests(requestId);
    assertEq(paid, expectedPaid);
    //
    vm.startPrank(address(s_testCoordinator));
    uint256[] memory words = new uint256[](3);
    for (uint256 i = 0; i < 3; i++) {
      words[i] = uint256(keccak256(abi.encode(requestId, i)));
    }
    s_wrapper.rawFulfillRandomWords(requestId, words);
    uint256[] memory randWords;
    (, fulfilled, randWords) = s_consumer.getRequestStatus(requestId);
    assertEq(fulfilled, true);
    for (uint256 i = 0; i < 3; i++) {
      assertEq(words[i], randWords[i]);
    }
    // Withdraw funds from wrapper
    vm.startPrank(LINK_WHALE);
    uint256 priorWhaleBalance = LINK_WHALE.balance;
    s_wrapper.withdrawNative(LINK_WHALE);
    assertEq(LINK_WHALE.balance, priorWhaleBalance + paid);
    assertEq(address(s_wrapper).balance, 0);
  }

  function testSlotMachine() public {
    string memory logString;
    uint256 nUsers = 30;
    uint256 nWords = 3;
    address[] memory addr = getRandomAddresses(nUsers);
    // Fund users
    for (uint256 i = 0; i < nUsers; i++) {
      vm.deal(addr[i], 1 ether);
    }
    // Set gas price
    vm.txGasPrice(1 gwei);
    uint256[] memory requestId = new uint256[](nUsers);
    for (uint256 i = 0; i < nUsers; i++) {
      // All users spin
      vm.startPrank(addr[i]);
      requestId[i] = slotMachine.spin{value: 0.02 ether}();
      vm.stopPrank();
      // Provide random numbers
      vm.startPrank(address(s_testCoordinator));
      uint256[] memory words = new uint256[](nWords);
      for (uint256 j = 0; j < nWords; j++) {
        words[j] = uint256(keccak256(abi.encode(requestId[i], j)));
      }
      s_wrapper.rawFulfillRandomWords(requestId[i], words);
      vm.stopPrank();
      // Get random numbers
      vm.startPrank(addr[i]);
      (, bool reqFulfilled, uint256[] memory reqNumbers) = slotMachine.getRequestStatus(requestId[i]);
      require(reqFulfilled, "request must be fulfilled");
      vm.stopPrank();
    }
    // Final balance
    uint256 contractBalance = address(slotMachine).balance / 1 gwei;
    logString = string(abi.encodePacked("Slot machine balance -> ", vm.toString(contractBalance), " gwei"));
    console.logString(logString);
    for (uint256 i = 0; i < nUsers; i++) {
      uint256 accountBalance = addr[i].balance / 1 gwei;
      if (accountBalance != 995000000) {
        logString =
          string(abi.encodePacked("Address ", vm.toString(addr[i]), " -> ", vm.toString(accountBalance), " gwei"));
        console.logString(logString);
      }
    }
  }
}
