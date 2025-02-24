// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SlotMachine} from "../src/Consumer.sol";
import "forge-std/Script.sol";

contract DeploySlotMachine is Script {
  SlotMachine public slotMachine;

  function setUp() public {}

  function run() external {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address wrapperAddress = vm.envAddress("WRAPPER_ADDRESS");

    vm.startBroadcast(deployerPrivateKey);
    slotMachine = new SlotMachine(wrapperAddress); // Deploy with an initial value of 123
    vm.stopBroadcast();
  }
}
