// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SlotMachine} from "../src/Consumer.sol";
import "forge-std/Script.sol";

contract DeploySlotMachine is Script {
  SlotMachine public slotMachine;

  function setUp() public {}

  function run() external {
    address wrapperAddress = vm.envAddress("WRAPPER_ADDRESS");

    vm.startBroadcast();
    slotMachine = new SlotMachine(wrapperAddress);
    vm.stopBroadcast();
  }
}
