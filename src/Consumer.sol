// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConfirmedOwner} from "@chainlink/contracts/shared/access/ConfirmedOwner.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/vrf/dev/libraries/VRFV2PlusClient.sol";

contract DirectFundingConsumer is VRFV2PlusWrapperConsumerBase, ConfirmedOwner {
  event WrappedRequestFulfilled(uint256 requestId, uint256[] randomWords, uint256 payment);
  event WrapperRequestMade(uint256 indexed requestId, uint256 paid);

  struct RequestStatus {
    uint256 paid;
    bool fulfilled;
    uint256[] randomWords;
    bool native;
  }

  mapping(uint256 => RequestStatus) /* requestId */ /* requestStatus */ public s_requests;

  constructor(
    address _vrfV2Wrapper
  ) ConfirmedOwner(msg.sender) VRFV2PlusWrapperConsumerBase(_vrfV2Wrapper) {}

  function makeRequestNative(
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations,
    uint32 _numWords
  ) external onlyOwner returns (uint256 requestId) {
    bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}));
    uint256 paid;
    (requestId, paid) = requestRandomnessPayInNative(_callbackGasLimit, _requestConfirmations, _numWords, extraArgs);
    s_requests[requestId] = RequestStatus({paid: paid, randomWords: new uint256[](0), fulfilled: false, native: true});
    emit WrapperRequestMade(requestId, paid);
    return requestId;
  }

  function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
    require(s_requests[_requestId].paid > 0, "request not found");
    s_requests[_requestId].fulfilled = true;
    s_requests[_requestId].randomWords = _randomWords;
    emit WrappedRequestFulfilled(_requestId, _randomWords, s_requests[_requestId].paid);
  }

  function getRequestStatus(
    uint256 _requestId
  ) external view returns (uint256 paid, bool fulfilled, uint256[] memory randomWords) {
    require(s_requests[_requestId].paid > 0, "request not found");
    RequestStatus memory request = s_requests[_requestId];
    return (request.paid, request.fulfilled, request.randomWords);
  }

  function withdrawNative(
    uint256 amount
  ) external onlyOwner {
    (bool success,) = payable(owner()).call{value: amount}("");
    require(success, "withdrawNative failed");
  }

  event Received(address, uint256);

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }
}

contract SlotMachine is VRFV2PlusWrapperConsumerBase, ConfirmedOwner {
  event WrappedRequestFulfilled(uint256 requestId, uint256[] randomWords, uint256 payment);
  event WrapperRequestMade(uint256 indexed requestId, uint256 paid);

  struct RequestStatus {
    uint256 paid;
    bool fulfilled;
    uint256[] randomWords;
    bool native;
    address playerAddress;
  }

  uint32 internal callbackGasLimit = 250_000;
  uint16 internal requestConfirmations = 3;
  uint32 internal numWords = 3;
  uint32 internal numComb = 3;
  uint256 internal minPayForPlay = 0.02 ether;
  uint256 internal transferToFunds = 0.015 ether;

  uint256 internal funds = 0;

  mapping(uint256 => RequestStatus) /* requestId */ /* requestStatus */ public s_requests;

  event NoHit(address player, uint256[] comb);
  event Jackpot(address player, uint256[] winComb);

  constructor(
    address _vrfV2Wrapper
  ) ConfirmedOwner(msg.sender) VRFV2PlusWrapperConsumerBase(_vrfV2Wrapper) {}

  function updateParameters(
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations,
    uint32 _numWords,
    uint32 _numComb,
    uint256 _minPayForPlay,
    uint256 _transferToFunds
  ) external onlyOwner {
    callbackGasLimit = _callbackGasLimit;
    requestConfirmations = _requestConfirmations;
    numWords = _numWords;
    numComb = _numComb;
    minPayForPlay = _minPayForPlay;
    transferToFunds = _transferToFunds;
  }

  function updateFunds(
    uint256 _updateFunds
  ) external onlyOwner {
    funds += _updateFunds;
  }

  function getMinPayForPlay() external view returns (uint256) {
    return minPayForPlay;
  }

  function getFunds() external view returns (uint256) {
    return funds;
  }

  function spin() external payable returns (uint256 requestId) {
    require(msg.value >= minPayForPlay, "Minimal pay for play not fulfilled");
    bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}));
    uint256 paid;
    (requestId, paid) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, numWords, extraArgs);
    s_requests[requestId] = RequestStatus({
      paid: paid,
      randomWords: new uint256[](0),
      fulfilled: false,
      native: true,
      playerAddress: msg.sender
    });
    emit WrapperRequestMade(requestId, paid);
    funds += transferToFunds - paid;
    return requestId;
  }

  function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
    require(s_requests[_requestId].paid > 0, "request not found");
    emit WrappedRequestFulfilled(_requestId, _randomWords, s_requests[_requestId].paid);
    s_requests[_requestId].fulfilled = true;
    s_requests[_requestId].randomWords = _randomWords;
    for (uint256 i = 0; i < numWords; i++) {
      s_requests[_requestId].randomWords[i] %= numComb;
    }
    // check if jackpot
    bool jackpot = true;
    uint256 firstValue = s_requests[_requestId].randomWords[0];
    for (uint256 i = 1; i < numWords; i++) {
      if (s_requests[_requestId].randomWords[i] != firstValue) {
        jackpot = false;
        break;
      }
    }
    // send the reward
    if (jackpot) {
      require(funds < address(this).balance, "Insufficent funds");
      (bool success,) = s_requests[_requestId].playerAddress.call{value: funds}("Jackpot");
      require(success, "Failed to send the reward");
      emit Jackpot(s_requests[_requestId].playerAddress, s_requests[_requestId].randomWords);
      funds = 0;
    } else {
      emit NoHit(s_requests[_requestId].playerAddress, s_requests[_requestId].randomWords);
    }
  }

  function getRequestStatus(
    uint256 _requestId
  ) external view returns (uint256 paid, bool fulfilled, uint256[] memory randomWords) {
    require(s_requests[_requestId].paid > 0, "request not found");
    require(s_requests[_requestId].playerAddress == msg.sender);
    RequestStatus memory request = s_requests[_requestId];
    return (request.paid, request.fulfilled, request.randomWords);
  }

  function withdrawNative(
    uint256 amount
  ) external onlyOwner {
    (bool success,) = payable(owner()).call{value: amount}("Withdraw");
    require(success, "withdrawNative failed");
  }

  event Received(address, uint256);

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }
}
