// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SlotMachine} from "../src/Consumer.sol";
import "forge-std/Script.sol";

contract DeploySlotMachine is Script {
  SlotMachine public slotMachine;

  function setUp() public {}

  function run() external {
    address wrapperAddress = vm.envAddress("WRAPPER_ADDRESS_ARB");

    vm.startBroadcast();
    slotMachine = new SlotMachine(wrapperAddress,250_000,1,3,4,0.005 ether,0.004 ether);
    vm.stopBroadcast();
  }
}