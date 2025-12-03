// SPDX License Identifier: MIT

pragma solidity ^0.8.13;

contract MockContract {

    uint256 public value;

    constructor(uint256 _value) {
        value = _value;
    }

    function setValue(uint256 _value) public {
        value = _value;
    }

}