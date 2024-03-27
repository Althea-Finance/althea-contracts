// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OFTV2} from "@layerzerolabs/contracts/token/oft/v2/OFTV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // @audit-info IERC20 not used here. Inherited as part of OFTV2 most likely
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // @audit-info ERC20 not used here. Inherited as part of OFTV2 most likely

/**
 * @title Prisma Governance Token  @audit-info search and replace Prisma -> Althea everywhere
 *     @notice Given as an incentive for users of the protocol. Can be locked in `TokenLocker`
 *             to receive lock weight, which gives governance power within the Prisma DAO.
 */
contract TheaToken is OFTV2 {
    // --- ERC20 Data ---

    string internal constant _NAME = "Thea Governance Token";
    string internal constant _SYMBOL = "THEA";

    address public locker;
    address public allocationVesting;

    // @audit-issue maxTotalSupply is not checked when minting
    uint256 public maxTotalSupply; // @audit-info max supply is known, so better store it as a constant, to save tons of gas (because it gets hardcoded in the bytecode instead of reading from storage)

    mapping(address => uint256) private _nonces;

    // @audit-issue during bootstrap period, owner can add new minters. Ownerhsip will be eventually transferred to the dao when Dao is ready

    constructor(address _layerZeroEndpoint, address _locker, uint8 _sharedDecimals)
        OFTV2(_NAME, _SYMBOL, _sharedDecimals, _layerZeroEndpoint)
    {
        locker = _locker;
    }

    //////////////////////////// SETTERS (OnlyOwner) //////////////////////////////

    function setAllocationVestingAddress(address _allocationVesting) external onlyOwner {
        // Once the Allocation vesting is set, it cannot be ever updated
        require(allocationVesting == address(0), "AllocationVesting address already set");
        allocationVesting = _allocationVesting;
        // @audit-info missing event in state changing function
    }

    function setLockerAddress(address _locker) external onlyOwner {
        require(locker == address(0), "Locker address already set");
        locker = _locker;
        // @audit-info missing event in state changing function
    }

    //////////////////////////// EXTERNAL //////////////////////////////

    // @audit-info this is not really minting to the AllocationVesting. It mints to `to`, but it is invoked by the allocationVesting
    function mintToAllocationVesting(address to, uint256 amount) external {
        // Only allocationVesting is ever allowed to mint THEA tokens
        // @audit-issue validate that the maxSupply is not exceeded when minting
        require(msg.sender == allocationVesting, "Not allocationVesting");
        _mint(to, amount);
    }

    function transferToLocker(address sender, uint256 amount) external returns (bool) {
        require(msg.sender == locker, "Not locker");
        _transfer(sender, locker, amount);
        return true;
    }

    //////////////////////////// INTERNAL //////////////////////////////

    function _beforeTokenTransfer(address, address to, uint256) internal virtual override {
        require(to != address(this), "ERC20: transfer to the token address");
    }
}
