// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUmbra {
  function sendEth(
    address payable receiver,
    uint256 tollCommitment,
    bytes32 pkx,
    bytes32 ciphertext
  ) external payable;

  function sendToken(
    address receiver,
    address tokenAddr,
    uint256 amount,
    bytes32 pkx,
    bytes32 ciphertext
  ) external payable;
}

contract UmbraBatchSend {
  IUmbra internal constant umbra = IUmbra(0xFb2dc580Eed955B528407b4d36FfaFe3da685401);

  struct SendEth {
    address payable receiver;
    uint256 amount;
    bytes32 pkx;
    bytes32 ciphertext;
  }

  struct SendToken {
    address receiver;
    address tokenAddr;
    uint256 amount;
    bytes32 pkx;
    bytes32 ciphertext;
  }
  
  error ValueMismatch();
  event Log(address indexed caller, uint256 indexed value, string message);

  function batchSendEth(uint256 _tollCommitment, SendEth[] calldata _params) external payable {
    uint256 valAccumulator;

    for (uint256 i = 0; i < _params.length; i++) {
      //amount to be sent per receiver
      uint256 _amount = _params[i].amount;
      valAccumulator += _amount;
      valAccumulator += _tollCommitment;
    }

    if(msg.value != valAccumulator) revert ValueMismatch();
    _batchSendEth(_tollCommitment, _params);
  }

  function batchSendTokens(uint256 _tollCommitment, SendToken[] calldata _params) external payable {
    if(msg.value != _tollCommitment * _params.length) revert ValueMismatch();
    _batchSendTokens(_tollCommitment, _params);
  }

  function batchSend(
    uint256 _tollCommitment,
    SendEth[] calldata _ethParams,
    SendToken[] calldata _tokenParams
  ) external payable {
    uint256 valAccumulator;

    for (uint256 i = 0; i < _ethParams.length; i++) {
      //amount to be sent per receiver
      uint256 _amount = _ethParams[i].amount;
      valAccumulator += _amount;
      valAccumulator += _tollCommitment;
    }

    if(msg.value != valAccumulator + _tollCommitment * _tokenParams.length) revert ValueMismatch();

    _batchSendEth(_tollCommitment, _ethParams);
    _batchSendTokens(_tollCommitment, _tokenParams);
    emit Log(msg.sender, msg.value, "called batchSend");
  }

  function _batchSendEth(uint256 _tollCommitment, SendEth[] calldata _params) internal {
    for (uint256 i = 0; i < _params.length; i++) {
      umbra.sendEth{value: _params[i].amount + _tollCommitment}(_params[i].receiver, _tollCommitment, _params[i].pkx, _params[i].ciphertext);
    }
    emit Log(msg.sender, msg.value, "called batchSendEth");
  }

  function _batchSendTokens(uint256 _tollCommitment, SendToken[] calldata _params) internal {
    for (uint256 i = 0; i < _params.length; i++) {
      uint256 _amount = _params[i].amount;
      address _tokenAddr = _params[i].tokenAddr;
      IERC20 token = IERC20(address(_tokenAddr));

      SafeERC20.safeTransferFrom(token, msg.sender, address(this), _amount);

      if (token.allowance(address(this), address(umbra)) == 0) {
        SafeERC20.safeApprove(token, address(umbra), type(uint256).max);
      }

      umbra.sendToken{value: _tollCommitment}(
        _params[i].receiver,
        _params[i].tokenAddr,
        _amount,
        _params[i].pkx,
        _params[i].ciphertext
      );
    }
    emit Log(msg.sender, msg.value, "called batchSendTokens");
  }
}
