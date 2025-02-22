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


  function spin() external payable returns (uint256 requestId){
    require(msg.value >= 0.01 ether, "0.01 ether to play");
    uint32 callbackGasLimit = 250_000;
    uint16 requestConfirmations = 3; 
    uint32 numWords = 3;
    bytes memory extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}));
    uint256 paid;
    (requestId, paid) = requestRandomnessPayInNative(callbackGasLimit, requestConfirmations, numWords, extraArgs);
    s_requests[requestId] = RequestStatus({paid: paid, randomWords: new uint256[](0), fulfilled: false, native: true});
    emit WrapperRequestMade(requestId, paid);
    return requestId;
  }


  function getCombo(uint256 _requestId) external view returns (uint256[] memory combo) {
    require(s_requests[_requestId].paid > 0, "request not found");
    RequestStatus memory request = s_requests[_requestId];
    combo = request.randomWords;
    for(uint256 i = 0; i <3; i++){
      combo[i] = combo[i] % 3;
    }
    return combo;
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







