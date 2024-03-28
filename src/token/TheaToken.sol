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
    uint256 public maxTotalSupply = 10 ** 8 * 10 ** 18; // 100 million THEA

    mapping(address => uint256) private _nonces;

    mapping(address => bool) public minters;

    event MinterAdded(address indexed minter);
    event LockerAddressSet(address indexed locker);

    // @audit-issue during bootstrap period, owner can add new minters. Ownerhsip will be eventually transferred to the dao when Dao is ready

    constructor(address _layerZeroEndpoint, address _locker, uint8 _sharedDecimals)
        OFTV2(_NAME, _SYMBOL, _sharedDecimals, _layerZeroEndpoint)
    {
        locker = _locker;
    }

    //////////////////////////// SETTERS (OnlyOwner) //////////////////////////////

    function addMinter(address _minter) external onlyOwner {
        minters[_minter] = true;
        emit MinterAdded(_minter);
    }

    function setLockerAddress(address _locker) external onlyOwner {
        require(locker == address(0), "Locker address already set");
        locker = _locker;
        emit LockerAddressSet(_locker);
    }

    //////////////////////////// EXTERNAL //////////////////////////////

    function mintTo(address to, uint256 amount) external {
        require(totalSupply() + amount <= maxTotalSupply, "Exceeds maxTotalSupply");
        require(minters[msg.sender], "Not allowed minter");
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
