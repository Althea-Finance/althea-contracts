// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/forge-std/src/Script.sol";
import {AltheaCore} from "src/core/AltheaCore.sol";
import {PriceFeed} from "src/core/PriceFeed.sol";
import {Factory} from "src/core/Factory.sol";
import {SortedTroves} from "src/core/SortedTroves.sol";
import {LiquidationManager} from "src/core/LiquidationManager.sol";
import {GasPool} from "src/core/GasPool.sol";
import {BorrowerOperations} from "src/core/BorrowerOperations.sol";
import {DebtToken} from "src/core/DebtToken.sol";
import {StabilityPool} from "src/core/StabilityPool.sol";

import {TheaToken} from "src/dao/TheaToken.sol";
import {InterimAdmin} from "src/dao/InterimAdmin.sol";
import {FeeReceiver} from "src/dao/FeeReceiver.sol";
import {TokenLocker} from "src/dao/TokenLocker.sol";
import {ITheaToken} from "src/interfaces/ITheaToken.sol";
import {AltheaVault} from "src/dao/Vault.sol";
import "script/sepolia/00constants.sol";
import "openzeppelin-contracts\contracts\utils\introspection\ERC1820Implementer.sol";

contract AltheaCoreDeployment is Script {
    AltheaCore altheaCore;
    PriceFeed priceFeed;
    FeeReceiver feeReceiver;
    TheaToken theaToken;
    TokenLocker tokenLocker;
    AltheaVault altheaVault;
    InterimAdmin interAdmin;
    SortedTroves sortedTroves;
    LiquidationManager liquidationManager;
    Factory factory;
    GasPool gasPool;
    BorrowerOperations borrowerOperations;
    DebtToken debtToken;
    StabilityPool stabilityPool;


    function setUp() public virtual {}

    function run() public {
        vm.startBroadcast();
        altheaCore = deployAltheaCore();
        vm.stopBroadcast();

        vm.startBroadcast();
        priceFeed = deployPriceFeed();
        altheaCore.setPriceFeed(address(priceFeed));
        vm.stopBroadcast();

        vm.startBroadcast();
        feeReceiver = deployFeeReceiver();
        vm.stopBroadcast();

        vm.startBroadcast();
        interimAdmin = deployInterimAdmin();
        vm.stopBroadcast();


        vm.startBroadcast();
        theaToken = deployTheaToken();
        vm.stopBroadcast();

        vm.startBroadcast();
        tokenLocker = deployTokenLocker();
        theaToken.setLockerAddress(address(tokenLocker));
        vm.stopBroadcast();

        vm.startBroadcast();
        sortedTroves = deploySortedTroves();
        vm.stopBroadcast();

        vm.startBroadcast();
        factory = deployFactory();
        vm.stopBroadcast();

        vm.startBroadcast();
        liquidationManager = deployLiquidationManager();
        vm.stopBroadcast();

        vm.startBroadcast();
        gasPool = deployGasPool();
        vm.stopBroadcast();

        vm.startBroadcast();
        borrowerOperations = deployBorrowerOperations();
        factory.setBorrowerOperationsAddress(address(borrowerOperations));
        liquidationManager.setBorrowerOperationsAddress(address(borrowerOperations));
        vm.stopBroadcast();

        vm.startBroadcast();
        debtToken = deployDebtToken();
        factory.setDebtTokenAddress(address(debtToken));
        borrowerOperations.setDebtTokenAddress(address(debtToken));
        vm.stopBroadcast();

        vm.startBroadcast();
        stabilityPool = deployStabilityPool();
        vm.stopBroadcast();

        vm.startBroadcast();
        altheaVault = deployAltheaVault();
        stabilityPool.setVaultAddress(address(altheaVault));
        vm.stopBroadcast();
    }

    function deployAltheaCore() internal returns (AltheaCore){
        altheaCore = new AltheaCore(
            OWNER_ADDRESS,
            GUARDIAN_ADDRESS,
            address(0), // Price feed. Will be set later
            FEE_RECEIVER_ADDRESS
        );
        return altheaCore;
    }


    function deployPriceFeed() internal returns (PriceFeed){
        address[] memory emptyArray = new address[](0);
        priceFeed = new PriceFeed(
            address(altheaCore),
            ETH_PRICEFEED,
            emptyArray
        );
        return priceFeed;
    }


    function deployFeeReceiver() internal returns (FeeReceiver){
        feeReceiver = new FeeReceiver(
            address(altheaCore)
        );
        return feeReceiver;
    }

    function deployInterimAdmin() internal returns (InterimAdmin){
        interAdmin = new InterimAdmin(address(altheaCore));
        return interAdmin;
    }


    function deployTheaToken() internal returns (TheaToken){
        theaToken = new TheaToken(
            address(0), // Vault. Will be set later
            address(LAYERZERO_ENDPOINT),
            address(0) // TokenLocker. Will be set later
        );
        return theaToken;
    }

    function deployTokenLocker() internal returns (TokenLocker){
        ITheaToken theaToken = ITheaToken(address(theaToken));

        uint256 lockToTokenRatio = 10 ** 18;
        //TODO: Frontend has to take this into account.
        //TODO: Can this actually have any other value?

        tokenLocker = new TokenLocker(
            address(altheaCore),
            theaToken,
            address(0), // IncentiveVoter. Will be set later
            OWNER_ADDRESS, // should be deployment manager, but owner is used
            lockToTokenRatio
        );
        return tokenLocker;
    }

    function deploySortedTroves() internal returns (SortedTroves){
        sortedTroves = new SortedTroves();
        return sortedTroves;
    }

    function deployFactory() internal returns (Factory){
        factory = new Factory(
            address(altheaCore),
            address(0), //debtToken. Will be set later
            address(0), //stabilityPool. Will be set later
            address(0), //borrowerOperations. Will be set later
            address(sortedTroves),
            address(0), // TroveManager. Will be set later
            address(0) // LiquidationManager. Will be set later
        );
        return factory;
    }

    function deployLiquidationManager() internal returns (LiquidationManager){

        uint gasCompensation = 200 * 10 ** 18;
        // in debt units, from Prisma

        liquidationManager = new LiquidationManager(
            address(0), // StabilityPool. Will be set later
            address(0), // borrowerOperations. Will be set later
            address(factory),
            gasCompensation
        );
        return liquidationManager;
    }

    function deployGasPool() internal returns (GasPool){
        gasPool = new GasPool();
        return gasPool;
    }

    function deployBorrowerOperations() internal returns (BorrowerOperations) {
        // taken from Prisma
        uint minNetDebt = 180 * 10 ** 18;

        // in debt units, from Prisma
        uint gasCompensation = 200 * 10 ** 18;


        borrowerOperations = new BorrowerOperations(
            address(altheaCore),
            address(0), // DebtToken. Will be set later
            address(factory),
            minNetDebt,
            gasCompensation
        );
        return borrowerOperations;
    }

    function deployDebtToken() internal returns (DebtToken){

        string memory name = "aUSD";
        string memory symbol = "aUSD";

        uint gasCompensation = 200 * 10 ** 18;

        debtToken = new DebtToken(
            name,
            symbol,
            address(0), // StabilityPool. Will be set later
            address(borrowerOperations),
            altheaCore,
            address(LAYERZERO_ENDPOINT),
            address(factory),
            address(gasPool),
            gasCompensation
        );
        return debtToken;
    }

    function deployStabilityPool() internal returns (StabilityPool) {
        stabilityPool = new StabilityPool(
            address(altheaCore),
            address(debtToken),
            address(0), //Vault. Will be set later
            address(factory),
            address(liquidationManager)
        );
        return stabilityPool;
    }

    function deployAltheaVault() internal returns (AltheaVault){
        altheaVault = new AltheaVault(
            address(altheaCore),
            theaToken,
            tokenLocker,
            address(0), // IncentiveVoter. Will be set later
            address(stabilityPool),
            OWNER_ADDRESS // TODO: should be deployment manager
        );
        return vault;
    }


}
