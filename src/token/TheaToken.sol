// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {OFTV2} from "@layerzerolabs/contracts/token/oft/v2/OFTV2.sol";

/**
 * @title Prisma Governance Token  @audit-info search and replace Prisma -> Althea everywhere
 *     @notice Given as an incentive for users of the protocol. Can be locked in `TokenLocker`
 *             to receive lock weight, which gives governance power within the Prisma DAO.
 */
contract TheaToken is OFTV2 {
    string internal constant _NAME = "Thea Governance Token";
    string internal constant _SYMBOL = "THEA";

    // @audit review if we need this address, or it would be just a normal minter:
    // @audit consider if we should control in this contract, wether a mint comes from oThea redemptions, or vesting allocations, and control individual supplies?
    address public allocationVesting;
    
    // max total supply hardcoded and never exceeded
    uint256 public constant maxTotalSupply =  100_000_000 * 1e18; // 100 million THEA

    // allowed minters. 
    mapping(address => bool) public minters;

    event MinterStatusUpdated(address indexed minter, bool newStatus);

    error MinterStatusAlreadySet();
    error MaxSupplyExceeded();
    error UnauthorizedMinter();

    // @audit during bootstrap period, owner can add new minters. Ownerhsip will be eventually transferred to the dao when Dao is ready
    // @audit reviiew if we should limit the number of minters to a specific entity 

    constructor(address _layerZeroEndpoint, address _locker, uint8 _sharedDecimals)
        OFTV2(_NAME, _SYMBOL, _sharedDecimals, _layerZeroEndpoint)
    {}

    //////////////////////////// SETTERS (OnlyOwner) //////////////////////////////
    
    function setMinterStatus(address _minter, bool _enabled) external onlyOwner {
        if (minters[_minter] == _enabled) revert MinterStatusAlreadySet();

        minters[_minter] = _enabled;
        emit MinterStatusUpdated(_minter, _enabled);
    }

    //////////////////////////// EXTERNAL //////////////////////////////

    // minting zero amount is not dangerous here // review
    function mintTo(address to, uint256 amount) external {
        if (!minters[msg.sender]) revert UnauthorizedMinter();
        if (totalSupply() + amount > maxTotalSupply) revert MaxSupplyExceeded();
        
        _mint(to, amount);
    }

    //////////////////////////// INTERNAL //////////////////////////////

    function _beforeTokenTransfer(address, address to, uint256) internal virtual override {
        // @audit do we really need this?
        require(to != address(this), "ERC20: transfer to the token address");
    }
}
