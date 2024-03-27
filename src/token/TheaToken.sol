// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "../interfaces/IERC2612.sol";
import {OFTV2} from "@layerzerolabs/contracts/token/oft/v2/OFTV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";  // @audit-info IERC20 not used here. Inherited as part of OFTV2 most likely
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // @audit-info ERC20 not used here. Inherited as part of OFTV2 most likely

/**
    @title Prisma Governance Token  @audit-info search and replace Prisma -> Althea everywhere
    @notice Given as an incentive for users of the protocol. Can be locked in `TokenLocker`
            to receive lock weight, which gives governance power within the Prisma DAO.
 */
contract TheaToken is OFTV2, IERC2612 {
    // --- ERC20 Data ---

    string internal constant _NAME = "Thea Governance Token";
    string internal constant _SYMBOL = "THEA";
    string public constant version = "1";

    // --- EIP 2612 Data ---

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant permitTypeHash = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // Cache the domain separator as an immutable value, but also store the chain id that it
    // corresponds to, in order to invalidate the cached domain separator if the chain id changes.
    
    // cached as immutable to save gas for as long as the chainId doesn't change
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;

    address public locker;
    address public allocationVesting;

    // @audit-issue maxTotalSupply is not checked when minting
    uint256 public maxTotalSupply; // @audit-info max supply is known, so better store it as a constant, to save tons of gas (because it gets hardcoded in the bytecode instead of reading from storage)

    mapping(address => uint256) private _nonces;

    // --- Functions ---

    // @audit-issue during bootstrap period, owner can add new minters. Ownerhsip will be eventually transferred to the dao when Dao is ready

    constructor(address _layerZeroEndpoint, address _locker, uint8 _sharedDecimals)
    OFTV2(_NAME, _SYMBOL, _sharedDecimals, _layerZeroEndpoint) {
        bytes32 hashedName = keccak256(bytes(_NAME));
        bytes32 hashedVersion = keccak256(bytes(version));

        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, hashedName, hashedVersion);

        locker = _locker;
    }

    function setAllocationVestingAddress(address _allocationVesting) external onlyOwner {
        // Once the Allocation vesting is set, it cannot be ever updated
        require(allocationVesting == address(0), "AllocationVesting address already set");
        allocationVesting = _allocationVesting;
        // @audit-info missing event in state changing function
    }

    // @audit-info this is not really minting to the AllocationVesting. It mints to `to`, but it is invoked by the allocationVesting
    function mintToAllocationVesting(address to, uint256 amount) external {
        // Only allocationVesting is ever allowed to mint THEA tokens
        // @audit-issue validate that the maxSupply is not exceeded when minting
        require(msg.sender == allocationVesting, "Not allocationVesting");
        _mint(to, amount);
    }

    function setLockerAddress(address _locker) external onlyOwner {
        require(locker == address(0), "Locker address already set");
        locker = _locker;
        // @audit-info missing event in state changing function
    }

    function transferToLocker(address sender, uint256 amount) external returns (bool) {
        require(msg.sender == locker, "Not locker");
        _transfer(sender, locker, amount);
        return true;
    }

    // --- EIP 2612 functionality ---

    function domainSeparator() public view override returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
        }
    }

    function permit(
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(deadline >= block.timestamp, "PRISMA: expired deadline");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                keccak256(abi.encode(permitTypeHash, owner, spender, amount, _nonces[owner]++, deadline))
            )
        );
        // @audit-issue ecrecover is vulnerable to signature malleability, but I guess it is fine in this case
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, "PRISMA: invalid signature");
        _approve(owner, spender, amount);
    }

    function nonces(address owner) external view override returns (uint256) {
        // FOR EIP 2612
        return _nonces[owner];
    }

    // --- Internal operations ---

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name_, bytes32 version_) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, name_, version_, block.chainid, address(this)));
    }

    function _beforeTokenTransfer(address, address to, uint256) internal virtual override {
        require(to != address(this), "ERC20: transfer to the token address");
    }
}
