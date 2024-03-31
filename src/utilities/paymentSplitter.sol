// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

/// @title Payment Splitter contract for Althea team
/// @notice Once set the shares, the split function distributes the balance of any erc20 or native tokens into addresses balances
/// @dev    Once deployed, the percentages (shares) cannot be modified
contract AltheaPaymentSplitter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // shares of each payee
    mapping(address => uint256) public shares;
    // If a new payee is needed, a new splitter contract needs to be deployed
    address[] public payees;

    // total shares among which to distribute payments
    uint256 public totalShares;

    // EVENTS
    event ShareAllocated(address _payee, uint256 _share);
    event NativeTokensSent(address _payee, uint256 amount);
    event NativeTokenSkippedToContract(address _payeeContract, uint256 amount);

    // ERRORs
    error LengthsMustMatch();
    error NoBalanceToDistribute();
    error AlreadyHasShares();

    constructor(address[] memory _payees, uint256[] memory _shares) {
        if (_payees.length != _shares.length) revert LengthsMustMatch();

        uint256 _totalShares = 0;
        for (uint256 i; i < _payees.length; i++) {
            address _payee = _payees[i];
            uint256 _share = _shares[i];

            if (shares[_payee] > 0) revert AlreadyHasShares();

            _totalShares += _share;
            shares[_payee] = _share;
            payees.push(_payee);
            emit ShareAllocated(_payee, _share);
        }
        require(payees.length > 1, "Set more than on payee");

        // only update storage at the end
        totalShares = _totalShares;
    }

    /// @notice distributes all tokens in the contract balance among the payees
    ///         Use token=address(0) to distribute native tokens
    /// @dev    No access control as the tokens reach the payees regardless of the msg.sender
    function distribute(address token) external nonReentrant {
        uint256 balance = (token == address(0)) ? address(this).balance : IERC20(token).balanceOf(address(this));
        if (balance == 0) revert NoBalanceToDistribute();

        uint256 _totalShares = totalShares; // cash to memory to save gas
        uint256 distributed;
        uint256 numberOfPayees = payees.length;
        // only iterate until the second last. The last is processed outside the iteration
        for (uint256 i; i < numberOfPayees - 1; i++) {
            address _payee = payees[i];
            uint256 _amount = (balance * shares[_payee]) / _totalShares;

            distributed += _amount;
            _handlePayment(token, _amount, _payee);
        }

        // this last one can differ from the rest in dust amounts. This is to avoid dust staying in this contract
        uint256 lastAmount = balance - distributed;
        _handlePayment(token, lastAmount, payees[numberOfPayees]);
    }

    /// @dev ignores output from tranfers, to avoid all the funds stuck in contract if one transfer fails
    function _handlePayment(address token, uint256 amount, address to) internal {
        if (token == address(0)) {
            // if payee is a contract, skip it to avoid reentrancy or DoS attacks
            if (address(to).code.length > 0) {
                emit NativeTokenSkippedToContract(to, amount);
            } else {
                // intentionally using send() here, as we don't want the call 
                // to revert DoSing the other payees. This payee losses his payement.
                // If an EIP changed the gas configs, a new splitter contract can be deployed
                (bool success) = payable(to).send(amount);
                {success;} // just to silence warnings
                emit NativeTokensSent(to, amount);
            }
        } else {
            // ERC20 has its own event already
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
