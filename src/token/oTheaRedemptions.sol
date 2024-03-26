// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {AltheaOwnable} from "../dependencies/AltheaOwnable.sol";

/**
    @title oTHEA Redemptions manager
    @notice Manages the redemption of oTHEA tokens for THEA tokens, handling also the payment in native METIS
 */

// todo add the necessary ihnterfaces to the /interfaces folder

interface ITHEA {
    function mintTo(address to, uint256 amount) external;
}

interface IoTHEA {
    function burnFrom(address from, uint256 amount) external;
}

contract oTheaRedemptions is AltheaOwnable {

    ITHEA public immutable THEA;
    IoTHEA public immutable oTHEA;

    IPriceFeed public priceFeed;

    uint256 public redemptionDiscountBp = 2500; // 25% discount  // in basis points
    uint256 constant BASIS_POINTS = 10000;

    error NotEnoughMetisValue();
    error TooMuchMetisValue();
    error InvalidParameter();

    event PriceFeedSet(address priceFeed);
    event DiscountSet(uint256 discountBp);
    event Redeemed(address indexed redeemer, address theaReceiver, uint256 oTheaAmount, uint256 metisValue);

    constructor(address theaToken, address oTheaToken, address _altheaCore) AltheaOwnable(_altheaCore) {
        THEA = ITHEA(theaToken);
        oTHEA = IoTHEA(oTheaToken);
    }

    ///////////////////////////  EXTERNAL /////////////////////////////

    function redeem(uint256 oTheaAmount, address theaReceiver) external payable {
        require(oTheaAmount > 0, "Invalid oTHEA amount");
        // todo input validations? theaReceiver this contract ? etc

        // convert othea to metis, using oracles
        uint256 amountInMetisValue = _convertTheaToMetis(oTheaAmount);
        // apply discount
        uint256 requiredMetisValue = _applyCurrentDiscount(amountInMetisValue);

        // check msg.value is correct
        // we accept more value than the required to account for slippage in case the oracle price fluctuates.
        // The remaining value is returned to the user
        if (msg.value < requiredMetisValue) revert NotEnoughMetisValue();
        // max slippage is controlled by the user with msg.value, but
        // only accept a max 10% slippage in case users send a completely wrong amount;
        if (msg.value - requiredMetisValue > requiredMetisValue / 10) revert TooMuchMetisValue();

        // we need the oTHEA token to have this burnFrom function
        // burn oTHEA from msg.sender // todo make sure this revert if not enough balance, etc
        oTHEA.burnFrom(msg.sender, oTheaAmount);

        // mint THEA to theaReceiver
        THEA.mintTo(theaReceiver, amountInMetisValue);

        emit Redeemed(msg.sender, theaReceiver, oTheaAmount, amountInMetisValue);

        // return remaining msg.value to msg.sender ... @audit potential reentrancy  // no state changes after this
        uint256 remainingMetis = msg.value - requiredMetisValue;
        // Intentionally not checking the bool return value of the call. As returning remaining value is not critical
        // We don't want redemptions to fail
        (bool success, ) = payable(msg.sender).call{value: remainingMetis}("");
        {success;} // silence the annoying warning from above
    }

    ///////////////////////////  OnlyOwner SETTERS  /////////////////////////////

    function setPriceFeed(address _priceFeed) external onlyOwner {
        // todo input validations?
        priceFeed = IPriceFeed(_priceFeed);
        emit PriceFeedSet(_priceFeed);
    }

    // discountBp is in basis points (10000 == 100% discount)
    // if discountBp = 2500, then 25% discount, which means that the remaining 75% would need to be paid in METIS
    function setRedemptionDiscount(uint256 discountBp) external onlyOwner {
        // intentionally allowing 0% and 100% discounts
        if (discountBp > BASIS_POINTS) revert InvalidParameter();
        redemptionDiscountBp = discountBp;
        emit DiscountSet(discountBp);
    }

    ///////////////////////////  VIEW  /////////////////////////////

    // visibility cannot be view, because PriceFeed can be state-changing ...
    function getEstimatedRequiredMetisForRedemption(uint256 oTheaAmount) public returns (uint256 estimatedValue) {
        estimatedValue = _applyCurrentDiscount(_convertTheaToMetis(oTheaAmount));
    }

    ///////////////////////////  INTERNAL  /////////////////////////////

    // visibility cannot be view, because PriceFeed can be state-changing ...
    function _convertTheaToMetis(uint256 theaAmount) internal returns (uint256 amountInMetisValue) {
        uint256 usdPerThea = priceFeed.fetchPrice(address(THEA)); // units [USD/THEA]  // todo make sure units and decimals are correct
        // todo: input here the native METIS_FEED to get Metis to USD price
        uint256 usdPerMetis = priceFeed.fetchPrice(address(0)); // units [USD/METIS] // todo make sure units and decimals are correct
        // calculate the amount of METIS required
        // note that THEA:oTHEA redemptions are 1:1
        // units : THEA * [USD/THEA] / [USD/METIS] = [METIS]
        amountInMetisValue = (theaAmount * usdPerThea) / usdPerMetis;
    }

    // discount will subject to change via dao proposal
    function _applyCurrentDiscount(uint256 amount) internal view returns (uint256 amountWithDiscount) {
        amountWithDiscount = (amount * (BASIS_POINTS - redemptionDiscountBp)) / BASIS_POINTS;
    }
}
