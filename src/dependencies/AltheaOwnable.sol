// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../interfaces/IAltheaCore.sol";

/**
 * @title Althea Ownable
 *     @notice Contracts inheriting `AltheaOwnable` have the same owner as `AltheaCore`.
 *             The ownership cannot be independently modified or renounced.
 */
contract AltheaOwnable {
    IAltheaCore public immutable ALTHEA_CORE;

    constructor(address _altheaCore) {
        ALTHEA_CORE = IAltheaCore(_altheaCore);
    }

    modifier onlyOwner() {
        require(msg.sender == ALTHEA_CORE.owner(), "Only owner");
        _;
    }

    function owner() public view returns (address) {
        return ALTHEA_CORE.owner();
    }

    function guardian() public view returns (address) {
        return ALTHEA_CORE.guardian();
    }
}
